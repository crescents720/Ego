extends Node3D

# +Z is map north. Existing home/store coordinates remain the starter street.
const DRIVE_BOUNDS := Rect2(-165, -223, 480, 638)
const MODELS := ["Filler_Housing", "group84", "LM_Laundrette", "LM_PawnShop1", "LM_Liquor"]
const ROOT := "res://assets/third_party/ccity/"
const SITES := [
	{"name":"五金店", "rect":Rect2(-112,130,42,48)},
	{"name":"工厂", "rect":Rect2(-112,218,92,64)},
	{"name":"医院", "rect":Rect2(12,218,50,64)},
	{"name":"警察局", "rect":Rect2(88,222,48,60)},
	{"name":"武器店", "rect":Rect2(88,130,48,48)},
	{"name":"加油站", "rect":Rect2(12,-158,62,49)},
	{"name":"湖畔取水点", "rect":Rect2(174,291,32,22)},
	{"name":"垂钓码头", "rect":Rect2(170,60,22,24)},
	{"name":"湖畔营地", "rect":Rect2(174,-58,45,40)},
	{"name":"汽车修理厂", "rect":Rect2(88,-148,35,30)},
	{"name":"集装箱码头", "rect":Rect2(-155,-225,310,58)},
	{"name":"寺庙", "rect":Rect2(-112,320,36,45)},
]
const LAKE := [Vector2(207,-2),Vector2(195,42),Vector2(202,90),Vector2(185,132),Vector2(194,183),Vector2(211,222),Vector2(216,272),Vector2(262,305),Vector2(307,267),Vector2(312,190),Vector2(302,110),Vector2(310,42),Vector2(277,-12),Vector2(235,-27)]
var main
var roads: Array[Dictionary] = []
var lots: Array[Dictionary] = []
var site_labels: Array[Label3D] = []
var _meshes: Array[GeometryInstance3D] = []
var _materials: Dictionary = {}
var _building_shapes: Dictionary = {}

func build(owner_main: Node3D) -> void:
	main=owner_main
	name="TownFramework"
	var ground:=_box("TownGround",Vector3(500,0.22,650),Vector3(70,-0.16,95),"52614b",true)
	var grass_shader:=Shader.new()
	grass_shader.code="""shader_type spatial;
varying vec3 world;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void fragment(){vec2 p=world.xz;float wide=hash(floor(p*0.25));float fine=hash(floor(p*32.0));float blade=step(0.90,fine);ALBEDO=mix(vec3(0.22,0.29,0.16),vec3(0.36,0.43,0.25),wide*0.65+fine*0.15)+blade*vec3(0.035,0.055,0.015);ROUGHNESS=1.0;}"""
	var turf:=ShaderMaterial.new()
	turf.shader=grass_shader
	ground.material_override=turf
	# Main rectangular loop, starter street, two connectors and residential lane.
	for x in [-120.0,0.0,75.0,150.0]:
		_road(Vector2(x,-100),Vector2(x,300),10.0)
	for z in [-100.0,0.0,100.0,200.0,300.0]:
		_road(Vector2(-120,z),Vector2(150,z),10.0)
	_road(Vector2(-60,-100),Vector2(-60,200),7.0)
	_road(Vector2(0,-216),Vector2(0,-100),10.0)
	_road(Vector2(-145,-180),Vector2(145,-180),12.0)
	_road(Vector2(0,300),Vector2(0,390),10.0)
	# Dry access lanes to reserved shore sites; stop before the water.
	for z in [-45.0,72.0,302.0]:
		_road(Vector2(150,z),Vector2(190,z),7.0)
	_road(Vector2(105,-100),Vector2(105,-118),7.0)
	_road(Vector2(45.7,-100),Vector2(45.7,-148),7.0)
	_road(Vector2(-94,300),Vector2(-94,328),7.0)
	_lake()
	for site in SITES:
		if site.name not in ["汽车修理厂","加油站","武器店","工厂","寺庙","集装箱码头"]:_reserved_site(site)
	_populate()
	_trees()
	for x in [-177.0,317.0]:
		_box("MapEdge",Vector3(1,8,650),Vector3(x,3,95),"52614b",true).visible=false
	for z in [-228.0,417.0]:
		_box("MapEdge",Vector3(500,8,1),Vector3(70,3,z),"52614b",true).visible=false
	main._add_label("北向公路 · 后续区域",Vector3(0,3,368),Color("fff0b1"),30)
	# End of the currently built roads, rather than barriers on the starter street.
	_box("NorthRoadEnd",Vector3(12,0.8,0.7),Vector3(0,0.4,390),"b89b62",true)
	_box("SouthRoadEnd",Vector3(12,0.8,0.7),Vector3(0,0.4,-223),"b89b62",true)

func _material(hex: String) -> StandardMaterial3D:
	if not _materials.has(hex):
		var material:=StandardMaterial3D.new()
		material.albedo_color=Color(hex)
		material.roughness=0.95
		_materials[hex]=material
	return _materials[hex]

