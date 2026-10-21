"""Five root-motion-free two-hand odachi modules. No training/unlock logic."""
from build_combat_rigs import Builder,from_to,qmul,qinv,qmat,euler
import numpy as np, math, json
from pathlib import Path
b=Builder('assets/characters/anime-girl/hotaru_workshop.glb');rest=b.globals();ids={n.name:i for i,n in enumerate(b.g.nodes)}
parents={c:i for i,n in enumerate(b.g.nodes) for c in n.children or []}
# Grip center, blade direction, torso yaw. The left hand grips 12cm below right.
ready=([.015,1.12,.23],[.08,.82,.57],0)
keys=[
 ([.13,1.32,.12],[.64,.70,-.32],-18), # raised right guard
 ([-.12,1.02,.25],[-.68,-.26,.69],22), # descending diagonal
 ([-.13,1.05,.22],[-.72,-.18,.67],20),
 ([.14,1.28,.20],[.62,.58,.53],-20), # rising return
 ([.14,1.15,.20],[.94,.04,.34],-28),
 ([-.14,1.13,.23],[-.93,.04,.36],28), # level sweep
 ([0,1.44,.12],[.03,.98,-.15],0),
 ([0,1.02,.30],[.02,-.42,.91],0), # overhead vertical
 ([.15,1.34,.12],[.70,.66,-.26],-25),
 ([-.13,.98,.27],[-.60,-.40,.69],30), # low finishing diagonal
]
def pose(k,walk=0):
 grip,axis,yaw=k;grip=np.array(grip);axis=np.array(axis);axis/=np.linalg.norm(axis)
 p={'Pelvis':(0,yaw*.22,0),'Chest':(0,yaw*.78,0),'Head':(0,-yaw*.55,0),'Thigh.L':(walk+7+yaw*.12,0,-7),'Thigh.R':(-walk+7-yaw*.12,0,7),'Shin.L':(-14-max(0,walk)*.6,0,0),'Shin.R':(-14-max(0,-walk)*.6,0,0),'Foot.L':(7,0,0),'Foot.R':(7,0,0)}
 # Chest rotation moves shoulder origins; solve using the same hierarchy as Builder.
 worlds={};deltas={}
 def fk(i):
  if i in worlds:return worlds[i]
  par=parents.get(i);r=rest[i];pr=rest[par] if par is not None else np.eye(4)
  parent_delta=deltas.get(par,np.array([0.,0,0,1.]))
  if par is not None:fk(par);parent_delta=deltas[par]
  localdelta=euler(p.get(b.g.nodes[i].name,(0,0,0)))
  delta=qmul(parent_delta,localdelta);deltas[i]=delta
  origin=(worlds[par][:3,3]+qmat(parent_delta)@(r[:3,3]-pr[:3,3])) if par is not None else r[:3,3]
  m=np.eye(4);m[:3,:3]=qmat(delta)@r[:3,:3];m[:3,3]=origin;worlds[i]=m
  return m
 # Project the shared grip into both arms' reachable spheres, retaining exact two-hand spacing.
 for iteration in range(80):
  for side in ['R','L']:
   ui,fi,hi=[ids[n+'.'+side] for n in ['UpperArm','Forearm','Hand']]
   shoulder=fk(ui)[:3,3];reach=(np.linalg.norm(rest[fi][:3,3]-rest[ui][:3,3])+np.linalg.norm(rest[hi][:3,3]-rest[fi][:3,3]))*.97
   target=grip-axis*(.12 if side=='L' else 0);v=target-shoulder;length=np.linalg.norm(v)
   if length>reach:grip-=v*(1-reach/length)
 for side in ['R','L']:
  ui,fi,hi=[ids[n+'.'+side] for n in ['UpperArm','Forearm','Hand']]
  shoulder=fk(ui)[:3,3];elbow=rest[fi][:3,3];hand=rest[hi][:3,3];rs=rest[ui][:3,3]
  target=grip-axis*(.12 if side=='L' else 0)
  a=np.linalg.norm(elbow-rs);c=np.linalg.norm(hand-elbow);d=target-shoulder;dist=np.linalg.norm(d)
  assert dist<a+c+.01,(side,k,dist,a+c)
  dist=min(dist,(a+c)*.995);d/=np.linalg.norm(d);target=shoulder+d*dist
  along=(a*a-c*c+dist*dist)/(2*dist);height=np.sqrt(max(0,a*a-along*along))
  bend=np.array([-.32 if side=='L' else .32,-1.,-.1]);bend-=d*np.dot(bend,d);bend/=np.linalg.norm(bend)
  mid=shoulder+d*along+bend*height
  upper=from_to(elbow-rs,mid-shoulder);fore=from_to(hand-elbow,target-mid)
  pd=deltas[parents[ui]]
  p['UpperArm.'+side]=qmul(qinv(pd),upper)
  p['Forearm.'+side]=qmul(qinv(upper),fore)
  # Runtime sword basis cancels hand's rest rotation, then animated hand aims +Y.
  handdelta=from_to(np.array([0.,1.,0.]),axis)
  p['Hand.'+side]=qmul(qinv(fore),handdelta)
  p['Fingers.'+side]=(65,0,0);p['FingerTips.'+side]=(55,0,0)
 return p
b.clip('SwordIdle',[0,.6,1.2],[pose(ready)]*3)
b.clip('SwordWalk',np.linspace(0,.8,25).tolist(),[pose(ready,16*math.sin(t*math.tau)) for t in np.linspace(0,1,25)])
metadata={}
for count in range(1,6):
 anchors=[(0,ready),(.20,keys[0])];hits=[]
 for cut in range(count):
  start=.20+cut*.46
  if cut:anchors.append((start,keys[cut*2]))
  anchors.extend([(start+.12,keys[cut*2+1]),(start+.23,keys[cut*2+1])]);hits.append(round(start+.12,3))
 end=anchors[-1][0]+.30;anchors.append((end,ready))
 times=sorted(set([round(t,6) for t in np.arange(0,end,1/120)]+[x[0] for x in anchors]))
 poses=[]
 for t in times:
  j=next((i for i in range(len(anchors)-1) if anchors[i][0]<=t<=anchors[i+1][0]),len(anchors)-2)
  ta,a=anchors[j];tb,c=anchors[j+1];f=np.clip((t-ta)/(tb-ta),0,1);f=f*f*(3-2*f)
  k=[(np.array(a[n])*(1-f)+np.array(c[n])*f).tolist() if n<2 else a[n]*(1-f)+c[n]*f for n in range(3)]
  poses.append(pose(k))
 b.clip('SwordCombo'+str(count),times,poses)
 metadata[str(count)]={'duration':round(end,3),'contacts':hits,'directions':['right_down','left_up','horizontal','overhead','finisher'][:count]}
b.save('assets/characters/anime-girl/hotaru_sword.glb')
Path('assets/temple/sword_combos.json').write_text(json.dumps(metadata,indent=2))
print(metadata)

