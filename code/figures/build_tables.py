"""Builds every number needed for Figs 3, 4a, 4b, 7, S1, S4, S5 + QC. Writes tables.pkl and an Excel workbook."""
import os, numpy as np, pandas as pd, pickle
from core import *

F = load_meta().set_index("Station")
P = load_pairs()
E = load_events_k090()

# ------------------------------------------------------------------ inventory / grey rule
inv = P.groupby("Station").agg(n_assign=("PhysID","size"), n_lsdays=("Date","nunique"),
        n_shared=("Repeated_between_station_buffers","sum")).reindex(ORDER)
inv["n_assign_0719"] = P[P.Date.dt.year<=HYD_Y1].groupby("Station").size().reindex(ORDER)
inv["n_lsdays_0719"] = P[P.Date.dt.year<=HYD_Y1].groupby("Station").Date.nunique().reindex(ORDER)
inv["Low_sample"] = inv.n_assign <= LOW_N
inv["Status"] = np.where(inv.Low_sample, "Grey (<=15)", "Retained")
RET = [s for s in ORDER if not inv.loc[s,"Low_sample"]]

# ------------------------------------------------------------------ FIGURE 3: monthly MDL likelihood (JJAS)
years = np.arange(INV_Y0, INV_Y1+1)
ndays = {m: sum(pd.Period(f"{y}-{m:02d}").days_in_month for y in years) for m in (6,7,8,9)}
f3=[]
for s in ORDER:
    p=P[P.Station==s]
    row={"Station":disp(s),"IMD_ID":int(F.loc[s,"IMD_ID"]),"Status":inv.loc[s,"Status"]}
    lik={}
    for m,nm in zip((6,7,8,9),("Jun","Jul","Aug","Sep")):
        d=p[p.Date.dt.month==m]
        row[f"{nm}_landslides"]=len(d); row[f"{nm}_ls_days"]=d.Date.nunique()
        lik[m]=d.Date.nunique()/ndays[m]; row[f"{nm}_P_pct"]=100*lik[m]
    mx=max(lik.values()); tied=[m for m in lik if abs(lik[m]-mx)<1e-15]
    if len(tied)>1:   # tie-break: more landslides in that month, then flag
        cnts={m:row[f"{('Jun','Jul','Aug','Sep')[m-6]}_landslides"] for m in tied}
        best=max(cnts.values()); tied2=[m for m in tied if cnts[m]==best]
        peak=tied2[0]; tie_note=f"tie on likelihood {[('Jun','Jul','Aug','Sep')[t-6] for t in tied]}; broken by landslide count" + (" (still tied -> first month)" if len(tied2)>1 else "")
    else: peak=tied[0]; tie_note=""
    row["JJAS_share_of_landslides_pct"]=100*p.Date.dt.month.isin([6,7,8,9]).mean()
    row["Peak_month"]=("Jun","Jul","Aug","Sep")[peak-6]; row["Peak_month_num"]=peak; row["Peak_P_pct"]=100*lik[peak]; row["Tie_note"]=tie_note
    # peak by landslide counts (original-style count) for comparison
    cm={m:row[f"{('Jun','Jul','Aug','Sep')[m-6]}_landslides"] for m in (6,7,8,9)}
    row["Peak_by_count"]=("Jun","Jul","Aug","Sep")[max(cm,key=cm.get)-6]
    f3.append(row)
fig3=pd.DataFrame(f3)
fig3_bar = fig3[fig3.Status=="Retained"].Peak_month.value_counts().reindex(["Jun","Jul","Aug","Sep"],fill_value=0)
fig3_bar21 = fig3.Peak_month.value_counts().reindex(["Jun","Jul","Aug","Sep"],fill_value=0)

# ------------------------------------------------------------------ FIGURE 4a: ADF (supplied) + sensitivities
E["Year"]=E.Date.dt.year
def adf(df):
    g=df.groupby("Station").agg(n=("API_GT_TR","size"),k=("API_GT_TR","sum")); return g
s_all=adf(E); s_0719=adf(E[E.Year<=HYD_Y1]); s_day=adf(E[E.Year<=HYD_Y1].drop_duplicates(["Station","Date"]))
f4a=[]
for s in ORDER:
    a=F.loc[s,"ADF_K090"]
    f4a.append({"Station":disp(s),"IMD_ID":int(F.loc[s,"IMD_ID"]),"Nstar":int(F.loc[s,"Nstar"]),"Status":inv.loc[s,"Status"],
      "ADF_K090_supplied":a,"API>TR_events":int(s_all.loc[s,"k"]),"Events":int(s_all.loc[s,"n"]),
      "Class":"AMC-dominant" if a>=0.5 else "TR-dominant",
      "ADF_2007_2019_rows":s_0719.loc[s,"k"]/s_0719.loc[s,"n"],"Events_2007_2019":int(s_0719.loc[s,"n"]),
      "ADF_2007_2019_lsdays":s_day.loc[s,"k"]/s_day.loc[s,"n"],"LS_days_2007_2019":int(s_day.loc[s,"n"])})