func _box(title: String,size: Vector3,point: Vector3,color: String,solid: bool=false) -> MeshInstance3D:
	var mesh:=MeshInstance3D.new()
	mesh.name=title
	var box:=BoxMesh.new()
	box.size=size
	mesh.mesh=box
	mesh.material_override=_material(color)
	mesh.position=point
	add_child(mesh)
	if solid:
		var body:=StaticBody3D.new()
		body.collision_layer=3
		body.collision_mask=0
		var shape:=CollisionShape3D.new()
		var box_shape:=BoxShape3D.new()
		box_shape.size=size
		shape.shape=box_shape
		body.add_child(shape)
		mesh.add_child(body)
	return mesh

func _road(a: Vector2,b: Vector2,width: float) -> void:
	var middle: Vector2=(a+b)/2
	var along_z: bool=is_equal_approx(a.x,b.x)
	var length: float=a.distance_to(b)
	var dimensions:=Vector3(width,0.035,length) if along_z else Vector3(length,0.035,width)
	_box("Sidewalk",dimensions+Vector3(3.6,0,3.6),Vector3(middle.x,0.008,middle.y),"91938a")
	_box("Road",dimensions,Vector3(middle.x,0.045,middle.y),"41474a")
	roads.append({"a":a,"b":b,"width":width})
	for d in range(5,int(length)-4,9):
		var point: Vector2=a.direction_to(b)*d+a
		var at_crossing:=false
		if along_z:
			for z in [-100.0,0.0,100.0,200.0,300.0]:
				if absf(point.y-z)<8: at_crossing=true
		else:
			for x in [-120.0,-60.0,0.0,75.0,150.0]:
				if absf(point.x-x)<8: at_crossing=true
		if not at_crossing:
			_box("LaneDash",Vector3(0.14,0.012,3.0) if along_z else Vector3(3.0,0.012,0.14),Vector3(point.x,0.069,point.y),"c8bf93")

func _reserved_site(site: Dictionary) -> void:
	var rect: Rect2=site.rect
	var center:=rect.get_center()
	_box("Reserved_"+site.name,Vector3(rect.size.x,0.025,rect.size.y),Vector3(center.x,0.014,center.y),"657363")
	# Ground-level corner markers only: no fake building, collider or interaction.
	for point in [rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)]:
		_box("PlotCorner",Vector3(1.8,0.04,1.8),Vector3(point.x,0.04,point.y),"b7ac83")
	var label: Label3D=main._add_label(site.name+" · 场地预留",Vector3(center.x,0.5,center.y),Color("e6d9af"),28)
	label.no_depth_test=false
	site_labels.append(label)

func _populate() -> void:
	var scenes: Array[PackedScene]=[]
	for title in MODELS: scenes.append(load(ROOT+title+".glb"))
	# Continuous street frontage: roughly 1–3 m gaps, rather than isolated
	# buildings in the middle of large grass plots. Keep all roads unchanged.
	for road_x in [-120.0,-60.0,0.0,75.0,150.0]:
		for side in [-1.0,1.0]:
			if road_x==150.0 and side>0:continue # Promenade and tree belt.
			var setback:=11.0 if road_x==-60.0 else 12.5
			for step in range(33):
				var z: float=-84.0+step*11.5
				if road_x==-60.0 and z>184:continue
				_place_frontage(Vector2(road_x+side*setback,z),-side*PI/2,scenes)
	for road_z in [-100.0,0.0,100.0,200.0,300.0]:
		for side in [-1.0,1.0]:
			for step in range(22):
				_place_frontage(Vector2(-104.0+step*11.5,road_z+side*12.5),PI if side>0 else 0.0,scenes)

	# Back-to-back homes fill the block interiors while preserving every access road.
	for x in [-90.0,-30.0,25.0,37.5,50.0,100.0,112.5,125.0]:
		for z in range(-78,289,15):
			_place_frontage(Vector2(x,z),PI/2,scenes)

