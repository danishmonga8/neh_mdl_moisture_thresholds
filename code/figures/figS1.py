from plots_common import *
C=T["curves_rows"]; b=T["fig4b"].set_index("Station")
colEq=(0.60,0.60,0.60); colTR=(0.10,0.40,0.85); colAMC=(0.92,0.20,0.18)
colTRg=(0.55,0.75,0.98); colAMCg=(1.00,0.68,0.68); colRef=(0.78,0.78,0.78)
fig,axs=plt.subplots(6,4,figsize=(18.5,13.6)); fig.subplots_adjust(left=0.065,right=0.99,top=0.975,bottom=0.075,hspace=0.42,wspace=0.16)
for k,ax in enumerate(axs.flat):
    if k>=len(ORDER): ax.axis("off"); continue
    s=ORDER[k]; pT,LT,pA,LA=C[s]; r=b.loc[disp(s)]; low=is_low(s)
    hE,=ax.plot([0,1],[0,1],color=colEq,lw=1.0)
    hT,=ax.plot(pT,LT,color=colTR,lw=2.2); hA,=ax.plot(pA,LA,color=colAMC,lw=2.2)
    yT=np.interp(0.5,pT,LT); yA=np.interp(0.5,pA,LA)
    ax.plot([0.5,0.5],[0,1],"--",color=colRef,lw=0.9)
    ax.plot([0,0.5],[yT,yT],"--",color=colTRg,lw=1.0); ax.plot([0,0.5],[yA,yA],"--",color=colAMCg,lw=1.0)
    ax.plot(0.5,yT,"o",ms=4.5,color=colTR); ax.plot(0.5,yA,"o",ms=4.5,color=colAMC)
    for xa,yy,cg,c,pct in ((0.10,yT,colTRg,colTR,100*(1-yT)),(0.20,yA,colAMCg,colAMC,100*(1-yA))):
        ax.plot([xa,xa],[yy,1],color=cg,lw=1.1); ax.plot(xa,1,"k^",ms=4); ax.plot(xa,yy,"kv",ms=4)
        ax.text(xa+0.01,(1+yy)/2,f"{pct:.0f}%",color=c,fontsize=9.5,fontweight="bold",ha="left",va="center",
                bbox=dict(fc="white",ec="none",pad=0.5))
    ax.text(0.34,0.88,f"G$_{{TR}}$ = {r.G_TR:.3f}",transform=ax.transAxes,fontsize=11,fontweight="bold",color=colTR,va="top",bbox=dict(fc="white",ec="none",pad=0.5))
    ax.text(0.34,0.60,f"G$_{{AMC}}$ = {r.G_AMC:.3f}",transform=ax.transAxes,fontsize=11,fontweight="bold",color=colAMC,va="top",bbox=dict(fc="white",ec="none",pad=0.5))
    ax.set_xlim(0,1); ax.set_ylim(0,1); ax.set_xticks([0,0.5,1]); ax.set_yticks([0,0.5,1])
    ax.set_xticklabels(["0","0.5","1"],fontweight="bold",fontsize=11); ax.set_yticklabels(["0","0.5","1"],fontweight="bold",fontsize=11)
    ax.tick_params(direction="out",width=1.0)
    ttl=disp(s)+(" (≤15 events)" if low else "")
    ax.set_title(ttl,fontsize=14,fontweight="bold",color=("0.55" if low else "k"))
    if low:
        ax.set_facecolor("#F2F2F2")
        for sp in ax.spines.values(): sp.set_edgecolor("0.55")
fig.supxlabel("Cumulative fraction of events per year",fontsize=19,fontweight="bold",y=0.012)
fig.supylabel("Cumulative fraction of annual total TR/AMC",fontsize=19,fontweight="bold",x=0.008)
axs.flat[len(ORDER)].legend([hE,hT,hA],["Equality line","TR","AMC"],loc="center left",frameon=False,fontsize=15,ncol=3,
                             prop={"weight":"bold","size":15})
fig.savefig("FigureS1_Lorenz_TR_AMC_FINAL_300dpi.png",dpi=300,facecolor="white"); print("ok")
