"""Cut actual hatch openings into the supplied RV and prepare its mounted M60."""
from pathlib import Path
import numpy as np
from pygltflib import GLTF2,Accessor,BufferView

def read(g,blob,index):
 a=g.accessors[index];b=g.bufferViews[a.bufferView];n={'VEC3':3,'VEC2':2,'SCALAR':1}[a.type];dt={5126:'<f4',5125:'<u4',5123:'<u2',5121:'u1'}[a.componentType];return np.ndarray((a.count,n),dtype=dt,buffer=blob,offset=(b.byteOffset or 0)+(a.byteOffset or 0),strides=(b.byteStride or np.dtype(dt).itemsize*n,np.dtype(dt).itemsize)).copy()
def add(g,blob,v,kind):
 v=np.asarray(v,dtype='<f4');blob.extend(b'\0'*(-len(blob)%4));off=len(blob);blob.extend(v.tobytes());g.bufferViews.append(BufferView(buffer=0,byteOffset=off,byteLength=v.nbytes));a=Accessor(bufferView=len(g.bufferViews)-1,componentType=5126,count=len(v),type=kind)
 if kind=='VEC3':a.min=v.min(0).tolist();a.max=v.max(0).tolist()
 g.accessors.append(a);return len(g.accessors)-1

def split(poly,axis,bound,sign):
 inside=[];outside=[]
 for a,b in zip(poly,poly[1:]+poly[:1]):
  da=(a[axis]-bound)*sign;db=(b[axis]-bound)*sign
  (inside if da>=-1e-7 else outside).append(a)
  if (da>1e-7 and db< -1e-7) or (db>1e-7 and da< -1e-7):
   v=a+(b-a)*(da/(da-db));inside.append(v);outside.append(v)
 return inside,outside

g=GLTF2().load('assets/vehicles/bounder/bounder.glb');src=g.binary_blob();blob=bytearray(src)
boxes=[[(0,1.05,1),(0,2.1,-1),(1,1.90,1),(1,2.60,-1),(2,1.32,1),(2,2.55,-1)],[(0,-2.1,1),(0,-1.05,-1),(1,1.90,1),(1,2.60,-1),(2,1.32,1),(2,2.55,-1)]]
for mesh in g.meshes:
 for prim in mesh.primitives:
  v=read(g,src,prim.attributes.POSITION);n=read(g,src,prim.attributes.NORMAL);uv=read(g,src,prim.attributes.TEXCOORD_0);idx=read(g,src,prim.indices).ravel() if prim.indices is not None else np.arange(len(v));rows=np.concatenate([v,n,uv],axis=1);result=[]
  for tri in idx.reshape(-1,3):
   polys=[[rows[i].copy() for i in tri]]
   for planes in boxes:
    remaining=[]
    for poly in polys:
     candidate=poly
     for axis,bound,sign in planes:
      if len(candidate)<3:break
      candidate,outside=split(candidate,axis,bound,sign)
      if len(outside)>=3:remaining.append(outside)
    polys=remaining
   for poly in polys:
    for k in range(1,len(poly)-1):result.extend([poly[0],poly[k],poly[k+1]])
  r=np.array(result);r[:,3:6]/=np.maximum(np.linalg.norm(r[:,3:6],axis=1,keepdims=True),1e-8)
  prim.attributes.POSITION=add(g,blob,r[:,:3],'VEC3');prim.attributes.NORMAL=add(g,blob,r[:,3:6],'VEC3');prim.attributes.TEXCOORD_0=add(g,blob,r[:,6:8],'VEC2');prim.attributes.TANGENT=None;prim.indices=None
 g.buffers[0].byteLength=len(blob)
g.set_binary_blob(bytes(blob));g.save_binary('assets/vehicles/bounder/bounder_hatches.glb')

g=GLTF2().load('assets/weapon_shop/m60.glb');src=g.binary_blob();blob=bytearray(src);keep=[];rot=np.array([[0,0,-1],[0,1,0],[1,0,0]],float)
for i,node in enumerate(g.nodes):
 if node.mesh is None:continue
 mesh=g.meshes[node.mesh]
 if min(g.accessors[p.attributes.POSITION].min[2] for p in mesh.primitives)>.1:continue
 keep.append(i)
 for p in mesh.primitives:
  v=(read(g,src,p.attributes.POSITION)-np.array([-.22,.32,-.38]))@rot.T;n=read(g,src,p.attributes.NORMAL)@rot.T
  p.attributes.POSITION=add(g,blob,v,'VEC3');p.attributes.NORMAL=add(g,blob,n,'VEC3');p.attributes.TANGENT=None
g.scenes[0].nodes=keep;g.buffers[0].byteLength=len(blob);g.set_binary_blob(bytes(blob));g.save_binary('assets/weapon_shop/m60_mounted.glb')
print('Hatches cut, mounted M60 ready')
