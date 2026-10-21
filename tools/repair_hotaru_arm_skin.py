"""Repair disconnected arm/hand skin islands and joint landmarks, preserving neutral geometry."""
import numpy as np
from build_combat_rigs import qmat

def repair_arms(b):
 g=b.g;skin=g.skins[0];ids={n.name:i for i,n in enumerate(g.nodes)}
 parents={c:i for i,n in enumerate(g.nodes)for c in n.children or []}
 targets={'UpperArm.L':[-.108,1.194,-.046],'Forearm.L':[-.135,1.025,-.049],'Hand.L':[-.190,.875,-.034],
 'UpperArm.R':[.092,1.194,-.032],'Forearm.R':[.119,1.025,-.040],'Hand.R':[.173,.874,-.013],
 'Fingers.L':[-.210,.845,-.035],'FingerTips.L':[-.226,.823,-.036],
 'Fingers.R':[.200,.847,-.009],'FingerTips.R':[.221,.829,-.006]}
 # Only joint translations change; the original rest orientations remain compatible with all clips.
 for name,target in targets.items():
  i=ids[name];old=np.array(g.nodes[i].translation);r=b.globals();new=(np.linalg.inv(r[parents[i]])@np.r_[target,1])[:3]
  g.nodes[i].translation=new.tolist()
  for anim in g.animations:
   for ch in anim.channels:
    if ch.target.node==i and ch.target.path=='translation':
     sampler=anim.samplers[ch.sampler];sampler.output=b.add(b.read(sampler.output)+(new-old),'VEC3')
 r=b.globals();skin.inverseBindMatrices=b.add([np.linalg.inv(r[i]).T.reshape(-1)for i in skin.joints],'MAT4')
 jid={g.nodes[i].name:k for k,i in enumerate(skin.joints)}
 arm_ids={k for name,k in jid.items()if any(name.startswith(x)for x in ['UpperArm','Forearm','Hand','Fingers','FingerTips'])}
 for mesh in g.meshes:
  for prim in mesh.primitives:
   if prim.attributes.JOINTS_0 is None:continue
   v=b.read(prim.attributes.POSITION);j=b.read(prim.attributes.JOINTS_0);w=b.read(prim.attributes.WEIGHTS_0);tri=b.read(prim.indices).reshape(-1,3)
   _,inverse=np.unique(np.round(v,5),axis=0,return_inverse=True);parent=list(range(max(inverse)+1))
   def root(x):
    while parent[x]!=x:parent[x]=parent[parent[x]];x=parent[x]
    return x
   for a,c,d in inverse[tri]:
    for x in [c,d]:parent[root(x)]=root(a)
   labels=np.array([root(i)for i in inverse]);components={}
   for label in np.unique(labels):
    points=v[labels==label];lo=points.min(0);hi=points.max(0)
    side='L' if points[:,0].mean()<0 else 'R'
    if len(points)>80 and lo[1]>.85 and hi[1]>1.20 and hi[1]<1.24 and (hi[0]<0 or lo[0]>0):components[label]=('arm',side)
    elif len(points)>20 and hi[1]<.085:components[label]=('shoe',side)
    elif len(points)>150 and lo[1]>.78 and hi[1]<.91 and (hi[0]<-.15 or lo[0]>.15):components[label]=('hand',side)
   if not components:continue
   assert sum(kind in ['arm','hand'] for kind,side in components.values()) in [0,4],components
   for i,point in enumerate(v):
    kind,side=components.get(labels[i],('', ''))
    y=point[1]
    if kind=='arm':
     upper=np.clip((y-.992)/.065,0,1);hand=np.clip((.902-y)/.035,0,1);chest=np.clip((y-1.16)/.06,0,.85)
     weights={jid['Chest']:chest,jid['UpperArm.'+side]:(1-chest)*upper,jid['Forearm.'+side]:(1-chest)*(1-upper)*(1-hand),jid['Hand.'+side]:(1-chest)*(1-upper)*hand}
    elif kind=='shoe':
     weights={jid['Foot.'+side]:1.0}
    elif kind=='hand':
     finger=np.clip((.86-y)/.024,0,1);tip=np.clip((.834-y)/.025,0,1)
     weights={jid['Hand.'+side]:1-finger,jid['Fingers.'+side]:finger*(1-tip),jid['FingerTips.'+side]:finger*tip}
    else:
     weights={}
     for bone,weight in zip(j[i],w[i]):
      bone=jid['Chest' if y>1.08 else 'Spine'] if bone in arm_ids else int(bone)
      weights[bone]=weights.get(bone,0)+float(weight)
    pairs=sorted(weights.items(),key=lambda x:-x[1])[:4];total=sum(x[1]for x in pairs)
    j[i]=[x[0]for x in pairs]+[0]*(4-len(pairs));w[i]=[x[1]/total for x in pairs]+[0]*(4-len(pairs))
   prim.attributes.JOINTS_0=b.add(j,'VEC4',True);prim.attributes.WEIGHTS_0=b.add(w,'VEC4')
 print('Rebound four arm/hand islands; removed arm influences from torso.')
