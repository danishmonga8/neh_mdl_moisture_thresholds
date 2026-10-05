import sys
from plots_common import *
def _local(x,y,x0,q):
    d=np.abs(x-x0); h=np.sort(d)[q-1]
    if h<=0: h=1e-12
    h=h*1.0
    w=np.clip(1-(d/h)**3,0,None)**3
    W=w.sum()
    if W<=0: return np.nan,0.0
    xm=(w*x).sum()/W; ym=(w*y).sum()/W; sxx=(w*(x-xm)**2).sum()
    if sxx<=1e-10*max(1.0,h*h)*W: return ym,0.0
    b=(w*(x-xm)*(y-ym)).sum()/sxx
    return ym+b*(x0-xm),b
def _kd_vertices(x,fc):
    lo,hi=x.min(),x.max(); m=0.005*max(hi-lo,1e-10); verts={lo-m,hi+m}
    def split(pts):
        if len(pts)<=fc or np.ptp(pts)==0: return
        pts=np.sort(pts); k=(len(pts)-1)//2; v=(pts[k]+pts[k+1])/2
        L=pts[pts<=v]; R=pts[pts>v]
        if len(L)==0 or len(R)==0: return
        verts.add(v); split(L); split(R)
    split(np.asarray(x,float)); return np.array(sorted(verts))
def loess1(x,y,xg,span=0.55,cell=0.2):
    """R loess(degree=1, family='gaussian', surface='interpolate'): local linear fits (tricube, q=floor(n*span))
    at kd-tree vertices (fc=floor(n*span*cell)), cubic Hermite interpolation between vertices."""
    x=np.asarray(x,float); y=np.asarray(y,float); n=len(x); q=max(int(np.floor(n*span)),2)
    fc=max(int(np.floor(n*span*cell)),1); V=_kd_vertices(x,fc)
    fv=np.array([_local(x,y,v,q) for v in V]); val,der=fv[:,0],fv[:,1]
    out=np.empty(len(xg))
    for i,x0 in enumerate(xg):
        j=np.clip(np.searchsorted(V,x0)-1,0,len(V)-2); x1,x2=V[j],V[j+1]; hseg=x2-x1; t=(x0-x1)/hseg
        h00=2*t**3-3*t**2+1; h10=t**3-2*t**2+t; h01=-2*t**3+3*t**2; h11=t**3-t**2
        out[i]=h00*val[j]+h10*hseg*der[j]+h01*val[j+1]+h11*hseg*der[j+1]
    return out
def make(df,fname,title_note=None,nboot=1000,seed=1):
    x=df.Slope_deg.to_numpy(float); y=df.DeltaP_pct.to_numpy(float)
    xg=np.linspace(x.min(),x.max(),300); fit=loess1(x,y,xg)
    rng=np.random.default_rng(seed); B=np.empty((nboot,len(xg)))
    for b in range(nboot):
        idx=rng.integers(0,len(x),len(x)); B[b]=loess1(x[idx],y[idx],xg)
    lo,hi=np.nanpercentile(B,2.5,axis=0),np.nanpercentile(B,97.5,axis=0)
    fig,ax=plt.subplots(figsize=(10.5,7.2)); fig.subplots_adjust(left=0.13,right=0.97,top=0.97,bottom=0.12)
    ax.fill_between(xg,lo,hi,color="0.6",alpha=0.55,lw=0,zorder=1)
    ax.plot(xg,fit,color="black",lw=3.2,zorder=2)
    ax.scatter(x,y,s=95,facecolor="#f39c12",edgecolor="black",lw=1.0,zorder=3)
    ax.set_xlim(5,30); ax.set_ylim(-25,100); ax.set_xticks(range(5,31,5)); ax.set_yticks(range(-25,101,25))
    ax.grid(True,ls=":",color="0.6",lw=0.8); ax.set_axisbelow(True)
    for sp in ax.spines.values(): sp.set_linewidth(1.0)
    ax.tick_params(labelsize=15,width=0.8)
    for t in ax.get_xticklabels()+ax.get_yticklabels(): t.set_fontweight("bold")
    ax.set_xlabel("Terrain slope (in degree)",fontsize=17,fontweight="bold")
    ax.set_ylabel(r"Exceedance probability$_{\{\mathrm{TR}\}}$ $-$ JEP$_{\{\mathrm{TR,\,API,\,S_{eff}}\}}$ (in %)",fontsize=16,fontweight="bold")
    h=[Patch(fc="0.6",ec="black",alpha=0.8),Line2D([],[],color="black",lw=3.2)]
    ax.legend(h,["95% bootstrap CI","LOWESS fit"],loc="upper left",bbox_to_anchor=(0.06,0.97),frameon=True,edgecolor="black",fancybox=False,
              prop={"weight":"bold","size":13},borderpad=0.9,labelspacing=1.0)
    if title_note: ax.text(0.98,0.97,title_note,transform=ax.transAxes,ha="right",va="top",fontsize=11,style="italic")
    fig.savefig(fname,dpi=300,facecolor="white"); plt.close(fig)
    return pd.DataFrame(dict(Slope_deg=xg,LOWESS=fit,CI_lo=lo,CI_hi=hi))
import pandas as pd
S5=T["S5"]
assert (S5.DeltaP_pct>=-1e-9).all(), "DeltaP<0 found -> STOP"
curve=make(S5,"FigureS5_Slope_vs_PTRminusJEP_LOWESS_27events_FINAL_300dpi.png")
alt=T["alt_days"].rename(columns={"Slope":"Slope_deg"})
curve_alt=make(alt,"FigureS5_ALT_consistentJEP_32largeDays_300dpi.png",
               title_note="Sensitivity: consistent ≤-count ranks, unique landslide-days (32 events)")
pickle.dump(dict(curve=curve,curve_alt=curve_alt),open("s5_curves.pkl","wb"))
print("S5 n=",len(S5),"DeltaP range",S5.DeltaP_pct.min().round(3),S5.DeltaP_pct.max().round(3),"| ALT n=",len(alt),"min",alt.DeltaP_pct.min().round(3))
for c,lab in ((curve,"27"),(curve_alt,"ALT32")):
    i=[np.argmin(abs(c.Slope_deg-v)) for v in (6.5,10,15,20,25,27.5)]
    print(lab,c.iloc[i].round(1).to_string(index=False))
