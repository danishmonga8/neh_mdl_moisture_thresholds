"""Core data + statistics for the final figure update (Figs 3, 4, 7, S1, S4, S5)."""
import os, math, numpy as np, pandas as pd
B = os.environ.get("NEH_ROOT", os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "data"))
R1 = B
SEFF_DIR = f"{B}/10_soil_moisture_extraction/effective_saturation_time_series_all_stations/effective_saturation_time_series_all_stations"
PAIRS_XLSX = f"{R1}/step_0_landslide_filtering/Station_Landslide_Metadata_radius_ALLOW_OVERLAP.xlsx"
STEP8_XLSX = f"{R1}/step7_lag_selection_updated/K_sensitivity_fixed_Nstar/Step8_K_Sensitivity_Fixed_Nstar_ADF.xlsx"
META_XLSX = f"{B}/all_stations_neh.xlsx"

# ---------------- FINAL N* and ADF (authoritative, user-supplied) ----------------
FINAL = pd.DataFrame([
 ("Aizwal",326239204,3,0.500000000),("Guwahati",42410,3,0.444444444),("Khanapara",504269140,3,0.349206349),
 ("Kiphira",326259404,3,0.166666667),("Neihbawih Farm",326239209,3,0.640000000),("Sechu",504259407,3,0.529411765),
 ("Singla Bazar",505278806,3,0.454545455),("Kalimpong",42296,5,0.555555556),("Maram Farm",326259402,5,0.363636364),
 ("Nangpoh",504259111,5,0.333333333),("Kohima",42527,11,0.435897436),("Sairang",326239202,11,0.416666667),
 ("Tuensang",504269424,11,0.444444444),("Darjeeling",42295,15,0.474226804),("Lengpui",42726,15,0.560000000),
 ("Shillong",42516,15,0.588235294),("Barapani",42512,21,0.529411765),("Itanagar",42308,21,0.470588235),
 ("Gangtok",42299,25,0.419354839),("Imphal",42623,25,0.500000000),("Tadong",42217,25,0.419354839)],
 columns=["Station","IMD_ID","Nstar","ADF_K090"])
DISPLAY = {"Aizwal":"Aizawl","Neihbawih Farm":"Neihbawi Farm"}
# manuscript station order (as in current Fig 7 / S1)
ORDER = ["Tadong","Darjeeling","Kalimpong","Gangtok","Itanagar","Guwahati","Barapani","Shillong","Kohima","Imphal",
         "Lengpui","Sairang","Aizwal","Neihbawih Farm","Maram Farm","Kiphira","Nangpoh","Sechu","Khanapara","Tuensang","Singla Bazar"]
LOW_N = 15                 # stations with <= 15 landslide assignments are low-sample (grey)
HYD_Y0, HYD_Y1 = 2007, 2019  # rainfall / S_eff records end 31 Dec 2019
INV_Y0, INV_Y1 = 2007, 2021  # inventory window

def disp(s): return DISPLAY.get(s, s)

def load_meta():
    M = pd.read_excel(META_XLSX, sheet_name="Sheet1"); M.columns=[str(c).strip() for c in M.columns]
    M["Station"]=M.Station.astype(str).str.strip(); M["IMD_ID"]=M.IMD.astype(int)
    F = FINAL.merge(M[["IMD_ID","Lat","Long","Slope_Mean_Deg","Ideal_lag"]], on="IMD_ID", how="left")
    return F

def load_pairs():
    P = pd.read_excel(PAIRS_XLSX, sheet_name="Station_event_pairs")
    P["Station"]=P.Station.astype(str).str.strip(); P["IMD_ID"]=P.IMD_ID.astype(int)
    P["Date"]=pd.to_datetime(P.EventDate).dt.normalize()
    P["PhysID"]=P.Date.dt.strftime("%Y-%m-%d")+"_"+P.Latitude.round(6).astype(str)+"_"+P.Longitude.round(6).astype(str)
    return P[(P.Date.dt.year>=INV_Y0)&(P.Date.dt.year<=INV_Y1)].reset_index(drop=True)

