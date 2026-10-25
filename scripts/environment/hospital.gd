extends Node3D
# Dimensions follow the supplied courtyard clinic, in the same metres as its exterior.
# Architecture uses plan coordinates; furnishings retain metre-sized geometry.
const SPACE_SCALE=Vector3(2,1,2)
const SITE=Vector3(37,.08,250)
const ORIGIN=Vector3(5000,0,0)
const DOOR=SITE+Vector3(6,.87,-8.1)
const ENTRY=Vector3(0,.95,-5.6)
const STOREY=3.6
const MAIN_RECTS=[Rect2(-5.7,-16.8,11.8,12.3),Rect2(-15.2,-9.4,9.5,16.7),Rect2(6.1,-9.4,9.1,11.9)]
const ANNEX=Rect2(-7.7,7.3,13.7,9.5)
const STAIR=Rect2(-5.7,-16.8,4.1,5.05)
const NOTCHES=[Rect2(-1.1,-16.8,2.2,1.3),Rect2(-15.2,-1.8,1.35,2.2),Rect2(13.85,-4.35,1.35,2.2),Rect2(-3,15.5,1.4,1.3)]
const PALETTE={"wall":Color("bcb7a8"),"floor":Color("687975"),"trim":Color("597674"),"accent":Color("c6ac5d")}
var main
const GATE=Vector3(69,.08,260)
var in_campus=false
var gate_busy=false
var gate_tween: Tween
var campus_labels=[]
var campus_restore_pending=true
var gate_root: Node3D
var gate_leaves=[]
var gate_block: StaticBody3D
var active=false
var floor_index=0
var room: Node3D
var exterior: Node3D
var levels: Array[Node3D]=[]
var rooms: Array[Dictionary]=[]
var doors: Array[Dictionary]=[]
var camera_rig=preload("res://scripts/environment/hospital_camera.gd").new()
var _bed_meshes=[]
var yaw=PI
var pitch=.05
var aim_finger=-1
var dragging=false
var return_position=Vector3.ZERO
var outdoor_states=[]
var population_was_processing=true
var map_view: Control
var _entry_lock=0.0
var _materials={}
var interior_environment: Environment
var _hidden_labels=[]
var _lamps=[]
var _saved_hint_style={}

func build(owner_main):
 main=owner_main
 name="Hospital"
 interior_environment=Environment.new()
 interior_environment.background_mode=Environment.BG_COLOR
 interior_environment.background_color=Color("c3d5da")
 interior_environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 interior_environment.ambient_light_color=Color("fff8eb")
 interior_environment.ambient_light_energy=.32
 interior_environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
 process_mode=Node.PROCESS_MODE_ALWAYS
 process_physics_priority=-10
 exterior=load("res://assets/hospital/exterior.glb").instantiate()
 exterior.name="DistrictClinic";exterior.position=SITE;exterior.scale=SPACE_SCALE
 main.world_root.add_child(exterior)
 # Hospital remains opaque: the campus gate provides a close exploration camera.
 _build_campus()
 main.town_layout._add_building_collision(exterior,"DistrictClinic")
 main.town_layout._road(Vector2(75,260),Vector2(39,260),8)
 main.town_layout._box("HospitalCourtyard",Vector3(23,.05,23),SITE+Vector3(.2,-.035,2.6),"a5aca5")
 _exterior_entry()
 _sign(exterior,"区立医院 · 正门",Vector3(3,3.18,-3.05),0,23).modulate=Color("e6e5cd")
 _box(exterior,Vector3(3.25,.42,.10),Vector3(3,3.18,-3.10),Color("526e70"))
 room=Node3D.new();room.name="HospitalInterior";room.position=ORIGIN;room.scale=SPACE_SCALE;add_child(room)
 for level in range(2):
  var node=Node3D.new();node.name="Floor%d"%(level+1);node.position.y=level*STOREY;room.add_child(node);levels.append(node)
  var footprint=MAIN_RECTS.duplicate()
  if level==0:footprint.append(ANNEX)
  _floors(node,footprint,level)
  _boundary(node,footprint)
 _layout()
 for level in range(2):
  _partitions(level)
  var parent=levels[level]
  for data in rooms:
   if data.floor==level:_dress_room(data)
  for point in [Vector2(0,-7.5),Vector2(0,-13),Vector2(-11,-5.6),Vector2(-11,1.8),Vector2(-11,6.1),Vector2(10.5,-5.6)]:_lamp(parent,Vector3(point.x,3.12,point.y))
  _box(parent,Vector3(29,.012,.10),Vector3(0,.02,-5.65),PALETTE.accent)
  _box(parent,Vector3(.10,.012,11),Vector3(-10.9,.02,.6),PALETTE.accent)
  _sign(parent,"← 101–104 观察病房    检验 / 手术 →" if level==0 else "← 204–208 病房    209–212 病房 →",Vector3(0,2.65,-6.8),0,19)
  _sign(parent,"↑ 楼梯 / 2F" if level==0 else "↓ 楼梯 / 1F",Vector3(-1.48,2.6,-12.1),PI/2,22)
  _reception(parent)
  _sign(parent,"接待 / RECEPTION" if level==0 else "护士站 / NURSE",Vector3(0,2.45,-15.35),0,24)
 for z in [-7.25,-8.0]:
  var parent=Node3D.new();levels[0].add_child(parent);parent.position=Vector3(-1.1,0,z);parent.scale=Vector3(.5,1,.5)
  _box(parent,Vector3(.52,.12,.58),Vector3(0,.48,0),Color("365f70"),true)
  _box(parent,Vector3(.10,.62,.58),Vector3(-.26,.79,0),Color("365f70"))
  for x in [-.2,.2]:
   for dz in [-.23,.23]:_box(parent,Vector3(.035,.43,.035),Vector3(x,.215,dz),Color("4b5e60"))
 _exit_door()
 _stairs()
 var layer=CanvasLayer.new();layer.layer=9;add_child(layer)
 map_view=load("res://scripts/ui/hospital_map.gd").new();map_view.hospital=self;layer.add_child(map_view)
 room.hide();room.process_mode=Node.PROCESS_MODE_DISABLED

func _mat(color: Color):
 if not _materials.has(color):
  var mat=StandardMaterial3D.new();mat.albedo_color=color;mat.roughness=.85;_materials[color]=mat
 return _materials[color]
