"""Append a non-looping skeletal knockdown. Preserve all equipment/locomotion clips."""
from pathlib import Path
import numpy as np
from build_combat_rigs import Builder,qmat
b=Builder('assets/characters/anime-girl/hotaru_equipment.glb')
times=[0,.14,.32,.54,.78,1.02,1.3,1.65]
poses=[{},
 {'Root':(-9,0,0),'Chest':(-12,0,0),'Head':(-8,0,0),'UpperArm.L':(-35,0,-24),'UpperArm.R':(-40,0,28)},
 {'Root':(-28,0,2),'Chest':(-14,0,0),'Thigh.L':(-28,0,0),'Thigh.R':(-20,0,0),'Shin.L':(48,0,0),'Shin.R':(38,0,0),'UpperArm.L':(-45,0,-35),'UpperArm.R':(-35,0,45),'Forearm.L':(-25,0,0),'Forearm.R':(-35,0,0)},
 {'Root':(-60,0,5),'Chest':(-9,0,0),'Thigh.L':(-20,0,-7),'Thigh.R':(-12,0,9),'Shin.L':(36,0,0),'Shin.R':(24,0,0),'UpperArm.L':(-22,0,-40),'UpperArm.R':(-25,0,38),'Forearm.L':(-25,0,0),'Forearm.R':(-30,0,0)},
 {'Root':(-87,0,7),'Chest':(0,0,0),'Head':(5,12,0),'Thigh.L':(-5,0,-7),'Thigh.R':(-10,0,8),'Shin.L':(12,0,0),'Shin.R':(18,0,0),'UpperArm.L':(-5,0,-35),'UpperArm.R':(-8,0,30),'Forearm.L':(-15,0,0),'Forearm.R':(-20,0,0)},
 {'Root':(-83,0,7),'Head':(4,15,0),'Thigh.L':(-3,0,-7),'Thigh.R':(-8,0,8),'Shin.L':(10,0,0),'Shin.R':(15,0,0),'UpperArm.L':(0,0,-30),'UpperArm.R':(-5,0,26),'Forearm.L':(-12,0,0),'Forearm.R':(-18,0,0)},]
poses += [poses[-1].copy(),poses[-1].copy()]
locations=[{'Root':np.array([0.,0.,z])} for z in [0,-.03,-.13,-.30,-.48,-.52,-.52,-.52]]
b.clip('Death',times,poses,locations)
# Solve floor contact on the skinned geometry, not the rig's abstract foot pivot.
parents={c:i for i,n in enumerate(b.g.nodes) for c in n.children or []}
rest=b.globals();ibm=[np.linalg.inv(rest[j]) for j in b.g.skins[0].joints]
clip=b.g.animations[-1]
for k in range(len(times)):
 local={}
 for i,n in enumerate(b.g.nodes):
  m=np.eye(4);m[:3,:3]=qmat(np.array(n.rotation or [0,0,0,1]))@np.diag(n.scale or [1,1,1]);m[:3,3]=n.translation or [0,0,0];local[i]=m
 for c in clip.channels:
  if c.target.path=='rotation':local[c.target.node][:3,:3]=qmat(b.read(clip.samplers[c.sampler].output)[k])
  if c.target.path=='translation':local[c.target.node][:3,3]=b.read(clip.samplers[c.sampler].output)[k]
 cache={}
 def glob(i):
  if i not in cache:cache[i]=glob(parents[i])@local[i] if i in parents else local[i]
  return cache[i]
 mats=np.array([glob(j)@ibm[q] for q,j in enumerate(b.g.skins[0].joints)])
 minimum=1e6
 for mesh in b.g.meshes:
  for p in mesh.primitives:
   if p.attributes.JOINTS_0 is None:continue
   v=b.read(p.attributes.POSITION);v=np.c_[v,np.ones(len(v))];j=b.read(p.attributes.JOINTS_0);w=b.read(p.attributes.WEIGHTS_0)
   transformed=np.einsum('nvij,nj->nvi',mats[j],v)
   y=(transformed[:,:,1]*w).sum(1).min();minimum=min(minimum,y)
 locations[k]['Root'][1]=max(0.,.015-minimum)
 print(times[k], 'floor correction',round(locations[k]['Root'][1],3))
b.clip('Death',times,poses,locations)
b.save('assets/characters/anime-girl/hotaru_survival.glb')
