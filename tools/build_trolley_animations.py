from pathlib import Path
from build_combat_rigs import Builder
import math
b=Builder('assets/characters/anime-girl/hotaru_service.glb')
# Preserve all original combat/rest/service clips and add hands-on-handle locomotion.
base={'Chest':(8,0,0),'Head':(-6,0,0),'UpperArm.L':(-66,0,-9),'UpperArm.R':(-66,0,9),'Forearm.L':(-24,0,0),'Forearm.R':(-24,0,0)}
b.clip('PushIdle',[0,.6,1.2],[base,dict(base,Chest=(9,0,0)),base])
times=[i*.15 for i in range(9)];poses=[]
for t in times:
 phase=t/1.2*math.tau;pose=base.copy();pose.update({'Thigh.L':(18*math.sin(phase),0,0),'Thigh.R':(-18*math.sin(phase),0,0),'Shin.L':(-max(0,26*math.sin(phase)),0,0),'Shin.R':(-max(0,-26*math.sin(phase)),0,0) });poses.append(pose)
b.clip('PushWalk',times,poses)
b.save('assets/characters/anime-girl/hotaru_trolley.glb')
p=Path('scripts/actors/hotaru.gd');s=p.read_text(encoding='utf-8').replace('anime-girl/hotaru_service.glb','anime-girl/hotaru_trolley.glb').replace('"RepairKneel","FuelHold"','"RepairKneel","FuelHold","PushIdle","PushWalk"').replace('["Walk","BatWalkL","BatWalkR"]','["Walk","BatWalkL","BatWalkR","PushWalk"]');s=s.replace('\t\tif not pushing_cart and not _weapon_hand', '\t\tif pushing_cart:desired_animation="PushWalk" if direction.length_squared()>.01 and active else "PushIdle"\n\t\tif not pushing_cart and not _weapon_hand');p.write_text(s,encoding='utf-8')
p=Path('scripts/story/weapon_shop.gd');s=p.read_text(encoding='utf-8').replace('Vector3(106,.95,154)','Vector3(107.8,.95,153.8)').replace('Vector3(9.0,4.3,7.0)','Vector3(7.2,4.3,6.8)').replace('SHOP_CENTER+Vector3(0,2.1,0)','SHOP_CENTER+Vector3(.65,2.1,0)');p.write_text(s,encoding='utf-8')
