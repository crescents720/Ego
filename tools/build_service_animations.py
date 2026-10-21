from pathlib import Path
from build_combat_rigs import Builder
import numpy as np
b=Builder('assets/characters/anime-girl/hotaru_rest.glb')
base={'Thigh.L':(94,0,-8),'Thigh.R':(92,0,8),'Shin.L':(-136,0,0),'Shin.R':(-134,0,0),'Foot.L':(40,0,0),'Foot.R':(40,0,0),'Chest':(16,0,0),'Head':(-4,0,0),'UpperArm.L':(-42,0,-10),'UpperArm.R':(-46,0,10),'Forearm.L':(-65,0,0),'Forearm.R':(-62,0,0)}
poses=[]
for t in [0,.3,.6,.9,1.2]:
 pose=base.copy();pose['Forearm.R']=(-62+12*np.sin(t/1.2*np.pi*2),0,0);pose['Forearm.L']=(-65-8*np.sin(t/1.2*np.pi*2),0,0);poses.append(pose)
b.clip('RepairKneel',[0,.3,.6,.9,1.2],poses,[{'Pelvis':(0,-.52,0)}for _ in poses])
pose={'UpperArm.R':(-65,0,8),'Forearm.R':(-20,0,0),'Hand.R':(0,0,10),'UpperArm.L':(-28,0,-5),'Forearm.L':(-42,0,0),'Head':(8,0,0)}
b.clip('FuelHold',[0,1,2],[pose,dict(pose,Chest=(1,0,1)),pose])
b.save('assets/characters/anime-girl/hotaru_service.glb');print('Service animations generated')
