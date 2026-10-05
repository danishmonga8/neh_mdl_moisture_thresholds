"""
R1C5_JJAS_TSS_Protocol_v2.py  --  PRE-SPECIFIED validation protocol

Written and fixed BEFORE any result was computed. The PRIMARY result is
whatever protocol C gives, even if another variant happens to score higher.

Unchanged from the earlier version (user-specified scope):
  * JJAS storms only; only years in which the station had >=1 landslide
  * N* fixed per station from all_stations_neh.xlsx (Ideal_lag)
  * leave-one-year-out CV; predictors standardised on the TRAIN fold only
  * ridge logistic regression, lambda = 1/2.5^2 (Gelman et al. 2008),
    intercept(s) unpenalised; identical settings for both models
  * 95% CI by year-block bootstrap, 2000 reps, seed 20240916

Two principled changes (decided a priori, applied to BOTH models):
  1. Classification threshold = TRAINING-fold prevalence, instead of searching
     for the TSS-maximising cutoff in-sample. For a calibrated model the
     TSS (Youden J) optimum is exactly where p = base rate (likelihood
     ratio = 1); logistic regression with an unpenalised intercept is
     calibrated-in-the-large on its training data. Removes a noisy,
     overfit-prone search step (Liu et al. 2005; Freeman & Moisen 2008).
  2. log(1+x) of rainfall-derived predictors (TR, API). Standard in
     ED / ID threshold work (log-log space); confirmed by an outcome-blind
     skewness check (TR skew 2.2-4.5). Seff is bounded [0,1] and roughly
     symmetric (|skew| < 0.4) -> left untransformed.

Variants reported (ALL are reported, none dropped):
  A  previous version: raw predictors, in-sample TSS-max cutoff
  B  raw predictors, prevalence cutoff             (ablation of change 1)
  C  log predictors, prevalence cutoff             <-- PRIMARY
  D  as C, but one model POOLED over the 5 stations (station-specific
     intercepts, shared slopes on within-station z-scored predictors,
     station-specific prevalence cutoffs) -- pre-specified sensitivity
     analysis for the small-sample limitation (partial borrowing of
     strength). Answers a different question (regional vs local model),
     so it is reported as a sensitivity result, not as the primary one.

Not done, deliberately: no tuning of lambda, N*, cutoff, transforms or
feature set on test performance; no post-hoc dropping of stations/years;
no change to the landslide definition; no in-sample TSS reported as skill.
"""
import os
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
_WIN_ROOT = os.environ.get("NEH_ROOT", os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "data"))
_MNT_ROOT = _WIN_ROOT
ROOT = _WIN_ROOT if os.path.isdir(_WIN_ROOT) else _MNT_ROOT
DATA_XLSX = os.path.join(ROOT, "supplementary_data", "Supplementary_Dataset_S3_Predictive_Modeling_Dataset.xlsx")
META_XLSX = os.path.join(ROOT, "all_stations_neh.xlsx")
TABLE_OUT = os.path.join(SCRIPT_DIR, "Table_R1C5_JJAS_TwoModel_Protocol_v2.xlsx")
FIG_OUT = os.path.join(SCRIPT_DIR, "Figure_R1C5_JJAS_TSS_Protocol_v2_300dpi.png")

STATIONS = ["Darjeeling", "Sechu", "Gangtok", "Kohima", "Singla Bazar"]
MODELS = ["Rainfall only", "Rainfall + saturation"]
RIDGE = 1.0 / 2.5 ** 2
N_BOOT = 2000
SEED = 20240916


# ---------------------------------------------------------------- core fit
def fit_logreg(X, y, pen_mask, ridge=RIDGE, n_iter=200, tol=1e-9):
    p = X.shape[1]
    pen = np.where(pen_mask, ridge, 0.0)
    beta = np.zeros(p)
    for _ in range(n_iter):
        mu = 1.0 / (1.0 + np.exp(-np.clip(X @ beta, -35, 35)))
        W = np.clip(mu * (1 - mu), 1e-9, None)
        grad = X.T @ (y - mu) - pen * beta
        H = -(X * W[:, None]).T @ X - np.diag(pen)
        try:
            step = np.linalg.solve(H, grad)
        except np.linalg.LinAlgError:
            step = np.linalg.lstsq(H, grad, rcond=None)[0]
        new = beta - step
        if np.max(np.abs(new - beta)) < tol:
            beta = new
            break
        beta = new
    return beta


