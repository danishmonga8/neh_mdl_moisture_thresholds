from plots_common import *
f3=T["fig3"].set_index("Station")
cols={"Jun":"#E31A1C","Jul":"#FDBF6F","Aug":"#FF7F00","Sep":"#D81B60"}
fig=plt.figure(figsize=(17.5,7.6))
ax=fig.add_axes([0.05,0.20,0.48,0.72])
allp=np.vstack(G["polys"]); x0,y0=allp.min(0)-0.6; x1,y1=allp.max(0)+0.6
for xg in np.arange(86,99,2): ax.axvline(xg,color="#DEDEDE",ls=(0,(4,3)),lw=0.8,zorder=0)
for yg in np.arange(22,31,2): ax.axhline(yg,color="#DEDEDE",ls=(0,(4,3)),lw=0.8,zorder=0)
draw_states(ax,fill="#F2F2F2",edge="#7F7F7F",lw=0.9,z=1)
for r in G["rivers"]: ax.plot(r[:,0],r[:,1],color="#3399FF",lw=1.3,zorder=2,solid_capstyle="round")
for s in ORDER:
    d=disp(s); lo,la=F.loc[s,"Long"],F.loc[s,"Lat"]
    if is_low(s):
        ax.scatter(lo,la,s=230,facecolor="#BDBDBD",edgecolor="black",lw=1.6,alpha=0.85,zorder=4)
    else:
        ax.scatter(lo,la,s=230,facecolor=cols[f3.loc[d,"Peak_month"]],edgecolor="black",lw=1.6,alpha=0.75,zorder=5)
ax.set_xlim(x0,x1); ax.set_ylim(y0,y1); ax.set_aspect("equal")
deg_ticks(ax,list(range(86,99,2)),list(range(22,31,2)),16)
for sp in ax.spines.values(): sp.set_visible(False)
ax.tick_params(length=0,colors="#4D4D4D")
ax.set_xlabel("Longitude",fontsize=18,fontweight="bold"); ax.set_ylabel("Latitude",fontsize=18,fontweight="bold")
h=[Line2D([],[],marker="o",ls="",markersize=13,markerfacecolor=cols[m],markeredgecolor="black",mew=1.4,alpha=0.8) for m in cols]
h.append(Line2D([],[],marker="o",ls="",markersize=13,markerfacecolor="#BDBDBD",markeredgecolor="black",mew=1.4))
fig.legend(h,list(cols)+["≤15 events"],title="Peak MDL likelihood month",loc="lower left",bbox_to_anchor=(0.03,0.015),ncol=5,
           frameon=False,fontsize=15,title_fontproperties={"weight":"bold","size":16},columnspacing=1.0,handletextpad=0.3)
fig.legend_.set_alignment("left") if hasattr(fig,"legend_") and fig.legend_ else None
ax.text(-0.17,1.0,"(a)",transform=ax.transAxes,fontsize=26,fontweight="bold")
# bar chart (retained sites only)
bx=fig.add_axes([0.60,0.13,0.38,0.76]); bar=T["fig3_bar"]
bx.bar(range(4),bar.values,width=0.75,color=[cols[m] for m in bar.index],edgecolor="black",lw=1.0,alpha=0.85,zorder=3)
bx.set_xticks(range(4)); bx.set_xticklabels(bar.index,fontsize=15)
ymax=int(bar.max()); bx.set_yticks(range(0,ymax+1)); bx.set_ylim(0,ymax*1.05); bx.tick_params(axis="y",labelsize=15,length=0); bx.tick_params(axis="x",length=0)
bx.grid(axis="y",color="#DEDEDE",ls=(0,(4,3)),lw=0.9,zorder=0)
for sp in bx.spines.values(): sp.set_visible(False)
bx.set_ylabel("Number of stations",fontsize=17,fontweight="bold")
bx.text(-0.12,0.985,"(b)",transform=bx.transAxes,fontsize=26,fontweight="bold")
fig.savefig("Figure3_Peak_MDL_Likelihood_Month_FINAL_300dpi.png",dpi=300,facecolor="white")
print("ok",bar.to_dict())
