"""
Paired year-block bootstrap for dTSS = TSS(Rainfall + saturation) - TSS(Rainfall only).
Same out-of-fold predictions as R1C5_JJAS_TSS_Protocol_v2.py; in each bootstrap
replicate the SAME resampled years are used for both models (paired).
2000 reps, seed 20240916, percentile 95% CI.
"""
import numpy as np, pandas as pd
import R1C5_JJAS_TSS_Protocol_v2 as P

def oof_station(D, s, model, log_rain, rule):
    d = D[D.Station == s].reset_index(drop=True)
    years = sorted(d.Year.unique())
    X_all = P.features(d, model, log_rain); y_all = d.Landslide_status.to_numpy(float)
    yh = np.zeros(len(d), int)
    for ty in years:
        tr = (d.Year != ty).to_numpy(); te = ~tr
        mu = X_all[tr].mean(0); sd = X_all[tr].std(0); sd[sd == 0] = 1
        Xtr = np.column_stack([np.ones(tr.sum()), (X_all[tr]-mu)/sd])
        Xte = np.column_stack([np.ones(te.sum()), (X_all[te]-mu)/sd])
        b = P.fit_logreg(Xtr, y_all[tr], np.array([False]+[True]*X_all.shape[1]))
        c = y_all[tr].mean() if rule == "prevalence" else P.tss_max_cutoff(y_all[tr], P.proba(Xtr, b))
        yh[te] = (P.proba(Xte, b) >= c).astype(int)
    return y_all, yh, d.Year.to_numpy(), years

def oof_pooled(D, model):
    D = D.reset_index(drop=True)
    st = D.Station.map({s:i for i,s in enumerate(P.STATIONS)}).to_numpy()
    y = D.Landslide_status.to_numpy(float); F = P.features(D, model, True)
    yh = np.zeros(len(D), int)
    for ty in sorted(D.Year.unique()):
        tr = (D.Year != ty).to_numpy(); te = ~tr
        Z = np.empty_like(F)
        for i in range(len(P.STATIONS)):
            ms = st == i; mt = ms & tr
            mu = F[mt].mean(0); sd = F[mt].std(0); sd[sd == 0] = 1
            Z[ms] = (F[ms]-mu)/sd
        X = np.column_stack([np.eye(len(P.STATIONS))[st], Z])
        b = P.fit_logreg(X[tr], y[tr], np.array([False]*len(P.STATIONS)+[True]*F.shape[1]))
        cut = np.array([y[tr & (st == i)].mean() for i in range(len(P.STATIONS))])
        yh[te] = (P.proba(X[te], b) >= cut[st[te]]).astype(int)
    return D, st, y, yh

def tss_years(y, yh, yr, samp):
    tp=fp=fn=tn=0
    for yy in samp:
        m = yr == yy
        a,b_,c,d_ = P.confusion(y[m], yh[m]); tp+=a; fp+=b_; fn+=c; tn+=d_
    return P.tss_of(tp,fp,fn,tn)

def paired(y, h1, h2, yr, years):
    rng = np.random.default_rng(P.SEED); years = np.array(years)
    d = np.empty(P.N_BOOT)
    for b in range(P.N_BOOT):
        samp = rng.choice(years, size=len(years), replace=True)
        d[b] = tss_years(y, h2, yr, samp) - tss_years(y, h1, yr, samp)
    obs = P.tss_of(*P.confusion(y, h2)) - P.tss_of(*P.confusion(y, h1))
    lo, hi = np.percentile(d, [2.5, 97.5])
    return obs, lo, hi, np.mean(d > 0)

D = P.load()
out = []
for label, log_rain, rule in [("C_PRIMARY", True, "prevalence"), ("A_previous_REG", False, "tss_max"),
                              ("B_prevcutoff", False, "prevalence")]:
    for s in P.STATIONS:
        y, h1, yr, yrs = oof_station(D, s, "Rainfall only", log_rain, rule)
        _, h2, _, _   = oof_station(D, s, "Rainfall + saturation", log_rain, rule)
        obs, lo, hi, pgt = paired(y, h1, h2, yr, yrs)
        out.append(dict(Variant=label, Station=s, TSS_rain=round(P.tss_of(*P.confusion(y,h1)),3),
                        TSS_sat=round(P.tss_of(*P.confusion(y,h2)),3), dTSS=round(obs,3),
                        CI_lo=round(lo,3), CI_hi=round(hi,3), includes_zero=bool(lo <= 0 <= hi),
                        share_boot_dTSS_gt0=round(pgt,3)))
Dp, st, y, h1 = oof_pooled(D, "Rainfall only")
_, _, _, h2 = oof_pooled(D, "Rainfall + saturation")
for i, s in enumerate(P.STATIONS):
    m = st == i; yr = Dp.Year.to_numpy()[m]
    obs, lo, hi, pgt = paired(y[m], h1[m], h2[m], yr, sorted(np.unique(yr)))
    out.append(dict(Variant="D_pooled", Station=s, TSS_rain=round(P.tss_of(*P.confusion(y[m],h1[m])),3),
                    TSS_sat=round(P.tss_of(*P.confusion(y[m],h2[m])),3), dTSS=round(obs,3),
                    CI_lo=round(lo,3), CI_hi=round(hi,3), includes_zero=bool(lo <= 0 <= hi),
                    share_boot_dTSS_gt0=round(pgt,3)))
R = pd.DataFrame(out)
pd.set_option("display.width", 200)
print(R.to_string(index=False))
R.to_excel("Paired_dTSS_bootstrap_check.xlsx", index=False)
