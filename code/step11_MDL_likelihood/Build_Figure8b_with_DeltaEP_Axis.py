import pandas as pd
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

IN_XLSX = "Figure8b_CALC_TABLE.xlsx"
OUT_PNG = "panel_b_with_delta_axis_300dpi.png"

df = pd.read_excel(IN_XLSX, sheet_name="Figure8b_CALC_TABLE")
df["Class"] = df["Class"].astype(str).str.strip()
df = df[df["N_bin"].notna() & (df["N_bin"] > 0)].copy()

def start(c):
    return 999.0 if c == ">90" else float(c.split("-")[0])
df["ord"] = df["Class"].map(start)
df = df.sort_values("ord").reset_index(drop=True)

def midlabel(c):
    if c == ">90":
        return ">90"
    a, b = c.split("-")
    return str((float(a) + float(b)) / 2)
df["ClassLabel"] = df["Class"].map(midlabel)

N_bin = df["N_bin"].to_numpy(float)
P_rain_pct = 100 * df["P_rainonly"].to_numpy(float)
P_wet_pct = 100 * df["P_joint_plot"].to_numpy(float)
delta_pct = P_wet_pct - P_rain_pct

n = len(df)
x = np.arange(1, n + 1)

highlight_bins = {"5-10", "10-15", "15-20"}
lightgreen = np.array([0.565, 0.933, 0.565])
alphaHL = 0.35
highlight_color = alphaHL * lightgreen + (1 - alphaHL) * np.array([1, 1, 1])
grey85 = np.array([0.85, 0.85, 0.85])
bar_colors = np.tile(grey85, (n, 1))
is_hl = df["Class"].isin(highlight_bins).to_numpy()
bar_colors[is_hl] = highlight_color

AXIS_TITLE = 20
AXIS_TEXT = 14
LEGEND_TEXT = 16
TOP_TICK = 13
TOP_TITLE = 17

# Bigger canvas, and the plot area itself now fills most of it -- legend
# moves INSIDE the frame (matching the original figure's 'north' style),
# so the only reserved outer band is the slim Delta-EP row on top.
fig, ax = plt.subplots(figsize=(15.0, 9.2), dpi=300)
fig.subplots_adjust(left=0.075, right=0.935, top=0.815, bottom=0.10)

# ---- left axis: bars ----
ax.bar(x, N_bin, width=0.78, color=bar_colors, edgecolor="none", zorder=2)
ymax_left = N_bin.max() * 1.10
ax.set_ylim(0, ymax_left)
ax.set_ylabel("Number of rainy days in each threshold category",
              fontsize=AXIS_TITLE, fontweight="bold")
ax.tick_params(axis="both", labelsize=AXIS_TEXT, width=1.2, length=6)
for lab in ax.get_yticklabels() + ax.get_xticklabels():
    lab.set_fontweight("bold")

# ---- right axis: MDL likelihood lollipop ----
axR = ax.twinx()
p_all = np.concatenate([P_rain_pct, P_wet_pct])
prob_top = np.ceil((p_all.max() + 0.2) / 0.5) * 0.5
axR.set_ylim(0, prob_top)
axR.set_ylabel("MDL likelihood (%)", fontsize=AXIS_TITLE, fontweight="bold")
axR.tick_params(axis="y", labelsize=AXIS_TEXT, width=1.2, length=6)
for lab in axR.get_yticklabels():
    lab.set_fontweight("bold")

y_top = np.maximum(P_rain_pct, P_wet_pct)
for xi, yi in zip(x, y_top):
    axR.plot([xi, xi], [0, yi], "--", color="k", linewidth=0.9, alpha=0.35, zorder=1)

hRain, = axR.plot(x, P_rain_pct, "o", markersize=11, markeredgewidth=2.2,
                   markeredgecolor="blue", markerfacecolor="none",
                   linestyle="none", zorder=3)
hWet, = axR.plot(x, P_wet_pct, "o", markersize=11, markeredgewidth=1.8,
                  markeredgecolor="red", markerfacecolor="red",
                  linestyle="none", zorder=4)

# ---- bottom x axis ----
ax.set_xlim(0.4, n + 0.6)
ax.set_xticks(x)
ax.set_xticklabels(df["ClassLabel"].tolist(), fontsize=AXIS_TEXT, fontweight="bold")
ax.set_xlabel("Rainfall threshold (percentiles)", fontsize=AXIS_TITLE, fontweight="bold")

ax.grid(True, linestyle="-", alpha=0.22, zorder=0)
ax.set_axisbelow(True)
for spine in ax.spines.values():
    spine.set_linewidth(1.3)
for spine in axR.spines.values():
    spine.set_linewidth(1.3)

# ---- legend: INSIDE the plot, top-center, matching the original 'north'
#      placement -- this bin range (mid-chart) never gets tall enough to
#      collide with either the bars or the data points ----
leg = ax.legend([hWet, hRain],
                 ["Rain + Wetness (80th percentile)", "Rain only"],
                 loc="upper center", bbox_to_anchor=(0.5, 0.995),
                 ncol=2, frameon=True, fontsize=LEGEND_TEXT,
                 handletextpad=0.5, columnspacing=1.4,
                 borderpad=0.6)
for t in leg.get_texts():
    t.set_fontweight("bold")
leg.get_frame().set_edgecolor("black")
leg.get_frame().set_facecolor("white")
leg.get_frame().set_linewidth(1.2)
leg.set_zorder(10)

# ==================================================================
# Secondary top x-axis -- per-bin amplification, requested by advisor:
# Delta EP = EP(Rain+Seff) - EP(Rain), same x positions as the bottom
# axis, labelled with the actual per-bin delta (pct pts). Kept as a
# slim reserved strip above the frame so the main plot stays large.
# ==================================================================
axT = ax.twiny()
axT.set_xlim(ax.get_xlim())
axT.set_xticks(x)
delta_labels = [f"{d:+.2f}" for d in delta_pct]
axT.set_xticklabels(delta_labels, fontsize=TOP_TICK, fontweight="bold", rotation=0)
axT.set_xlabel(r"$\Delta EP = EP_{Rain+Seff} - EP_{Rain}$ (%)",
               fontsize=TOP_TITLE, fontweight="bold", labelpad=8)
axT.tick_params(axis="x", pad=4, width=1.0, length=4)

fig.savefig(OUT_PNG, dpi=300, facecolor="w")
print("Saved:", OUT_PNG)
