import pickle, numpy as np, pandas as pd
from core import *
T=pickle.load(open("tables.pkl","rb")); C5=pickle.load(open("s5_curves.pkl","rb"))
inv=T["inv"]; RET=T["RET"]; P=T["P"]; E=T["E"]; F=T["F"]
def pc(k,n): return f"{k} ({round(100*k/n)}%)"
out="Figure_Data_Tables_FINAL_fixedNstar.xlsx"; W=pd.ExcelWriter(out,engine="openpyxl")
# ---------- QC
qc=pd.DataFrame({"Station":[disp(s) for s in ORDER],"IMD_ID":[int(F.loc[s,"IMD_ID"]) for s in ORDER],
  "Final_Nstar_days":[int(F.loc[s,"Nstar"]) for s in ORDER],"ADF_at_K_0p90":[F.loc[s,"ADF_K090"] for s in ORDER],
  "Landslide_assignments_2007_2021":inv.n_assign.values,"Landslide_days_2007_2021":inv.n_lsdays.values,
  "Assignments_2007_2019":inv.n_assign_0719.values,"Landslide_days_2007_2019":inv.n_lsdays_0719.values,
  "Shared_with_other_buffers":inv.n_shared.values,"Retained_or_grey":inv.Status.values})
fig4a=T["fig4a"]; qc["Fig4a_plotted_ADF_equals_supplied"]=np.isclose(fig4a.ADF_K090_supplied.values,qc.ADF_at_K_0p90.values)
for c in ("Fig4b_S1_Nstar","FigS4_Nstar","Fig7_Topt_Nstar"): qc[c]=qc.Final_Nstar_days
qc.to_excel(W,"QC_station_table",index=False)
# ---------- inventory audit / decisions
mult=P.groupby("PhysID").Station.nunique().value_counts().sort_index()
sd=P.groupby(["Station","Date"]).size()
aud=pd.DataFrame([
 ("Station-landslide assignments (station-radius buffer, 2007-2021)",len(P)),
 ("Distinct physical landslides",P.PhysID.nunique()),
 ("Physical landslides inside >1 station buffer",int((P.groupby('PhysID').Station.nunique()>1).sum())),
 ("Extra assignments created by buffer overlap",len(P)-P.PhysID.nunique()),
 ("Physical landslides in 1 / 2 / 3 / 4 buffers"," / ".join(str(mult.get(k,0)) for k in (1,2,3,4))),
 ("Distinct station landslide-days",int(len(sd))),
 ("Station-days with >1 landslide (same-day duplicates)",int((sd>1).sum())),
 ("Extra rows from same-day duplicates",int((sd-1).sum())),
 ("Assignments in 2020-2021 (no rainfall / S_eff data)",int((P.Date.dt.year>=2020).sum())),
 ("Retained stations (>15 assignments)",len(RET)),
 ("Low-sample stations (<=15 assignments)",", ".join(disp(s) for s in ORDER if s not in RET)),
 ("Co-located stations sharing all landslides","Tadong-Gangtok (31/31; identical S_eff series); Barapani-Shillong (17/17)"),
],columns=["Item","Value"])
aud.to_excel(W,"Inventory_audit",index=False)
dec=pd.DataFrame([
 ("Fig 3","Seasonality","Station's own station-radius landslides (overlap retained); counted as landslide-DAYS; likelihood = landslide-days in month / days in month, 2007-2021","A day with several reported slides is one triggering occasion; per-day probability is what 'likelihood' means"),
 ("Fig 4a","ADF","Supplied ADF_at_K_0p90 plotted exactly (counts every landslide assignment, 2007-2021)","As instructed; sensitivity (2007-2019; landslide-days) given in Fig4a sheet"),
 ("Fig 4b / S1","Annual Lorenz/Gini","Annual sums of TR and API(N*) over landslide assignments, 2007-2019 (13 years)","Same unit as the original script; years 2020-21 excluded because rainfall is zero-filled; landslide-day sensitivity given"),
 ("Fig 7","Kendall LF vs S_eff","Station-years; LF = number of landslide assignments; S_eff medians over that year's landslides; All = 17 retained stations with exact duplicate station-years removed","Pooling all 21 stations double-counts co-located stations (Gangtok = Tadong exactly) and lets low-sample sites into the summary"),
 ("Fig S4","Pairwise Kendall tau","Unique landslide-DAYS, 2007-2019; p < 0.05","Same-day duplicates repeat identical TR/API/S_eff values, creating artificial ties and inflating n and significance"),
 ("Fig S5","P_TR - JEP vs slope","27 events as specified (Fig 8 set, rank/(N+1))","Flag: the 27 are 32 large events minus 5 average-rank artefacts; and only 18 distinct physical large landslides underlie them"),
 ("Text / pooled totals","Inventory statements","Use distinct physical landslides (369) for catalogue totals; never sum station counts","645 assignments contain 276 overlap duplicates"),
],columns=["Figure","Quantity","Counting unit used","Reason"])
dec.to_excel(W,"Counting_decisions",index=False)
# ---------- Fig 3
f3=T["fig3"].copy()
def margin(r):
    v=sorted([r.Jun_ls_days,r.Jul_ls_days,r.Aug_ls_days,r.Sep_ls_days],reverse=True); return v[0]-v[1]
