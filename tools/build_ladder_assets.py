from pathlib import Path
import zipfile, numpy as np
from pxr import Usd, UsdGeom, UsdShade
from build_harbor_assets import GlbBuilder, _world_vertices, _triangulate, _uvs
source=Path.home()/"Downloads/Ladder.usdz"
stage=Usd.Stage.Open(str(source)); cache=UsdGeom.XformCache()
parts=[p for p in stage.Traverse() if p.IsA(UsdGeom.Mesh)]
allv=np.concatenate([_world_vertices(p,cache) for p in parts]);low=allv.min(0);high=allv.max(0)
origin=(low+high)/2;origin[1]=low[1]
b=GlbBuilder(zipfile.ZipFile(source),512)
for p in parts:
 v=(_world_vertices(p,cache)-origin)*2.25/(high[1]-low[1]);v,uv,f=_uvs(p,v,_triangulate(UsdGeom.Mesh(p)))
 b.add_mesh(p.GetName(),v,uv,f,UsdShade.MaterialBindingAPI(p).ComputeBoundMaterial()[0])
b.save(Path("assets/harbor/ladder.glb"))
from build_combat_rigs import Builder
import math
b=Builder("assets/characters/anime-girl/hotaru_sword.glb")
times=[i/30 for i in range(61)];poses=[]
for t in times:
 s=math.sin(t*math.tau*1.5)
 poses.append({"Chest":(7,0,0),"UpperArm.L":(-110-20*s,0,-8),"UpperArm.R":(-110+20*s,0,8),"Forearm.L":(-30+15*s,0,0),"Forearm.R":(-30-15*s,0,0),"Thigh.L":(-25-23*s,0,0),"Thigh.R":(-25+23*s,0,0),"Shin.L":(35+25*s,0,0),"Shin.R":(35-25*s,0,0)})
b.clip("Climb",times,poses);b.save("assets/characters/anime-girl/hotaru_climb.glb")