fig4a=pd.DataFrame(f4a)
for c in ["ADF_2007_2019_rows","ADF_2007_2019_lsdays"]:
    fig4a["Class_"+c.split("ADF_")[1]]=np.where(fig4a[c]>=0.5,"AMC-dominant","TR-dominant")

# ------------------------------------------------------------------ FIGURE 4b + S1: annual Lorenz / Gini (2007-2019)
yrs=np.arange(HYD_Y0,HYD_Y1+1)
def gini_block(df,label):
    out={}; curves={}
    for s in ORDER:
        e=df[(df.Station==s)&(df.Year>=HYD_Y0)&(df.Year<=HYD_Y1)]
        trA=e.groupby("Year").TR_raw.sum().reindex(yrs,fill_value=0).to_numpy()
        amA=e.groupby("Year").API_raw.sum().reindex(yrs,fill_value=0).to_numpy()
        pT,LT,GT=lorenz_gini(trA); pA,LA,GA=lorenz_gini(amA)
        yT=np.interp(0.5,pT,LT); yA=np.interp(0.5,pA,LA)
        out[s]=dict(G_TR=GT,G_AMC=GA,Ratio=GA/GT,Upper50_TR_pct=100*(1-yT),Upper50_AMC_pct=100*(1-yA),
                    L50_TR=yT,L50_AMC=yA,Years_with_MDL=int((trA>0).sum()+0*(amA>0).sum()),N_events=len(e))
        curves[s]=(pT,LT,pA,LA)
    return pd.DataFrame(out).T, curves
g_rows,curves_rows=gini_block(E,"rows")
g_days,_=gini_block(E.drop_duplicates(["Station","Date"]),"days")
fig4b=pd.DataFrame({"Station":[disp(s) for s in ORDER],"IMD_ID":[int(F.loc[s,"IMD_ID"]) for s in ORDER],
    "Nstar":[int(F.loc[s,"Nstar"]) for s in ORDER],"Status":[inv.loc[s,"Status"] for s in ORDER],
    "N_events_2007_2019":g_rows.N_events.astype(int).values,"G_TR":g_rows.G_TR.values,"G_AMC":g_rows.G_AMC.values,
    "G_AMC_over_G_TR":g_rows.Ratio.values,"Upper50_TR_pct":g_rows.Upper50_TR_pct.values,"Upper50_AMC_pct":g_rows.Upper50_AMC_pct.values,
    "Class":np.where(g_rows.Ratio.values>1,"AMC > TR","AMC < TR"),
    "G_ratio_lsdays":g_days.Ratio.values,"Class_lsdays":np.where(g_days.Ratio.values>1,"AMC > TR","AMC < TR")})

# ------------------------------------------------------------------ FIGURE 7: Kendall tau LF vs S_eff (station-years)
def seff_metrics(imd,nstar,dates):
    s=load_seff(imd); out=[]
    for d in dates:
        w=s[(s.index>=d-pd.Timedelta(days=nstar))&(s.index<=d-pd.Timedelta(days=1))]
        out.append((w.median() if len(w) else np.nan, s.get(d-pd.Timedelta(days=1),np.nan), s.get(d,np.nan)))
    return np.array(out,float)
f7_pairs={}; f7=[]
for s in ORDER:
    imd=int(F.loc[s,"IMD_ID"]); ns=int(F.loc[s,"Nstar"]); p=P[P.Station==s]
    rows=[]
    for y,grp in p.groupby(p.Date.dt.year):
        v=seff_metrics(imd,ns,list(grp.Date))
        rows.append(dict(Year=y,LF=len(grp),SeffTopt=np.nanmedian(v[:,0]) if np.isfinite(v[:,0]).any() else np.nan,
                         Seff1=np.nanmedian(v[:,1]) if np.isfinite(v[:,1]).any() else np.nan,
                         Seff0=np.nanmedian(v[:,2]) if np.isfinite(v[:,2]).any() else np.nan))
    yr=pd.DataFrame(rows); f7_pairs[s]=yr
    rec={"Station":disp(s),"IMD_ID":imd,"Nstar":ns,"Status":inv.loc[s,"Status"]}
    for k in ("SeffTopt","Seff1","Seff0"):
        d=yr[["LF",k]].dropna(); t,pv,n=kendall(d.LF,d[k]); se=jackknife_se(d.LF,d[k]) if n>=3 else np.nan
        rec.update({f"tau_{k}":t,f"p_{k}":pv,f"n_{k}":n,f"SE_{k}":se})
    f7.append(rec)
fig7=pd.DataFrame(f7)
def pooled(stations, dedup):
    out={}
    allp=pd.concat([f7_pairs[s].assign(Station=s) for s in stations])
    for k in ("SeffTopt","Seff1","Seff0"):
        d=allp[["LF",k,"Year"]].dropna()
        if dedup: d=d.drop_duplicates(["Year","LF",k])
        t,pv,n=kendall(d.LF,d[k]); se=jackknife_se(d.LF,d[k])
        out.update({f"tau_{k}":t,f"p_{k}":pv,f"n_{k}":n,f"SE_{k}":se})
    return out
