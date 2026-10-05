from plots_common import *
import matplotlib.colors as mcolors
S4=T["figS4"].set_index("Station")
pairs=[("TR_API","(a) TR–API"),("TR_Seff1","(b) TR–S$_{\\rm eff}$[1]"),("API_Seff1","(c) API–S$_{\\rm eff}$[1]")]
cmap=mcolors.LinearSegmentedColormap.from_list("bwr3",[(0,0,1),(1,1,1),(1,0,0)],256)
lim=0.7; norm=mcolors.Normalize(-lim,lim)
fig=plt.figure(figsize=(18,6.6))
rects=[[0.045,0.24,0.29,0.70],[0.375,0.24,0.29,0.70],[0.705,0.24,0.29,0.70]]
for (lab,ttl),rc in zip(pairs,rects):
    ax=fig.add_axes(rc)
    for xg in range(86,97,2): ax.plot([xg,xg],[21.4,29.6],"--",color=(0.82,)*3,lw=0.45,zorder=0)
    for yg in range(22,30): ax.plot([85.5,97.6],[yg,yg],"--",color=(0.82,)*3,lw=0.45,zorder=0)
    draw_states(ax,fill=(0.96,0.96,0.96),edge="black",lw=1.4,z=1)
    cnt={"pos":0,"neg":0,"ns":0}
    for s in ORDER:
        d=disp(s); t=S4.loc[d,f"tau_{lab}_days"]; p=S4.loc[d,f"p_{lab}_days"]; lo,la=F.loc[s,"Long"],F.loc[s,"Lat"]
        if is_low(s):
            ax.scatter(lo,la,s=120,facecolor="white",edgecolor="0.5",lw=1.6,zorder=4); continue
        if np.isfinite(p) and p<0.05:
            ax.scatter(lo,la,s=160,color=cmap(norm(t)),edgecolor="k",lw=1.35,zorder=6); cnt["pos" if t>0 else "neg"]+=1
        else:
            ax.scatter(lo,la,s=145,color=cmap(norm(t)),edgecolor=(0.55,)*3,lw=0.95,alpha=0.8,zorder=5); cnt["ns"]+=1
    ax.set_xlim(85.5,97.6); ax.set_ylim(21.4,29.6); ax.set_aspect("equal")
    deg_ticks(ax,list(range(86,97,2)),list(range(22,30)),13)
    for tl in ax.get_xticklabels()+ax.get_yticklabels(): tl.set_fontweight("bold")
    ax.set_xlabel("Longitude",fontsize=16,fontweight="bold"); ax.set_ylabel("Latitude",fontsize=16,fontweight="bold")
    ax.set_title(ttl,fontsize=17,fontweight="bold"); [sp.set_visible(False) for sp in (ax.spines["top"],ax.spines["right"])]
    ax.tick_params(direction="out",width=1.1)
    vals=[cnt["pos"],cnt["ns"],cnt["neg"]]; tot=sum(vals)
    ad=ax.inset_axes([0.70,0.06,0.30,0.38])
    donut(ad,vals,[(1,0,0),(0.45,0.45,0.45),(0,0,1)],[f"{round(100*v/tot)}%" for v in vals],r_in=0.32,fs=10.5)
    S4.loc[:, f"donut_{lab}"]=str(vals)
    print(ttl,"pos/ns/neg (retained 17):",vals)
cax=fig.add_axes([0.36,0.075,0.32,0.035])
cb=fig.colorbar(plt.cm.ScalarMappable(norm=norm,cmap=cmap),cax=cax,orientation="horizontal",ticks=[-0.6,-0.4,-0.2,0,0.2,0.4,0.6])
cb.set_label(r"Kendall's $\tau$",fontsize=16,fontweight="bold"); cb.ax.tick_params(labelsize=12)
h=[Line2D([],[],marker="o",ls="",ms=12,mfc=(1,0.15,0.15),mec="k",mew=1.3),Line2D([],[],marker="o",ls="",ms=12,mfc=(0.15,0.15,1),mec="k",mew=1.3),
   Line2D([],[],marker="o",ls="",ms=12,mfc=(0.75,0.75,0.75),mec=(0.55,)*3),Line2D([],[],marker="o",ls="",ms=10,mfc="white",mec="0.5",mew=1.6)]
fig.legend(h,["Significant positive dependence","Significant negative dependence","Insignificant dependence","≤15 events (not classified)"],
           loc="lower left",bbox_to_anchor=(0.01,0.0),frameon=False,fontsize=12.5,prop={"weight":"bold","size":12.5},ncol=1,labelspacing=0.35)
fig.savefig("FigureS4_Pairwise_Kendall_TR_API_Seff1_FINAL_300dpi.png",dpi=300,facecolor="white"); print("ok")