def proba(X, b):
    return 1.0 / (1.0 + np.exp(-np.clip(X @ b, -35, 35)))


def tss_max_cutoff(y, p):
    best_c, best = 0.5, -np.inf
    for c in np.concatenate([[0.0], np.unique(p), [1.0]]):
        yh = p >= c
        tp = np.sum(yh & (y == 1)); fn = np.sum(~yh & (y == 1))
        fp = np.sum(yh & (y == 0)); tn = np.sum(~yh & (y == 0))
        t = (tp / (tp + fn) if tp + fn else 0) + (tn / (tn + fp) if tn + fp else 0) - 1
        if t > best:
            best, best_c = t, c
    return best_c


def confusion(y, yh):
    tp = int(np.sum((yh == 1) & (y == 1))); fp = int(np.sum((yh == 1) & (y == 0)))
    fn = int(np.sum((yh == 0) & (y == 1))); tn = int(np.sum((yh == 0) & (y == 0)))
    return tp, fp, fn, tn


def tss_of(tp, fp, fn, tn):
    return (tp / (tp + fn) if tp + fn else 0) + (tn / (tn + fp) if tn + fp else 0) - 1


def auc_of(y, s):
    pos, neg = s[y == 1], s[y == 0]
    if len(pos) == 0 or len(neg) == 0:
        return np.nan
    r = pd.Series(np.concatenate([pos, neg])).rank().to_numpy()
    return (r[:len(pos)].sum() - len(pos) * (len(pos) + 1) / 2) / (len(pos) * len(neg))


def year_block_ci(y, yh, yr, years):
    rng = np.random.default_rng(SEED)
    years = np.array(years)
    out = np.empty(N_BOOT)
    for b in range(N_BOOT):
        tp = fp = fn = tn = 0
        for yy in rng.choice(years, size=len(years), replace=True):
            m = yr == yy
            a, c, d_, e = confusion(y[m], yh[m])
            tp += a; fp += c; fn += d_; tn += e
        out[b] = tss_of(tp, fp, fn, tn)
    return np.percentile(out, [2.5, 97.5])


# ---------------------------------------------------------------- data
def load():
    df = pd.read_excel(DATA_XLSX, sheet_name="Dataset_S3_Modeling")
    meta = pd.read_excel(META_XLSX, sheet_name="Sheet1")
    meta.columns = [str(c).strip() for c in meta.columns]
    meta["Station"] = meta["Station"].astype(str).str.strip()
    parts = []
    for s in STATIONS:
        ns = int(meta.loc[meta.Station == s, "Ideal_lag"].iloc[0])
        d = df[df.Station == s].copy()
        d["month"] = pd.to_datetime(d["Storm_start"]).dt.month
        d = d[d.month.isin([6, 7, 8, 9])]
        yrs = d.loc[d.Landslide_status == 1, "Year"].unique()
        d = d[d.Year.isin(yrs)].copy()
        d["API_fixed"] = d[f"API_{ns}"].astype(float)
        d["Nstar"] = ns
        parts.append(d)
    return pd.concat(parts, ignore_index=True)


def features(d, model, log_rain):
    tr = np.log1p(d["TR_mm"].to_numpy(float)) if log_rain else d["TR_mm"].to_numpy(float)
    if model == "Rainfall only":
        return tr[:, None]
    api = np.log1p(d["API_fixed"].to_numpy(float)) if log_rain else d["API_fixed"].to_numpy(float)
    return np.column_stack([tr, api, d["Seff_lag1"].to_numpy(float)])


