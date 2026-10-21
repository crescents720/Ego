from pathlib import Path
import numpy as np,zipfile,io,json,struct
from pxr import Usd,UsdGeom
from PIL import Image
src=Path.home()/'Downloads/Auto_Repair_Facade__Stylized_Tier_I.usdz';stage=Usd.Stage.Open(str(src));cache=UsdGeom.XformCache();data=[]
for prim in stage.Traverse():
 if prim.IsA(UsdGeom.Mesh):
  mesh=UsdGeom.Mesh(prim);v=np.array(mesh.GetPointsAttr().Get(),dtype=float);m=np.array(cache.GetLocalToWorldTransform(prim));v=(v@m[:3,:3]+m[3,:3])*.01
  uv=next(v for v in UsdGeom.PrimvarsAPI(prim).GetPrimvars() if str(v.GetName()).startswith('primvars:st'));uv=np.array(uv.ComputeFlattened());uv[:,1]=1-uv[:,1]
  ix=np.array(mesh.GetFaceVertexIndicesAttr().Get(),dtype=np.uint32).reshape(-1,3)
  if mesh.GetOrientationAttr().Get()=='leftHanded':ix=ix[:,::-1].copy()
  data.append((v,uv,ix))
a=np.concatenate([x[0]for x in data]);center=(a.min(0)+a.max(0))/2;center[1]=a[:,1].min();blob=bytearray();g={'asset':{'version':'2.0'},'scene':0,'scenes':[{'nodes':[]}],'nodes':[],'meshes':[],'materials':[{'doubleSided':True,'pbrMetallicRoughness':{'baseColorTexture':{'index':0},'metallicFactor':0,'roughnessFactor':.9}}],'images':[],'textures':[{'source':0}],'bufferViews':[],'accessors':[]}
def view(raw):
 blob.extend(b'\0'*(-len(blob)%4));offset=len(blob);blob.extend(raw);g['bufferViews'].append({'buffer':0,'byteOffset':offset,'byteLength':len(raw)});return len(g['bufferViews'])-1
def acc(v,kind,ctype=5126):
 v=np.asarray(v,dtype='<u4' if ctype==5125 else '<f4');x={'bufferView':view(v.tobytes()),'componentType':ctype,'count':len(v),'type':kind}
 if kind=='VEC3':x.update(min=v.min(0).tolist(),max=v.max(0).tolist())
 g['accessors'].append(x);return len(g['accessors'])-1
z=zipfile.ZipFile(src);name=next(n for n in z.namelist()if 'baseColor' in n and n.endswith('.jpg'));im=Image.open(io.BytesIO(z.read(name)));im.thumbnail((1024,1024));buf=io.BytesIO();im.save(buf,'JPEG',quality=95);g['images']=[{'bufferView':view(buf.getvalue()),'mimeType':'image/jpeg'}]
for v,uv,ix in data:
 v-=center;n=np.zeros_like(v);face=np.cross(v[ix[:,1]]-v[ix[:,0]],v[ix[:,2]]-v[ix[:,0]])
 for k in range(3):np.add.at(n,ix[:,k],face)
 n/=np.maximum(np.linalg.norm(n,axis=1,keepdims=True),1e-10)
 g['meshes'].append({'primitives':[{'attributes':{'POSITION':acc(v,'VEC3'),'NORMAL':acc(n,'VEC3'),'TEXCOORD_0':acc(uv,'VEC2')},'indices':acc(ix.reshape(-1,1),'SCALAR',5125),'material':0}]})
 g['nodes'].append({'mesh':len(g['meshes'])-1});g['scenes'][0]['nodes'].append(len(g['nodes'])-1)
g['buffers']=[{'byteLength':len(blob)}];enc=json.dumps(g,separators=(',',':')).encode();enc+=b' '*(-len(enc)%4);blob.extend(b'\0'*(-len(blob)%4));out=struct.pack('<4sII',b'glTF',2,28+len(enc)+len(blob))+struct.pack('<I4s',len(enc),b'JSON')+enc+struct.pack('<I4s',len(blob),b'BIN\0')+blob;Path('output/model_work').mkdir(parents=True,exist_ok=True);Path('output/model_work/.gdignore').write_text('');Path('output/model_work/repair_reference.glb').write_bytes(out);print('bytes',len(out))
