"""Odachi v3: readable cut silhouettes, palm-space grips and planted-foot IK.

Each combo is a strict prefix of the five-cut sequence.  Every cut owns a
wind-up, an explicit contact pose and a finish pose so a hit cannot disappear
inside a generic transition.  In particular, cut two is a deliberately broad
left-low to right-high rising cut rather than a small recovery motion.
"""
from build_combat_rigs import Builder,from_to,qmul,qinv,qmat,matq,euler
from pathlib import Path
import numpy as np, math,json
from repair_hotaru_arm_skin import repair_arms
b=Builder('assets/characters/anime-girl/hotaru_workshop.glb');repair_arms(b);rest=b.globals()
ids={n.name:i for i,n in enumerate(b.g.nodes)}
parents={c:i for i,n in enumerate(b.g.nodes) for c in n.children or []}
I=np.array([0.,0,0,1.]);PALM=np.array([0.,-.035,-.012]);GAP=.115
# center of right palm, blade unit direction, torso yaw, body lean, weight shift.
def key(grip,axis,yaw=0,lean=0,shift=0):return [np.array(grip,float),np.array(axis,float)/np.linalg.norm(axis),yaw,lean,shift,np.array([-1.,0,0])]
ready=key([0,1.075,.275],[0,.62,.785],-8,0,-.015)
# The sword travels on the front/right of the head during high preparations.
winds=[
 # Level one is intentionally untrained: Hotaru loads the whole sword beside
 # her right shoulder and swings it like a heavy baseball bat, with too much
 # torso rotation and no refined edge-leading diagonal guard.
 key([.12,1.21,.35],[.80,.22,.56],-30,-2,-.045),
 # Cut two begins below the left hip.  The low blade tip and reverse hip load
 # make the rising cut visually separate from cut one's low finish.
 key([.00,.91,.40],[-.58,-.66,.48],38,8,.07),
 key([.07,1.17,.265],[.91,.12,.40],-34,-1,-.02),
 key([.025,1.39,.22],[.18,.98,-.03],-7,-4,-.035),
 key([.14,1.45,.16],[.48,.87,-.10],-48,-7,-.06)]
# Contact silhouettes are authored explicitly.  Besides making the intended
# edge line readable in previews, these poses give runtime hit times an exact
# matching keyframe instead of an arbitrary point in an interpolation.
contacts=[key([.015,1.13,.42],[-.04,.04,.998],0,4,.015),
 key([.04,1.16,.38],[.10,.62,.78],-6,1,.01),
 key([-.005,1.13,.31],[-.12,.06,.99],2,2,.01),
 key([.005,1.18,.31],[.02,-.10,.995],4,3,.015),
 key([-.015,1.15,.34],[-.13,-.08,.988],5,4,.025)]
ends=[key([-.08,1.06,.38],[-.80,.08,.595],32,9,.065),
 # Finish over the right shoulder with the hips fully reversed.  The large
 # vertical and lateral displacement is what makes attack two read as a cut.
 key([.13,1.36,.34],[.64,.74,.21],-38,-4,-.035),
 key([-.045,1.11,.285],[-.88,.02,.47],32,5,.04),
 key([.005,1.005,.30],[.04,-.43,.90],6,9,.055),
 # A deep opposite-side finish and long hold sell the fifth hit as an ending
 # technique; the luminous trail itself is added by the runtime combat VFX.
 key([.01,.90,.43],[-.66,-.55,.51],42,10,.09)]
# Align the blade plane with each cut, including edge-first horizontal cuts.
previous_normal=ready[5]
for wind,contact,finish in zip(winds,contacts,ends):
 normal=np.cross(wind[1],finish[1]);normal/=np.linalg.norm(normal)
 if np.dot(normal,previous_normal)<0:normal=-normal
 wind[5]=normal;contact[5]=normal;finish[5]=normal;previous_normal=normal
