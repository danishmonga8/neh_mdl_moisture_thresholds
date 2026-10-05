import pickle, numpy as np, matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Polygon as MPoly, Wedge, Patch
from matplotlib.lines import Line2D
from core import ORDER, disp
plt.rcParams.update({"font.family":"DejaVu Sans"})
T=pickle.load(open("tables.pkl","rb")); G=pickle.load(open("geo.pkl","rb"))
F=T["F"]; inv=T["inv"]; RET=T["RET"]
LON=F.Long; LAT=F.Lat
def is_low(s): return bool(inv.loc[s,"Low_sample"])
def deg_ticks(ax,xt,yt,fs):
    ax.set_xticks(xt); ax.set_yticks(yt)
    ax.set_xticklabels([f"{v}°E" for v in xt],fontsize=fs); ax.set_yticklabels([f"{v}°N" for v in yt],fontsize=fs)
def draw_states(ax,fill="white",edge="black",lw=0.8,z=1):
    for p in G["polys"]: ax.add_patch(MPoly(p,closed=True,facecolor=fill,edgecolor=edge,lw=lw,zorder=z))
def donut(ax_d,vals,cols,labels_pct,r_in=0.32,fs=11,start=90):
    tot=sum(vals); ang=start
    for v,c,lab in zip(vals,cols,labels_pct):
        if v==0: continue
        th=360*v/tot
        ax_d.add_patch(Wedge((0,0),1,ang-th,ang,width=1-r_in,facecolor=c,edgecolor="#333333",lw=1.0))
        mid=np.radians(ang-th/2); rr=(1+r_in)/2
        ax_d.text(rr*np.cos(mid),rr*np.sin(mid),lab,ha="center",va="center",fontsize=fs,fontweight="bold")
        ang-=th
    ax_d.set_xlim(-1.05,1.05); ax_d.set_ylim(-1.05,1.05); ax_d.set_aspect("equal"); ax_d.axis("off")
