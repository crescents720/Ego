from pathlib import Path
import sys,numpy as np
sys.path.insert(0,str(Path(__file__).parent))
from build_combat_rigs import Builder,euler,qmul,qinv,matq
from copy import deepcopy
root=Path(__file__).resolve().parents[1]
b=Builder('assets/items/baseball_bat/source.glb')
points=np.concatenate([b.read(p.attributes.POSITION)for m in b.g.meshes for p in m.primitives])
y0,y1=points[:,1].min(),points[:,1].max()
ends=[]
for lo,hi in [(0,.12),(.88,1)]:
 v=points[(points[:,1]>=y0+(y1-y0)*lo)&(points[:,1]<=y0+(y1-y0)*hi)]
 ends.append(float(np.ptp(v[:,[0,2]],axis=0).max()))
print('Bat end diameters:',ends)
# Origin at the knob, +Y from handle to barrel, 85 cm total length.
for mesh in b.g.meshes:
 for p in mesh.primitives:
  v=b.read(p.attributes.POSITION)
  if ends[0]>ends[1]*1.2:v[:,1]=y1-v[:,1]
  else:v[:,1]-=y0
  v*=.85/(y1-y0)
  p.attributes.POSITION=b.add(v,'VEC3')
  ac=b.g.accessors[p.attributes.POSITION];ac.min=v.min(axis=0).tolist();ac.max=v.max(axis=0).tolist()
b.save('assets/items/baseball_bat/bat.glb')

b=Builder('assets/characters/anime-girl/hotaru_combat.glb')
g=b.g
base_animations={a.name:deepcopy(a) for a in g.animations}
for side in ['R','L']:
 other='L' if side=='R' else 'R'
 sign=1 if side=='R' else -1
 def pose(kind,sway=0):
  # Relaxed single-hand carry; bring elbow forward, grip the handle.
  p={'UpperArm.'+side:(-16+sway,0,-sign*12),'Forearm.'+side:(-30,0,0),'Hand.'+side:(8,0,sign*8),'Fingers.'+side:(0,0,0),'FingerTips.'+side:(0,0,0)}
  if kind=='wind':p.update({'Chest':(0,-sign*24,0),'UpperArm.'+side:(-112,-sign*24,-sign*35),'Forearm.'+side:(-72,0,0),'Hand.'+side:(5,0,sign*12),'UpperArm.'+other:(-24,0,sign*20)})
  if kind=='strike':p.update({'Chest':(6,sign*24,0),'Pelvis':(0,sign*10,0),'UpperArm.'+side:(-70,sign*65,sign*15),'Forearm.'+side:(-12,0,0),'Hand.'+side:(-18,0,-sign*20),'UpperArm.'+other:(-20,0,sign*24)})
  return p
 for locomotion in ['Idle','Walk']:
  name='Bat'+locomotion+side
  base=deepcopy(base_animations[locomotion])
  duration=max(float(b.read(s.input).max()) for s in base.samplers)
  times=np.linspace(0,duration,17)
  poses=[pose('carry',3*np.sin(2*np.pi*t/duration) if locomotion=='Walk' else 0)for t in times]
  b.clip(name,times,poses)
  generated=g.animations[-1]
  arm_names={'UpperArm.'+side,'Forearm.'+side,'Hand.'+side,'Fingers.'+side,'FingerTips.'+side}
  override_nodes={i for i,n in enumerate(g.nodes)if n.name in arm_names}
  base.name=name
  base.channels=[c for c in base.channels if not(c.target.node in override_nodes and c.target.path=='rotation') and c.target.path!='weights']
  for c in generated.channels:
   if (c.target.node in override_nodes and c.target.path=='rotation')or c.target.path=='weights':
    sampler=deepcopy(generated.samplers[c.sampler]);c=deepcopy(c);c.sampler=len(base.samplers);base.samplers.append(sampler);base.channels.append(c)
  # Close the equipped hand for the whole hold/walk cycle.
  for c in base.channels:
   if c.target.path=='weights':
    s=base.samplers[c.sampler];s.output=b.add(np.ones((len(b.read(s.input)),1)),'SCALAR')
  g.animations[-1]=base
 b.clip('BatAttack'+side,[0,.16,.30,.40,.50,.68,.86],[pose('carry'),pose('wind'),pose('wind'),pose('strike'),pose('strike'),pose('carry'),pose('carry')])
 for c in g.animations[-1].channels:
  if c.target.path=='weights':
   s=g.animations[-1].samplers[c.sampler];s.output=b.add(np.ones((len(b.read(s.input)),1)),'SCALAR')
b.save('assets/characters/anime-girl/hotaru_equipment.glb')
print('Equipment clips:',[a.name for a in g.animations])
