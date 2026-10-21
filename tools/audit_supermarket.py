from pxr import Usd, UsdGeom, UsdShade
from collections import Counter
s=Usd.Stage.Open(r'C:\Users\ding5\Downloads\Supermarket.usdz')
print('units',UsdGeom.GetStageMetersPerUnit(s),'up',UsdGeom.GetStageUpAxis(s))
print(Counter(p.GetTypeName() for p in s.Traverse()))
cache=UsdGeom.BBoxCache(Usd.TimeCode.Default(),['default','render'])
print('BOUNDS',cache.ComputeWorldBound(s.GetPseudoRoot()).ComputeAlignedRange())
meshes=[p for p in s.Traverse() if p.IsA(UsdGeom.Mesh)]
for p in meshes[:15]:
 m=UsdGeom.Mesh(p); print(p.GetPath(),'pts',len(m.GetPointsAttr().Get()),'bounds',cache.ComputeWorldBound(p).ComputeAlignedRange())
 print('primvars',[(v.GetName(),v.GetInterpolation(),len(v.ComputeFlattened() or [])) for v in UsdGeom.PrimvarsAPI(p).GetPrimvars()])
 print('mat',UsdShade.MaterialBindingAPI(p).ComputeBoundMaterial()[0].GetPath())
for p in [p for p in s.Traverse() if p.IsA(UsdShade.Material)][:3]:
 print(p.GetPath())
 for c in Usd.PrimRange(p):
  if c.IsA(UsdShade.Shader): print(c.GetName(),[(a.GetName(),str(a.Get())[:180],str(a.GetConnections())) for a in c.GetAttributes()])
