# Tree_Animate contains three trees laid out along X. Split by the gaps between trunks.
from build_combat_rigs import Builder
import numpy as np,json
from pathlib import Path
for variant,(lo,hi) in enumerate([(-100,-2.2),(-2.2,1.9),(1.9,100)],1):
 b=Builder('assets/environment/vegetation/grove.glb');selected=[]
 for m in b.g.meshes:
  for p in m.primitives:
   v=b.read(p.attributes.POSITION).reshape(-1,3,3);mask=(v[:,:,0].mean(1)>=lo)&(v[:,:,0].mean(1)<hi)
   selected.append((p,mask,v))
 allv=np.concatenate([v[mask].reshape(-1,3) for _,mask,v in selected]);center=(allv.min(0)+allv.max(0))*.5;center[1]=allv[:,1].min();scale=5.5/np.ptp(allv[:,1])
 for p,mask,v in selected:
  v=(v[mask].reshape(-1,3)-center)*scale
  for attribute,kind,size in [('POSITION','VEC3',3),('NORMAL','VEC3',3),('TEXCOORD_0','VEC2',2)]:
   values=v if attribute=='POSITION' else b.read(getattr(p.attributes,attribute)).reshape(-1,3,size)[mask].reshape(-1,size)
   setattr(p.attributes,attribute,b.add(values,kind))
  a=b.g.accessors[p.attributes.POSITION];a.min=v.min(0).tolist();a.max=v.max(0).tolist()
 b.save(f'assets/environment/vegetation/leaf{variant}.glb')
 print('leaf',variant,len(allv)//3)