# Vary preparation/strike/recovery rhythm instead of mechanically repeating beats.
wind_times=[.29,.30,.29,.36,.46];cut_times=[.24,.30,.19,.18,.27]
contact_fractions=[.592,.56,.62,.62,.60]
holds=[.04,.09,.06,.09,.18]
max_grip_error=0.;audit=[]
def pose(k,walk=0,step=0,lift=0):
 global max_grip_error
 grip,axis,yaw,lean,shift,blade_normal=k;grip=grip.copy()
 p={'Pelvis':(lean*.20,yaw*.38,0),'Spine':(lean*.25,yaw*.20,0),'Chest':(lean*.55,yaw*.42,0),'Head':(-lean*.65,-yaw*.58,0)}
 loc={'Pelvis':np.array([.012*math.sin(math.radians(yaw)),-.035,shift+step*.05])}
 grip+=loc["Pelvis"]
 worlds={};deltas={}
 def fk(i):
  if i in worlds:return worlds[i]
  par=parents.get(i);r=rest[i]
  if par is not None:fk(par);pd=deltas[par];pr=rest[par];origin=worlds[par][:3,3]+qmat(pd)@(r[:3,3]-pr[:3,3])
  else:pd=I;origin=r[:3,3].copy()
  v=p.get(b.g.nodes[i].name,(0,0,0));delta=np.asarray(v) if len(v)==4 else euler(v)
  total=qmul(pd,delta);deltas[i]=total
  origin+=loc.get(b.g.nodes[i].name,np.zeros(3))
  m=np.eye(4);m[:3,:3]=qmat(total)@r[:3,:3];m[:3,3]=origin;worlds[i]=m
  return m
 def chain(names,target,pole,end_delta):
  ui,fi,hi=[ids[n] for n in names];start=fk(ui)[:3,3];rs=rest[ui][:3,3];re=rest[fi][:3,3];rh=rest[hi][:3,3]
  a=np.linalg.norm(re-rs);c=np.linalg.norm(rh-re);v=target-start;length=np.linalg.norm(v);d=v/length
  length=min(length,(a+c)*.999);target=start+d*length
  along=(a*a-c*c+length*length)/(2*length);height=math.sqrt(max(0,a*a-along*along))
  bend=pole-start;bend-=d*np.dot(bend,d);bend/=np.linalg.norm(bend)
  middle=start+d*along+bend*height
  upper=from_to(re-rs,middle-start);fore=from_to(rh-re,target-middle)
  p[names[0]]=qmul(qinv(deltas[parents[ui]]),upper)
  p[names[1]]=qmul(qinv(upper),fore)
  p[names[2]]=qmul(qinv(fore),end_delta)
  return start,middle,target
 # Feet stay planted while hip and torso rotate; a staggered stance supports the cut.
 for side,sign in [('L',-1),('R',1)]:
  f=rest[ids['Foot.'+side]][:3,3].copy();f[0]=sign*.125;f[2]=-.10 if side=='L' else .13
  if side=='R':f[2]+=step*.10;f[1]+=lift*.045
  if walk:f[2]+=sign*.10*math.sin(walk);f[1]+=max(0,sign*math.sin(walk))*.035
  chain(['Thigh.'+side,'Shin.'+side,'Foot.'+side],f,np.array([sign*.15,.4,.65]),euler((0,-sign*7,0)))
 # Palm radial follows the edge-aligned blade frame, so cuts do not slap with the flat.
 radial=blade_normal-axis*np.dot(blade_normal,axis);radial/=np.linalg.norm(radial)
 frames={};offsets={}
 for side,sign in [('R',1),('L',-1)]:
  x=axis*sign;y=-radial*sign;z=np.cross(x,y);z/=np.linalg.norm(z);y=np.cross(z,x)
  D=np.column_stack((x,y,z));frames[side]=matq(D);offsets[side]=D@PALM
 # Keep the palms on the hilt and wrists outside it, rather than putting wrists inside the handle.
 for iteration in range(80):
  for side in ['R','L']:
   ui,fi,hi=[ids[n+'.'+side] for n in ['UpperArm','Forearm','Hand']]
   shoulder=fk(ui)[:3,3];reach=(np.linalg.norm(rest[fi][:3,3]-rest[ui][:3,3])+np.linalg.norm(rest[hi][:3,3]-rest[fi][:3,3]))*.985
   target=grip-axis*(GAP if side=='L' else 0)-offsets[side]
   v=target-shoulder;length=np.linalg.norm(v)
   if length>reach:grip-=v*(1-reach/length)
 for side,sign in [('R',1),('L',-1)]:
  target=grip-axis*(GAP if side=='L' else 0)-offsets[side]
  shoulder,elbow,wrist=chain(['UpperArm.'+side,'Forearm.'+side,'Hand.'+side],target,np.array([sign*.32,.90,.50]),frames[side])
  max_grip_error=max(max_grip_error,np.linalg.norm(target-wrist))
  p['Fingers.'+side]=(85,0,0);p['FingerTips.'+side]=(75,0,0)
 return p,loc
