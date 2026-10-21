from pxr import Usd, UsdGeom, UsdSkel
from collections import Counter
from pathlib import Path
for name in ['Breaking_Bad_1986_Fleetwood_Bounder_RV.usdz','Zombie.usdz']:
 s=Usd.Stage.Open(str(Path.home()/'Downloads'/name)); print('\nASSET',name,'units',UsdGeom.GetStageMetersPerUnit(s),'up',UsdGeom.GetStageUpAxis(s),'time',s.GetStartTimeCode(),s.GetEndTimeCode())
 print(Counter(p.GetTypeName() for p in s.Traverse()))
 b=UsdGeom.BBoxCache(Usd.TimeCode.Default(),['default','render']);print('BOUNDS',b.ComputeWorldBound(s.GetPseudoRoot()).ComputeAlignedRange())
 for p in s.Traverse():
  if p.IsA(UsdGeom.Mesh):
   m=UsdGeom.Mesh(p); print('MESH',str(p.GetPath()),len(m.GetPointsAttr().Get()),'faces',len(m.GetFaceVertexCountsAttr().Get()),'bounds',b.ComputeWorldBound(p).ComputeAlignedRange())
   print('UV',[(str(v.GetName()),str(v.GetInterpolation())) for v in UsdGeom.PrimvarsAPI(p).GetPrimvars()]);print('timeattrs',[(a.GetName(),len(a.GetTimeSamples())) for a in p.GetAttributes() if a.GetNumTimeSamples()>0])
  if p.GetTypeName() in ['Skeleton','SkelAnimation']:
   print('RIG',p.GetPath(),[(a.GetName(),str(a.Get())[:200],len(a.GetTimeSamples())) for a in p.GetAttributes()])
