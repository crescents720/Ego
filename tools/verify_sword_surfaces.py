"""Check deformed arm surfaces, not just wrist markers, against torso/head core volumes."""
import sys, numpy as np,json
from build_combat_rigs import Builder,qmat
b=Builder('assets/characters/anime-girl/hotaru_sword.glb');g=b.g;r=b.globals();ids={n.name:i for i,n in enumerate(g.nodes)}
parents={c:i for i,n in enumerate(g.nodes)for c in n.children or []};skin=g.skins[0]
p=g.meshes[0].primitives[0];v=b.read(p.attributes.POSITION);j=b.read(p.attributes.JOINTS_0).astype(int);w=b.read(p.attributes.WEIGHTS_0)
arm_joints=[k for k,i in enumerate(skin.joints)if any(g.nodes[i].name.startswith(n)for n in ['Forearm','Hand','Fingers','FingerTips'])]
mask=(((np.isin(j,arm_joints))*w).sum(1)>.65)&(v[:,1]<1.06)
vh=np.column_stack((v[mask],np.ones(mask.sum())));jj=j[mask];ww=w[mask]
inv=np.array([np.linalg.inv(r[i])for i in skin.joints]);report={};failures=[]
for anim in g.animations:
 if not anim.name.startswith('Sword'):continue
 channels=[];duration=0
 for c in anim.channels:
  if c.target.path not in ['translation','rotation']:continue
  s=anim.samplers[c.sampler];ts=b.read(s.input).ravel();vals=b.read(s.output);channels.append((c.target.node,c.target.path,ts,vals));duration=max(duration,ts[-1])
 minimum_body=100.;minimum_head=100.
 for t in np.arange(0,duration+.0001,1/60):
  transforms={}
  for i,path,ts,vals in channels:
   k=min(max(0,np.searchsorted(ts,t)-1),len(ts)-2);f=np.clip((t-ts[k])/max(1e-8,ts[k+1]-ts[k]),0,1)
   a=vals[k];c=vals[k+1]
   if path=='rotation':
    if np.dot(a,c)<0:c=-c
    value=a*(1-f)+c*f;value/=np.linalg.norm(value)
   else:value=a*(1-f)+c*f
   transforms[(i,path)]=value
  world={}
  def fk(i):
   if i in world:return world[i]
   n=g.nodes[i];m=np.eye(4);m[:3,:3]=qmat(transforms.get((i,'rotation'),n.rotation or [0,0,0,1]));m[:3,3]=transforms.get((i,'translation'),n.translation or [0,0,0])
   world[i]=fk(parents[i])@m if i in parents else m;return world[i]
  matrices=np.array([fk(i)for i in skin.joints])@inv
  deformed=np.sum(np.einsum('nvij,nj->nvi',matrices[jj],vh)*ww[:,:,None],axis=1)
  # Conservative core volumes exclude clothing/sleeve seams at the shoulder.
  chest_delta=fk(ids['Chest'])@np.linalg.inv(r[ids['Chest']]);local=(np.linalg.inv(chest_delta)@deformed.T).T[:,:3]
  score=np.sum(((local-np.array([-.005,1.08,-.026]))/np.array([.105,.175,.105]))**2,axis=1)
  head_delta=fk(ids['Head'])@np.linalg.inv(r[ids['Head']]);localh=(np.linalg.inv(head_delta)@deformed.T).T[:,:3]
  scoreh=np.sum(((localh-np.array([0,1.38,-.01]))/np.array([.105,.13,.105]))**2,axis=1)
  minimum_body=min(minimum_body,float(score.min()));minimum_head=min(minimum_head,float(scoreh.min()))
  if score.min()<1.0 or scoreh.min()<1.0:failures.append((anim.name,round(float(t),3),float(score.min()),float(scoreh.min())))
 report[anim.name]={'torso_core_min':minimum_body,'head_core_min':minimum_head}
print(json.dumps(report,indent=2));print('core penetrations',failures[:15], 'count',len(failures))
open('artifacts/sword_surface_audit.json','w').write(json.dumps({'clips':report,'failures':failures},indent=2))
sys.exit(bool(failures))
