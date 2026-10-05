from plots_common import *
f7=T["fig7"].set_index("Station"); A=T["all_ret_dd"]
keys=["SeffTopt","Seff1","Seff0"]; cols=[(0.90,0.45,0.10),(0.15,0.45,0.85),(0.55,0.34,0.69)]; greys=[(0.80,)*3,(0.66,)*3,(0.52,)*3]
labels=["All"]+[disp(s) for s in ORDER]
fig,ax=plt.subplots(figsize=(17,6.6)); fig.subplots_adjust(left=0.07,right=0.99,top=0.97,bottom=0.21)
w=0.27; x=np.arange(len(labels))
for j,k in enumerate(keys):
    for i,lab in enumerate(labels):
        if lab=="All": t,se,p,scale,low=A[f"tau_{k}"],A[f"SE_{k}"],A[f"p_{k}"],1.0,False
        else:
            s=ORDER[i-1]; r=f7.loc[lab]; t,se,p,scale,low=r[f"tau_{k}"],r[f"SE_{k}"],r[f"p_{k}"],0.5,is_low(s)
        xi=x[i]+(j-1)*w; c=greys[j] if low else cols[j]
        if not np.isfinite(t): continue
        ax.bar(xi,t,w,color=c,edgecolor=(0.2,0.2,0.2),lw=0.6,zorder=3)
        if np.isfinite(se):
            lo=max(-1,t-scale*se); hi=min(1,t+scale*se)
            ax.errorbar(xi,t,yerr=[[t-lo],[hi-t]],fmt="none",ecolor=("0.6" if low else "k"),elinewidth=(0.8 if low else 1),capsize=3,zorder=4)
        else: hi,lo=t,t
        if np.isfinite(p) and p<=0.10 and not low:
            st="**" if p<=0.05 else "*"; yt=hi+0.05 if hi>=0 else lo-0.05
            ax.text(xi,yt,st,ha="center",va="center",fontsize=12,fontweight="bold")
ax.axhline(0,color="k",lw=0.8,zorder=2)
ax.set_xlim(-0.5,len(labels)-0.5); ax.set_ylim(-1,1); ax.set_yticks([-1,-0.5,0,0.5,1])
ax.set_xticks(x); ax.set_xticklabels(labels,rotation=32,ha="right",fontsize=14,rotation_mode="anchor")
ax.tick_params(axis="y",labelsize=14,direction="in"); ax.tick_params(axis="x",direction="in")
ax.set_ylabel(r"Kendall's $\tau$ (LF vs S$_{\rm eff}$)",fontsize=18,fontweight="bold")
ax.text(0.005,0.97,r"$\pm$0.5 SE (stations), $\pm$1 SE (All)",transform=ax.transAxes,fontsize=11,va="top")
h=[Patch(fc=c,ec=(0.2,0.2,0.2)) for c in cols]+[Patch(fc=greys[1],ec=(0.2,0.2,0.2))]
ax.legend(h,[r"S$_{\rm eff}$[T$_{\rm opt}$]",r"S$_{\rm eff}$[1]",r"S$_{\rm eff}$[0]","≤15 events (not interpreted)"],loc="lower center",
          bbox_to_anchor=(0.5,0.03),ncol=4,frameon=True,edgecolor="black",fancybox=False,fontsize=12)
fig.savefig("Figure7_Kendall_LF_vs_Seff_FINAL_300dpi.png",dpi=300,facecolor="white"); print("ok")