all_orig=pooled(ORDER,False); all_ret=pooled(RET,False); all_ret_dd=pooled(RET,True)

# ------------------------------------------------------------------ FIGURE S4: pairwise Kendall tau (TR, API, S_eff[1])
s4=[]
for s in ORDER:
    imd=int(F.loc[s,"IMD_ID"]); e=E[(E.Station==s)&(E.Year<=HYD_Y1)].copy()
    sf=load_seff(imd); e["Seff1"]=[sf.get(d-pd.Timedelta(days=1),np.nan) for d in e.Date]
    rec={"Station":disp(s),"IMD_ID":imd,"Nstar":int(F.loc[s,"Nstar"]),"Status":inv.loc[s,"Status"]}
    for unit,dd in (("days",e.drop_duplicates("Date")),("rows",e)):
        for a,b,lab in (("TR_raw","API_raw","TR_API"),("TR_raw","Seff1","TR_Seff1"),("API_raw","Seff1","API_Seff1")):
            t,pv,n=kendall(dd[a],dd[b]); rec.update({f"tau_{lab}_{unit}":t,f"p_{lab}_{unit}":pv,f"n_{lab}_{unit}":n})
    s4.append(rec)
figS4=pd.DataFrame(s4)
def s4class(t,p,alpha=0.05):
    if not np.isfinite(t) or not np.isfinite(p): return "NA"
    return "Sig. positive" if (p<alpha and t>0) else ("Sig. negative" if (p<alpha and t<0) else "Insignificant")
for lab in ("TR_API","TR_Seff1","API_Seff1"):
    for unit in ("days","rows"):
        figS4[f"class_{lab}_{unit}"]=[s4class(t,p) for t,p in zip(figS4[f"tau_{lab}_{unit}"],figS4[f"p_{lab}_{unit}"])]
        figS4[f"class10_{lab}_{unit}"]=[s4class(t,p,0.10) for t,p in zip(figS4[f"tau_{lab}_{unit}"],figS4[f"p_{lab}_{unit}"])]

# ------------------------------------------------------------------ FIGURE S5: P_TR - JEP for the 27 events
J=pd.read_excel(os.path.join(os.path.dirname(os.path.abspath(__file__)),"jep_inputs","out_nplus1_final27.xlsx"))
J["DeltaP_pct"]=100*(J.TR_exceedance-J.JEP_formula)
S5=J[["Station","StationID","Year_sel","Month_sel","Day_sel","Slope_deg","TR_sel","API_sel","Seff_sel","TR_exceedance","JEP_formula","DeltaP_pct","n_station"]].copy()
S5.insert(0,"Event",range(1,len(S5)+1))
alt_days=pd.read_csv(os.path.join(os.path.dirname(os.path.abspath(__file__)),"jep_inputs","jep_test_max_days.csv")); alt_days["DeltaP_pct"]=100*alt_days.dP
cur_rows=pd.read_csv(os.path.join(os.path.dirname(os.path.abspath(__file__)),"jep_inputs","jep_test_average_rows.csv")); cur_rows["DeltaP_pct"]=100*cur_rows.dP

pickle.dump(dict(F=F,P=P,E=E,inv=inv,RET=RET,fig3=fig3,fig3_bar=fig3_bar,fig3_bar21=fig3_bar21,fig4a=fig4a,fig4b=fig4b,
                 curves_rows=curves_rows,fig7=fig7,f7_pairs=f7_pairs,all_orig=all_orig,all_ret=all_ret,all_ret_dd=all_ret_dd,
                 figS4=figS4,S5=S5,alt_days=alt_days,cur_rows=cur_rows),open("tables.pkl","wb"))
pd.set_option("display.width",250); pd.set_option("display.max_columns",40)
print("RETAINED:",len(RET),"| GREY:",[s for s in ORDER if s not in RET])
print("\n=== FIG 3 ==="); print(fig3[["Station","Status","Jun_ls_days","Jul_ls_days","Aug_ls_days","Sep_ls_days","Peak_month","Peak_P_pct","Peak_by_count","Tie_note"]].round(3).to_string(index=False))
print("bars retained:",fig3_bar.to_dict(),"| all 21:",fig3_bar21.to_dict())
print("\n=== FIG 4a ==="); print(fig4a.round(3).to_string(index=False))
print("\n=== FIG 4b/S1 ==="); print(fig4b.round(3).to_string(index=False))
print("\n=== FIG 7 ==="); print(fig7.round(3).to_string(index=False))
for k,v in (("All (21, as script)",all_orig),("All (17 retained)",all_ret),("All (17 retained, exact dup removed)",all_ret_dd)):
    print(k,{kk:round(vv,3) for kk,vv in v.items()})
print("\n=== FIG S4 (days) ==="); print(figS4[["Station","Status"]+[c for c in figS4.columns if c.endswith("_days") and (c.startswith("tau") or c.startswith("p_") or c.startswith("n_"))]].round(3).to_string(index=False))
print("\n=== S5 ==="); print(S5.round(3).to_string(index=False)); print("min DeltaP:",S5.DeltaP_pct.min())
