from build_combat_rigs import Builder
import math
b=Builder('assets/characters/anime-girl/hotaru_trolley.glb')
times=[0,.3,.6,.9,1.2];poses=[]
for t in times:
 phase=t/1.2*math.tau
 poses.append({'Chest':(9,0,0),'Head':(-7,0,0),'UpperArm.L':(-65,0,-10),'UpperArm.R':(-62,0,10),'Forearm.L':(-42-8*math.sin(phase),0,0),'Forearm.R':(-38+12*math.sin(phase),0,0),'Hand.R':(0,0,8*math.sin(phase))})
b.clip('LatheWork',times,poses)
b.save('assets/characters/anime-girl/hotaru_workshop.glb')
