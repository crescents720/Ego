from pathlib import Path
import sys, zipfile
import numpy as np
from pxr import Usd,UsdGeom,UsdShade
from build_hospital_assets import HospitalBuilder,hospital_uvs
from build_harbor_assets import _world_vertices,_triangulate
out=Path('assets/hospital')
for source in ['Fence_retaining_wall','Gate_01']:
 src=Path.home()/'Downloads'/(source+'.usdz');stage=Usd.Stage.Open(str(src));cache=UsdGeom.XformCache()
 parts=[(p,_world_vertices(p,cache)) for p in stage.Traverse() if p.IsA(UsdGeom.Mesh)]
 groups={'campus_wall':[parts[0]]} if source.startswith('Fence') else {'campus_gate_posts':[parts[0],parts[3]],'campus_gate_left':parts[4:6],'campus_gate_right':parts[1:3]}
 for key,selected in groups.items():
  builder=HospitalBuilder(zipfile.ZipFile(src),1024)
  if key=='campus_wall':
   v=selected[0][1];lo=v.min(0);hi=v.max(0);origin=(lo+hi)/2;origin[1]=lo[1];scale=.01
  else:
   origin=np.array([-75 if key.endswith('left') else 75 if key.endswith('right') else 0,-65.7625,0]);scale=.028
  for p,v in selected:
   v=(v-origin)*scale;t=_triangulate(UsdGeom.Mesh(p));v,uv,t=hospital_uvs(p,v,t)
   builder.add_mesh(p.GetName(),v,uv,t,UsdShade.MaterialBindingAPI(p).ComputeBoundMaterial()[0])
  builder.save(out/(key+'.glb'));print(key,builder.triangles)
