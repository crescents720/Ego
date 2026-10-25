"""Extract reusable, source-coloured furniture, in metres; never alter USDZ originals."""
from build_hospital_assets import *
from build_harbor_assets import _world_vertices,_triangulate
import fast_simplification
from scipy.spatial import cKDTree
jobs={'lab_device':('lab',lambda p:'Group_617138_213_94/' in str(p.GetPath())),'office_station':('office',lambda p:int(p.GetName().split('_')[-1]) in list(range(1,20))+[25,26,29,30,31,33,40,41,66,67]),'bed_a':('ward_a',lambda p:23<=int(p.GetName().split('_')[-1])<=96),
 'monitor':('ward_b',lambda p:32<=int(p.GetName().split('_')[-1])<=48),
 'reception_desk':('reception',lambda p:p.GetName().startswith('polySurface83_') or 'ComputerAndMonitor' in p.GetName()),
 'waiting_chairs':('reception',lambda p:'Patient_Chair' in p.GetName())}
for name,(source,predicate) in jobs.items():
 src=Path.home()/'Downloads'/(SOURCES[source]+'.usdz');stage=Usd.Stage.Open(str(src));cache=UsdGeom.XformCache()
 parts=[(p,_world_vertices(p,cache)*.01) for p in stage.Traverse() if p.IsA(UsdGeom.Mesh) and predicate(p)]
 allv=np.concatenate([v for _,v in parts]);lo=allv.min(0);hi=allv.max(0);center=(lo+hi)/2;center[1]=lo[1]
 if source=='office':center=np.array([2.2,0,-1.65])
 builder=HospitalBuilder(zipfile.ZipFile(src),1024)
 groups={}
 for p,v in parts:
  tri=_triangulate(UsdGeom.Mesh(p));v,uv,tri=hospital_uvs(p,v-center,tri)
  if source=='office':
   ps=v[tri];tri=tri[(ps[:,:,0].min(1)>-1.45)&(ps[:,:,0].max(1)<1.45)&(ps[:,:,2].min(1)>-1.45)&(ps[:,:,2].max(1)<1.45)]
   if not len(tri):continue
   used,inv=np.unique(tri,return_inverse=True);v=v[used];uv=uv[used];tri=inv.reshape(-1,3).astype(np.uint32)
  target=300 if name=="bed_a" else (2500 if source=="office" else 450)
  if len(tri)>target:
   source_v=v.copy();source_uv=uv.copy()
   _,first,mapping=np.unique(np.round(v,6),axis=0,return_index=True,return_inverse=True)
   v=v[first];tri=mapping[tri].astype(np.uint32)
   tri=tri[(tri[:,0]!=tri[:,1])&(tri[:,0]!=tri[:,2])&(tri[:,1]!=tri[:,2])]
   out,faces=fast_simplification.simplify(v.copy(),tri.copy(),target_reduction=1-target/len(tri));uv=source_uv[cKDTree(source_v).query(out)[1]];v=out;tri=np.asarray(faces,dtype=np.uint32)
  mat=UsdShade.MaterialBindingAPI(p).ComputeBoundMaterial()[0]
  groups.setdefault(str(mat.GetPath()),[]).append((v,uv,tri,mat))
 for key,items in groups.items():
  vs=[];us=[];ts=[];offset=0
  for v,uv,tri,mat in items:vs.append(v);us.append(uv);ts.append(tri+offset);offset+=len(v)
  builder.add_mesh(key.split('/')[-1],np.concatenate(vs),np.concatenate(us),np.concatenate(ts),items[0][3])
 builder.save(OUT/(name+'.glb'));print(name,np.round(hi-lo,2),builder.triangles,flush=True)
