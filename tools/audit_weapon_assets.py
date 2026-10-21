from pxr import Usd,UsdGeom,UsdShade
from pathlib import Path
import numpy as np
for name in ['Gun_shop_-_Schneiders_gun_shop','Masked_Character_in_Suit','M60_Machine_Gun_-_Vietnam_War','Platform_Trolley']:
 s=Usd.Stage.Open('C:/Users/ding5/Downloads/'+name+'.usdz');c=UsdGeom.XformCache();points=[];faces=0
 print('\nMODEL',name,'up',UsdGeom.GetStageUpAxis(s),'unit',UsdGeom.GetStageMetersPerUnit(s))
 for p in s.Traverse():
  if p.IsA(UsdGeom.Mesh):
   m=UsdGeom.Mesh(p);v=np.array(m.GetPointsAttr().Get());t=np.array(c.GetLocalToWorldTransform(p));v=v@t[:3,:3]+t[3,:3];points.extend(v);faces+=sum(int(x)-2 for x in m.GetFaceVertexCountsAttr().Get());print(p.GetName(),len(v),[(str(x.GetName()),str(x.GetInterpolation()),len(x.ComputeFlattened() or [])) for x in UsdGeom.PrimvarsAPI(p).GetPrimvars() if 'st' in str(x.GetName())][:3])
 a=np.array(points);print('BOUNDS',a.min(0),a.max(0),'tri',faces)
 for p in s.Traverse():
  if p.IsA(UsdShade.Shader):
   sh=UsdShade.Shader(p)
   for i in sh.GetInputs():
    if i.GetBaseName() in ['file','diffuseColor']:print('MAT',p.GetPath(),i.GetBaseName(),i.Get())
