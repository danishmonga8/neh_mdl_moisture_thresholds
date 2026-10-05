"""Runs the core analysis chain on the sample data (or on any data in the same layout).

For every station:
  1. rainfall episodes (E = total mm, D = duration in days)
  2. triggering rainfall (TR) and antecedent precipitation index API(N*, K) for each landslide
  3. antecedent-dominance fraction (ADF) from rank(API) > rank(TR)
  4. Kendall tau-b between API(N*) and lag-1 effective saturation
  5. linear E-D threshold at quantile 0.20 and E3 = a + 3b
Then, pooled over the large landslides: the joint empirical probability (JEP) of TR and API
with rank/(N+1) and non-exceedance counts, and its consistency with the marginals.

Usage:  python run_sample_pipeline.py [data_dir]
"""
import os
import sys
import numpy as np
import pandas as pd

K = 0.90
WET_DAY_MM = 2.5
QUANTILE = 0.20
TOL = 1e-12
HERE = os.path.dirname(os.path.abspath(__file__))
DATA = sys.argv[1] if len(sys.argv) > 1 else HERE


def episodes(rain):
    """Consecutive days with rain >= WET_DAY_MM; returns (start, end, total, duration)."""
    wet = rain >= WET_DAY_MM
    out, i, n = [], 0, len(rain)
    while i < n:
        if wet[i]:
            j = i
            while j + 1 < n and wet[j + 1]:
                j += 1
            out.append((i, j, float(rain[i:j + 1].sum()), j - i + 1))
            i = j + 1
        else:
            i += 1
    return out


def api(rain, t, N, k=K):
    lags = np.arange(1, N + 1)
    idx = t - lags
    ok = idx >= 0
    return float(np.sum((k ** lags[ok]) * rain[idx[ok]]))


def tiedrank(x):
    x = np.asarray(x, float)
    order = np.argsort(x, kind="mergesort")
    r = np.empty(len(x))
    i = 0
    while i < len(x):
        j = i
        while j + 1 < len(x) and abs(x[order[j + 1]] - x[order[i]]) <= TOL:
            j += 1
        r[order[i:j + 1]] = 0.5 * (i + j) + 1
        i = j + 1
    return r


def kendall_tau_b(x, y):
    x, y = np.asarray(x, float), np.asarray(y, float)
    dx = np.sign(x[:, None] - x[None, :])
    dy = np.sign(y[:, None] - y[None, :])
    iu = np.triu_indices(len(x), 1)
    num = np.sum(dx[iu] * dy[iu])
    den = np.sqrt(np.sum(dx[iu] != 0) * np.sum(dy[iu] != 0))
    return float(num / den) if den > 0 else np.nan


def linear_quantile(x, y, q=QUANTILE):
    """Exact linear quantile regression y = a + b x: the optimum passes through two data points."""
    x, y = np.asarray(x, float), np.asarray(y, float)
    best = (np.inf, np.nan, np.nan)
    n = len(x)
    for i in range(n):
        for j in range(i + 1, n):
            if x[i] == x[j]:
                continue
            b = (y[j] - y[i]) / (x[j] - x[i])
            a = y[i] - b * x[i]
            r = y - (a + b * x)
            loss = np.sum(np.where(r >= 0, q * r, (q - 1) * r))
            if loss < best[0]:
                best = (loss, a, b)
    return best[1], best[2]


stations = pd.read_csv(os.path.join(DATA, "stations.csv"))
lands = pd.read_csv(os.path.join(DATA, "landslides.csv"), parse_dates=["EventDate"])
rows, large_events = [], []
for _, st in stations.iterrows():
    imd, nstar = int(st.IMD), int(st.Ideal_lag)
    rain_df = pd.read_csv(os.path.join(DATA, f"rain_{imd}.csv"), parse_dates=["date"]).set_index("date")
    seff_df = pd.read_csv(os.path.join(DATA, f"seff_{imd}.csv"), parse_dates=["date"]).set_index("date")
    rain = rain_df.rain_mm.values
    pos = {d: i for i, d in enumerate(rain_df.index)}
    eps = episodes(rain)
    ev = lands[lands.IMD == imd].drop_duplicates("EventDate")
    tr, ap, sf, size = [], [], [], []
    for _, e in ev.iterrows():
        t = pos.get(e.EventDate)
        if t is None or t < 1:
            continue
        # triggering episode: the one containing the event day, or ending within the previous 3 days
        cand = [x for x in eps if x[0] <= t <= x[1] or 0 <= t - x[1] <= 3]
        if not cand:
            continue
        ep = max(cand, key=lambda x: x[1])
        tr.append(ep[2])
        ap.append(api(rain, t, nstar))
        sf.append(seff_df.seff.values[t - 1])
        size.append(e.landslide_size)
    tr, ap, sf, size = map(np.array, (tr, ap, sf, size))
    n = len(tr)
    adf = float(np.mean(tiedrank(ap) / (n + 1) > tiedrank(tr) / (n + 1) + TOL))
    tau = kendall_tau_b(ap, sf)
    E = np.array([x[2] for x in eps if x[3] >= 1])
    D = np.array([x[3] for x in eps if x[3] >= 1])
    a, b = linear_quantile(D, E)
    rows.append(dict(Station=st.Station, IMD=imd, N_star=nstar, n_events=n, ADF=round(adf, 4),
                     tau_API_vs_Seff_lag1=round(tau, 4), ED_intercept=round(a, 3), ED_slope=round(b, 3),
                     E3_P20_mm=round(a + 3 * b, 3)))
    for t_, a_, s_ in zip(tr, ap, size):
        if s_ == "large":
            large_events.append((st.Station, t_, a_))

summary = pd.DataFrame(rows)
print(summary.to_string(index=False))
summary.to_csv(os.path.join(HERE, "output_station_summary.csv"), index=False)

if large_events:
    T = np.array([e[1] for e in large_events])
    A = np.array([e[2] for e in large_events])
    N = len(T)
    P_tr = np.array([np.sum(T <= t) for t in T]) / (N + 1)
    P_api = np.array([np.sum(A <= a) for a in A]) / (N + 1)
    jep = np.array([np.sum((T <= t) & (A <= a)) for t, a in zip(T, A)]) / (N + 1)
    ok = bool(np.all(jep <= np.minimum(P_tr, P_api) + 1e-12))
    out = pd.DataFrame(dict(Station=[e[0] for e in large_events], TR_mm=T, API_mm=A, P_TR=P_tr, P_API=P_api, JEP=jep))
    out.to_csv(os.path.join(HERE, "output_jep_large_events.csv"), index=False)
    print(f"\nLarge events: {N}; JEP <= min(P_TR, P_API) for all events: {ok}")
