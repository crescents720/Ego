from pathlib import Path
import json,struct,copy
import numpy as np
from pygltflib import GLTF2
p=Path('assets/story/bedroom'); src=GLTF2().load(str(p/'bedroom.glb'));b=src.binary_blob();g=src.to_dict();g['nodes']=[];g['meshes']=[];g['scenes']=[{'nodes':[]}];g['scene']=0;g['accessors']=[]
# Preserve the embedded texture buffer views; new geometry is appended.
blob=bytearray(b)
def read(i,n):
 a=src.accessors[i];v=src.bufferViews[a.bufferView];return np.frombuffer(b,dtype='<f4',offset=(v.byteOffset or 0)+(a.byteOffset or 0),count=a.count*n).reshape(-1,n).copy()
def attr(a,kind):
 a=np.asarray(a,dtype='<f4');blob.extend(b'\0'*(-len(blob)%4));vi=len(g['bufferViews']);g['bufferViews'].append({'buffer':0,'byteOffset':len(blob),'byteLength':a.nbytes,'target':34962});blob.extend(a.tobytes());d={'bufferView':vi,'componentType':5126,'count':len(a),'type':kind}
 if kind=='VEC3':d.update(min=a.min(0).tolist(),max=a.max(0).tolist())
 g['accessors'].append(d);return len(g['accessors'])-1
def clean(v):
 if isinstance(v,dict):return {k:clean(x) for k,x in v.items() if x is not None and not (k=="byteStride" and x==0)}
 if isinstance(v,list):return [clean(x) for x in v]
 return v
count=0
for mesh in src.meshes:
 if mesh.name.startswith('Shell'):continue
 for pr in mesh.primitives:
  a=read(pr.attributes.POSITION,3).reshape(-1,3,3);uv=read(pr.attributes.TEXCOORD_0,2).reshape(-1,3,2)
  mask=(a[:,:,0].min(1)>2.0)&(a[:,:,0].max(1)<4.6)&(a[:,:,2].min(1)>-.7)&(a[:,:,2].max(1)<2.12)&(a[:,:,1].max(1)<1.65)
  a=a[mask].reshape(-1,3);uv=uv[mask].reshape(-1,2)
  if not len(a):continue
  _,first,mp=np.unique(np.round(a/.04).astype(np.int32),axis=0,return_index=True,return_inverse=True);pts=a[first];tx=np.nan_to_num(uv[first]);faces=mp.reshape(-1,3);mask=(faces[:,0]!=faces[:,1])&(faces[:,1]!=faces[:,2])&(faces[:,0]!=faces[:,2]);faces=faces[mask];_,ix=np.unique(np.sort(faces,axis=1),axis=0,return_index=True);faces=faces[ix]
  if not len(faces):continue
  a=pts[faces];n=np.cross(a[:,1]-a[:,0],a[:,2]-a[:,0]);length=np.linalg.norm(n,axis=1);valid=length>1e-7;a=a[valid];tx=tx[faces[valid]].reshape(-1,2);n=n[valid]/length[valid,None]
  if not len(a):continue
  attributes={'POSITION':attr(a.reshape(-1,3),'VEC3'),'NORMAL':attr(np.repeat(n,3,axis=0),'VEC3'),'TEXCOORD_0':attr(tx,'VEC2')};idx=len(g['meshes']);g['meshes'].append({'name':mesh.name,'primitives':[{'attributes':attributes,'material':pr.material}]});g['nodes'].append({'name':mesh.name,'mesh':idx});g['scenes'][0]['nodes'].append(idx);count+=len(a)
# Drop unused old geometry byte ranges by repacking only image and new accessor views.
used={im['bufferView'] for im in g['images']}|{a['bufferView'] for a in g['accessors']};out=bytearray();views=[];mapping={}
for old in sorted(used):
 v=g['bufferViews'][old];out.extend(b'\0'*(-len(out)%4));new=copy.deepcopy(v);new['byteOffset']=len(out);start=v.get('byteOffset') or 0;out.extend(blob[start:start+v['byteLength']]);mapping[old]=len(views);views.append(new)
for im in g['images']:im['bufferView']=mapping[im['bufferView']]
for a in g['accessors']:a['bufferView']=mapping[a['bufferView']]
g['bufferViews']=views;g['buffers']=[{'byteLength':len(out)}];j=json.dumps(clean(g),separators=(',',':'),allow_nan=False).encode();j+=b' '*(-len(j)%4);out.extend(b'\0'*(-len(out)%4));result=struct.pack('<4sII',b'glTF',2,28+len(j)+len(out))+struct.pack('<I4s',len(j),b'JSON')+j+struct.pack('<I4s',len(out),b'BIN\0')+out;(p/'bedroom_mobile.glb').write_bytes(result);print({'triangles':count,'meshes':len(g['meshes']),'bytes':len(result)})