def load_events_k090():
    """Event-level TR and API(N*, K=0.90) for all 645 assignments (Step8 source of the supplied ADF)."""
    E = pd.read_excel(STEP8_XLSX, sheet_name="Event_level")
    E = E[(E.K-0.90).abs()<1e-9].copy()
    E["Station"]=E.Station.astype(str).str.strip(); E["IMD_ID"]=E.IMD_ID.astype(int)
    E["Date"]=pd.to_datetime(E.Event_date).dt.normalize()
    return E

_seff_cache={}
def load_seff(imd):
    if imd in _seff_cache: return _seff_cache[imd]
    S = pd.read_csv(f"{SEFF_DIR}/{imd}_SMrz_Seff.txt", sep=r"\s+"); S.columns=[c.lower() for c in S.columns]
    s = pd.Series(S.s_eff.astype(float).to_numpy(), index=pd.to_datetime(dict(year=S.year,month=S.month,day=S.day)))
    _seff_cache[imd]=s; return s

# ---------------- statistics ----------------
def _mahonian(n):
    """counts of permutations of n with k inversions, k=0..n(n-1)/2"""
    c=np.array([1],dtype=object)
    for m in range(2,n+1):
        new=np.zeros(len(c)+m-1,dtype=object)
        for j in range(m): new[j:j+len(c)]+=c
        c=new
    return c

def kendall(x, y):
    """Kendall tau-b and two-sided p (exact for n<50 without ties, else normal approx with tie-corrected variance)."""
    x=np.asarray(x,float); y=np.asarray(y,float); m=np.isfinite(x)&np.isfinite(y); x=x[m]; y=y[m]; n=len(x)
    if n<2: return np.nan,np.nan,n
    iu=np.triu_indices(n,1)
    dx=np.sign(x[:,None]-x[None,:])[iu]; dy=np.sign(y[:,None]-y[None,:])[iu]
    S=float((dx*dy).sum()); n0=n*(n-1)/2; n1=float((dx==0).sum()); n2=float((dy==0).sum())
    if n0-n1==0 or n0-n2==0: return np.nan,np.nan,n
    tau=S/math.sqrt((n0-n1)*(n0-n2))
    if n1==0 and n2==0 and n<50:
        cnt=_mahonian(n); tot=sum(cnt); inv=np.arange(len(cnt)); Sv=n0-2*inv
        p=float(sum(c for c,s in zip(cnt,Sv) if abs(s)>=abs(S)-1e-9))/float(tot)
    else:
        tx=pd.Series(x).value_counts().to_numpy(float); ty=pd.Series(y).value_counts().to_numpy(float)
        v0=n*(n-1)*(2*n+5); vt=(tx*(tx-1)*(2*tx+5)).sum(); vu=(ty*(ty-1)*(2*ty+5)).sum()
        v1=(tx*(tx-1)).sum()*(ty*(ty-1)).sum()/(2*n*(n-1))
        v2=(tx*(tx-1)*(tx-2)).sum()*(ty*(ty-1)*(ty-2)).sum()/(9*n*(n-1)*(n-2)) if n>2 else 0
        var=(v0-vt-vu)/18+v1+v2
        p=math.erfc(abs(S)/math.sqrt(var)/math.sqrt(2)) if var>0 else np.nan
    return tau,min(p,1.0),n

def jackknife_se(x,y):
    x=np.asarray(x,float); y=np.asarray(y,float); m=np.isfinite(x)&np.isfinite(y); x=x[m]; y=y[m]; n=len(x)
    if n<3: return np.nan
    t=np.array([kendall(np.delete(x,k),np.delete(y,k))[0] for k in range(n)])
    return math.sqrt((n-1)/n*np.nansum((t-np.nanmean(t))**2))

def lorenz_gini(x):
    x=np.sort(np.clip(np.nan_to_num(np.asarray(x,float)),0,None)); n=len(x); p=np.arange(n+1)/n
    if x.sum()==0: return p,np.zeros(n+1),np.nan
    L=np.concatenate([[0],np.cumsum(x)/x.sum()]); G=1-2*np.trapz(L,p)
    return p,L,G