f3["Margin_top_minus_second_lsdays"]=f3.apply(margin,axis=1)
f3["Robust_peak_(margin>=2)"]=f3["Margin_top_minus_second_lsdays"]>=2
f3.round(3).to_excel(W,"Fig3_peak_month",index=False)
r3=f3[f3.Status=="Retained"]; n=len(r3)
s3=pd.DataFrame({"Month":["Jun","Jul","Aug","Sep"],
  "Stations_peaking_retained17":[pc(int((r3.Peak_month==m).sum()),n) for m in ["Jun","Jul","Aug","Sep"]],
  "Stations_peaking_all21":[pc(int((f3.Peak_month==m).sum()),21) for m in ["Jun","Jul","Aug","Sep"]],
  "Retained_peaks_by_landslide_count":[int((r3.Peak_by_count==m).sum()) for m in ["Jun","Jul","Aug","Sep"]]})
s3.to_excel(W,"Fig3_summary",index=False)
# ---------- Fig 4a
a=fig4a.copy(); a.round(4).to_excel(W,"Fig4a_ADF",index=False)
ra=a[a.Status=="Retained"]; nr=len(ra)
s4a=pd.DataFrame([
 ("Supplied ADF (plotted)",pc(int((ra.Class=="TR-dominant").sum()),nr),pc(int((ra.Class=="AMC-dominant").sum()),nr),f"{ra.ADF_K090_supplied.min():.3f}-{ra.ADF_K090_supplied.max():.3f}",f"{ra.ADF_K090_supplied.median():.3f}"),
 ("Sensitivity: 2007-2019 only",pc(int((ra.Class_2007_2019_rows=="TR-dominant").sum()),nr),pc(int((ra.Class_2007_2019_rows=="AMC-dominant").sum()),nr),f"{ra.ADF_2007_2019_rows.min():.3f}-{ra.ADF_2007_2019_rows.max():.3f}",f"{ra.ADF_2007_2019_rows.median():.3f}"),
 ("Sensitivity: 2007-2019, landslide-days",pc(int((ra.Class_2007_2019_lsdays=="TR-dominant").sum()),nr),pc(int((ra.Class_2007_2019_lsdays=="AMC-dominant").sum()),nr),f"{ra.ADF_2007_2019_lsdays.min():.3f}-{ra.ADF_2007_2019_lsdays.max():.3f}",f"{ra.ADF_2007_2019_lsdays.median():.3f}"),
],columns=["Version (17 retained sites)","TR-dominant","AMC-dominant","ADF range","ADF median"])
s4a.to_excel(W,"Fig4a_summary",index=False)
# ---------- Fig 4b / S1
b=T["fig4b"].copy(); b.round(4).to_excel(W,"Fig4b_S1_Gini",index=False)
rb=b[b.Status=="Retained"]
s4b=pd.DataFrame([
 ("G_TR",f"{rb.G_TR.min():.3f}-{rb.G_TR.max():.3f}",f"{rb.G_TR.median():.3f}"),
 ("G_AMC",f"{rb.G_AMC.min():.3f}-{rb.G_AMC.max():.3f}",f"{rb.G_AMC.median():.3f}"),
 ("G_AMC/G_TR",f"{rb.G_AMC_over_G_TR.min():.3f}-{rb.G_AMC_over_G_TR.max():.3f}",f"{rb.G_AMC_over_G_TR.median():.3f}"),
 ("Top-50% years share of annual TR (%)",f"{rb.Upper50_TR_pct.min():.0f}-{rb.Upper50_TR_pct.max():.0f}",f"{rb.Upper50_TR_pct.median():.0f}"),
 ("Top-50% years share of annual AMC (%)",f"{rb.Upper50_AMC_pct.min():.0f}-{rb.Upper50_AMC_pct.max():.0f}",f"{rb.Upper50_AMC_pct.median():.0f}"),
 ("Sites with AMC > TR (ratio > 1)",pc(int((rb.Class=='AMC > TR').sum()),len(rb)),", ".join(rb[rb.Class=='AMC > TR'].Station)),
 ("Sites with AMC < TR",pc(int((rb.Class=='AMC < TR').sum()),len(rb)),""),
 ("Landslide-day sensitivity: AMC > TR",pc(int((rb.Class_lsdays=='AMC > TR').sum()),len(rb)),", ".join(rb[rb.Class_lsdays=='AMC > TR'].Station)),
],columns=["Metric (17 retained sites, 2007-2019)","Range / count","Median / sites"])
s4b.to_excel(W,"Fig4b_S1_summary",index=False)
# ---------- Fig 7
f7=T["fig7"].copy()
for k in ("SeffTopt","Seff1","Seff0"):
    f7[f"stars_{k}"]=np.where(f7[f"p_{k}"]<=0.05,"**",np.where(f7[f"p_{k}"]<=0.10,"*",""))
    f7.loc[f7.Status!="Retained",f"stars_{k}"]="(grey)"
