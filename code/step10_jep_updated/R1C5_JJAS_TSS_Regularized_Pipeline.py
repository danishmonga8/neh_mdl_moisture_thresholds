"""
R1C5_JJAS_TSS_Regularized_Pipeline.py

Rebuilds the two-model (Rainfall only vs Rainfall + saturation) out-of-sample
TSS table and bar chart for 5 stations (Darjeeling, Sechu, Gangtok, Kohima,
Singla Bazar), using:

  - JJAS months only (Storm_start month in {6,7,8,9})
  - only years where that station has >=1 landslide-associated JJAS storm
  - N* FIXED per station (from all_stations_neh.xlsx, Ideal_lag column),
    never reselected inside a fold
  - leave-one-year-out cross-validation (grouped by Year) on that
    JJAS+landslide-year subset only
  - per outer fold: standardize predictors on TRAIN only, fit logistic
    regression by Newton-Raphson with a FIXED, a-priori weakly-informative
    ridge penalty (lambda = 1/2.5^2 ~= 0.16, Gelman et al. 2008 default
    prior scale for standardized logistic-regression coefficients;
    intercept left unpenalized -- chosen once, not tuned to any outcome),
    pick the classification cutoff that maximizes TSS on the TRAINING
    fold itself (in-sample, matches this project's own
    Cutoff_M*/InnerTSS_M* convention), apply that cutoff to the held-out
    year
  - pooled out-of-fold confusion matrix -> TSS
  - 95% CI via year-block bootstrap (resample outer years with
    replacement), 2000 reps, seed 20240916 (same convention as this
    project's other bootstrap tables)

Outputs (written next to this script):
  Table_R1C5_JJAS_TwoModel_UpdatedNstar_REG.xlsx
  Figure_R1C5_JJAS_TSS_UpdatedNstar_REG_300dpi.png

Source data (read only, not modified):
  supplementary_data\Supplementary_Dataset_S3_Predictive_Modeling_Dataset.xlsx
     (sheet Dataset_S3_Modeling)
  all_stations_neh.xlsx (sheet Sheet1, column Ideal_lag)
"""
import os
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

# ------------------------------------------------------------------
# 0) Paths
# ------------------------------------------------------------------
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

# Data root: NEH_ROOT if set, otherwise the data/ folder of the repository.
_WIN_ROOT = os.environ.get("NEH_ROOT", os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "data"))
_MNT_ROOT = _WIN_ROOT
DATA_ROOT = _WIN_ROOT if os.path.isdir(_WIN_ROOT) else _MNT_ROOT

DATA_XLSX = os.path.join(DATA_ROOT, "supplementary_data",
                          "Supplementary_Dataset_S3_Predictive_Modeling_Dataset.xlsx")
META_XLSX = os.path.join(DATA_ROOT, "all_stations_neh.xlsx")

TABLE_OUT = os.path.join(SCRIPT_DIR, "Table_R1C5_JJAS_TwoModel_UpdatedNstar_REG.xlsx")
FIG_OUT   = os.path.join(SCRIPT_DIR, "Figure_R1C5_JJAS_TSS_UpdatedNstar_REG_300dpi.png")

STATIONS = ["Darjeeling", "Sechu", "Gangtok", "Kohima", "Singla Bazar"]
N_BOOT = 2000
SEED = 20240916
RIDGE = 1.0 / 2.5 ** 2  # ~0.16, Gelman et al. (2008) weakly-informative default

BLUE = "#1f5fa8"
TEAL = "#1a9c76"


# ------------------------------------------------------------------
# 1) Logistic regression (Newton-Raphson / IRLS), ridge-penalized,
#    intercept left unpenalized
# ------------------------------------------------------------------
def fit_logreg_newton(X, y, n_iter=100, tol=1e-8, ridge=RIDGE):
    n, p = X.shape
    beta = np.zeros(p)
    pen = np.full(p, ridge)
    pen[0] = 0.0
    Pmat = np.diag(pen)
    for _ in range(n_iter):
        eta = np.clip(X @ beta, -35, 35)
        mu = 1.0 / (1.0 + np.exp(-eta))
        W = np.clip(mu * (1 - mu), 1e-8, None)
        grad = X.T @ (y - mu) - pen * beta
        H = -(X * W[:, None]).T @ X - Pmat
        try:
            step = np.linalg.solve(H, grad)
        except np.linalg.LinAlgError:
            step = np.linalg.lstsq(H, grad, rcond=None)[0]
        beta_new = beta - step
        if np.max(np.abs(beta_new - beta)) < tol:
            beta = beta_new
            break
        beta = beta_new
    return beta


