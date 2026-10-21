"""Bake source surface colors into a mobile facade mesh; avoid atlas stretching at low LOD."""
from pathlib import Path
import sys,numpy as np,json,struct,io,fast_simplification
from PIL import Image
sys.path.insert(0,str(Path(__file__).parent))
from build_combat_rigs import Builder
raw=Builder('output/model_work/repair_reference.glb');g=raw.g;image=g.images[0];view=g.bufferViews[image.bufferView];im=np.asarray(Image.open(io.BytesIO(raw.blob[view.byteOffset:view.byteOffset+view.byteLength])).convert('RGB'))/255.0
positions=[];colors=[];source_faces=[];vertex_offset=0
for mesh in g.meshes:
 for p in mesh.primitives:
  v=raw.read(p.attributes.POSITION);source_faces.append(raw.read(p.indices).reshape(-1,3)+vertex_offset);vertex_offset+=len(v);uv=raw.read(p.attributes.TEXCOORD_0);x=np.clip((uv[:,0]*(im.shape[1]-1)).astype(int),0,im.shape[1]-1);y=np.clip((uv[:,1]*(im.shape[0]-1)).astype(int),0,im.shape[0]-1);positions.append(v);colors.append(im[y,x])
positions=np.concatenate(positions);colors=np.concatenate(colors)
cell=.003;origin=positions.min(0)-cell*4;dims=np.ceil((positions.max(0)-origin)/cell).astype(int)+9
indices=np.floor((positions-origin)/cell).astype(np.int64);keys=indices[:,0]+dims[0]*(indices[:,1]+dims[1]*indices[:,2]);order=np.argsort(keys);uk,first,count=np.unique(keys[order],return_index=True,return_counts=True);centers=np.add.reduceat(positions[order],first,axis=0)/count[:,None];palette=np.add.reduceat(colors[order],first,axis=0)/count[:,None]
def sample(points):
 result=[]
 offsets=np.array([[x,y,z]for x in range(-2,3)for y in range(-2,3)for z in range(-2,3)])
 for chunk in np.array_split(points,max(1,int(np.ceil(len(points)/3000)))):
  q=np.floor((chunk-origin)/cell).astype(np.int64)[:,None,:]+offsets[None,:,:];key=q[:,:,0]+dims[0]*(q[:,:,1]+dims[1]*q[:,:,2]);idx=np.searchsorted(uk,key);idx=np.minimum(idx,len(uk)-1);valid=uk[idx]==key;distance=np.linalg.norm(centers[idx]-chunk[:,None,:],axis=2);distance[~valid]=1e6;nearest=distance.argmin(1);rgb=palette[idx[np.arange(len(chunk)),nearest]];result.append(rgb)
 return np.concatenate(result)
blob=bytearray();out={'asset':{'version':'2.0','generator':'Ego mobile surface-color bake'},'scene':0,'scenes':[{'nodes':[]}],'nodes':[],'meshes':[],'materials':[{'name':'BakedFacadeColors','doubleSided':True,'pbrMetallicRoughness':{'baseColorFactor':[1,1,1,1],'metallicFactor':0,'roughnessFactor':.9}}],'bufferViews':[],'accessors':[]}
def acc(values,kind,integer=False):
 values=np.asarray(values,dtype='<u4' if integer else '<f4');blob.extend(b'\0'*(-len(blob)%4));offset=len(blob);blob.extend(values.tobytes());out['bufferViews'].append({'buffer':0,'byteOffset':offset,'byteLength':values.nbytes});a={'bufferView':len(out['bufferViews'])-1,'componentType':5125 if integer else 5126,'count':len(values),'type':kind}
 if kind=='VEC3':a.update(min=values.min(0).tolist(),max=values.max(0).tolist())
 out['accessors'].append(a);return len(out['accessors'])-1
triangles=0
# Merge artificial 16-bit export chunks before decimating. No atlas seams are needed in this color LOD.
faces=np.concatenate(source_faces).astype(np.int32)
_,first,mapping=np.unique(np.round(positions,6),axis=0,return_index=True,return_inverse=True)
points=positions[first]
faces=mapping[faces].astype(np.int32)
faces=faces[(faces[:,0]!=faces[:,1])&(faces[:,1]!=faces[:,2])&(faces[:,0]!=faces[:,2])]
area=np.linalg.norm(np.cross(points[faces[:,1]]-points[faces[:,0]],points[faces[:,2]]-points[faces[:,0]]),axis=1)
faces=faces[area>1e-12]
_,first=np.unique(np.sort(faces,axis=1),axis=0,return_index=True)
faces=faces[first]
v,faces=fast_simplification.simplify(points,faces,target_count=30000)
n=np.zeros_like(v)
normal=np.cross(v[faces[:,1]]-v[faces[:,0]],v[faces[:,2]]-v[faces[:,0]])
for k in range(3):np.add.at(n,faces[:,k],normal)
n/=np.maximum(np.linalg.norm(n,axis=1,keepdims=True),1e-10)
rgb=sample(v);rgb=np.where(rgb<=.04045,rgb/12.92,((rgb+.055)/1.055)**2.4);rgba=np.c_[rgb,np.ones(len(rgb))]
out['meshes'].append({'primitives':[{'attributes':{'POSITION':acc(v,'VEC3'),'NORMAL':acc(n,'VEC3'),'COLOR_0':acc(rgba,'VEC4')},'indices':acc(faces.reshape(-1,1),'SCALAR',True),'material':0}]})
out['nodes'].append({'mesh':0});out['scenes'][0]['nodes'].append(0);triangles=len(faces)
out['buffers']=[{'byteLength':len(blob)}];enc=json.dumps(out,separators=(',',':')).encode();enc+=b' '*(-len(enc)%4);blob.extend(b'\0'*(-len(blob)%4));data=struct.pack('<4sII',b'glTF',2,28+len(enc)+len(blob))+struct.pack('<I4s',len(enc),b'JSON')+enc+struct.pack('<I4s',len(blob),b'BIN\0')+blob;Path('assets/environment/repair_shop/repair_shop_mobile.glb').write_bytes(data);print('mobile bytes',len(data),'triangles',triangles)
