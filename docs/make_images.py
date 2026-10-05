"""Draws the two README images: the workflow diagram and a sample-data example figure."""
import os
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "images")
SAMPLE = os.path.join(HERE, "..", "sample_data")
os.makedirs(OUT, exist_ok=True)
plt.rcParams.update({"font.family": "DejaVu Sans", "font.size": 9})

# ------------------------------------------------------------ workflow diagram
fig, ax = plt.subplots(figsize=(11, 5.2))
ax.set_xlim(0, 11); ax.set_ylim(0, 5.2); ax.axis("off")


def box(x, y, w, h, title, sub, fc):
    ax.add_patch(FancyBboxPatch((x, y), w, h, boxstyle="round,pad=0.02,rounding_size=0.08", fc=fc, ec="#33415c", lw=1))
    ax.text(x + w / 2, y + h * 0.64, title, ha="center", va="center", fontweight="bold", fontsize=9)
    ax.text(x + w / 2, y + h * 0.28, sub, ha="center", va="center", fontsize=7.6, color="#333")


def arrow(x1, y1, x2, y2):
    ax.add_patch(FancyArrowPatch((x1, y1), (x2, y2), arrowstyle="-|>", mutation_scale=11, lw=1.1, color="#33415c"))


inp = "#e8eef7"; core = "#dcebdc"; res = "#f6e7d0"
box(0.2, 3.9, 2.4, 0.9, "Inputs", "rainfall, S_eff, landslide catalogue", inp)
box(3.1, 3.9, 2.4, 0.9, "step_0 - step1", "station assignment, lag selection", core)
box(6.0, 3.9, 2.4, 0.9, "step2 - step3", "ADF, K sensitivity", core)
box(8.6, 3.9, 2.2, 0.9, "step4 - step6", "triggering events, API", core)
box(0.2, 2.2, 2.4, 0.9, "step7", "optimal window N*", core)
box(3.1, 2.2, 2.4, 0.9, "step8", "E-D thresholds, cross-validation", core)
box(6.0, 2.2, 2.4, 0.9, "step9", "Kendall tau: API, S_eff, frequency", core)
box(8.6, 2.2, 2.2, 0.9, "step10", "JEP, TSS comparison", core)
box(0.2, 0.5, 2.4, 0.9, "step11", "P(MDL | rain severity, saturation)", core)
box(3.1, 0.5, 2.4, 0.9, "step12", "compounding index AR", core)
box(6.0, 0.5, 4.8, 0.9, "figures", "final figures and tables", res)
for a, b in [((2.6, 4.35), (3.1, 4.35)), ((5.5, 4.35), (6.0, 4.35)), ((8.4, 4.35), (8.6, 4.35)),
             ((9.7, 3.9), (1.4, 3.1)), ((2.6, 2.65), (3.1, 2.65)), ((5.5, 2.65), (6.0, 2.65)), ((8.4, 2.65), (8.6, 2.65)),
             ((9.7, 2.2), (1.4, 1.4)), ((2.6, 0.95), (3.1, 0.95)), ((5.5, 0.95), (6.0, 0.95))]:
    arrow(*a, *b)
fig.savefig(os.path.join(OUT, "workflow.png"), dpi=200, bbox_inches="tight", facecolor="white")
plt.close(fig)

# ------------------------------------------------------------ sample output figure
summ = pd.read_csv(os.path.join(SAMPLE, "output_station_summary.csv"))
jep = pd.read_csv(os.path.join(SAMPLE, "output_jep_large_events.csv"))
fig, axs = plt.subplots(1, 3, figsize=(11, 3.4))
x = np.arange(len(summ)); w = 0.55
axs[0].bar(x, summ.ADF, w, color="#3b6ea5"); axs[0].axhline(0.5, color="#999", ls="--", lw=0.9)
axs[0].set_xticks(x, summ.Station); axs[0].set_ylim(0, 1); axs[0].set_ylabel("ADF"); axs[0].set_title("Antecedent-dominance fraction")
d = np.linspace(1, 8, 50)
for (_, r), c in zip(summ.iterrows(), ["#3b6ea5", "#c0653b"]):
    axs[1].plot(d, r.ED_intercept + r.ED_slope * d, color=c, label=f"{r.Station}  E3 = {r.E3_P20_mm:.0f} mm")
axs[1].set_xlabel("Duration D (days)"); axs[1].set_ylabel("Rainfall E (mm)"); axs[1].set_title("Linear E-D threshold, q = 0.20")
axs[1].legend(frameon=False, fontsize=8)
m = np.minimum(jep.P_TR, jep.P_API)
axs[2].scatter(m, jep.JEP, s=22, color="#3b6ea5", alpha=0.85)
axs[2].plot([0, m.max() * 1.05], [0, m.max() * 1.05], color="#999", ls="--", lw=0.9)
axs[2].set_xlabel("min(P_TR, P_API)"); axs[2].set_ylabel("JEP"); axs[2].set_title("JEP of large events")
for a in axs:
    a.spines[["top", "right"]].set_visible(False)
fig.suptitle("Output of run_sample_pipeline.py on the synthetic sample data", fontsize=9.5, y=1.02)
fig.tight_layout()
fig.savefig(os.path.join(OUT, "sample_output.png"), dpi=200, bbox_inches="tight", facecolor="white")