b.clip('SwordIdle',[0,.8,1.6],[pose(ready)[0]]*3,[pose(ready)[1]]*3)
times=np.linspace(0,.8,49).tolist();pairs=[pose(ready,t/.8*math.tau) for t in times]
b.clip('SwordWalk',times,[v[0] for v in pairs],[v[1] for v in pairs])
def mix(a,c,f):
 # Spherical blade interpolation avoids uneven angular speed on broad arcs.
 dot=np.clip(np.dot(a[1],c[1]),-.99999,.99999);angle=math.acos(dot)
 axis=(math.sin((1-f)*angle)*a[1]+math.sin(f*angle)*c[1])/math.sin(angle)
 return [a[0]*(1-f)+c[0]*f,axis,*[a[i]*(1-f)+c[i]*f for i in range(2,6)]]
metadata={}
for count in range(1,6):
 anchors=[(0,ready)];cursor=0.;hits=[]
 for cut in range(count):
  cursor+=wind_times[cut];anchors.append((cursor,winds[cut]))
  contact_time=cursor+cut_times[cut]*contact_fractions[cut]
  hits.append(round(contact_time,3));anchors.append((contact_time,contacts[cut]))
  cursor+=cut_times[cut];anchors.append((cursor,ends[cut]));cursor+=holds[cut];anchors.append((cursor,ends[cut]))
 end=round(cursor+(.43 if count<5 else .72),4);anchors.append((end,ready))
 times=sorted(set([round(t,6) for t in np.arange(0,end,1/120)]+[v[0] for v in anchors]));pairs=[]
 for t in times:
  j=next((i for i in range(len(anchors)-1) if anchors[i][0]<=t<=anchors[i+1][0]),len(anchors)-2)
  ta,a=anchors[j];tb,c=anchors[j+1];f=np.clip((t-ta)/(tb-ta),0,1);f=f*f*(3-2*f)
  # Small forward step under the first cut; recover the foot only after the last cut.
  advance=np.clip((t-.16)/.29,0,1);retreat=np.clip((t-(end-.36))/.30,0,1)
  step=advance*advance*(3-2*advance)*(1-retreat*retreat*(3-2*retreat))
  lift=math.sin(advance*math.pi) if advance<1 else math.sin(retreat*math.pi)
  pairs.append(pose(mix(a,c,f),step=step,lift=lift))
 b.clip('SwordCombo'+str(count),times,[v[0] for v in pairs],[v[1] for v in pairs])
 metadata[str(count)]={'duration':end,'contacts':hits,'directions':['baseball_swing','left_up','horizontal','overhead','finisher'][:count]}
b.save('assets/characters/anime-girl/hotaru_sword.glb')
Path('assets/temple/sword_combos.json').write_text(json.dumps(metadata,indent=2))
print(metadata);print('maximum IK reach error',max_grip_error)


