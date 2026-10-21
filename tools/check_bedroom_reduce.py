from pxr import Usd,UsdGeom
from pathlib import Path
import numpy as np,fast_simplification as f
s=Usd.Stage.Open(str(Path.home()/'Downloads/Bedroom.usdz'));p=next(p for p in s.Traverse() if 'Material2_6/Material2' in str(p.GetPath()));m=UsdGeom.Mesh(p);a=np.array(m.GetPointsAttr().Get(),dtype=float);fs=np.array(m.GetFaceVertexIndicesAttr().Get(),dtype=np.int32).reshape(-1,3);_,first,mp=np.unique(np.round(a,5),axis=0,return_index=True,return_inverse=True);a=a[first];fs=mp[fs].astype(np.int32);fs=fs[(fs[:,0]!=fs[:,1])&(fs[:,1]!=fs[:,2])&(fs[:,0]!=fs[:,2])]
for agg in [7,12]:
 b,t,c=f.simplify(a.copy(),fs.copy(),target_count=1800,agg=agg,return_collapses=True);bb,tt,mp=f.replay_simplification(a.copy(),fs.copy(),c);print(agg,a.shape,fs.shape,b.shape,t.shape,bb.shape,tt.shape, 'same', b.shape==bb.shape and np.allclose(b,bb))