# ---------------------------------------------------------------- per-station (A, B, C)
def per_station(D, log_rain, cutoff_rule):
    rows = []
    for s in STATIONS:
        d = D[D.Station == s].reset_index(drop=True)
        years = sorted(d.Year.unique())
        for model in MODELS:
            X_all = features(d, model, log_rain)
            y_all = d["Landslide_status"].to_numpy(float)
            oy, oh, op, oyr = [], [], [], []
            for ty in years:
                tr_m = (d.Year != ty).to_numpy(); te_m = ~tr_m
                mu = X_all[tr_m].mean(0); sd = X_all[tr_m].std(0); sd[sd == 0] = 1
                Xtr = np.column_stack([np.ones(tr_m.sum()), (X_all[tr_m] - mu) / sd])
                Xte = np.column_stack([np.ones(te_m.sum()), (X_all[te_m] - mu) / sd])
                pm = np.array([False] + [True] * X_all.shape[1])
                b = fit_logreg(Xtr, y_all[tr_m], pm)
                ptr, pte = proba(Xtr, b), proba(Xte, b)
                c = y_all[tr_m].mean() if cutoff_rule == "prevalence" else tss_max_cutoff(y_all[tr_m], ptr)
                oy.append(y_all[te_m]); oh.append((pte >= c).astype(int)); op.append(pte)
                oyr.append(np.full(te_m.sum(), ty))
            oy, oh, op, oyr = map(np.concatenate, (oy, oh, op, oyr))
            tp, fp, fn, tn = confusion(oy, oh)
            lo, hi = year_block_ci(oy, oh, oyr, years)
            rows.append(dict(Station=s, Model=model, TP=tp, FP=fp, FN=fn, TN=tn,
                             TSS=tss_of(tp, fp, fn, tn), CI_lo=lo, CI_hi=hi,
                             AUC=auc_of(oy, op), Nstar=int(d.Nstar.iloc[0]),
                             n_years=len(years), n_events=len(d), n_pos=int(y_all.sum())))
    return pd.DataFrame(rows)


# ---------------------------------------------------------------- pooled (D)
def pooled(D):
    D = D.reset_index(drop=True)
    st_idx = D.Station.map({s: i for i, s in enumerate(STATIONS)}).to_numpy()
    years = sorted(D.Year.unique())
    y_all = D["Landslide_status"].to_numpy(float)
    rows = []
    for model in MODELS:
        F = features(D, model, log_rain=True)
        pred = np.full(len(D), -1); prob = np.full(len(D), np.nan)
        for ty in years:
            tr_m = (D.Year != ty).to_numpy(); te_m = ~tr_m
            if te_m.sum() == 0:
                continue
            Z = np.empty_like(F)
            for i in range(len(STATIONS)):  # within-station z-score, train stats only
                ms = st_idx == i; mt = ms & tr_m
                mu = F[mt].mean(0); sd = F[mt].std(0); sd[sd == 0] = 1
                Z[ms] = (F[ms] - mu) / sd
            dummies = np.eye(len(STATIONS))[st_idx]
            X = np.column_stack([dummies, Z])
            pm = np.array([False] * len(STATIONS) + [True] * F.shape[1])
            b = fit_logreg(X[tr_m], y_all[tr_m], pm)
            pte = proba(X[te_m], b)
            cut = np.array([y_all[tr_m & (st_idx == i)].mean() for i in range(len(STATIONS))])
            pred[te_m] = (pte >= cut[st_idx[te_m]]).astype(int); prob[te_m] = pte
        for i, s in enumerate(STATIONS):
            m = st_idx == i
            yy, hh, pp, yr = y_all[m], pred[m], prob[m], D.Year.to_numpy()[m]
            tp, fp, fn, tn = confusion(yy, hh)
            lo, hi = year_block_ci(yy, hh, yr, sorted(np.unique(yr)))
            rows.append(dict(Station=s, Model=model, TP=tp, FP=fp, FN=fn, TN=tn,
                             TSS=tss_of(tp, fp, fn, tn), CI_lo=lo, CI_hi=hi, AUC=auc_of(yy, pp),
                             Nstar=int(D.loc[m, "Nstar"].iloc[0]), n_years=len(np.unique(yr)),
                             n_events=int(m.sum()), n_pos=int(yy.sum())))
    return pd.DataFrame(rows)