func _place_frontage(point: Vector2,yaw: float,scenes: Array[PackedScene]) -> void:
	var model_index: int=absi(int(point.x*7+point.y*3))%MODELS.size()
	var sizes: Array[Vector2]=[Vector2(7.85,7.89),Vector2(8.69,9.71),Vector2(10.18,10.18),Vector2(8.48,8.72),Vector2(8.01,8.81)]
	var size2: Vector2=sizes[model_index]
	if absf(sin(yaw))>0.5:size2=Vector2(size2.y,size2.x)
	var footprint:=Rect2(point-size2/2,size2)
	for site in SITES:
		if footprint.intersects(site.rect.grow(2)):return
	# These include both doors and the entire prologue/backyard driving route.
	for protected in [Rect2(-36,-59,42,40),Rect2(3,36,24,32)]:
		if footprint.intersects(protected):return
	for road in roads:
		var width: float=road.width+4.4
		var minimum: Vector2=road.a.min(road.b)-Vector2.ONE*width/2
		var maximum: Vector2=road.a.max(road.b)+Vector2.ONE*width/2
		if footprint.intersects(Rect2(minimum,maximum-minimum)):return
	for lot in lots:
		var bb: AABB=lot.bounds
		var occupied:=Rect2(Vector2(bb.position.x,bb.position.z),Vector2(bb.size.x,bb.size.z))
		if footprint.grow(0.55).intersects(occupied.grow(0.55)):return
	var building: Node3D=scenes[model_index].instantiate()
	building.name="StreetBuilding_%03d"%lots.size()
	building.position=Vector3(point.x,0.07,point.y)
	building.rotation.y=yaw
	add_child(building)
	var bounds:=AABB()
	var first:=true
	for mesh in building.find_children("*","MeshInstance3D",true,false):
		var bb: AABB=mesh.global_transform*mesh.get_aabb()
		bounds=bb if first else bounds.merge(bb)
		first=false
		mesh.visibility_range_end=145
		_meshes.append(mesh)
	_add_building_collision(building,MODELS[model_index])
	main.town_occlusion.register_building(building)
	var pad_size:=Vector3(13,0.02,11.5) if absf(sin(yaw))>0.5 else Vector3(11.5,0.02,13)
	_box("FrontagePlot",pad_size,Vector3(point.x,-0.005,point.y),"697260")
	lots.append({"position":point,"bounds":bounds,"model":MODELS[model_index]})

func _add_building_collision(building: Node3D,model_name: String) -> void:
	if not _building_shapes.has(model_name):
		var faces:=PackedVector3Array()
		for mesh in building.find_children("*","MeshInstance3D",true,false):
			var local_transform: Transform3D=building.global_transform.affine_inverse()*mesh.global_transform
			for surface in range(mesh.mesh.get_surface_count()):
				var arrays: Array=mesh.mesh.surface_get_arrays(surface)
				var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
				var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
				var count: int=indices.size() if not indices.is_empty() else vertices.size()
				for offset in range(0,count,3):
					var a: Vector3=local_transform*vertices[indices[offset] if not indices.is_empty() else offset]
					var b: Vector3=local_transform*vertices[indices[offset+1] if not indices.is_empty() else offset+1]
					var c: Vector3=local_transform*vertices[indices[offset+2] if not indices.is_empty() else offset+2]
					# Parking aprons and tiny curbs are walkable, not solid cubes.
					if maxf(a.y,maxf(b.y,c.y))<0.35:continue
					faces.append_array(PackedVector3Array([a,b,c]))
		var shape:=ConcavePolygonShape3D.new()
		shape.backface_collision=true
		shape.set_faces(faces)
		_building_shapes[model_name]=shape
	var body:=StaticBody3D.new()
	body.name="BuildingWalls"
	body.collision_layer=3
	body.collision_mask=0
	var collision:=CollisionShape3D.new()
	collision.shape=_building_shapes[model_name]
	body.add_child(collision)
	building.add_child(body)

func _lake() -> void:
	var polygon:=PackedVector2Array(LAKE)
	var triangles:=Geometry2D.triangulate_polygon(polygon)
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in triangles:
		surface.set_normal(Vector3.UP)
		surface.add_vertex(Vector3(polygon[index].x,0.075,polygon[index].y))
	var water:=MeshInstance3D.new()
	water.name="LakeWater"
	water.mesh=surface.commit()
	var material:=_material("377d88").duplicate()
	material.cull_mode=BaseMaterial3D.CULL_DISABLED
	material.roughness=0.28
	water.material_override=material
	add_child(water)
	var shore:=StaticBody3D.new()
	shore.name="LakeShoreBoundary"
	shore.collision_layer=3
	shore.collision_mask=0
	var shape:=CollisionShape3D.new()
	var convex:=ConvexPolygonShape3D.new()
	var points:=PackedVector3Array()
	for point in polygon:
		points.append(Vector3(point.x,-1,point.y))
		points.append(Vector3(point.x,4,point.y))
	convex.points=points
	shape.shape=convex
	shore.add_child(shape)
	add_child(shore)
	# Continuous dry promenade, separate from the vehicle loop.
	for z in range(-30,292,8):
		_box("LakePath",Vector3(3.0,0.025,8.0),Vector3(166,0.04,z),"a59e7d")
	var label: Label3D=main._add_label("湖泊 · 水源与垂钓区域预留",Vector3(249,0.7,145),Color("c8edf1"),32)
	label.no_depth_test=false

var vegetation: Node3D

func _trees() -> void:
	vegetation=load("res://scripts/environment/town_vegetation.gd").new()
	add_child(vegetation)
	vegetation.build(self)

func set_overview(enabled: bool) -> void:
	if is_instance_valid(vegetation):vegetation.set_overview(enabled)
	for mesh in _meshes:
		mesh.visibility_range_end=0 if enabled else 145

func is_road(point: Vector2) -> bool:
	for road in roads:
		if point.distance_to(Geometry2D.get_closest_point_to_segment(point,road.a,road.b))<=road.width*0.5:
			return true
	return false