func _box(parent: Node,size: Vector3,point: Vector3,color: Color,solid=false):
 var mesh=MeshInstance3D.new();var shape=BoxMesh.new();shape.size=size;mesh.mesh=shape;mesh.position=point;mesh.material_override=_mat(color);parent.add_child(mesh)
 if solid:_solid(parent,size,point)
 return mesh
func _solid(parent: Node,size: Vector3,point: Vector3):
 var body=StaticBody3D.new();body.collision_layer=3;body.collision_mask=0;body.position=point
 var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=size;shape.shape=box;body.add_child(shape);parent.add_child(body)
 return body
func _slab(parent: Node,rect: Rect2,height: float,color: Color,solid: bool):
 var slab=_box(parent,Vector3(rect.size.x,.12,rect.size.y),Vector3(rect.get_center().x,height-.06,rect.get_center().y),color,solid)
 if height==0:
  if not _materials.has("floor_shader"):
   var shader=Shader.new()
   shader.code="""shader_type spatial;
varying vec3 world;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){vec2 p=world.xz*1.25;vec2 cell=fract(p);float grout=step(.988,max(cell.x,cell.y));float tint=mod(floor(p.x)+floor(p.y),2.0);ALBEDO=mix(mix(vec3(.19,.235,.22),vec3(.215,.25,.23),tint),vec3(.11,.14,.13),grout);ROUGHNESS=.78;}
"""
   var mat=ShaderMaterial.new();mat.shader=shader;_materials["floor_shader"]=mat
  slab.material_override=_materials["floor_shader"]
func _floors(parent: Node,footprint: Array,level: int):
 var xs=[];var zs=[]
 for r in footprint+NOTCHES+[STAIR]:
  for x in [r.position.x,r.end.x]:if not xs.has(x):xs.append(x)
  for z in [r.position.y,r.end.y]:if not zs.has(z):zs.append(z)
 xs.sort();zs.sort()
 for i in range(xs.size()-1):
  for j in range(zs.size()-1):
   var r=Rect2(xs[i],zs[j],xs[i+1]-xs[i],zs[j+1]-zs[j]);var c=r.get_center()
   if not _contains(footprint,c):continue
   if level==0 or not STAIR.has_point(c):_slab(parent,r,0,PALETTE.floor,true)
   if level==1 or not STAIR.has_point(c):
    _slab(parent,r,3.25,PALETTE.wall,false)
    var ceiling=_solid(parent,Vector3(r.size.x,.12,r.size.y),Vector3(c.x,3.25,c.y));ceiling.collision_layer=8
func _boundary(parent: Node,rects: Array):
 var xs=[];var zs=[]
 for rect in rects+NOTCHES:
  for x in [rect.position.x,rect.end.x]:if not xs.has(x):xs.append(x)
  for z in [rect.position.y,rect.end.y]:if not zs.has(z):zs.append(z)
 xs.sort();zs.sort()
 for i in range(xs.size()-1):
  for j in range(zs.size()-1):
   var c=Vector2((xs[i]+xs[i+1])/2,(zs[j]+zs[j+1])/2)
   if not _contains(rects,c):continue
   if not _contains(rects,Vector2(xs[i]-.01,c.y)):_wall(parent,Vector2(xs[i],c.y),zs[j+1]-zs[j],PI/2,true)
   if not _contains(rects,Vector2(xs[i+1]+.01,c.y)):_wall(parent,Vector2(xs[i+1],c.y),zs[j+1]-zs[j],PI/2,true)
   if not _contains(rects,Vector2(c.x,zs[j]-.01)):_wall(parent,Vector2(c.x,zs[j]),xs[i+1]-xs[i],0,true)
   if not _contains(rects,Vector2(c.x,zs[j+1]+.01)):_wall(parent,Vector2(c.x,zs[j+1]),xs[i+1]-xs[i],0,true)
func _contains(rects: Array,point: Vector2)->bool:
 for notch in NOTCHES:
  if notch.has_point(point):return false
 for rect in rects:
  if rect.has_point(point):return true
 return false
func _wall(parent: Node,point: Vector2,length: float,angle: float,window: bool):
 if length<.01:return
 var group=Node3D.new();group.position=Vector3(point.x,0,point.y);group.rotation.y=angle;parent.add_child(group)
 # Windows belong to facade bays, never a continuous glass wall around every room.
 var openings=[]
 if window:
  var vertical=absf(angle)>1
  var coordinate=point.y if vertical else point.x
  var centers=[]
  if not vertical and is_equal_approx(point.y,-9.4):
   for start in [-15.2,6.1]:
    for i in range(4):centers.append(start+(i+.5)*(9.5 if start<0 else 9.1)/4)
  elif vertical and (is_equal_approx(point.x,-5.7) or is_equal_approx(point.x,6.1)):
   centers=[-15.5,-13,-10.5] if point.y<-9.3 else ([-3.7,-1.7,.3,2.3,4.3] if point.x<0 else [])
  elif vertical and is_equal_approx(point.x,-15.2):centers=[-8.4,-6.1,-3.7]
  elif vertical and is_equal_approx(point.x,15.2):centers=[-8.1,-5.7,-3.1,.2]
  elif not vertical and is_equal_approx(point.y,7.3):centers=[-13.65,-10.85,-8.05]
  elif not vertical and is_equal_approx(point.y,2.5):centers=[7.65,10.45,13.25]
  elif not vertical and is_equal_approx(point.y,-15.5):centers=[0]
  elif vertical and is_equal_approx(point.x,6.0):centers=[11.0,13.5]
  elif vertical and is_equal_approx(point.x,-7.7):centers=[10,12,14.2]
  for c in centers:
   var relative=(coordinate-c) if vertical else (c-coordinate)
   if relative+.65>-length/2+.01 and relative-.65<length/2-.01:openings.append(Vector2(maxf(relative-.65,-length/2),minf(relative+.65,length/2)))
 openings.sort_custom(func(a,b):return a.x<b.x)
 var cursor=-length/2
 for span in openings:
  _wall_piece(group,cursor,span.x)
  var x=(span.x+span.y)/2;var w=span.y-span.x
  _box(group,Vector3(w,1.0,.16),Vector3(x,.5,0),Color("81958b"))
  _box(group,Vector3(w,.75,.16),Vector3(x,2.875,0),PALETTE.wall)
  _box(group,Vector3(w,1.5,.05),Vector3(x,1.75,0),Color("536e76"))
  for edge in [span.x,x,span.y]:_box(group,Vector3(.055,1.55,.20),Vector3(edge,1.75,0),Color("b2b2a7"))
  for y in [1.0,1.75,2.5]:_box(group,Vector3(w,.045,.20),Vector3(x,y,0),Color("b2b2a7"))
  cursor=span.y
 _wall_piece(group,cursor,length/2)
 _solid(group,Vector3(length,3.25,.16),Vector3(0,1.625,0))
 _box(group,Vector3(length,.10,.20),Vector3(0,.10,0),PALETTE.trim)
