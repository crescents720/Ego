"""Hospital sources remain untouched; normalize centimetres and cap textures."""
from pathlib import Path
import sys, json, zipfile, io
from PIL import Image
from scipy.spatial import cKDTree
import fast_simplification
import numpy as np
from pxr import Usd, UsdGeom, UsdShade
from build_harbor_assets import GlbBuilder, _world_vertices, _triangulate, _uvs, _simplify
SOURCES={"exterior":"Poznan_district_clinic_lite_Poland", "reception":"Hospital_Reception_Environment", "ward_a":"Hospital_Ward", "ward_b":"Hospital_ward (1)", "lab":"Neonatal_Unit_of_a_hospital (1)", "operating":"Charité_University_Hospital_-_Operating_Room", "office":"Office_Room", "morgue":"Morgue_Room"}
def hospital_uvs(prim, vertices, triangles):
 mesh=UsdGeom.Mesh(prim)
 candidates=[p for p in UsdGeom.PrimvarsAPI(prim).GetPrimvars() if p.GetTypeName().type.typeName in ('GfVec2f','GfVec2d') or str(p.GetName()).split(':')[-1].lower().startswith(('st','uv'))]
 if not candidates:return vertices,np.zeros((len(vertices),2)),triangles
 pv=candidates[0];uv=np.asarray(pv.ComputeFlattened(),dtype=float)
 if uv.ndim!=2 or uv.shape[1]<2:return vertices,np.zeros((len(vertices),2)),triangles
 uv=uv[:,:2].copy();uv[:,1]=1-uv[:,1]
 if str(pv.GetInterpolation())=='faceVarying':
  corners=[];start=0
  for count in mesh.GetFaceVertexCountsAttr().Get():
   for i in range(1,count-1):corners.append([start,start+i,start+i+1])
   start+=count
  corners=np.asarray(corners)
  if mesh.GetOrientationAttr().Get()=='leftHanded':corners=corners[:,::-1]
  return vertices[triangles.ravel()],uv[corners.ravel()],np.arange(triangles.size,dtype=np.uint32).reshape(-1,3)
 if len(uv)==len(vertices):return vertices,uv,triangles
 return vertices,np.zeros((len(vertices),2)),triangles

class HospitalBuilder(GlbBuilder):
 def material(self, mat):
  key=str(mat.GetPath())
  if key in self.materials:return self.materials[key]
  index=super().material(mat)
  target=self.doc["materials"][index]["pbrMetallicRoughness"]
  if "baseColorTexture" not in target:
   for child in Usd.PrimRange(mat.GetPrim()):
    if not child.IsA(UsdShade.Shader):continue
    value=UsdShade.Shader(child).GetInput("file").Get()
    if not value or not any(t in value.path.lower() for t in ["basecolor","diffuse","albedo"]):continue
    im=Image.open(io.BytesIO(self.archive.read(value.path))).convert("RGB");im.thumbnail((self.texture_limit,self.texture_limit));out=io.BytesIO();im.save(out,"PNG")
    self.doc["images"].append({"bufferView":self.view(out.getvalue()),"mimeType":"image/png"})
    self.doc["textures"].append({"source":len(self.doc["images"])-1,"sampler":0})
    target["baseColorTexture"]={"index":len(self.doc["textures"])-1};target["baseColorFactor"]=[1,1,1,1]
    break
  # Preserve the source solid colours as well as texture atlases.
  for child in Usd.PrimRange(mat.GetPrim()):
   if not child.IsA(UsdShade.Shader):continue
   sh=UsdShade.Shader(child)
   if sh.GetIdAttr().Get()!='UsdPreviewSurface':continue
   colour=sh.GetInput('diffuseColor').Get()
   if colour is not None and 'baseColorTexture' not in target:target['baseColorFactor']=[float(c) for c in colour]+[1.0]
   for field,out in [('roughness','roughnessFactor'),('metallic','metallicFactor')]:
    val=sh.GetInput(field).Get()
    if val is not None:target[out]=float(val)
  # Many converted packs mark every surface (even cloth/wood) as metal.
  # Keep colour/texture, but reserve metal response for identifiable hardware.
  label=key.lower()
  hardware=any(t in label for t in ['steel','metal','alumin','chuangjia','chrome'])
  target['metallicFactor']=min(float(target.get('metallicFactor',0)),.35 if hardware else .05)
  return index

OUT=Path("assets/hospital");OUT.mkdir(exist_ok=True)
if __name__ == "__main__":
 for key in (sys.argv[1:] or ["exterior"]):
  src=Path.home()/"Downloads"/(SOURCES[key]+".usdz")
  stage=Usd.Stage.Open(str(src));cache=UsdGeom.XformCache();parts=[]
  for p in stage.Traverse():
   if not p.IsA(UsdGeom.Mesh):continue
   v=_world_vertices(p,cache)
   if len(v):parts.append((p,UsdGeom.Mesh(p),v))
  # Office pack contains a distant stray mesh; use the furnished room cluster only.
  if key=="office":parts=[part for part in parts if part[2][:,2].mean()>-1000]
  allv=np.concatenate([v for _,_,v in parts]);lo=allv.min(0);hi=allv.max(0);center=(lo+hi)/2;center[1]=lo[1]
  scale=.026 if key=="exterior" else .01
  builder=HospitalBuilder(zipfile.ZipFile(src),4096 if key=="exterior" else (1024 if key=="operating" else 512))
  for p,m,v in parts:
   if key=="morgue" and ('Body_Small' in p.GetName() or 'Locker_Body_Small' in p.GetName()):continue
   v=(v-center)*scale;tri=_triangulate(m);v,uv,tri=hospital_uvs(p,v,tri)
   # Preserve silhouettes; expensive ward and office props get a per-mesh budget.
   if len(tri)>7000 and key not in ["operating","exterior"]:
    reduced,faces=fast_simplification.simplify(v.copy(),tri.copy(),target_reduction=max(0,1-5000/len(tri)))
    nearest=cKDTree(v).query(reduced)[1];uv=uv[nearest];v=reduced;tri=np.asarray(faces,dtype=np.uint32)
   builder.add_mesh(p.GetName(),v,uv,tri,UsdShade.MaterialBindingAPI(p).ComputeBoundMaterial()[0])
  output=OUT if key=="exterior" else Path("artifacts/hospital_reference_models")
  output.mkdir(parents=True,exist_ok=True)
  if key!="exterior":(output/".gdignore").touch()
  size=builder.save(output/(key+".glb"))
  print(key,"triangles",builder.triangles,"MB",round(size/1e6,2),"size",np.round((hi-lo)*scale,2),flush=True)
  (output/(key+".json")).write_text(json.dumps({"source":str(src),"source_center":center.tolist(),"scale":scale,"dimensions":((hi-lo)*scale).tolist(),"triangles":builder.triangles,"bytes":size},indent=2),encoding="utf-8")
