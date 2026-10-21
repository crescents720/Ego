extends Node3D
# Fixed seed gives a reproducible, road-safe landscape. Meshes are shared per 40 m tile.
var placements: Array[Dictionary]=[]
var batches: Array[MultiMeshInstance3D]=[]
var town
var rng:=RandomNumberGenerator.new()
var models: Dictionary={}
var groups: Dictionary={}
var _wind: Shader

func build(layout) -> void:
 town=layout
 name="TownVegetation"
 rng.seed=20261017
 _wind=Shader.new()
 _wind.code="""shader_type spatial;
render_mode cull_disabled;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float sway = 0.035;
void vertex(){vec3 p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;float w=sin(TIME*1.15+p.x*0.37+p.z*0.29);VERTEX.x+=w*sway*smoothstep(0.15,1.4,VERTEX.y);}
void fragment(){vec4 c=texture(albedo_tex,UV)*tint;ALBEDO=c.rgb;ROUGHNESS=0.95;ALPHA=c.a;ALPHA_SCISSOR_THRESHOLD=0.25;}
"""
 for id in ["tree1","tree2","tree3","leaf1","leaf2","leaf3","grass","reeds","grove"]:
  var scene: Node3D=load("res://assets/environment/vegetation/"+id+".glb").instantiate()
  models[id]=[]
  for part in scene.find_children("*","MeshInstance3D",true,false):
   var mesh: Mesh=part.mesh.duplicate()
   for surface in range(mesh.get_surface_count()):
    var original: StandardMaterial3D=mesh.surface_get_material(surface)
    var material:=ShaderMaterial.new()
    material.shader=_wind
    material.set_shader_parameter("albedo_tex",original.albedo_texture)
    material.set_shader_parameter("tint",original.albedo_color*Color(0.86,0.92,0.82,1))
    material.set_shader_parameter("sway",0.035 if id.begins_with("tree") or id=="grove" else 0.055)
    mesh.surface_set_material(surface,material)
   models[id].append({"mesh":mesh,"transform":part.transform})
  scene.free()
 # Small residential gardens and empty block interiors, rather than filling parking pads.
 for z in range(-145,351,6):
  for x in range(-150,177,6):
   var p:=Vector2(x+rng.randf_range(-2.5,2.5),z+rng.randf_range(-2.5,2.5))
   if not clear(p,2.6):continue
   var border: bool=x< -132 or x>155 or z< -113 or z>313
   if rng.randf()<(0.7 if border else 0.52):
    _place(("tree" if rng.randf()<0.16 else "leaf")+str(rng.randi_range(1,3)),p,rng.randf_range(0.78,1.12))
    for k in range(2):
     var g:=p+Vector2(rng.randf_range(-2,2),rng.randf_range(-2,2))
     if clear(g,1.8):_place("grass",g,rng.randf_range(0.6,1.05))
   elif rng.randf()<0.48:_place("grass",p,rng.randf_range(0.7,1.15))
 # Low grass can cover the home lawn, but never the actual house or paved escape lane.
 for z in range(-158,360,4):
  for x in range(-155,181,4):
   var p:=Vector2(x+rng.randf_range(-0.7,0.7),z+rng.randf_range(-0.7,0.7))
   if clear_grass(p) and rng.randf()<0.88:_place("grass",p,rng.randf_range(0.85,1.3))
 # Shore reeds follow the actual dry polygon edge, keeping the promenade and sites clear.
 for i in range(town.LAKE.size()):
  var a: Vector2=town.LAKE[i]
  var b: Vector2=town.LAKE[(i+1)%town.LAKE.size()]
  for step in range(int(a.distance_to(b)/4.0)):
   var p:=a.lerp(b,float(step)/maxf(1,a.distance_to(b)/4.0))
   var outward: Vector2=(p-Vector2(250,140)).normalized()
   p+=outward*2.8
   if clear(p,1.8):_place("reeds",p,rng.randf_range(0.85,1.2))
 # The supplied animated-tree pack is a wider grove: reserve it for town fringes.
 for p in [Vector2(-154,-146),Vector2(-151,342),Vector2(133,343)]:
  if clear(p,7):_place("grove",p,0.85)
 _flush()

func clear(p: Vector2,radius: float) -> bool:
 if not Rect2(-164,-164,470,565).has_point(p):return false
 if Geometry2D.is_point_in_polygon(p,PackedVector2Array(town.LAKE)):return false
 for i in range(town.LAKE.size()):
  if p.distance_to(Geometry2D.get_closest_point_to_segment(p,town.LAKE[i],town.LAKE[(i+1)%town.LAKE.size()]))<radius:return false
 if Rect2(163,-34,6,330).grow(radius).has_point(p):return false
 for road in town.roads:
  if p.distance_to(Geometry2D.get_closest_point_to_segment(p,road.a,road.b))<road.width*0.5+1.8+radius:return false
 for site in town.SITES:
  if site.rect.grow(radius+1.0).has_point(p):return false
 for area in [Rect2(-36,-59,42,40),Rect2(3,36,24,32)]:
  if area.grow(radius).has_point(p):return false
 for lot in town.lots:
  var box: AABB=lot.bounds
  if Rect2(Vector2(box.position.x,box.position.z),Vector2(box.size.x,box.size.z)).grow(radius+0.6).has_point(p):return false
 return true

func clear_grass(p: Vector2) -> bool:
 if Rect2(-36,-59,42,40).has_point(p):
  for road in town.roads:
   if p.distance_to(Geometry2D.get_closest_point_to_segment(p,road.a,road.b))<road.width*0.5+3.05:return false
  for region in [Rect2(-15.3,-48.6,8.6,11.2),Rect2(-26.5,-51,10,16),Rect2(-26,-35,28,5),Rect2(-8,-43,3.5,10),Rect2(-26,-43,4,11)]:
   if region.grow(0.6).has_point(p):return false
  return true
 return clear(p,1.25)

func _place(id: String,p: Vector2,scale_value: float) -> void:
 var key:=id+"_%d_%d"%[floori(p.x/40),floori(p.y/40)]
 if not groups.has(key):groups[key]={"id":id,"points":[]}
 var transform:=Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*scale_value),Vector3(p.x,0.06,p.y))
 groups[key].points.append(transform)
 placements.append({"id":id,"position":p,"scale":scale_value})

func _flush() -> void:
 for key in groups:
  var group: Dictionary=groups[key]
  var center:=Vector3.ZERO
  for transform in group.points:center+=transform.origin
  center/=group.points.size()
  for part in models[group.id]:
   var multi:=MultiMesh.new()
   multi.transform_format=MultiMesh.TRANSFORM_3D
   multi.mesh=part.mesh
   multi.instance_count=group.points.size()
   for i in range(multi.instance_count):
    var local: Transform3D=group.points[i]*part.transform
    local.origin-=center
    multi.set_instance_transform(i,local)
   var batch:=MultiMeshInstance3D.new()
   batch.name=key
   batch.multimesh=multi
   batch.position=center
   batch.visibility_range_end=65 if group.id in ["grass","reeds"] else 130
   batch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if group.id in ["grass","reeds"] else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
   add_child(batch)
   batches.append(batch)

func set_overview(enabled: bool) -> void:
 for batch in batches:
  batch.visibility_range_end=0 if enabled else (65 if batch.name.begins_with("grass") or batch.name.begins_with("reeds") else 130)