func _wall_piece(parent: Node,start: float,end: float):
 if end-start<.01:return
 _box(parent,Vector3(end-start,2.20,.16),Vector3((start+end)/2,2.15,0),PALETTE.wall)
 _box(parent,Vector3(end-start,1.05,.16),Vector3((start+end)/2,.525,0),Color("81958b"))
 _box(parent,Vector3(end-start,.06,.20),Vector3((start+end)/2,1.05,0),PALETTE.trim)
func _sign(parent: Node,text: String,point: Vector3,angle: float,font: int):
 var label=Label3D.new();label.text=text;label.position=point;label.rotation.y=angle;label.font_size=font;label.pixel_size=.009;label.modulate=Color("304e57");label.outline_size=0;label.no_depth_test=false;label.double_sided=false;parent.add_child(label)
 return label
func _lamp(parent: Node,point: Vector3):
 var panel=_box(parent,Vector3(1.1,.04,.5),point,Color("fff9e3"))
 var mat=StandardMaterial3D.new();mat.albedo_color=Color("fff9e3");mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;panel.material_override=mat
 var light=OmniLight3D.new();light.position=point-Vector3(0,.35,0);light.light_color=Color("fff8e9");light.light_energy=.65;light.omni_range=4.7;light.shadow_enabled=false;parent.add_child(light);_lamps.append(light)
func _spec(level: int,title: String,rect: Rect2,kind: String,side: String,beds=0):
 var point=rect.get_center()
 if side=="E":point.x=rect.end.x
 elif side=="W":point.x=rect.position.x
 elif side=="N":point.y=rect.position.y
 else:point.y=rect.end.y
 if (beds==1 or kind=="sample") and side=="S":point.x=rect.end.x-1.1
 if title in ["诊室 01","202 病房"]:point.y=-13.2
 rooms.append({"name":title,"floor":level,"rect":rect,"kind":kind,"side":side,"door":point,"beds":beds})
func _layout():
 for f in range(2):
  _spec(f,"医师办公室" if f==0 else "201 病房",Rect2(-5.7,-11.75,4.1,5.05),"office" if f==0 else "ward","E",0 if f==0 else 2)
  _spec(f,"诊室 01" if f==0 else "202 病房",Rect2(1.6,-16.8,4.5,5.05),"consult" if f==0 else "ward","W",0 if f==0 else 2)
  _spec(f,"诊室 02" if f==0 else "203 病房",Rect2(1.6,-11.75,4.5,5.05),"consult" if f==0 else "ward","W",0 if f==0 else 2)
  for i in range(2):
   _spec(f,"%d 病房"%((101 if f==0 else 204)+i),Rect2(-15.2+i*4.75,-9.4,4.75,2.7),"ward","S",1)
   _spec(f,"%d 病房"%((103 if f==0 else 206)+i),Rect2(-9.8,-4.5 if i==0 else 1.3,4.1,5.8 if i==0 else 3.8),"ward","W",2)
   _spec(f,("采样室" if i==0 else "检验室") if f==0 else "%d 病房"%(209+i),Rect2(6.1+i*4.55,-9.4,4.55,2.7),("sample" if i==0 else "lab") if f==0 else "ward","S",0 if f==0 else 1)
   _spec(f,("术前准备 / 术后观察" if i==0 else "手术室") if f==0 else "%d 病房"%(211+i),Rect2(6.1+i*4.55,-4.5,4.55,7),("recovery" if i==0 else "operating") if f==0 else "ward","N",0 if f==0 else 3)
  _spec(f,"卫生间" if f==0 else "208 病房",Rect2(-15.2,-4.5,3.2,4.8),"toilet" if f==0 else "ward","E",0 if f==0 else 1)
  _spec(f,"清洁 / 污物间" if f==0 else "卫生 / 清洁间",Rect2(-15.2,.3,3.2,4.8),"utility" if f==0 else "toilet","E")
 _spec(0,"准备 / 转运",Rect2(-7.7,9.5,7.2,3.6),"preparation","N")
 _spec(0,"器械 / 布草储藏",Rect2(-7.7,13.1,7.2,3.7),"storage","N")
 _spec(0,"太平间",Rect2(-.5,9.5,6.5,7.3),"morgue","N")
func _partitions(level: int):
 var segments={};var portal_specs=[]
 for data in rooms:
  if data.floor!=level:continue
  portal_specs.append(data)
  var r: Rect2=data.rect
  for edge in [[false,r.position.y,r.position.x,r.end.x],[false,r.end.y,r.position.x,r.end.x],[true,r.position.x,r.position.y,r.end.y],[true,r.end.x,r.position.y,r.end.y]]:
   var key="%s:%0.3f"%[edge[0],edge[1]]
   if not segments.has(key):segments[key]=[]
   segments[key].append(edge)
 # Stair walls are open to the hall at the same landing on both levels.
 var stair_door={"name":"楼梯","floor":level,"door":Vector2(-1.6,-12.275),"side":"E","stair":true}
 portal_specs.append(stair_door)
 for edge in [[true,-1.6,-16.8,-11.75],[false,-11.75,-5.7,-1.6]]:
  var key="%s:%0.3f"%[edge[0],edge[1]]
  if not segments.has(key):segments[key]=[]
  segments[key].append(edge)
 var footprint=MAIN_RECTS.duplicate()
 if level==0:footprint.append(ANNEX)
 for group in segments.values():
  var vertical: bool=group[0][0];var fixed: float=group[0][1];var cuts=[];var portals=[]
  for edge in group:
   cuts.append(edge[2]);cuts.append(edge[3])
  for data in portal_specs:
   var p: Vector2=data.door
   if vertical!=(data.side in ["E","W"]):continue
   if absf((p.x if vertical else p.y)-fixed)>.01:continue
   var c=p.y if vertical else p.x
   var width=1.05 if data.has("stair") else 1.4
   portals.append(Vector2(c-width/2,c+width/2));cuts.append(c-width/2);cuts.append(c+width/2)
  cuts.sort()
  for i in range(cuts.size()-1):
   var a: float=cuts[i];var b: float=cuts[i+1];var c=(a+b)/2
   if b-a<.01:continue
   var covered=false
   for edge in group:
    if c>edge[2]-.001 and c<edge[3]+.001:covered=true
   if not covered:continue
   var p=Vector2(fixed,c) if vertical else Vector2(c,fixed)
   var normal=Vector2(.12,0) if vertical else Vector2(0,.12)
   if not _contains(footprint,p+normal) or not _contains(footprint,p-normal):continue
   var opening=false
   for portal in portals:
    if c>portal.x and c<portal.y:opening=true
   if opening:
    _box(levels[level],Vector3(.16,.7,b-a) if vertical else Vector3(b-a,.7,.16),Vector3(p.x,2.9,p.y),PALETTE.wall)
   else:_wall(levels[level],p,b-a,PI/2 if vertical else 0,false)
 for data in portal_specs:
  if not data.has("stair"):_door(data)
