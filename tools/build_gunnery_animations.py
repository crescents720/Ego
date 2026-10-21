from build_combat_rigs import Builder,from_to,qinv,qmul
import numpy as np
b=Builder('assets/characters/anime-girl/hotaru_trolley.glb');g=b.globals();ids={n.name:i for i,n in enumerate(b.g.nodes)};p={}
for side,target in [('L',[-.18,1.18,.28]),('R',[-.10,1.20,.48])]:
 shoulder=g[ids['UpperArm.'+side]][:3,3];elbow=g[ids['Forearm.'+side]][:3,3];hand=g[ids['Hand.'+side]][:3,3]
 a=np.linalg.norm(elbow-shoulder);c=np.linalg.norm(hand-elbow);target=np.array(target);v=target-shoulder;dist=np.linalg.norm(v);dist=min(dist,(a+c)*.98);d=v/np.linalg.norm(v);target=shoulder+d*dist
 along=(a*a-c*c+dist*dist)/(2*dist);height=np.sqrt(max(0,a*a-along*along));bend=np.array([0.,-1.,0.]);bend-=d*np.dot(bend,d);bend/=np.linalg.norm(bend);desired_elbow=shoulder+d*along+bend*height
 upper=from_to(elbow-shoulder,desired_elbow-shoulder);fore=from_to(hand-elbow,target-desired_elbow)
 p['UpperArm.'+side]=upper;p['Forearm.'+side]=qmul(qinv(upper),fore)
 print(side,'length',a+c,'target',target)
b.clip('GunHold',[0,.7,1.4],[p,p,p])
b.clip('GunFire',[0,.045,.12],[p,dict(p,Chest=(-3,0,0)),p])
b.save('assets/characters/anime-girl/hotaru_gunnery.glb')
