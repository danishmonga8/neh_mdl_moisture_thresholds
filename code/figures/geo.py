import os, struct, numpy as np
from matplotlib.path import Path
SHP_STATES = os.path.join(os.environ.get("NEH_ROOT", os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "data")), "shapefiles", "Himalayan_UP_Bihar.shp")
SHP_RIVERS = os.path.join(os.environ.get("NEH_ROOT", os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "data")), "shapefiles", "River_Himalaya.shp")
import os
def _p(p): return p

def read_shp(path):
    """Minimal ESRI shapefile reader -> list of records, each a list of parts (Nx2 arrays)."""
    with open(_p(path),"rb") as f: data=f.read()
    pos=100; recs=[]
    while pos+8<=len(data):
        _,clen=struct.unpack(">ii",data[pos:pos+8]); pos+=8
        c=data[pos:pos+2*clen]; pos+=2*clen
        st=struct.unpack("<i",c[:4])[0]
        if st in (0,):
            recs.append([]); continue
        if st in (3,5,13,15,23,25):
            nparts,npts=struct.unpack("<ii",c[36:44])
            parts=list(struct.unpack(f"<{nparts}i",c[44:44+4*nparts]))
            o=44+4*nparts
            pts=np.frombuffer(c[o:o+16*npts],dtype="<f8").reshape(npts,2)
            parts.append(npts)
            recs.append([pts[parts[i]:parts[i+1]].copy() for i in range(nparts)])
        else:
            recs.append([])
    return recs

def poly_area(xy):
    x,y=xy[:,0],xy[:,1]; return 0.5*abs(np.dot(x,np.roll(y,1))-np.dot(y,np.roll(x,1)))

def study_polygons(lon,lat):
    """Polygons (states) containing >=1 station; keep the largest part of each (as in the R/MATLAB scripts)."""
    recs=read_shp(SHP_STATES); keep=[]
    pts=np.column_stack([lon,lat])
    for parts in recs:
        parts=[p for p in parts if len(p)>3]
        if not parts: continue
        if any(Path(p).contains_points(pts).any() for p in parts):
            keep.append(max(parts,key=poly_area))
    return keep

def clip_lines_to_polys(lines,polys):
    paths=[Path(p) for p in polys]; out=[]
    for ln in lines:
        inside=np.zeros(len(ln),bool)
        for pa in paths: inside|=pa.contains_points(ln)
        seg=[]
        for i in range(len(ln)):
            if inside[i]: seg.append(ln[i])
            else:
                if len(seg)>1: out.append(np.array(seg))
                seg=[]
        if len(seg)>1: out.append(np.array(seg))
    return out

def rivers_in(polys):
    recs=read_shp(SHP_RIVERS); lines=[p for r in recs for p in r]
    allp=np.vstack(polys); x0,y0=allp.min(0); x1,y1=allp.max(0)
    lines=[l for l in lines if (l[:,0].max()>=x0)&(l[:,0].min()<=x1)&(l[:,1].max()>=y0)&(l[:,1].min()<=y1)]
    return clip_lines_to_polys(lines,polys)

def lcc_inverse(x,y,lon0=80.0,lat0=24.0,sp1=12.4729444,sp2=35.17280555,FE=4e6,FN=4e6,a=6378137.0,f=1/298.257223563):
    e=np.sqrt(2*f-f*f); r=np.radians
    m=lambda p: np.cos(p)/np.sqrt(1-(e*np.sin(p))**2)
    t=lambda p: np.tan(np.pi/4-p/2)/((1-e*np.sin(p))/(1+e*np.sin(p)))**(e/2)
    p1,p2,p0=r(sp1),r(sp2),r(lat0)
    n=(np.log(m(p1))-np.log(m(p2)))/(np.log(t(p1))-np.log(t(p2)))
    Fc=m(p1)/(n*t(p1)**n); rho0=a*Fc*t(p0)**n
    xp=np.asarray(x)-FE; yp=np.asarray(y)-FN
    rho=np.sign(n)*np.sqrt(xp**2+(rho0-yp)**2); tt=(rho/(a*Fc))**(1/n)
    th=np.arctan2(xp,rho0-yp); lam=th/n+r(lon0)
    phi=np.pi/2-2*np.arctan(tt)
    for _ in range(10): phi=np.pi/2-2*np.arctan(tt*((1-e*np.sin(phi))/(1+e*np.sin(phi)))**(e/2))
    return np.degrees(lam),np.degrees(phi)

def rivers_in(polys):
    recs=read_shp(SHP_RIVERS); lines=[]
    for r in recs:
        for p in r:
            lo,la=lcc_inverse(p[:,0],p[:,1]); lines.append(np.column_stack([lo,la]))
    allp=np.vstack(polys); x0,y0=allp.min(0); x1,y1=allp.max(0)
    lines=[l for l in lines if (l[:,0].max()>=x0)&(l[:,0].min()<=x1)&(l[:,1].max()>=y0)&(l[:,1].min()<=y1)]
    return clip_lines_to_polys(lines,polys)