func _door(data: Dictionary):
 var p: Vector2=data.door;var vertical=data.side in ["E","W"];var angle=PI/2 if vertical else 0.0
 var tangent=Vector3(cos(angle),0,-sin(angle));var center=Vector3(p.x,0,p.y)
 var parent=levels[data.floor];var pivot=Node3D.new();pivot.position=center-tangent*.68;pivot.rotation.y=angle;parent.add_child(pivot)
 _box(pivot,Vector3(1.36,2.55,.075),Vector3(.68,1.275,0),Color("4f7779"))
 _box(pivot,Vector3(.48,.55,.08),Vector3(.68,1.75,0),Color("738f92"))
 _box(pivot,Vector3(.13,.04,.15),Vector3(1.17,1.05,0),Color("b3ac8d"))
 var body=_solid(parent,Vector3(.12,2.55,1.36) if vertical else Vector3(1.36,2.55,.12),center+Vector3(0,1.275,0))
 doors.append({"name":data.name,"pivot":pivot,"body":body,"open":false,"busy":false,"floor":data.floor,"point":center+Vector3(0,.95+data.floor*STOREY,0),"angle":angle,"east":true,"vertical":vertical,"closed_position":pivot.position,"open_position":pivot.position-tangent*1.42,"open_angle":angle})
 var normal={"E":Vector3.RIGHT,"W":Vector3.LEFT,"N":Vector3.FORWARD,"S":Vector3.BACK}[data.side]
 var sign_angle={"E":PI/2,"W":-PI/2,"N":PI,"S":0.0}[data.side]
 _sign(parent,data.name,center+Vector3(0,2.78,0)+normal*.13,sign_angle,19)
func _asset(parent: Node,key: String,point: Vector3,size=Vector3.ONE,angle=0.0):
 var path="res://assets/hospital/"+key+".glb"
 var model=load(path).instantiate();model.name=key.capitalize();model.position=point;model.scale=size;model.rotation.y=angle;parent.add_child(model)
 for mesh in model.find_children("*","MeshInstance3D",true,false):
  var body=StaticBody3D.new();body.collision_layer=3;body.collision_mask=0
  var shape=CollisionShape3D.new();shape.shape=mesh.mesh.create_trimesh_shape();body.add_child(shape);mesh.add_child(body)
 return model
func _bed(parent: Node,point: Vector3,angle=0.0):
 if _bed_meshes.is_empty():_build_light_bed()
 var model=Node3D.new();model.name="LightHospitalBed";parent.add_child(model);model.position=point;model.rotation.y=angle;model.add_to_group("hospital_beds")
 for mesh in _bed_meshes:
  var instance=MeshInstance3D.new();instance.mesh=mesh;model.add_child(instance)
 # One smooth solid volume, no wheel/rail crevices or per-triangle character contact.
 _solid(model,Vector3(1.98,.94,1.04),Vector3(0,.47,0))
 return model
func _build_light_bed():
 var groups={}
 var parts=[
  [Vector3(1.96,.13,1.0),Vector3(0,.42,0),"657a79"],
  [Vector3(1.84,.18,.94),Vector3(0,.575,0),"d9d8c7"],
  [Vector3(1.28,.045,.92),Vector3(.27,.68,0),"c2cec5"],
  [Vector3(.40,.12,.67),Vector3(-.63,.72,0),"e7e4d2"],
  [Vector3(.10,.60,1.02),Vector3(-.95,.72,0),"9b9178"],
  [Vector3(.10,.36,1.02),Vector3(.95,.59,0),"9b9178"]]
 for x in [-.74,.74]:
  for z in [-.39,.39]:
   parts.append([Vector3(.07,.31,.07),Vector3(x,.245,z),"657a79"])
   parts.append([Vector3(.16,.15,.11),Vector3(x,.075,z),"354748"])
 for z in [-.48,.48]:
  parts.append([Vector3(1.28,.055,.045),Vector3(.07,.88,z),"aebdb7"])
  for x in [-.55,.68]:parts.append([Vector3(.045,.23,.045),Vector3(x,.765,z),"aebdb7"])
 for part in parts:
  if not groups.has(part[2]):
   var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES);surface.set_material(_mat(Color(part[2])));groups[part[2]]=surface
  var box=BoxMesh.new();box.size=part[0]
  groups[part[2]].append_from(box,0,Transform3D(Basis.IDENTITY,part[1]))
 for surface in groups.values():_bed_meshes.append(surface.commit())
func _cabinet(parent: Node,p: Vector3,w=1.1):
 _box(parent,Vector3(w,.85,.5),p+Vector3(0,.425,0),Color("9b9178"),true)
 _box(parent,Vector3(w+.05,.055,.55),p+Vector3(0,.88,0),Color("58696a"))
 for x in [-.25,.25]:_box(parent,Vector3(.13,.035,.03),p+Vector3(x,.64,.27),Color("384b50"))
