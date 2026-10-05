import pickle, numpy as np, time
from geo import *
from matplotlib.path import Path
t0=time.time()
T=pickle.load(open("tables.pkl","rb")); F=T["F"]
polys=study_polygons(F.Long.values,F.Lat.values)
print("polys",time.time()-t0,flush=True)
recs=read_shp(SHP_RIVERS); lines=[]
for r in recs:
    for p in r:
        lo,la=lcc_inverse(p[:,0],p[:,1]); lines.append(np.column_stack([lo,la]))
print("rivers read",len(lines),sum(len(l) for l in lines),time.time()-t0,flush=True)
allp=np.vstack(polys); x0,y0=allp.min(0); x1,y1=allp.max(0)
lines=[l for l in lines if (l[:,0].max()>=x0)&(l[:,0].min()<=x1)&(l[:,1].max()>=y0)&(l[:,1].min()<=y1)]
simp=[Path(p[::5]) for p in polys]
out=[]
for ln in lines:
    inside=np.zeros(len(ln),bool)
    for pa in simp: inside|=pa.contains_points(ln)
    seg=[]
    for i in range(len(ln)):
        if inside[i]: seg.append(ln[i])
        else:
            if len(seg)>1: out.append(np.array(seg))
            seg=[]
    if len(seg)>1: out.append(np.array(seg))
print("clipped",len(out),time.time()-t0,flush=True)
pickle.dump(dict(polys=polys,rivers=out),open("geo.pkl","wb")); print("done",flush=True)
