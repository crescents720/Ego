from pathlib import Path
import numpy as np, json,struct,zipfile,io
from pxr import Usd,UsdGeom,UsdShade
from PIL import Image
src=Path('C:/Users/ding5/Downloads/Old_Gas_Station.usdz');s=Usd.Stage.Open(str(src));cache=UsdGeom.XformCache();z=zipfile.ZipFile(src);out=Path('assets/environment/gas_station');out.mkdir(parents=True,exist_ok=True)
g={'asset':{'version':'2.0'},'scene':0,'scenes':[{'nodes':[]}],'nodes':[],'meshes':[],'materials':[],'images':[],'textures':[],'bufferViews':[],'accessors':[]};blob=bytearray();mats={};records=[]
def view(data):
 blob.extend(b'\0'*(-len(blob)%4));off=len(blob);blob.extend(data);g['bufferViews'].append({'buffer':0,'byteOffset':off,'byteLength':len(data)});return len(g['bufferViews'])-1
def acc(x,kind,integer=False):
 x=np.asarray(x,dtype='<u4' if integer else '<f4');a={'bufferView':view(x.tobytes()),'componentType':5125 if integer else 5126,'count':len(x),'type':kind}
 if kind=='VEC3':a.update(min=x.min(0).tolist(),max=x.max(0).tolist())
 g['accessors'].append(a);return len(g['accessors'])-1
for p in s.Traverse():
 if not p.IsA(UsdGeom.Mesh):continue
 mesh=UsdGeom.Mesh(p);verts=np.asarray(mesh.GetPointsAttr().Get(),dtype=float);matrix=np.array(cache.GetLocalToWorldTransform(p));verts=(verts@matrix[:3,:3]+matrix[3,:3])*.025
 # Model authored in centimeters but the whole station is undersized; x2.5 gives a 28m forecourt and 4m canopy.
 verts[:,0]+=2.3;verts[:,2]-=1.3
 counts=np.array(mesh.GetFaceVertexCountsAttr().Get());indices=np.array(mesh.GetFaceVertexIndicesAttr().Get());uvvar=next(v for v in UsdGeom.PrimvarsAPI(p).GetPrimvars()if 'st0' in str(v.GetName()));uv=np.array(uvvar.ComputeFlattened());uv[:,1]=1-uv[:,1]
 if len(uv)!=len(verts):verts=verts[indices];indices=np.arange(len(indices))
 tris=[];offset=0
 for count in counts:
  for i in range(1,int(count)-1):tris.append([indices[offset],indices[offset+i],indices[offset+i+1]])
  offset+=int(count)
 tris=np.array(tris,dtype=np.uint32)
 if mesh.GetOrientationAttr().Get()=='leftHanded':tris=tris[:,::-1]
 normals=np.zeros_like(verts);face=np.cross(verts[tris[:,1]]-verts[tris[:,0]],verts[tris[:,2]]-verts[tris[:,0]])
 for i in range(3):np.add.at(normals,tris[:,i],face)
 normals/=np.maximum(np.linalg.norm(normals,axis=1,keepdims=True),1e-10)
 material=UsdShade.MaterialBindingAPI(p).ComputeBoundMaterial()[0];key=material.GetPrim().GetName()
 if key not in mats:
  tex=UsdShade.Shader(s.GetPrimAtPath(str(material.GetPath())+'/tex_base')).GetInput('file').Get().path
  im=Image.open(io.BytesIO(z.read(tex))).convert('RGBA');im.thumbnail((1024,1024));buffer=io.BytesIO();im.save(buffer,'PNG',optimize=True)
  g['images'].append({'bufferView':view(buffer.getvalue()),'mimeType':'image/png'});g['textures'].append({'source':len(g['images'])-1})
  mats[key]=len(g['materials']);g['materials'].append({'name':key,'doubleSided':True,'alphaMode':'MASK' if key=='material' else 'OPAQUE','alphaCutoff':.5,'pbrMetallicRoughness':{'baseColorTexture':{'index':len(g['textures'])-1},'metallicFactor':0,'roughnessFactor':.85}})
 name=p.GetName();g['meshes'].append({'name':name,'primitives':[{'attributes':{'POSITION':acc(verts,'VEC3'),'NORMAL':acc(normals,'VEC3'),'TEXCOORD_0':acc(uv,'VEC2')},'indices':acc(tris.reshape(-1,1),'SCALAR',True),'material':mats[key]}]});g['nodes'].append({'name':name,'mesh':len(g['meshes'])-1});g['scenes'][0]['nodes'].append(len(g['nodes'])-1)
 records.append({'name':name,'triangles':len(tris),'min':verts.min(0).tolist(),'max':verts.max(0).tolist()})
g['buffers']=[{'byteLength':len(blob)}];enc=json.dumps(g,separators=(',',':')).encode();enc+=b' '*(-len(enc)%4);blob.extend(b'\0'*(-len(blob)%4));data=struct.pack('<4sII',b'glTF',2,28+len(enc)+len(blob))+struct.pack('<I4s',len(enc),b'JSON')+enc+struct.pack('<I4s',len(blob),b'BIN\0')+blob;(out/'gas_station_mobile.glb').write_bytes(data)
(out/'gas_station_mobile.json').write_text(json.dumps({'source':str(src),'triangles':sum(r['triangles']for r in records),'bytes':len(data),'materials':len(mats),'texture_max':1024,'parts':records},indent=2));print('gas model',len(data),'bytes',sum(r['triangles']for r in records),'triangles');print([r for r in records if any(k in r['name']for k in ['GAS_CORPUS','STATION_','ROOF_','POST_'])])
