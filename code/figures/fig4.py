from plots_common import *
import matplotlib.colors as mcolors
a=T["fig4a"].set_index("Station"); b=T["fig4b"].set_index("Station")
cmap=plt.get_cmap("magma_r")
TRc="#2166D9"; AMCc="#E8433A"
fig=plt.figure(figsize=(19,7.4))
allp=np.vstack(G["polys"])
def panel(rect,vals,vmin,vmax,donut_vals,donut_cols,legend_labels,cbar_label,cbar_ticks,tag):
    ax=fig.add_axes(rect)
    for xg in range(86,97,2): ax.plot([xg,xg],[21.3,29.6],color="#D9D9D9",ls="--",lw=0.5,zorder=0)
    for yg in range(22,30): ax.plot([85.6,97.6],[yg,yg],color="#D9D9D9",ls="--",lw=0.5,zorder=0)
    draw_states(ax,fill="white",edge="black",lw=0.6,z=1)
    norm=mcolors.Normalize(vmin,vmax)
    for s in ORDER:
        lo,la=F.loc[s,"Long"],F.loc[s,"Lat"]
        if is_low(s): ax.scatter(lo,la,s=150,facecolor="#BFBFBF",edgecolor="black",lw=0.9,alpha=0.9,zorder=4)
        else: ax.scatter(lo,la,s=150,color=cmap(norm(vals[s])),edgecolor="black",lw=0.9,alpha=0.85,zorder=5)
    ax.set_xlim(85.6,97.6); ax.set_ylim(21.3,29.6); ax.set_aspect("equal")
    deg_ticks(ax,list(range(86,97,2)),list(range(22,30)),12)
    ax.set_xlabel("Longitude",fontsize=15,fontweight="bold"); ax.set_ylabel("Latitude",fontsize=15,fontweight="bold")
    for t in ax.get_xticklabels()+ax.get_yticklabels(): t.set_fontweight("bold")
    ax.tick_params(direction="out",width=1.0); [sp.set_linewidth(1.0) for sp in ax.spines.values()]
    ax.text(-0.12,1.02,tag,transform=ax.transAxes,fontsize=24,fontweight="bold")
    # donut inset
    tot=sum(donut_vals); labs=[f"{round(100*v/tot)}%" for v in donut_vals]
    ad=ax.inset_axes([0.745,0.205,0.235,0.30])
    donut(ad,donut_vals,donut_cols,labs,r_in=0.30,fs=10.5)
    lg=ax.legend([Patch(fc=c,ec="black") for c in donut_cols],legend_labels,loc="lower right",bbox_to_anchor=(0.995,0.02),
              frameon=True,edgecolor="black",fancybox=False,prop={"weight":"bold","size":10.5},handlelength=1.2)
    ax.add_artist(lg)
    ax.legend([Line2D([],[],marker="o",ls="",ms=10,mfc="#BFBFBF",mec="black")],["≤15 events (not classified)"],
              loc="upper left",frameon=False,prop={"size":10.5},handletextpad=0.2,borderaxespad=0.3)
    # colourbar
    cax=fig.add_axes([rect[0]-0.02,0.115,rect[2]+0.04,0.03])
    cb=fig.colorbar(plt.cm.ScalarMappable(norm=norm,cmap=cmap),cax=cax,orientation="horizontal",ticks=cbar_ticks)
    cb.set_label(cbar_label,fontsize=16,fontweight="bold"); cb.ax.tick_params(labelsize=12)
    return ax
ret=RET
amc=sum(a.loc[disp(s),"ADF_K090_supplied"]>=0.5 for s in ret); trd=len(ret)-amc
panel([0.055,0.27,0.40,0.66],{s:a.loc[disp(s),"ADF_K090_supplied"] for s in ORDER},0,1,[trd,amc],[TRc,AMCc],
      ["TR-dominant","AMC-dominant"],"ADF",[0,0.25,0.5,0.75,1],"(a)")
g_amc=sum(b.loc[disp(s),"G_AMC_over_G_TR"]>1 for s in ret); g_tr=len(ret)-g_amc
panel([0.555,0.27,0.40,0.66],{s:b.loc[disp(s),"G_AMC_over_G_TR"] for s in ORDER},0.6,1.4,[g_amc,g_tr],[AMCc,TRc],
      ["AMC > TR","AMC < TR"],r"$\mathbf{G_{AMC}/G_{TR}}$",[0.6,0.8,1.0,1.2,1.4],"(b)")

fig.savefig("Figure4_ADF_GiniRatio_FINAL_300dpi.png",dpi=300,facecolor="white")
print("ADF donut TR/AMC:",trd,amc,"| Gini donut AMC>TR / AMC<TR:",g_amc,g_tr)