func _dress_room(data: Dictionary):
 var original: Rect2=data.rect
 var r=Rect2(original.position*2,original.size*2);var c=r.get_center();var kind: String=data.kind
 var parent=Node3D.new();parent.name="RoomFurniture";parent.scale=Vector3(.5,1,.5);levels[data.floor].add_child(parent)
 _lamp(parent,Vector3(c.x,3.12,c.y))
 if kind=="ward":
  if data.beds==1:
   var p=Vector3(c.x-.55,0,c.y-.35)
   if data.name.begins_with("208"):p=Vector3(c.x-.5,0,-6.1)
   _bed(parent,p,PI/2 if data.name.begins_with("208") else 0.0)
   _cabinet(parent,Vector3(r.end.x-.65,0,r.position.y+.5),.7)
  else:
   for i in range(data.beds):
    var z=r.position.y+.8+(i+.5)*(r.size.y-1.2)/data.beds
    var x=r.end.x-1.15 if data.side=="W" else (r.position.x+1.15 if data.side=="E" else c.x)
    _bed(parent,Vector3(x,0,z))
   _cabinet(parent,Vector3(c.x,0,r.end.y-.4),.75)
 elif kind=="operating":
  # Keep source surgical colours and detail. Its west opening faces our north door.
  _asset(parent,"operating_furniture",Vector3(c.x,0,c.y),Vector3(.86,1,.65),-PI/2)
 elif kind=="morgue":_asset(parent,"morgue_furniture",Vector3(c.x,0,r.end.y-3.3),Vector3(.85,1,.85),PI)
 elif kind=="lab":
  for x in [c.x-1.05,c.x+1.05]:_asset(parent,"lab_device",Vector3(x,0,r.position.y+.65))
 elif kind=="office":_office(parent,r)
 elif kind in ["sample","consult","recovery"]:
  _bed(parent,Vector3(r.position.x+1.12 if kind=="sample" else c.x,0,c.y-.35 if kind=="sample" else r.position.y+2.3))
  _asset(parent,"monitor",Vector3(r.end.x-.55,0,r.position.y+.7))
  _cabinet(parent,Vector3(r.end.x-.55,0,r.position.y+.45),.7)
 elif kind=="toilet":
  for x in [r.position.x+.65,r.end.x-.65]:
   _box(parent,Vector3(.52,.45,.7),Vector3(x,.225,r.position.y+.65),Color("b3b4a8"),true)
   _box(parent,Vector3(.55,.60,.23),Vector3(x,.65,r.position.y+.27),Color("b3b4a8"))
  _cabinet(parent,Vector3(c.x,0,r.end.y-.55),1.4)
 else:
  for x in [r.position.x+.75,r.end.x-.75]:
   _cabinet(parent,Vector3(x,0,r.position.y+.7))
   _box(parent,Vector3(1.1,1.1,.45),Vector3(x,1.7,r.position.y+.7),Color("82938c"),true)
  if kind=="preparation":_asset(parent,"monitor",Vector3(c.x,0,c.y))
func _stairs():
 var parent=levels[0]
 for i in range(11):
  var h=(i+1)*STOREY/22
  _camera_box(parent,Vector3(1.70,h,3.0/11),Vector3(-2.65,h/2,-12.8-(i+.5)*3.0/11),Color("727f7a"))
  _box(parent,Vector3(1.70,.025,.045),Vector3(-2.65,h,-12.8-i*3.0/11),PALETTE.accent)
  _camera_box(parent,Vector3(1.70,1.8+h,3.0/11),Vector3(-4.65,(1.8+h)/2,-15.8+(i+.5)*3.0/11),Color("727f7a"))
  _box(parent,Vector3(1.70,.025,.045),Vector3(-4.65,1.8+h,-15.8+(i+1)*3.0/11),PALETTE.accent)
 _box(parent,Vector3(4.0,.12,1.0),Vector3(-3.65,1.74,-16.3),PALETTE.floor,true)
 _box(parent,Vector3(4.0,.12,1.05),Vector3(-3.65,STOREY-.06,-12.275),PALETTE.floor,true)
 # Prevent walking directly onto the high flight, or off the upstairs landing.
 _solid(parent,Vector3(1.8,1.7,4.0),Vector3(-4.65,.85,-13.75))
 _solid(parent,Vector3(.13,4.8,3.0),Vector3(-3.65,2.4,-14.3))
 _solid(parent,Vector3(1.9,1.1,.12),Vector3(-2.65,4.15,-12.8))
 # Continuous rails follow the actual tread heights on both flights.
 for flight in [0,1]:
  for x in ([-3.53,-1.80] if flight==0 else [-5.50,-3.77]):
   var a=Vector3(x,.95 if flight==0 else 4.55,-12.8)
   var b=Vector3(x,2.75,-15.8)
   _rail(parent,a,b)
   for i in range(7):
    var top=a.lerp(b,float(i)/6)
    _box(parent,Vector3(.055,.95,.055),top-Vector3(0,.475,0),Color("43595a"))
 _rail(parent,Vector3(-5.5,2.75,-16.65),Vector3(-1.8,2.75,-16.65))
 _lamp(parent,Vector3(-3.5,5.8,-16.1))

func near_entrance()->bool:
 return main.controls_enabled and main.phase not in [main.Phase.TITLE,main.Phase.GAME_OVER,main.Phase.COMPLETE] and in_campus and not active and _entry_lock<=0 and not main.in_vehicle and not main.inside_rv and not main.inside_store and not main.factory.active and not main.temple.active and main.trolley.near_door(DOOR,2.5)
func near_exit()->bool:
 if not active or floor_index!=0:return false
 for p in main.trolley.doorway_points():
  var local=to_interior_local(p)
  if absf(local.x)<1.6 and local.z>-6.5 and local.z<-4:return true
 return false
