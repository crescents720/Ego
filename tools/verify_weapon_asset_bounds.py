"""Verify generated model geometry stays finite and within its intended world scale."""
from pathlib import Path
import numpy as np
from pygltflib import GLTF2
for name,limit in [('gun_shop',11),('merchant',2.0),('m60',1.6),('trolley',1.4)]:
 g=GLTF2().load('assets/weapon_shop/'+name+'.glb');blob=g.binary_blob();points=[];triangles=0
 for mesh in g.meshes:
  for prim in mesh.primitives:
   for index,n in [(prim.attributes.POSITION,3),(prim.attributes.NORMAL,3),(prim.attributes.TEXCOORD_0,2)]:
    a=g.accessors[index];v=g.bufferViews[a.bufferView];values=np.ndarray((a.count,n),dtype='<f4',buffer=blob,offset=(v.byteOffset or 0)+(a.byteOffset or 0))
    assert np.isfinite(values).all(),(name,mesh.name,'nonfinite attributes')
    if index==prim.attributes.POSITION:points.append(values.copy())
   a=g.accessors[prim.indices];v=g.bufferViews[a.bufferView];idx=np.frombuffer(blob,dtype='<u4',count=a.count,offset=(v.byteOffset or 0)+(a.byteOffset or 0));assert idx.max()<g.accessors[prim.attributes.POSITION].count
   triangles+=a.count//3
 p=np.concatenate(points);assert np.max(p.max(0)-p.min(0))<=limit,(name,p.min(0),p.max(0))
 print(name,'triangles',triangles,'bounds',p.min(0),p.max(0))
print('WEAPON_ASSET_BOUNDS_CHECK errors=0')
