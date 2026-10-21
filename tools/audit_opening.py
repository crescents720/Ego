from pxr import Usd,UsdGeom
from pathlib import Path
from collections import Counter
for name in ['Bedroom.usdz','American_House.usdz']:
 s=Usd.Stage.Open(str(Path.home()/'Downloads'/name));cache=UsdGeom.BBoxCache(Usd.TimeCode.Default(),['default','render']);print(name,'units',UsdGeom.GetStageMetersPerUnit(s),'up',UsdGeom.GetStageUpAxis(s),Counter(p.GetTypeName() for p in s.Traverse()))
 print('bounds',cache.ComputeWorldBound(s.GetPseudoRoot()).ComputeAlignedRange());ms=[p for p in s.Traverse() if p.IsA(UsdGeom.Mesh)];print('faces',sum(len(UsdGeom.Mesh(p).GetFaceVertexCountsAttr().Get()) for p in ms))
 for p in ms[:18]:print(p.GetName(),len(UsdGeom.Mesh(p).GetFaceVertexCountsAttr().Get()),cache.ComputeWorldBound(p).ComputeAlignedRange())