func enter():
 if not near_entrance() or not main.controls_enabled:return
 active=true;floor_index=0;return_position=main.hotaru.global_position
 _saved_hint_style={"color":main.hint_label.get_theme_color("font_outline_color"),"width":main.hint_label.get_theme_constant("outline_size")}
 main.hint_label.add_theme_color_override("font_outline_color",Color("253a40"));main.hint_label.add_theme_constant_override("outline_size",5)
 main.mobile_joystick.reset()
 var bring=main.trolley.pushing and main.trolley.nearby()
 main.trolley.release()
 if bring:
  GameState.cart_exterior_position=GameState.cart_position
  GameState.cart_position=to_interior_world(ENTRY)+Vector3(0,-.87,-1.1);GameState.cart_yaw=PI
 main.world_root.hide();main.rv.hide();outdoor_states=[]
 for z in get_tree().get_nodes_in_group("zombies"):
  outdoor_states.append([z,z.visible,z.is_physics_processing()]);z.hide();z.set_physics_process(false);z.remove_from_group("zombies")
 population_was_processing=main.zombie_population.is_processing();main.zombie_population.set_process(false)
 room.show();room.process_mode=Node.PROCESS_MODE_PAUSABLE
 main.hotaru.set_ground_height(.95);main.hotaru.global_position=to_interior_world(ENTRY);main.hotaru.velocity=Vector3.ZERO;main.hotaru.rotation.y=PI
 _hidden_labels=[]
 for label in main.hotaru.find_children("*","Label3D",true,false):
  if label.visible:_hidden_labels.append(label);label.hide()
 yaw=PI;pitch=.05;dragging=false;aim_finger=-1
 if bring:main.trolley.interact()
 update_camera(0)
 main.rest_notice("医院：沿导向线探索，门旁交互开门。
左侧楼梯通往二层，西侧走廊通往附楼。")
func leave(silent=false):
 if not active:return
 var bring=main.trolley.pushing and main.trolley.nearby()
 main.trolley.release()
 if bring:GameState.cart_position=GameState.cart_exterior_position
 active=false;floor_index=0;dragging=false;aim_finger=-1
 if not _saved_hint_style.is_empty():
  main.hint_label.add_theme_color_override("font_outline_color",_saved_hint_style.color);main.hint_label.add_theme_constant_override("outline_size",_saved_hint_style.width)
 for light in _lamps:light.shadow_enabled=false
 room.hide();room.process_mode=Node.PROCESS_MODE_DISABLED
 main.world_root.show();main.rv.show()
 for state in outdoor_states:
  if is_instance_valid(state[0]):
   state[0].visible=state[1];state[0].set_physics_process(state[2] and not state[0]._dying);state[0].add_to_group("zombies")
 outdoor_states=[];main.zombie_population.set_process(population_was_processing)
 for label in _hidden_labels:
  if is_instance_valid(label):label.show()
 for mesh in main.hotaru._body_meshes:mesh.transparency=0
 main.hotaru._visual_root.show()
 main.hotaru.set_ground_height(.95);main.hotaru.global_position=return_position;main.hotaru.velocity=Vector3.ZERO
 main.camera.environment=null
 main.camera.fov=52;main.camera.near=.15;main._update_camera(100);_entry_lock=.6
 if bring:main.trolley.interact()
 if not silent:main.rest_notice("离开主楼，回到医院庭院。沿道路可返回院门。")
func reset():
 camera_rig.reset()
 if is_instance_valid(gate_tween):gate_tween.kill()
 main.hotaru.cancel_boarding_step()
 leave(true);in_campus=false;gate_busy=false;campus_restore_pending=true;_entry_lock=0
 camera_rig.reset()
 _restore_campus_labels()
 if is_instance_valid(gate_root):
  for leaf in gate_leaves:leaf.rotation.y=0
  gate_block.collision_layer=3
 for door in doors:
  if door.has("tween") and is_instance_valid(door.tween):door.tween.kill()
  door.erase("tween")
  door.open=false;door.busy=false;door.pivot.rotation.y=door.angle;door.pivot.position=door.closed_position;door.body.collision_layer=3
func _physics_process(delta):
 _entry_lock=maxf(0,_entry_lock-delta)
 if campus_restore_pending and main.controls_enabled and main.phase not in [main.Phase.TITLE,main.Phase.GAME_OVER]:
  campus_restore_pending=false
  var p: Vector3=main.hotaru.global_position
  if not active and not gate_busy and not main.in_vehicle and not main.inside_rv and Rect2(6,208,63,84).has_point(Vector2(p.x,p.z)):
   in_campus=true;yaw=PI;pitch=.05
   for label in main.hotaru.find_children("*","Label3D",true,false):
    if label.visible:campus_labels.append(label);label.hide()
 if not active or get_tree().paused or not main.controls_enabled:return
 var p=to_interior_local(main.hotaru.global_position)
 if STAIR.has_point(Vector2(p.x,p.z)):
  var height: float=floor_index*STOREY
  if p.z<-15.8:height=STOREY/2
  elif p.z<-12.8:
   var t=clampf((-p.z-12.8)/3.0,0,1)
   height=1.8*t if p.x>-3.65 else 1.8+1.8*(1-t)
   floor_index=0 if p.x>-3.65 else 1
   if p.x<-3.65 and t<.03:floor_index=1
   elif p.x>-3.65 and t<.03:floor_index=0
  main.hotaru.set_ground_height(.95+height)
 else:main.hotaru.set_ground_height(.95+floor_index*STOREY)
 # Do not show an unused second-floor interior through first-floor windows.
 levels[1].visible=floor_index==1 or STAIR.has_point(Vector2(p.x,p.z))
 levels[0].visible=floor_index==0 or STAIR.grow(2.5).has_point(Vector2(p.x,p.z))
 # Limit local lighting work: distant rooms and the other floor need no live lamps.
 var nearby_lamps=_lamps.duplicate()
 nearby_lamps.sort_custom(func(a,b):return a.global_position.distance_squared_to(main.hotaru.global_position)<b.global_position.distance_squared_to(main.hotaru.global_position))
 for i in range(nearby_lamps.size()):
  var light=nearby_lamps[i]
  light.visible=i<4 and light.global_position.distance_to(main.hotaru.global_position)<8
  light.shadow_enabled=false
 if main.hotaru.dead:dragging=false;aim_finger=-1
func focused_door()->Dictionary:
 var best={};var distance=1.8
 for door in doors:
  if door.floor!=floor_index:continue
  var d=main.hotaru.global_position.distance_to(to_interior_world(door.point))
  if d<distance:distance=d;best=door
 return best
func interact():
 if not active:
  if near_gate():use_gate()
  elif near_entrance():enter()
  else:main.trolley.interact()
  return
 if near_exit():leave();return
 var door=focused_door()
 if door.is_empty():main.trolley.interact();return
 if door.busy:return
 # A close request while someone stands in the opening leaves it safely open.
 var local=to_interior_local(main.hotaru.global_position)
 if door.open and absf((local.x-door.point.x) if door.vertical else (local.z-door.point.z))<.275:
  main.rest_notice("先离开门框，再关门。");return
 door.open=not door.open;door.busy=true;door.body.collision_layer=0
 var tween=create_tween();tween.set_pause_mode(Tween.TWEEN_PAUSE_STOP);door.tween=tween
 tween.tween_property(door.pivot,"position",door.open_position if door.open else door.closed_position,.4)
 tween.tween_callback(func():door.busy=false;door.body.collision_layer=0 if door.open else 3;door.erase("tween"))
 AudioDirector.sound("door",to_interior_world(door.point))
func current_room()->String:
 var p=to_interior_local(main.hotaru.global_position)
 if STAIR.has_point(Vector2(p.x,p.z)):return "主楼楼梯"
 for data in rooms:
  if data.floor==floor_index and data.rect.has_point(Vector2(p.x,p.z)):return data.name
 return "主楼走廊" if p.z<7.3 else "附楼走廊"
func update_hud():
 if not active:
  main.vehicle_button.hide();main.upgrade_button.hide()
  main.interact_button.visible=near_gate() or near_entrance() or main.trolley.nearby()
  main.interact_button.text=("离开园区" if in_campus else "推开院门") if near_gate() else ("进入医院" if near_entrance() else "推车 E")
  main.attack_button.visible=main.controls_enabled and not main.trolley.pushing
  main.speed_label.text="医院 · 庭院"
  main.objective_label.text="医院园区 · 沿道路前往主楼正门"
  main.hint_label.text="院门 · E / 交互返回街道" if near_gate() else ("主楼正门 · E / 交互进入" if near_entrance() else "沿院内道路前往正门 · 右键 / 右侧拖动视角")
  return
 main.vehicle_button.hide();main.upgrade_button.hide()
 main.attack_button.visible=main.controls_enabled and not main.hotaru.dead and not main.trolley.pushing
 var door=focused_door()
 main.interact_button.visible=near_exit() or not door.is_empty() or main.trolley.nearby()
 main.interact_button.text="离开医院" if near_exit() else (("关门" if door.get("open",false) else "开门")+" E" if not door.is_empty() else "推车 E")
 main.speed_label.text="医院 · %dF"%(floor_index+1)
 main.objective_label.text="医院 · %dF · %s"%[floor_index+1,current_room()]
 main.hint_label.text="正门：E / 交互返回庭院" if near_exit() else (str(door.name)+" · E / 交互开关门" if not door.is_empty() else "沿走廊探索 · 右键 / 右侧拖动视角")
func update_camera(delta):
 camera_rig.update(self,delta)
func _unhandled_input(event):
 if not (active or in_campus) or get_tree().paused or not main.controls_enabled:return
 if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT:dragging=event.pressed;get_viewport().set_input_as_handled()
 elif event is InputEventMouseMotion and dragging:camera_rig.manual_input();yaw-=event.relative.x*.004;pitch=clampf(pitch+event.relative.y*.004,-.30,.55);get_viewport().set_input_as_handled()
 elif event is InputEventScreenTouch:
  if event.index==aim_finger and not event.pressed:aim_finger=-1
  elif event.pressed and event.position.x>350 and event.position.y>290 and event.position.y<970 and aim_finger<0:aim_finger=event.index
 elif event is InputEventScreenDrag and event.index==aim_finger:camera_rig.manual_input();yaw-=event.relative.x*.004;pitch=clampf(pitch+event.relative.y*.004,-.30,.55);get_viewport().set_input_as_handled()


func _build_campus():
 var campus=Node3D.new();campus.name="HospitalCampus";main.world_root.add_child(campus)
 # Eastern entrance faces the street, with a direct path into the existing courtyard.
 for segment in [[Vector3(6,0,208),Vector3(69,0,208)],[Vector3(6,0,292),Vector3(69,0,292)],[Vector3(6,0,208),Vector3(6,0,292)],[Vector3(69,0,208),Vector3(69,0,257.2)],[Vector3(69,0,262.8),Vector3(69,0,292)]]:
  var a: Vector3=segment[0];var b: Vector3=segment[1];var length=a.distance_to(b);var count=int(ceil(length/4.0))
  for i in range(count):
   var panel=load("res://assets/hospital/campus_wall.glb").instantiate();campus.add_child(panel)
   panel.position=a.lerp(b,(i+.5)/count)+Vector3(0,.08,0)
   panel.rotation.y=-atan2(b.z-a.z,b.x-a.x);panel.scale.x=length/count/4.0091
  _solid(campus,Vector3(length,2.15,.48) if absf(a.x-b.x)>1 else Vector3(.48,2.15,length),(a+b)/2+Vector3(0,1.15,0))
 gate_root=Node3D.new();gate_root.name="HospitalStreetGate";campus.add_child(gate_root);gate_root.position=GATE;gate_root.rotation.y=PI/2
 gate_root.add_child(load("res://assets/hospital/campus_gate_posts.glb").instantiate())
 for side in [-1,1]:
  var hinge=Node3D.new();gate_root.add_child(hinge);hinge.position.x=side*2.1
  hinge.add_child(load("res://assets/hospital/campus_gate_%s.glb"%("left" if side<0 else "right")).instantiate());gate_leaves.append(hinge)
  _solid(gate_root,Vector3(.8,3.7,.8),Vector3(side*2.4,1.85,0))
 gate_block=_solid(gate_root,Vector3(4.2,3.2,.22),Vector3(0,1.6,0))
 _sign(gate_root,"区立医院 · 院门",Vector3(0,3.9,0),0,30)

func near_gate()->bool:
 return not gate_busy and not active and _entry_lock<=0 and main.controls_enabled and not main.in_vehicle and not main.inside_rv and not main.inside_store and not main.factory.active and not main.temple.active and main.phase not in [main.Phase.TITLE,main.Phase.GAME_OVER,main.Phase.COMPLETE] and main.trolley.near_door(GATE+Vector3(0,.87,0),3.2)

func use_gate():
 if not near_gate():return
 gate_busy=true;main.mobile_joystick.reset();main.hotaru.set_active(false)
 var entering=not in_campus
 var pushing=main.trolley.pushing
 main.trolley.release()
 gate_block.collision_layer=0
 AudioDirector.sound("door",GATE)
 var tween=create_tween();gate_tween=tween;tween.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
 tween.tween_property(gate_leaves[0],"rotation:y",-PI*.48,.4)
 tween.parallel().tween_property(gate_leaves[1],"rotation:y",PI*.48,.4)
 tween.tween_callback(func():
  in_campus=entering;yaw=-PI/2 if entering else PI/2;pitch=.05
  main.hotaru.rotation.y=yaw
  main.hotaru.play_boarding_step()
  if entering:
   campus_labels=[]
   for label in main.hotaru.find_children("*","Label3D",true,false):
    if label.visible:campus_labels.append(label);label.hide()
 )
 tween.tween_property(main.hotaru,"global_position",GATE+Vector3(-2.4 if entering else 2.4,.87,0),.65)
 tween.tween_callback(func():
  if pushing:
   GameState.cart_position=GATE+Vector3(-3.5 if entering else 3.5,0,0);GameState.cart_yaw=yaw
  main.hotaru.cancel_boarding_step();main.hotaru.set_active(true);_entry_lock=.7
  if pushing:main.trolley.interact()
  if not in_campus:
   _restore_campus_labels()
   camera_rig.restore_character()
   for mesh in main.hotaru._body_meshes:mesh.transparency=0
   main.hotaru._visual_root.show();main.camera.environment=null;main.camera.near=.15
  main._update_camera(100)
 )
 tween.tween_property(gate_leaves[0],"rotation:y",0,.4)
 tween.parallel().tween_property(gate_leaves[1],"rotation:y",0,.4)
 tween.tween_callback(func():gate_block.collision_layer=3;gate_busy=false)

func _exit_door():
 # A clearly visible double exit door on the foyer's courtyard-facing wall.
 var parent=levels[0]
 for x in [-.57,.57]:
  _box(parent,Vector3(1.1,2.35,.12),Vector3(x,1.175,-4.64),Color("4f7779"))
  _box(parent,Vector3(.78,1.15,.025),Vector3(x,1.55,-4.72),Color("86adb1"))
  _box(parent,Vector3(.36,.055,.055),Vector3(x,.95,-4.76),Color("b7b7a6"))
 for x in [-1.2,1.2]:_box(parent,Vector3(.10,2.5,.2),Vector3(x,1.25,-4.68),PALETTE.trim)
 _box(parent,Vector3(2.5,.12,.2),Vector3(0,2.47,-4.68),PALETTE.trim)
 _sign(parent,"出口 EXIT · 返回庭院",Vector3(0,2.8,-4.8),PI,26)

func _restore_campus_labels():
 for label in campus_labels:
  if is_instance_valid(label):label.show()
 campus_labels.clear()

func _rail(parent: Node,a: Vector3,b: Vector3):
 var rail=_box(parent,Vector3(.075,.075,a.distance_to(b)),(a+b)/2,Color("43595a"))
 rail.look_at(parent.to_global(b),Vector3.UP)

func _office(parent: Node,r: Rect2):
 # Complete desks and chairs, with a clear entrance and no clipped source fragments.
 for z in [r.position.y+1.1,r.end.y-1.1]:
  var x=r.position.x+1.0
  _box(parent,Vector3(1.45,.09,.70),Vector3(x,.76,z),Color("9b9178"),true)
  for dx in [-.62,.62]:
   for dz in [-.26,.26]:_box(parent,Vector3(.06,.72,.06),Vector3(x+dx,.36,z+dz),Color("43595a"))
  _box(parent,Vector3(.55,.36,.055),Vector3(x,1.04,z-.12),Color("293d46"))
  _box(parent,Vector3(.07,.17,.07),Vector3(x,.87,z-.12),Color("43595a"))
  _box(parent,Vector3(.43,.025,.15),Vector3(x,.825,z+.16),Color("536366"))
  var chair=Vector3(x+.25,0,z+.70 if z<r.get_center().y else z-.70)
  _box(parent,Vector3(.5,.12,.5),chair+Vector3(0,.46,0),Color("365f70"),true)
  _box(parent,Vector3(.5,.57,.09),chair+Vector3(0,.79,.23 if z<r.get_center().y else -.23),Color("365f70"),true)
  _box(parent,Vector3(.10,.4,.10),chair+Vector3(0,.2,0),Color("43595a"))

func _reception(level: Node):
 var parent=Node3D.new();parent.position=Vector3(0,0,-14.7);parent.scale=Vector3(.5,1,.5);level.add_child(parent)
 # Counter faces the front entrance (+Z); staff access is behind, on the north side.
 _box(parent,Vector3(2.2,1.04,.62),Vector3(0,.52,0),Color("8e8973"),true)
 _box(parent,Vector3(2.3,.075,.74),Vector3(0,1.08,0),Color("526e70"))
 _box(parent,Vector3(1.95,.12,.025),Vector3(0,.78,.325),PALETTE.accent)
 _box(parent,Vector3(.48,.31,.055),Vector3(-.45,1.30,-.08),Color("2b4149"))
 _box(parent,Vector3(.06,.15,.06),Vector3(-.45,1.15,-.08),Color("43595a"))
 _box(parent,Vector3(.4,.025,.15),Vector3(-.45,1.13,-.25),Color("536366"))

func _exterior_entry():
 # Replace the baked low-resolution doorway with metre-sized close-view geometry.
 var frame=Node3D.new();frame.name="HospitalDetailedEntrance";exterior.add_child(frame)
 frame.position=Vector3(3,0,-3.8)
 _box(frame,Vector3(3.0,2.85,.12),Vector3(0,1.425,0),Color("52605f"))
 for x in [-.64,.64]:
  _box(frame,Vector3(1.23,2.56,.10),Vector3(x,1.28,.09),Color("687f83"))
  _box(frame,Vector3(1.03,1.85,.025),Vector3(x,1.54,.155),Color("263f4c"))
  _box(frame,Vector3(.045,.48,.10),Vector3(x*.32,1.17,.20),Color("b8bdb8"))
  _box(frame,Vector3(1.21,.07,.13),Vector3(x,.58,.16),Color("b8bdb8"))
 for x in [-1.35,0,1.35]:_box(frame,Vector3(.075,2.72,.19),Vector3(x,1.36,.10),Color("bac1b9"))
 _box(frame,Vector3(2.8,.09,.22),Vector3(0,2.73,.10),Color("bac1b9"))
 _box(frame,Vector3(3.25,.13,1.15),Vector3(0,2.95,.32),Color("526e70"))

func _camera_box(parent: Node,size: Vector3,point: Vector3,color: Color):
 _box(parent,size,point,color)
 var body=_solid(parent,size,point);body.collision_layer=8

func to_interior_world(point: Vector3)->Vector3:
 return ORIGIN+point*SPACE_SCALE
func to_interior_local(point: Vector3)->Vector3:
 return (point-ORIGIN)/SPACE_SCALE