def fmt(df):
    o = df.copy()
    o["95% CI"] = [f"{a:.2f}\u2013{b:.2f}" for a, b in zip(o.CI_lo, o.CI_hi)]
    o["TSS"] = o.TSS.round(2); o["AUC"] = o.AUC.round(2)
    return o[["Station", "Model", "TP", "FP", "FN", "TN", "TSS", "95% CI", "AUC",
              "Nstar", "n_years", "n_events", "n_pos"]]


def figure(df, path):
    BLUE, TEAL = "#1f5fa8", "#1a9c76"
    fig, ax = plt.subplots(figsize=(10, 6.2), dpi=100)
    x = np.arange(len(STATIONS)); w = 0.36
    for i, (m, col) in enumerate(zip(MODELS, [BLUE, TEAL])):
        r = df[df.Model == m].set_index("Station").loc[STATIONS]
        xp = x + (i - 0.5) * w
        ax.bar(xp, r.TSS, width=w, color=col, edgecolor="black", linewidth=0.6, label=m, zorder=3)
        ax.errorbar(xp, r.TSS, yerr=[r.TSS - r.CI_lo, r.CI_hi - r.TSS], fmt="none",
                    ecolor="black", elinewidth=1.3, capsize=4, zorder=4)
    ax.axhline(0, color="black", linewidth=0.8)
    ax.set_xticks(x); ax.set_xticklabels(STATIONS, fontsize=12)
    lo = min(0.0, np.floor(df.CI_lo.min() * 10) / 10)
    ax.set_ylim(lo, 1.0)
    ax.set_ylabel("Out-of-sample True Skill Statistic (TSS)", fontsize=12.5)
    ax.spines["top"].set_visible(False); ax.spines["right"].set_visible(False)
    ax.tick_params(axis="y", labelsize=11)
    ax.legend(loc="upper right", frameon=False, fontsize=11.5)
    fig.tight_layout(); fig.savefig(path, dpi=300, facecolor="w"); plt.close(fig)


if __name__ == "__main__":
    D = load()
    A = per_station(D, log_rain=False, cutoff_rule="tss_max")
    B = per_station(D, log_rain=False, cutoff_rule="prevalence")
    C = per_station(D, log_rain=True, cutoff_rule="prevalence")
    Dp = pooled(D)
    # keep every table in the same station-major, model-minor order
    order = {st: i for i, st in enumerate(STATIONS)}
    Dp = Dp.assign(_s=Dp.Station.map(order), _m=Dp.Model.map({m: i for i, m in enumerate(MODELS)})) \
           .sort_values(["_s", "_m"]).drop(columns=["_s", "_m"]).reset_index(drop=True)
    for T_ in (A, B, C):
        assert list(T_.Station) == list(Dp.Station) and list(T_.Model) == list(Dp.Model)
    with pd.ExcelWriter(TABLE_OUT) as xw:
        fmt(C).to_excel(xw, sheet_name="PRIMARY_C", index=False)
        fmt(Dp).to_excel(xw, sheet_name="Sensitivity_D_pooled", index=False)
        fmt(A).to_excel(xw, sheet_name="Ablation_A_previous", index=False)
        fmt(B).to_excel(xw, sheet_name="Ablation_B_prevcutoff", index=False)
    figure(C, FIG_OUT)
    comp = pd.DataFrame({"Station": C.Station, "Model": C.Model,
                         "A_prev": A.TSS.round(3), "B_prevcut": B.TSS.round(3),
                         "C_PRIMARY": C.TSS.round(3), "D_pooled": Dp.TSS.round(3),
                         "C_AUC": C.AUC.round(3), "D_AUC": Dp.AUC.round(3)})
    pd.set_option("display.width", 200)
    print(comp.to_string(index=False))
    print("\nPRIMARY (C):"); print(fmt(C).to_string(index=False))
    print("\nSENSITIVITY (D pooled):"); print(fmt(Dp).to_string(index=False))
    print("\nSaved", TABLE_OUT, FIG_OUT)
