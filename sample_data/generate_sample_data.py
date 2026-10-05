"""Writes a small synthetic data set with the same file layout the analysis scripts read.

Two stations, daily rainfall and effective saturation for 2007-2019, and a
landslide inventory. The values are random (seed 7); they are meant for running
and testing the code, not for scientific interpretation.
"""
import os
import numpy as np
import pandas as pd

OUT = os.path.dirname(os.path.abspath(__file__))
rng = np.random.default_rng(7)
dates = pd.date_range("2007-01-01", "2019-12-31", freq="D")
doy = dates.dayofyear.values
season = np.exp(-0.5 * ((doy - 200) / 45.0) ** 2)

stations = pd.DataFrame({
    "Station": ["Sample_A", "Sample_B"],
    "IMD": [900001, 900002],
    "Lat": [27.05, 25.60],
    "Long": [88.27, 91.88],
    "Ideal_lag": [15, 5],
})
stations.to_csv(os.path.join(OUT, "stations.csv"), index=False)

K = 0.9
lands = []
for k, imd in enumerate(stations.IMD):
    p_wet = 0.08 + 0.55 * season
    rain = np.where(rng.random(len(dates)) < p_wet, rng.gamma(1.4, 14.0 * (0.6 + season)), 0.0)
    # effective saturation: bounded, driven by exponentially weighted antecedent rain
    api = np.zeros(len(rain))
    for t in range(1, len(rain)):
        api[t] = K * (api[t - 1] + rain[t - 1])
    seff = np.clip(0.45 + 0.5 * (1 - np.exp(-api / 120.0)) + rng.normal(0, 0.02, len(rain)), 0.3, 1.0)
    pd.DataFrame({"date": dates, "rain_mm": np.round(rain, 2)}).to_csv(os.path.join(OUT, f"rain_{imd}.csv"), index=False)
    pd.DataFrame({"date": dates, "seff": np.round(seff, 4)}).to_csv(os.path.join(OUT, f"seff_{imd}.csv"), index=False)
    # landslide days: more likely on wet, high-API, rainy days
    score = (rain / 40.0) * (0.4 + seff)
    prob = 0.002 + 0.25 * (score > 1.0) + 0.04 * (score > 0.6)
    hit = rng.random(len(dates)) < prob
    for d in dates[hit]:
        lands.append({"IMD": imd, "Station": stations.Station[k], "EventDate": d.date().isoformat(),
                      "landslide_size": rng.choice(["small", "medium", "large"], p=[0.25, 0.6, 0.15])})
pd.DataFrame(lands).to_csv(os.path.join(OUT, "landslides.csv"), index=False)
print("stations:", len(stations), "landslides:", len(lands))
