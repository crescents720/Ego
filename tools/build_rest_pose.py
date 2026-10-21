from build_combat_rigs import Builder
b=Builder('assets/characters/anime-girl/hotaru_survival.glb')
pose={'Root':(-90,0,0),'UpperArm.L':(0,0,-8),'UpperArm.R':(0,0,8),'Forearm.L':(-8,0,0),'Forearm.R':(-8,0,0),'Head':(0,7,0)}
poses=[pose.copy() for _ in range(3)];poses[1]['Chest']=(.8,0,0)
b.clip('Sleep',[0,1,2],poses,[{'Root':(0,.16,0)} for _ in range(3)])
b.save('assets/characters/anime-girl/hotaru_rest.glb')
