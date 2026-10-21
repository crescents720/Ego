from pxr import Usd,UsdGeom
from pathlib import Path
s=Usd.Stage.Open(str(Path.home()/'Downloads/Bedroom.usdz'));b=UsdGeom.BBoxCache(Usd.TimeCode.Default(),['default'])
for p in sorted([p for p in s.Traverse() if p.IsA(UsdGeom.Mesh)],key=lambda p:len(UsdGeom.Mesh(p).GetFaceVertexCountsAttr().Get()),reverse=True)[:16]:
 print(p.GetPath(),len(UsdGeom.Mesh(p).GetFaceVertexCountsAttr().Get()),b.ComputeWorldBound(p).ComputeAlignedRange())
