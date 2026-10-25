"""Curate room furniture into a unified clean clinic kit, without source shells."""
from build_hospital_assets import SOURCES, HospitalBuilder, hospital_uvs
from build_harbor_assets import _world_vertices, _triangulate, _uvs
from pathlib import Path
from pxr import Usd,UsdGeom,UsdShade
import numpy as np,zipfile,json,fast_simplification
from scipy.spatial import cKDTree
OUT=Path("assets/hospital")
import sys
for key in (sys.argv[1:] or list(SOURCES)[1:]):
 src=Path.home()/"Downloads"/(SOURCES[key]+".usdz");stage=Usd.Stage.Open(str(src));cache=UsdGeom.XformCache()
 parts=[(p,UsdGeom.Mesh(p),_world_vertices(p,cache)) for p in stage.Traverse() if p.IsA(UsdGeom.Mesh)]
 allv=np.concatenate([v for _,_,v in parts]);lo=allv.min(0);hi=allv.max(0)
 if key=="office":lo=np.array([0.,0.,-735.]);hi=np.array([735.,298.,0.])
 center=(lo+hi)/2;center[1]=lo[1];half=(hi-lo)*.005
 builder=HospitalBuilder(zipfile.ZipFile(src),1024 if key=="operating" else 512)
 selected=[]
 for p,m,v in parts:
  name=p.GetName().lower()
  number=int(name.rsplit('_',1)[-1]) if name.rsplit('_',1)[-1].isdigit() else -1
  if key=='ward_a' and (number<=22 or number in [97,118,173,201,202,203,205,206,207,208]):continue
  if key=='ward_b' and number<=3:continue
  if key=='office' and number not in list(range(1,20))+[25,26,29,30,31,33,40,41,66,67]:continue
  if key=="reception" and any(x in name for x in ['wall','floor','direction_sign','tv']):continue
  if key=="morgue":
   # Select complete named objects. The generic plane crop used to remove the
   # cabinet's deep side/back panels and even autopsy-table supports.
   allowed=("locker_2048_", "surgical_trolley_", "cabinet_", "sink_", "autopsytable_", "autopsytable1_", "surgical_lamp_")
   if not name.startswith(allowed):continue
  tri=_triangulate(m);v,uv,tri=hospital_uvs(p,(v-center)*.01,tri)
  points=v[tri];mn=points.min(1);mx=points.max(1)
  keep=(mx[:,1]>.12)&(mn[:,1]<2.50)&(mn[:,0]>-half[0]+.15)&(mx[:,0]<half[0]-.15)&(mn[:,2]>-half[2]+.15)&(mx[:,2]<half[2]-.15)
  span=mx-mn
  architectural_plane=(span[:,1]>1.35)&(((span[:,0]<.035)&(span[:,2]>.60))|((span[:,2]<.035)&(span[:,0]>.60)))
  if key=='morgue':
   pass # Whole furniture, including bases, sides, backs and ceiling mount.
  elif key=='operating':
   # This scan merges room shell and equipment into texture batches. Retaining
   # the complete batches also retained its floor and mustard-yellow walls.
   # Select furniture strictly inside the shell, including low carts but no floor.
   interior=(mn[:,0]>-half[0]+.38)&(mx[:,0]<half[0]-.38)&(mn[:,2]>-half[2]+.38)&(mx[:,2]<half[2]-.38)
   floor_or_ceiling=(mx[:,1]<.16)|(mn[:,1]>2.56)
   tri=tri[interior & ~floor_or_ceiling & ~architectural_plane]
  else:tri=tri[keep & ~architectural_plane]
  if not len(tri):continue
  used,inverse=np.unique(tri,return_inverse=True);v=v[used];uv=uv[used];tri=inverse.reshape(-1,3).astype(np.uint32)
  selected.append((p,v,uv,tri))
 total=sum(len(t) for _,_,_,t in selected);budget=85000 if key=="operating" else 45000
 groups={}
 for p,v,uv,tri in selected:
  target=max(50,int(len(tri)*min(1,budget/max(1,total))))
  if len(tri)>target+20 and key not in ['operating','morgue']:
   out,faces=fast_simplification.simplify(v.copy(),tri.copy(),target_reduction=1-target/len(tri))
   uv=uv[cKDTree(v).query(out)[1]]
   v=out;tri=np.asarray(faces,dtype=np.uint32)
  mat=UsdShade.MaterialBindingAPI(p).ComputeBoundMaterial()[0]
  group=str(mat.GetPath())
  groups.setdefault(group,[]).append((p,v,uv,tri,mat))
 for group,items in groups.items():
  vs=[];us=[];ts=[];offset=0
  for p,v,uv,tri,mat in items:vs.append(v);us.append(uv);ts.append(tri+offset);offset+=len(v)
  builder.add_mesh(key+'_'+group.split('/')[-1],np.concatenate(vs),np.concatenate(us),np.concatenate(ts),items[0][4])
 size=builder.save(OUT/(key+'_furniture.glb'))
 (OUT/(key+'_furniture.json')).write_text(json.dumps({'source':str(src),'triangles':builder.triangles,'bytes':size,'dimensions':((hi-lo)*.01).tolist(),'room_shell_removed':True,'palette':'original source materials and UVs; no universal white override'},indent=2),encoding='utf-8')
 print(key,builder.triangles,round(size/1e6,2),flush=True)
