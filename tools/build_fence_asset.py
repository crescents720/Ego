from pathlib import Path
import numpy as np,json,struct,zipfile,io
from pxr import Usd,UsdGeom,UsdShade
from PIL import Image
models=[('Wire_mesh_fence_Low_Poly','fence',2.0)]
out=Path('assets/factory');out.mkdir(parents=True,exist_ok=True)
for srcname,name,target in models:
 src=Path('C:/Users/ding5/Downloads')/(srcname+'.usdz');s=Usd.Stage.Open(str(src));cache=UsdGeom.XformCache();z=zipfile.ZipFile(src);parts=[]
 for p in s.Traverse():
  if not p.IsA(UsdGeom.Mesh):continue
  m=UsdGeom.Mesh(p);v=np.array(m.GetPointsAttr().Get(),float);t=np.array(cache.GetLocalToWorldTransform(p));v=v@t[:3,:3]+t[3,:3];parts.append((p,m,v))
 allv=np.concatenate([x[2] for x in parts]);lo=allv.min(0);hi=allv.max(0);extent=hi-lo;scale=target/(extent[1] if name=='merchant' else max(extent));center=(hi+lo)/2;center[1]=lo[1]
 g={'asset':{'version':'2.0'},'scene':0,'scenes':[{'nodes':[]}],'nodes':[],'meshes':[],'materials':[],'images':[],'textures':[],'bufferViews':[],'accessors':[]};blob=bytearray();mats={};total=0
 def view(data):
  blob.extend(b'\0'*(-len(blob)%4));off=len(blob);blob.extend(data);g['bufferViews'].append({'buffer':0,'byteOffset':off,'byteLength':len(data)});return len(g['bufferViews'])-1
 def acc(x,kind,integer=False):
  x=np.asarray(x,dtype='<u4' if integer else '<f4');a={'bufferView':view(x.tobytes()),'componentType':5125 if integer else 5126,'count':len(x),'type':kind}
  if kind=='VEC3':a.update(min=x.min(0).tolist(),max=x.max(0).tolist())
  g['accessors'].append(a);return len(g['accessors'])-1
 for p,m,v in parts:
  v=(v-center)*scale
  if name=='merchant':
   # Relax the supplied static A-pose to hands resting alongside the suit.
   for side in [-1,1]:
    mask=(v[:,0]*side>.22)&(v[:,1]>.72)
    pivot=np.array([.22*side,1.43,0]);angle=np.radians(-34*side);rot=np.array([[np.cos(angle),-np.sin(angle),0],[np.sin(angle),np.cos(angle),0],[0,0,1]])
    weight=np.clip((v[mask,0]*side-.22)/.13,0,1)[:,None];moved=(v[mask]-pivot)@rot.T+pivot;v[mask]=v[mask]*(1-weight)+moved*weight
  counts=np.array(m.GetFaceVertexCountsAttr().Get());idx=np.array(m.GetFaceVertexIndicesAttr().Get());uvvars=[x for x in UsdGeom.PrimvarsAPI(p).GetPrimvars() if 'st0' in str(x.GetName())];uv=np.array(uvvars[0].ComputeFlattened()) if uvvars else np.zeros((len(v),2));uv[:,1]=1-uv[:,1]
  if len(uv)!=len(v):v=v[idx];idx=np.arange(len(idx))
  tris=[];off=0
  for count in counts:
   for j in range(1,int(count)-1):tris.append([idx[off],idx[off+j],idx[off+j+1]])
   off+=int(count)
  tris=np.array(tris,dtype=np.uint32)
  if m.GetOrientationAttr().Get()=='leftHanded':tris=tris[:,::-1]
  # Collapse each material island independently; UV seam vertices remain separate.
  if name=='m60' and len(tris)>1500:
   import fast_simplification
   # Centroid reconstruction avoids unstable QEM positions on tiny, thin parts.
   source_v=v.copy();scaled=(source_v-source_v.mean(0))*1000
   _,_,collapses=fast_simplification.simplify(scaled.copy(),tris.copy(),target_reduction=.75,return_collapses=True)
   reduced_v,reduced_f,mapping=fast_simplification.replay_simplification(scaled.copy(),tris.copy(),collapses)
   positions=np.zeros((len(reduced_v),3));reduced_uv=np.zeros((len(reduced_v),2));weights=np.zeros(len(reduced_v));valid=mapping>=0
   np.add.at(positions,mapping[valid],source_v[valid]);np.add.at(reduced_uv,mapping[valid],uv[valid]);np.add.at(weights,mapping[valid],1)
   uv=reduced_uv/np.maximum(weights[:,None],1);v=positions/np.maximum(weights[:,None],1);tris=np.asarray(reduced_f,dtype=np.uint32)
   assert np.isfinite(v).all() and (v.min(0)>=source_v.min(0)-1e-5).all() and (v.max(0)<=source_v.max(0)+1e-5).all()
  normals=np.zeros_like(v);face=np.cross(v[tris[:,1]]-v[tris[:,0]],v[tris[:,2]]-v[tris[:,0]])
  for j in range(3):np.add.at(normals,tris[:,j],face)
  normals/=np.maximum(np.linalg.norm(normals,axis=1,keepdims=True),1e-10)
  mat=UsdShade.MaterialBindingAPI(p).ComputeBoundMaterial()[0];key=str(mat.GetPath())
  if key not in mats:
   props={'baseColorFactor':[.4,.4,.4,1],'metallicFactor':0,'roughnessFactor':.85};alpha=False
   for child in Usd.PrimRange(mat.GetPrim()):
    if child.IsA(UsdShade.Shader) and 'tex_base' in child.GetName():
     tex=UsdShade.Shader(child).GetInput('file').Get()
     if not tex:continue
     im=Image.open(io.BytesIO(z.read(tex.path))).convert('RGBA');im.thumbnail((512,512) if name=="m60" else (1024,1024));pixels=np.array(im);coverage=255-pixels[:,:,:3].mean(2);pixels[:,:,:3]=[157,173,162];pixels[:,:,3]=coverage.astype(np.uint8);im=Image.fromarray(pixels);alpha=True;b=io.BytesIO();im.save(b,'PNG',optimize=True);g['images'].append({'bufferView':view(b.getvalue()),'mimeType':'image/png'});g['textures'].append({'source':len(g['images'])-1});props={'baseColorTexture':{'index':len(g['textures'])-1},'metallicFactor':0,'roughnessFactor':.85}
   mats[key]=len(g['materials']);g['materials'].append({'name':mat.GetPrim().GetName(),'doubleSided':True,'alphaMode':'MASK' if alpha else 'OPAQUE','pbrMetallicRoughness':props})
  g['meshes'].append({'name':p.GetName(),'primitives':[{'attributes':{'POSITION':acc(v,'VEC3'),'NORMAL':acc(normals,'VEC3'),'TEXCOORD_0':acc(uv,'VEC2')},'indices':acc(tris.reshape(-1,1),'SCALAR',True),'material':mats[key]}]});g['nodes'].append({'name':p.GetName(),'mesh':len(g['meshes'])-1});g['scenes'][0]['nodes'].append(len(g['nodes'])-1);total+=len(tris)
 g['buffers']=[{'byteLength':len(blob)}];enc=json.dumps(g,separators=(',',':')).encode();enc+=b' '*(-len(enc)%4);blob.extend(b'\0'*(-len(blob)%4));data=struct.pack('<4sII',b'glTF',2,28+len(enc)+len(blob))+struct.pack('<I4s',len(enc),b'JSON')+enc+struct.pack('<I4s',len(blob),b'BIN\0')+blob;(out/(name+'.glb')).write_bytes(data);(out/(name+'.json')).write_text(json.dumps({'source':str(src),'triangles':total,'bytes':len(data),'dimensions':(extent*scale).tolist(),'parts':[p.GetName() for p,m,v in parts]},indent=2));print(name,total,len(data),extent*scale)