def predict_proba(X, beta):
    eta = np.clip(X @ beta, -35, 35)
    return 1.0 / (1.0 + np.exp(-eta))


def best_cutoff_by_tss(y, p):
    cands = np.concatenate([[0.0], np.unique(p), [1.0]])
    best_c, best_tss = 0.5, -np.inf
    for c in cands:
        yhat = (p >= c).astype(int)
        tp = np.sum((yhat == 1) & (y == 1))
        fn = np.sum((yhat == 0) & (y == 1))
        fp = np.sum((yhat == 1) & (y == 0))
        tn = np.sum((yhat == 0) & (y == 0))
        sens = tp / (tp + fn) if (tp + fn) > 0 else 0.0
        spec = tn / (tn + fp) if (tn + fp) > 0 else 0.0
        tss = sens + spec - 1
        if tss > best_tss:
            best_tss, best_c = tss, c
    return best_c


def standardize_fit(train_X):
    mu = train_X.mean(axis=0)
    sd = train_X.std(axis=0, ddof=0)
    sd[sd == 0] = 1.0
    return mu, sd


# ------------------------------------------------------------------
# 2) Per-station LOYO-CV for both models
# ------------------------------------------------------------------
def run_station(df_all, station, nstar, verbose=True):
    d = df_all[df_all.Station == station].copy()
    d["Storm_start"] = pd.to_datetime(d["Storm_start"])
    d["month"] = d["Storm_start"].dt.month
    d_jjas = d[d.month.isin([6, 7, 8, 9])].copy()

    api_col = f"API_{nstar}"
    d_jjas = d_jjas.rename(columns={api_col: "API_fixed"})

    years_with_landslide = sorted(d_jjas.loc[d_jjas.Landslide_status == 1, "Year"].unique())
    d_final = d_jjas[d_jjas.Year.isin(years_with_landslide)].copy().reset_index(drop=True)

    if verbose:
        print(f"\n=== {station} (N*={nstar}) ===")
        print(f"  All rows: {len(d)}, JJAS rows: {len(d_jjas)}, "
              f"JJAS+landslide-year rows: {len(d_final)}")
        print(f"  Positives in final set: {int(d_final.Landslide_status.sum())} / {len(d_final)}")

    results = {}
    for model_name, feat_cols in [("Rainfall only", ["TR_mm"]),
                                   ("Rainfall + saturation", ["TR_mm", "API_fixed", "Seff_lag1"])]:
        oof_y, oof_pred, oof_year = [], [], []
        for test_year in years_with_landslide:
            train = d_final[d_final.Year != test_year]
            test = d_final[d_final.Year == test_year]
            if train.empty or test.empty:
                continue
            Xtr_raw = train[feat_cols].to_numpy(float)
            ytr = train["Landslide_status"].to_numpy(float)
            Xte_raw = test[feat_cols].to_numpy(float)
            yte = test["Landslide_status"].to_numpy(float)

            mu, sd = standardize_fit(Xtr_raw)
            Xtr = np.column_stack([np.ones(len(Xtr_raw)), (Xtr_raw - mu) / sd])
            Xte = np.column_stack([np.ones(len(Xte_raw)), (Xte_raw - mu) / sd])

            if ytr.sum() == 0 or ytr.sum() == len(ytr):
                p_train = np.full(len(ytr), ytr.mean())
                cutoff = 0.5
                p_test = np.full(len(yte), ytr.mean())
            else:
                beta = fit_logreg_newton(Xtr, ytr)
                p_train = predict_proba(Xtr, beta)
                cutoff = best_cutoff_by_tss(ytr, p_train)
                p_test = predict_proba(Xte, beta)

            yhat_test = (p_test >= cutoff).astype(int)
            oof_y.append(yte)
            oof_pred.append(yhat_test)
            oof_year.append(np.full(len(yte), test_year))

        oof_y = np.concatenate(oof_y)
        oof_pred = np.concatenate(oof_pred)
        oof_year = np.concatenate(oof_year)

        tp = int(np.sum((oof_pred == 1) & (oof_y == 1)))
        fp = int(np.sum((oof_pred == 1) & (oof_y == 0)))
        fn = int(np.sum((oof_pred == 0) & (oof_y == 1)))
        tn = int(np.sum((oof_pred == 0) & (oof_y == 0)))
        sens = tp / (tp + fn) if (tp + fn) > 0 else 0.0
        spec = tn / (tn + fp) if (tn + fp) > 0 else 0.0
        tss = sens + spec - 1

        rng = np.random.default_rng(SEED)
        uyears = np.array(years_with_landslide)
        boot_tss = np.empty(N_BOOT)
        for b in range(N_BOOT):
            samp_years = rng.choice(uyears, size=len(uyears), replace=True)
            btp = bfp = bfn = btn = 0
            for yy in samp_years:
                m = oof_year == yy
                btp += np.sum((oof_pred[m] == 1) & (oof_y[m] == 1))
                bfp += np.sum((oof_pred[m] == 1) & (oof_y[m] == 0))
                bfn += np.sum((oof_pred[m] == 0) & (oof_y[m] == 1))
                btn += np.sum((oof_pred[m] == 0) & (oof_y[m] == 0))
            bsens = btp / (btp + bfn) if (btp + bfn) > 0 else 0.0
            bspec = btn / (btn + bfp) if (btn + bfp) > 0 else 0.0
            boot_tss[b] = bsens + bspec - 1

        ci_lo, ci_hi = np.percentile(boot_tss, [2.5, 97.5])
        results[model_name] = dict(TP=tp, FP=fp, FN=fn, TN=tn, TSS=tss,
                                    CI_lo=ci_lo, CI_hi=ci_hi,
                                    n_years=len(years_with_landslide))
        if verbose:
            print(f"  {model_name:24s} TP={tp:3d} FP={fp:3d} FN={fn:3d} TN={tn:3d} "
                  f"TSS={tss:.3f}  95% CI=[{ci_lo:.2f},{ci_hi:.2f}]")
    return results