f7.round(4).to_excel(W,"Fig7_Kendall_LF_Seff",index=False)
rows=[]
for lab,d in (("All - 17 retained, exact duplicate station-years removed (PLOTTED)",T["all_ret_dd"]),("All - 17 retained",T["all_ret"]),("All - 21 stations (original script pooling)",T["all_orig"])):
    rows.append(dict(Pooling=lab,**{kk:round(v,4) for kk,v in d.items()}))
pd.DataFrame(rows).to_excel(W,"Fig7_All_pooled",index=False)
# ---------- Fig S4
s4=T["figS4"].copy(); s4.round(4).to_excel(W,"FigS4_pairwise_tau",index=False)
rs=s4[s4.Status=="Retained"]; rr=[]
for lab,nm in (("TR_API","TR-API"),("TR_Seff1","TR-Seff[1]"),("API_Seff1","API-Seff[1]")):
    for unit in ("days","rows"):
        for al,cc in (("0.05","class_"),("0.10","class10_")):
            c=rs[f"{cc}{lab}_{unit}"]
            rr.append(dict(Pair=nm,Unit=("landslide-days (PLOTTED)" if unit=="days" else "all rows (original)"),alpha=al,
               Sig_positive=pc(int((c=="Sig. positive").sum()),len(rs)),Sig_negative=pc(int((c=="Sig. negative").sum()),len(rs)),
               Insignificant=pc(int((c=="Insignificant").sum()),len(rs)),
               tau_range=f"{rs[f'tau_{lab}_{unit}'].min():.2f} to {rs[f'tau_{lab}_{unit}'].max():.2f}",tau_median=round(rs[f'tau_{lab}_{unit}'].median(),2)))
pd.DataFrame(rr).to_excel(W,"FigS4_summary",index=False)
# ---------- Fig S5
S5=T["S5"].copy(); S5.round(4).to_excel(W,"FigS5_27events",index=False)
t,p,n=kendall(S5.Slope_deg,S5.DeltaP_pct)
c=C5["curve"]; idx=[int(np.argmin(abs(c.Slope_deg-v))) for v in (6.5,10,12.5,15,17.5,20,22.5,25,27.5)]
cs=c.iloc[idx].round(1); cs.insert(0,"Note","LOWESS (span 0.55, degree 1) and 95% bootstrap CI, 1000 resamples")
cs.to_excel(W,"FigS5_LOWESS_curve",index=False)
alt=T["alt_days"].copy(); alt.round(4).to_excel(W,"FigS5_ALT_consistent32",index=False)
cur=T["cur_rows"]; v=cur[cur.viol]
ss=pd.DataFrame([
 ("Events plotted",len(S5)),("Sites",S5.Station.nunique()),("DeltaP range (%)",f"{S5.DeltaP_pct.min():.1f}-{S5.DeltaP_pct.max():.1f}"),
 ("DeltaP median (%)",round(S5.DeltaP_pct.median(),1)),("Events with DeltaP = 0 (JEP = P_TR)",int((S5.DeltaP_pct<1e-9).sum())),
 ("Events with DeltaP < 0",int((S5.DeltaP_pct<-1e-9).sum())),("Kendall tau slope vs DeltaP",f"{t:.3f} (p = {p:.3f}, n = {n})"),
 ("Large events before the JEP<=P_TR filter",len(cur)),("Events removed as violators (current average-rank method)","; ".join(f"{a} {b}" for a,b in zip(v.Station,v.Date))),
 ("Violations under consistent <=-count ranks",int(T['alt_days'].viol.sum())),("Distinct physical large landslides behind the 27 events",15),("Distinct physical large landslides behind the 32 consistent events",17),
],columns=["Item","Value"])
ss.to_excel(W,"FigS5_summary",index=False)
# ---------- flags
fl=pd.DataFrame([
 ("HIGH","Fig S5 / Fig 8","The 27-event set = 32 large events minus 5 whose JEP exceeded P_TR. Those violations are an artefact of average ranks (tiedrank) for marginals vs <=-counting in the copula; with consistent <=-count ranks all 32 satisfy JEP <= P_TR (sheet FigS5_ALT_consistent32). The 27 are therefore a filtered, not a complete, sample."),
 ("HIGH","Fig S5 / Fig 8","The large-event points are not independent: 27 station-events come from only 15 distinct physical landslides (15 dates) (e.g. 2015-09-14 appears at 4 Mizoram gauges, 2012-06-07 at Tadong, Gangtok and Kalimpong, and Guwahati-Khanapara share 3 events). Bootstrap CIs treat them as independent."),
 ("HIGH","Fig 4a","Supplied ADF counts the 2021-06-12 landslide (4 Mizoram stations), for which TR = API = 0 because rainfall is zero-filled after 2019. At Aizawl this event alone lifts ADF from 13/27 = 0.481 to 14/28 = 0.500 and flips the class to AMC-dominant."),
 ("MEDIUM","Fig 4a","ADF depends on counting unit: switching to landslide-days changes the class at 6 of 17 retained stations (Darjeeling, Itanagar, Guwahati to AMC; Kalimpong, Barapani, Lengpui to TR); total AMC-dominant stays 7."),
 ("MEDIUM","Fig 3","Peak month is decided by a margin of <=1 landslide-day at 11 of 17 (65%) retained stations (Itanagar, Kohima and Aizawl by 0). With the final inventory June leads (9 of 17); the old July/September result came from the superseded inventory."),
 ("MEDIUM","Fig 7","Caption/code: ** = p <= 0.05, * = 0.05 < p <= 0.10 (code). Error bars +/-0.5 SE stations, +/-1 SE All (code and caption agree). Check that the caption defines the star levels this way."),
 ("MEDIUM","Fig S4","Map code used p < 0.10 to classify; the specification asks for p < 0.05. Plotted at p < 0.05; counts at p < 0.10 in FigS4_summary."),
 ("LOW","Period","Inventory window 2007-2021, but rainfall and S_eff end 31 Dec 2019; all hydro-meteorological statistics use 2007-2019. Step8 ADF used 2007-2021."),
 ("LOW","Co-location","Tadong and Gangtok share all 31 landslides and an identical S_eff series, so their Fig 7 bars are identical; Barapani-Shillong share all 17 landslides."),
 ("LOW","Fig S5 LOWESS","Re-implemented R loess (degree 1, span 0.55, kd-tree vertices + cubic Hermite interpolation); bootstrap RNG differs from R set.seed(1), so CI edges differ slightly from an R run."),
 ("LOW","Kendall p-values","Exact null distribution for n < 50 without ties, otherwise normal approximation with tie correction; matches MATLAB/R behaviour except for any continuity correction."),
],columns=["Severity","Figure","Issue"])
fl.to_excel(W,"Flags_inconsistencies",index=False)
W.close(); print("saved",out)
print(s3.to_string(index=False)); print(s4a.to_string(index=False)); print(s4b.to_string(index=False))
print(pd.DataFrame(rr).to_string(index=False)); print(ss.to_string(index=False))
print(f3[["Station","Status","Peak_month","Margin_top_minus_second_lsdays","Tie_note"]].to_string(index=False))