# ------------------------------------------------------------------
# 3) Run all stations, build the table
# ------------------------------------------------------------------
def build_table():
    df_all = pd.read_excel(DATA_XLSX, sheet_name="Dataset_S3_Modeling")
    Meta = pd.read_excel(META_XLSX, sheet_name="Sheet1")
    Meta.columns = [str(c).strip() for c in Meta.columns]
    Meta["Station"] = Meta["Station"].astype(str).str.strip()

    rows = []
    for s in STATIONS:
        nstar = int(Meta.loc[Meta.Station == s, "Ideal_lag"].iloc[0])
        res = run_station(df_all, s, nstar)
        for model_name, r in res.items():
            rows.append(dict(Station=s, Model=model_name, **r, Nstar=nstar))

    df = pd.DataFrame(rows)
    out = df[["Station", "Model", "TP", "FP", "FN", "TN", "TSS", "CI_lo", "CI_hi", "Nstar", "n_years"]].copy()
    out["95% CI"] = out.apply(lambda r: f"{r.CI_lo:.2f}\u2013{r.CI_hi:.2f}", axis=1)
    out["TSS"] = out["TSS"].round(2)
    out = out[["Station", "Model", "TP", "FP", "FN", "TN", "TSS", "95% CI", "Nstar", "n_years"]]
    out.to_excel(TABLE_OUT, index=False)
    print(f"\nSaved table -> {TABLE_OUT}")
    print(out.to_string(index=False))
    return df


# ------------------------------------------------------------------
# 4) Bar chart, same style as the reference figure
# ------------------------------------------------------------------
def build_figure(df):
    models = ["Rainfall only", "Rainfall + saturation"]
    fig, ax = plt.subplots(figsize=(10, 6.2), dpi=100)
    x = np.arange(len(STATIONS))
    w = 0.36
    for i, (m, color) in enumerate(zip(models, [BLUE, TEAL])):
        vals, lo, hi = [], [], []
        for s in STATIONS:
            row = df[(df.Station == s) & (df.Model == m)].iloc[0]
            vals.append(row.TSS)
            lo.append(row.TSS - row.CI_lo)
            hi.append(row.CI_hi - row.TSS)
        xpos = x + (i - 0.5) * w
        ax.bar(xpos, vals, width=w, color=color, label=m, zorder=3)
        ax.errorbar(xpos, vals, yerr=[lo, hi], fmt="none", ecolor="black",
                    elinewidth=1.3, capsize=4, zorder=4)

    ax.set_xticks(x)
    ax.set_xticklabels(STATIONS, fontsize=12)
    ax.set_ylim(0, 1.0)
    ax.set_ylabel("Out-of-sample True Skill Statistic (TSS)", fontsize=12.5)
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    ax.tick_params(axis="y", labelsize=11)
    ax.legend(loc="upper right", frameon=False, fontsize=11.5)
    fig.tight_layout()
    fig.savefig(FIG_OUT, dpi=300, facecolor="w")
    print(f"Saved figure -> {FIG_OUT}")


if __name__ == "__main__":
    print(f"Data root in use: {DATA_ROOT}")
    _df = build_table()
    build_figure(_df)
