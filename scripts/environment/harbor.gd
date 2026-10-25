extends Node

# Playable harbor: drive the mobile crane, hoist marked cargo, then turn a
# 20-foot container into the RV's first explorable upper floor.
const CRANE_START := Vector3(-122.0, 0.12, -216.0)
const CRANE_TRAVEL := Rect2(-145.0, -224.5, 270.0, 20.0)
const SPREADER_Z := 27.23
const SPREADER_BOTTOM := 8.72
const HOIST_MIN := -6.0
const HOIST_MAX := 0.0
const ROOF_BOTTOM_LOCAL_Y := 1.78
const CRANE_SPEED := 5.2
const RV_LIFT_BAY := Vector3(-45.0, 0.14, -186.0)
# Exterior RV hull is 6.375 x 2.175 after MODEL_SCALE; cabin is 9.5 x 2.68.
# Apply the same longitudinal/lateral presentation ratios to the container.
const ROOF_INTERIOR_ORIGIN := Vector3(1000.0, 2.8, -1.027)
const ROOF_HALF_LENGTH := (6.06-0.16)*9.5/6.375/2.0
const ROOF_HALF_WIDTH := (2.30-0.16)*2.68/2.175/2.0
const RV_LADDER_ANCHOR := Vector3(-0.85, 1.13, -4.55)
const ROOF_HATCH_ANCHOR := Vector3(-0.85, 0.95, -3.523)

var main
var active := false
var touch_move := Vector2.ZERO
var crane: CharacterBody3D
var spreader: Node3D
var port_root: Node3D
var cable_root: Node3D
var cab_label: Label3D
var cargoes: Array[Dictionary] = []
var held: Dictionary = {}
var hoist_offset := -2.65
var speed := 0.0
var cab_transitioning := false
var _cab_tween: Tween
var _raise_held := false
var _lower_held := false
var _notice := ""
var _notice_time := 0.0
var controls: Control
var grab_button: Button
var raise_button: Button
var lower_button: Button
var exit_button: Button
var fix_button: Button
var roof_support: Node3D
var rv_ladder: Node3D
var roof_interior: Node3D
var roof_interior_active := false
var roof_transitioning := false
var _floor_blend := 0.0
var _floor_tween: Tween
var _roof_walls: Dictionary = {}
var _roof_ceiling: MeshInstance3D
var _ladder_label: Label3D
var _ladder_material: StandardMaterial3D

var _cargo_specs := [
	{"id":"C20-A", "model":"container_20_old", "length":6.06, "height":2.766, "position":Vector3(-134,0.16,-188)},
	{"id":"C20-B", "model":"container_20_blue", "length":6.06, "height":2.766, "position":Vector3(-126.7,0.16,-188)},
	{"id":"C20-C", "model":"container_20_red", "length":6.06, "height":2.766, "position":Vector3(-119.4,0.16,-188)},
	{"id":"C20-D", "model":"container_20_green", "length":6.06, "height":2.766, "position":Vector3(-112.1,0.16,-188)},
	{"id":"C20-E", "model":"container_20_yellow", "length":6.06, "height":2.766, "position":Vector3(-104.8,0.16,-188)},
	{"id":"C20-F", "model":"container_20_red", "length":6.06, "height":2.766, "position":Vector3(-97.5,0.16,-188)},
	{"id":"C20-G", "model":"container_20_blue", "length":6.06, "height":2.766, "position":Vector3(-90.2,0.16,-188)},
	{"id":"C20-H", "model":"container_20_old", "length":6.06, "height":2.766, "position":Vector3(-82.9,0.16,-188)},
	{"id":"C20-I", "model":"container_20_green", "length":6.06, "height":2.766, "position":Vector3(-75.6,0.16,-188)},
	{"id":"C20-J", "model":"container_20_yellow", "length":6.06, "height":2.766, "position":Vector3(-68.3,0.16,-188)},
	{"id":"C20-K", "model":"container_20_blue", "length":6.06, "height":2.766, "position":Vector3(-134,0.16,-196)},
	{"id":"C20-L", "model":"container_20_red", "length":6.06, "height":2.766, "position":Vector3(-126.7,0.16,-196)},
	{"id":"C20-M", "model":"container_20_green", "length":6.06, "height":2.766, "position":Vector3(-119.4,0.16,-196)},
	{"id":"C20-N", "model":"container_20_yellow", "length":6.06, "height":2.766, "position":Vector3(-112.1,0.16,-196)},
	{"id":"C20-O", "model":"container_20_old", "length":6.06, "height":2.766, "position":Vector3(-126.7,2.926,-196)},
	{"id":"C20-P", "model":"container_20_blue", "length":6.06, "height":2.766, "position":Vector3(-112.1,2.926,-196)},
	{"id":"C20-Q", "model":"container_20_red", "length":6.06, "height":2.766, "position":Vector3(-27.0,0.16,-188)},
	{"id":"C20-R", "model":"container_20_green", "length":6.06, "height":2.766, "position":Vector3(-19.7,0.16,-188)},
	{"id":"C20-S", "model":"container_20_yellow", "length":6.06, "height":2.766, "position":Vector3(-12.4,0.16,-188)},
	{"id":"C20-T", "model":"container_20_old", "length":6.06, "height":2.766, "position":Vector3(-19.7,2.926,-188)},
	{"id":"C40-A", "model":"container_40_blue", "length":12.19, "height":2.954, "position":Vector3(-91.0,0.16,-197)},
	{"id":"C40-B", "model":"container_40_red", "length":12.19, "height":2.954, "position":Vector3(-75.5,0.16,-197)},
	{"id":"C40-C", "model":"container_40_white", "length":12.19, "height":2.954, "position":Vector3(-60.0,0.16,-197)},
	{"id":"C40-D", "model":"container_40_green", "length":12.19, "height":2.954, "position":Vector3(-27.0,0.16,-197)},
	{"id":"C40-E", "model":"container_40_orange", "length":12.19, "height":2.954, "position":Vector3(-11.5,0.16,-197)},
	{"id":"C40-F", "model":"container_40_teal", "length":12.19, "height":2.954, "position":Vector3(4.0,0.16,-197)},
]


func build(owner_main) -> void:
	main = owner_main
	name = "ContainerHarborController"
	port_root = Node3D.new()
	port_root.name = "SouthernContainerHarbor"
	main.world_root.add_child(port_root)
	_build_port()
	_build_crane()
	_build_cargo()
	_build_controls()
	_build_roof_upgrade()
	reset()


func _build_port() -> void:
	# The racing pack contributes only its tiling water and terrain textures;
	# geometry remains purpose-built and lightweight for the phone viewport.
	var ocean := MeshInstance3D.new()
	ocean.name = "SouthernOcean"
	var ocean_mesh := PlaneMesh.new()
	ocean_mesh.size = Vector2(560, 285)
	ocean_mesh.subdivide_width = 24
	ocean_mesh.subdivide_depth = 12
	ocean.mesh = ocean_mesh
	ocean.position = Vector3(70, 0.055, -369)
	var water_shader := Shader.new()
	water_shader.code = """shader_type spatial;
render_mode cull_disabled;
uniform sampler2D water_color : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D water_normal : hint_normal, repeat_enable, filter_linear_mipmap;
varying vec3 world_position;
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;VERTEX.y+=sin(world_position.x*.16+TIME*.75)*.035+cos(world_position.z*.11-TIME*.55)*.025;}
void fragment(){vec2 a=world_position.xz*.035+vec2(TIME*.006,TIME*.009);vec2 b=world_position.zx*.047+vec2(-TIME*.008,TIME*.004);vec3 c1=texture(water_color,a).rgb;vec3 c2=texture(water_color,b).rgb;ALBEDO=mix(c1,c2,.42)*vec3(.72,.92,1.08);NORMAL_MAP=mix(texture(water_normal,a).rgb,texture(water_normal,b).rgb,.5);NORMAL_MAP_DEPTH=.42;ROUGHNESS=.2;METALLIC=.08;}"""
	var water_material := ShaderMaterial.new()
	water_material.shader = water_shader
	water_material.set_shader_parameter("water_color", load("res://assets/harbor/water_base.jpg"))
	water_material.set_shader_parameter("water_normal", load("res://assets/harbor/water_normal.jpg"))
	ocean.material_override = water_material
	port_root.add_child(ocean)

	_box("PortApron", Vector3(310,0.24,65), Vector3(0,-0.015,-199.5), Color("6f7472"), false)
	_box("QuayWall", Vector3(310,2.8,2.6), Vector3(0,-1.15,-233.1), Color("4a5355"), true)
	_box("EastShore", Vector3(165,0.18,48), Vector3(237.5,-0.04,-202), Color("8b8069"), false, load("res://assets/harbor/shore_dirt.jpg"))
	for x in range(160,316,7):
		var z := -225.0 + sin(float(x)*0.18)*2.2
		_box("ShoreRock", Vector3(5.5,1.4,4.5), Vector3(x,-0.45,z), Color("777368"), true, load("res://assets/harbor/shore_rock.jpg"), Vector3(0,sin(float(x)*0.37)*0.24,0))
	# Keep only a restrained quay edge marker.  The old full-width yellow
	# parking stripes made the apron noisy and had no gameplay meaning.
	for x in range(-140,141,14):
		_box("QuayEdgeMark",Vector3(7.0,0.025,0.18),Vector3(x,0.13,-230.7),Color("aab8b2"))
	for line in [
		[RV_LIFT_BAY+Vector3(0,0,-1.55),Vector3(7.2,0.025,0.12)],
		[RV_LIFT_BAY+Vector3(0,0,1.55),Vector3(7.2,0.025,0.12)],
		[RV_LIFT_BAY+Vector3(-3.6,0,0),Vector3(0.12,0.025,3.1)],
		[RV_LIFT_BAY+Vector3(3.6,0,0),Vector3(0.12,0.025,3.1)],
	]:
		_box("RVLiftBayLine",line[1],line[0],Color("78d6cf"))
	main._add_label("房车吊装位 · 车身横向停入",RV_LIFT_BAY+Vector3(0,0.51,0),Color("a6fff4"),24).no_depth_test=false
	main._add_label("南部集装箱码头",Vector3(0,4.0,-219),Color("ffe6a1"),34).no_depth_test=false
	for x in range(-145,151,18):
		# Visual only: the crane's wide invisible body used to snag these while
		# travelling laterally along the quay.
		var bollard := _cylinder("MooringBollard",0.34,0.65,Vector3(x,0.43,-231.2),Color("30383a"),false)
		bollard.rotation_degrees.z = 0


func _build_crane() -> void:
	crane = CharacterBody3D.new()
	crane.name = "DrivableHarborCrane"
	crane.collision_layer = 2
	crane.collision_mask = 3
	port_root.add_child(crane)
	var body: Node3D = load("res://assets/harbor/harbor_crane.glb").instantiate()
	body.name = "HarborCraneModel"
	crane.add_child(body)
	var access_ladder: Node3D=load("res://assets/harbor/ladder.glb").instantiate()
	access_ladder.name="CraneAccessLadder"
	access_ladder.position=Vector3(3.45,.10,-2.3)
	access_ladder.rotation.y=PI/2
	access_ladder.scale.y=1.35
	crane.add_child(access_ladder)
	spreader = load("res://assets/harbor/harbor_spreader.glb").instantiate()
	spreader.name = "MovingContainerSpreader"
	crane.add_child(spreader)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(7.0,3.2,10.2)
	collision.shape = shape
	collision.position = Vector3(0,1.6,-1.3)
	crane.add_child(collision)
	cable_root = Node3D.new()
	cable_root.name = "HoistCables"
	crane.add_child(cable_root)
	# Four genuinely continuous, phone-readable steel ropes.  The previous
	# 4.5 cm boxes became sub-pixel dotted lines after distant antialiasing.
	for x in [-2.62,2.62]:
		for z in [26.82,27.64]:
			var cable := _cylinder_to(cable_root,"HoistCable",0.12,1.0,Vector3(x,18,z),Color("263238"),true)
			cable.set_meta("hoist_rope",true)
	_box_to(cable_root,"UpperCableBeam",Vector3(5.55,0.22,1.10),Vector3(0,25.0,27.23),Color("313b3e"))
	cab_label = Label3D.new()
	cab_label.name = "CraneCabPrompt"
	cab_label.text = "港口吊车 · E 驾驶"
	cab_label.font_size = 28
	cab_label.outline_size = 8
	cab_label.modulate = Color("ffe4a1")
	cab_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	cab_label.no_depth_test = true
	cab_label.position = Vector3(4.2,2.3,-2.2)
	crane.add_child(cab_label)


func _build_cargo() -> void:
	for spec in _cargo_specs:
		var cargo := Node3D.new()
		cargo.name = "Cargo_" + spec.id
		port_root.add_child(cargo)
		var model: Node3D = load("res://assets/harbor/%s.glb" % spec.model).instantiate()
		model.name = "ContainerModel"
		cargo.add_child(model)
		var body := StaticBody3D.new()
		body.name = "ContainerCollision"
		body.collision_layer = 3
		body.collision_mask = 0
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		var width: float = 2.45 if float(spec.length)>7.0 else 2.30
		shape.size = Vector3(float(spec.length),float(spec.height),width)
		collision.shape = shape
		collision.position.y = float(spec.height)*0.5
		body.add_child(collision)
		cargo.add_child(body)
		var record: Dictionary = spec.duplicate()
		record["node"] = cargo
		record["collision"] = collision
		record["on_rv"] = false
		cargoes.append(record)


func _build_controls() -> void:
	controls = Control.new()
	controls.name = "HarborCraneControls"
	controls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main.get_node("HUD").add_child(controls)
	raise_button = _action_button("吊具升 R",Vector2(370,1010),func():pass)
	lower_button = _action_button("吊具降 F",Vector2(540,1010),func():pass)
	exit_button = _action_button("离开吊车",Vector2(370,1120),exit_crane)
	grab_button = _action_button("抓取 J",Vector2(540,1120),toggle_cargo)
	raise_button.button_down.connect(func():_raise_held=true)
	raise_button.button_up.connect(func():_raise_held=false)
	lower_button.button_down.connect(func():_lower_held=true)
	lower_button.button_up.connect(func():_lower_held=false)
	raise_button.set_meta("hold_action",true)
	lower_button.set_meta("hold_action",true)
	controls.hide()
	fix_button = Button.new()
	fix_button.name = "FixRoofContainerButton"
	fix_button.text = "固定承重结构"
	fix_button.position = Vector2(520,905)
	fix_button.size = Vector2(170,82)
	fix_button.focus_mode = Control.FOCUS_NONE
	fix_button.mouse_filter = Control.MOUSE_FILTER_IGNORE if main.mobile_joystick.mobile else Control.MOUSE_FILTER_STOP
	main._style_button(fix_button,Color("49623e"))
	fix_button.pressed.connect(fix_roof_container)
	main.get_node("HUD").add_child(fix_button)
	fix_button.hide()


func _build_roof_upgrade() -> void:
	# Exterior rack and load-distribution frame, parented to the moving RV.
	roof_support = Node3D.new()
	roof_support.name = "RoofContainerSupportFrame"
	main.rv.add_child(roof_support)
	var hull:=StaticBody3D.new()
	hull.name="HoistRVHull"
	hull.collision_layer=8
	hull.collision_mask=0
	var hull_shape:=CollisionShape3D.new()
	var box:=BoxShape3D.new()
	box.size=Vector3(2.25,2.8,6.5)
	hull_shape.shape=box
	hull_shape.position.y=ROOF_BOTTOM_LOCAL_Y-1.4
	hull.add_child(hull_shape)
	main.rv.add_child(hull)
	var steel := Color("34464a")
	for x in [-1.08,1.08]:
		_box_to(roof_support,"LongitudinalRail",Vector3(0.16,0.16,6.35),Vector3(x,1.61,0.15),steel)
	for z in [-2.72,-0.90,0.90,2.72]:
		_box_to(roof_support,"CrossBeam",Vector3(2.34,0.14,0.18),Vector3(0,1.66,z+0.15),steel)
	for x in [-1.08,1.08]:
		for z in [-2.72,2.72]:
			_box_to(roof_support,"LoadFoot",Vector3(0.24,0.30,0.24),Vector3(x,1.48,z+0.15),Color("657276"))

	# Cab-side ladder.  It follows the interior scene rather than the exterior
	# vehicle, because the detailed cabin is rendered at its own remote origin.
	rv_ladder = Node3D.new()
	rv_ladder.name = "PassengerRoofLadder"
	main.rv_interior.add_child(rv_ladder)
	_ladder_material = StandardMaterial3D.new()
	_ladder_material.albedo_color = Color("6d7c7a")
	_ladder_material.metallic = 0.72
	_ladder_material.roughness = 0.26
	_ladder_material.emission_enabled = true
	_ladder_material.emission = Color("2fd9cd")
	_ladder_material.emission_energy_multiplier = 0.0
	var ladder: Node3D=load("res://assets/harbor/ladder.glb").instantiate()
	ladder.name="RealPassengerLadder"
	ladder.position=Vector3(-1.20,0.14,-4.55)
	ladder.rotation.y=PI/2
	rv_ladder.add_child(ladder)
	var hatch_mat := StandardMaterial3D.new()
	hatch_mat.albedo_color = Color("10191b")
	hatch_mat.roughness = 0.82
	_box_with_material(rv_ladder,"CabRoofHatch",Vector3(0.72,0.035,0.82),Vector3(-0.85,2.30,-4.55),hatch_mat)
	_ladder_label = Label3D.new()
	_ladder_label.text = "上层集装箱"
	_ladder_label.position = Vector3(-1.15,1.90,-4.55)
	_ladder_label.rotation_degrees.y = 90
	_ladder_label.font_size = 20
	_ladder_label.outline_size = 6
	_ladder_label.modulate = Color("a8fff4")
	rv_ladder.add_child(_ladder_label)

	# Separate walkable interior.  Four floor pieces leave a real physical
	# opening over the ladder instead of painting a fake dark square.
	roof_interior = Node3D.new()
	roof_interior.name = "ExplorableRoofContainer"
	roof_interior.position = ROOF_INTERIOR_ORIGIN
	main.add_child(roof_interior)
	var floor_color := Color("465052")
	var wall_color := Color("647176")
	var w := ROOF_HALF_WIDTH
	var l := ROOF_HALF_LENGTH
	var hx := ROOF_HATCH_ANCHOR.x
	var hz := ROOF_HATCH_ANCHOR.z
	var left := hx-0.39
	var right := hx+0.39
	var front := hz-0.48
	var back := hz+0.48
	_box_to(roof_interior,"FloorRear",Vector3(w*2,0.12,l-back),Vector3(0,-0.06,(l+back)/2),floor_color,true)
	_box_to(roof_interior,"FloorNose",Vector3(w*2,0.12,front+l),Vector3(0,-0.06,(front-l)/2),floor_color,true)
	_box_to(roof_interior,"FloorHatchLeft",Vector3(left+w,0.12,0.96),Vector3((left-w)/2,-0.06,hz),floor_color,true)
	_box_to(roof_interior,"FloorHatchRight",Vector3(w-right,0.12,0.96),Vector3((right+w)/2,-0.06,hz),floor_color,true)
	_roof_walls.left=_box_to(roof_interior,"LeftWall",Vector3(0.10,2.58,l*2),Vector3(-w-.05,1.29,0),wall_color,true)
	_roof_walls.right=_box_to(roof_interior,"RightWall",Vector3(0.10,2.58,l*2),Vector3(w+.05,1.29,0),wall_color,true)
	_roof_walls.front=_box_to(roof_interior,"FrontWall",Vector3(w*2,2.58,0.10),Vector3(0,1.29,-l-.05),wall_color,true)
	_roof_walls.rear=_box_to(roof_interior,"RearWall",Vector3(w*2,2.58,0.10),Vector3(0,1.29,l+.05),wall_color,true)
	_roof_ceiling=_box_to(roof_interior,"Ceiling",Vector3(w*2,0.08,l*2),Vector3(0,2.62,0),Color("596568"),true)
	for side in ["left","right"]:
		var wall: Node3D=_roof_walls[side]
		for i in range(18):
			_box_to(wall,"WallRib",Vector3(0.06,2.40,0.055),Vector3(0.065 if side=="left" else -0.065,0,-l+.25+i*(l*2-.5)/17),Color("839093"))
	for x in [left,right]:
		_box_to(roof_interior,"HatchLip",Vector3(0.07,0.12,1.02),Vector3(x,0.06,hz),Color("a3a9a3"))
	for z in [front,back]:
		_box_to(roof_interior,"HatchLip",Vector3(0.85,0.12,0.07),Vector3(hx,0.06,z),Color("a3a9a3"))
	for x in [hx-.25,hx+.25]:
		_box_to(roof_interior,"UpperLadderRail",Vector3(0.07,1.10,0.07),Vector3(x,0.45,front+.10),Color("718282"))
	for y in [0.12,0.38,0.64,0.90]:
		_box_to(roof_interior,"UpperLadderRung",Vector3(0.56,0.065,0.07),Vector3(hx,y,front+.10),Color("718282"))
	var light := OmniLight3D.new()
	light.name = "ContainerCeilingLight"
	light.position = Vector3(0,2.35,0.45)
	light.light_color = Color("d8f6ee")
	light.light_energy = 1.35
	light.omni_range = 5.2
	light.shadow_enabled = false
	roof_interior.add_child(light)
	var room_label := Label3D.new()
	room_label.text = "房车上层 · 20 尺扩展舱"
	room_label.position = Vector3(0,1.75,ROOF_HALF_LENGTH-.06)
	room_label.rotation.y = PI
	room_label.font_size = 22
	room_label.outline_size = 7
	room_label.modulate = Color("d4fff8")
	roof_interior.add_child(room_label)
	roof_interior.hide()


func _action_button(text_value: String, point: Vector2, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	button.position = point
	button.size = Vector2(140,82)
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_IGNORE if main.mobile_joystick.mobile else Control.MOUSE_FILTER_STOP
	main._style_button(button,Color("30505a"))
	button.pressed.connect(callback)
	controls.add_child(button)
	return button


func reset() -> void:
	_cancel_floor_transition()
	if roof_interior_active:
		exit_roof_interior(true)
	if active:
		exit_crane(true)
	held = {}
	hoist_offset = -2.65
	touch_move = Vector2.ZERO
	crane.global_position = GameState.crane_position
	crane.rotation = Vector3(0,GameState.crane_yaw,0)
	for cargo in cargoes:
		var node: Node3D = cargo.node
		if node.get_parent() != port_root:
			node.reparent(port_root,true)
		cargo.on_rv = false
		_set_collision(cargo,true)
		var saved: Dictionary = GameState.harbor_container_states.get(cargo.id,{})
		if bool(saved.get("on_rv",false)):
			_attach_to_rv(cargo,false)
		else:
			node.global_position = saved.get("position",cargo.position)
			node.global_rotation = Vector3(0,float(saved.get("yaw",0.0)),0)
	if GameState.roof_container_id.is_empty():
		GameState.roof_container_fixed=false
	_sync_roof_upgrade()
	_update_spreader()
	controls.hide()
	fix_button.hide()
	cab_label.show()


func nearby() -> bool:
	if active or cab_transitioning or main.inside_rv or main.inside_store or main.in_vehicle:return false
	return main.hotaru.global_position.distance_to(crane.to_global(Vector3(4.1,0.95,-2.3))) <= 3.4


func enter() -> void:
	if active or cab_transitioning or not nearby():return
	if is_instance_valid(main.trolley):main.trolley.release()
	active=true
	crane.add_collision_exception_with(main.hotaru)
	main.mobile_joystick.reset()
	cab_label.hide()
	_climb_cab(true)


func _climb_cab(up: bool) -> void:
	cab_transitioning=true
	controls.hide()
	main.hotaru.set_active(false)
	main.hotaru.servicing=true
	main.hotaru.show()
	main.hotaru.rotation.y=-PI/2
	for attachment in main.hotaru._bat_attachments.values():attachment.hide()
	if is_instance_valid(main.hotaru._sword_sheath_root):main.hotaru._sword_sheath_root.hide()
	main.hotaru._play_character_animation("Climb",true)
	var bottom: Vector3=crane.to_global(Vector3(3.85,.95,-2.3))
	var top: Vector3=crane.to_global(Vector3(3.40,3.85,-2.3))
	main.hotaru.global_position=bottom if up else top
	_cab_tween=create_tween()
	_cab_tween.tween_property(main.hotaru,"global_position",top if up else bottom,1.8)
	_cab_tween.tween_callback(func():
		cab_transitioning=false
		main.hotaru.servicing=false
		main.hotaru.sync_equipment()
		if up:
			main.hotaru.hide()
			controls.show()
			_notice_message("吊车已启动：按住升/降连续操作，松手停止。")
		else:
			active=false
			crane.remove_collision_exception_with(main.hotaru)
			main.hotaru.global_position=crane.to_global(Vector3(4.7,.95,-2.3))
			main.hotaru.set_active(true)
			cab_label.show()
			_record_state()
	)


func exit_crane(force: bool=false) -> void:
	if not active:return
	if cab_transitioning and not force:return
	if not held.is_empty() and not force:
		_notice_message("先把集装箱安全放下，再离开驾驶室。")
		return
	_raise_held=false
	_lower_held=false
	touch_move=Vector2.ZERO
	crane.velocity=Vector3.ZERO
	main.mobile_joystick.reset()
	if force:
		if is_instance_valid(_cab_tween):_cab_tween.kill()
		cab_transitioning=false
		active=false
		main.hotaru.servicing=false
		main.hotaru.sync_equipment()
		crane.remove_collision_exception_with(main.hotaru)
		controls.hide()
		return
	_climb_cab(false)


func handle_input(event: InputEvent) -> void:
	if not active or cab_transitioning:return
	if event.is_action_pressed("attack"):
		toggle_cargo()
	elif event.is_action_pressed("interact") or event.is_action_pressed("toggle_vehicle"):
		exit_crane()


func _physics_process(delta: float) -> void:
	if _notice_time>0.0:_notice_time=maxf(0.0,_notice_time-delta)
	if not active or cab_transitioning:
		return
	if get_tree().paused or not main.controls_enabled:
		_raise_held=false
		_lower_held=false
		return
	var movement := Vector2(
		Input.get_axis("move_left","move_right") + touch_move.x,
		Input.get_axis("move_backward","move_forward") + touch_move.y
	).limit_length(1.0)
	var desired := Vector3(movement.x,0,movement.y)*CRANE_SPEED
	crane.velocity = crane.velocity.lerp(desired,1.0-exp(-delta*7.0))
	if not held.is_empty():
		crane.velocity*=_load_safe_fraction(crane.velocity*delta)
	crane.move_and_slide()
	crane.global_position.x = clampf(crane.global_position.x,CRANE_TRAVEL.position.x,CRANE_TRAVEL.end.x)
	crane.global_position.z = clampf(crane.global_position.z,CRANE_TRAVEL.position.y,CRANE_TRAVEL.end.y)
	crane.global_position.y = CRANE_START.y
	speed = Vector2(crane.velocity.x,crane.velocity.z).length()
	var hoist_axis := (1.0 if Input.is_key_pressed(KEY_R) or _raise_held else 0.0) - (1.0 if Input.is_key_pressed(KEY_F) or _lower_held else 0.0)
	if not is_zero_approx(hoist_axis):
		_move_hoist(hoist_axis*delta*1.4)
	_update_spreader()
	if not held.is_empty():_update_held_cargo()


func _move_hoist(amount: float) -> void:
	var next:=clampf(hoist_offset+amount,HOIST_MIN,HOIST_MAX)
	var motion:=Vector3(0,next-hoist_offset,0)
	var fraction:=_load_safe_fraction(motion) if not held.is_empty() else 1.0
	hoist_offset+=motion.y*fraction
	_update_spreader()
	if not held.is_empty():_update_held_cargo()
	if fraction<.99:_notice_message("载荷已接触障碍或车顶；请升高后对正，禁止穿过车身。")


func _load_safe_fraction(motion: Vector3) -> float:
	if held.is_empty() or motion.is_zero_approx():return 1.0
	var query:=PhysicsShapeQueryParameters3D.new()
	query.shape=held.collision.shape
	query.transform=held.node.global_transform*held.collision.transform
	query.motion=motion
	query.margin=.015
	query.collision_mask=11
	query.exclude=[held.collision.get_parent().get_rid(),crane.get_rid(),main.hotaru.get_rid(),main.rv.get_rid()]
	var result: PackedFloat32Array=main.rv.get_world_3d().direct_space_state.cast_motion(query)
	return result[0] if result.size()>0 else 1.0


func _roof_alignment_error(cargo: Dictionary) -> String:
	var rv_point: Vector3=main.rv.global_position
	if absf(rv_point.x-RV_LIFT_BAY.x)>.45 or absf(rv_point.z-RV_LIFT_BAY.z)>.30:
		return "吊装失败：请把房车停在蓝框中央。"
	if absf(main.rv.global_basis.z.dot(Vector3.RIGHT))<cos(deg_to_rad(6.0)):
		return "吊装失败：车身须沿蓝框长边平行停放（误差不超过6度）。"
	var axis: Vector3=cargo.node.global_basis.x.normalized()
	if absf(axis.dot(main.rv.global_basis.z.normalized()))<cos(deg_to_rad(8.0)):
		return "吊装失败：箱体与车身夹角过大，请重新对正。"
	var target: Vector3=main.rv.to_global(Vector3(0,ROOF_BOTTOM_LOCAL_Y,.15))
	var bottom: Vector3=cargo.node.global_position
	if Vector2(bottom.x-target.x,bottom.z-target.z).length()>.35:
		return "吊装失败：吊具偏离车顶中心，请微调位置。"
	if absf(bottom.y-target.y)>.22:
		return "请缓慢降低箱体，接近车顶后再释放。"
	return ""


func _update_spreader() -> void:
	if not is_instance_valid(spreader):return
	spreader.position.y = hoist_offset
	var top_y := 25.0
	# The outer ropes attach to the corner beam, not the taller centre pulley.
	var spreader_top := 8.95+hoist_offset
	var cable_height := maxf(0.2,top_y-spreader_top)
	for cable in cable_root.get_children():
		if not cable.has_meta("hoist_rope"):continue
		cable.scale.y = cable_height
		cable.position.y = spreader_top+cable_height*0.5


func _update_held_cargo() -> void:
	var node: Node3D = held.node
	if node.get_parent()!=crane:node.reparent(crane,false)
	node.position = Vector3(0,SPREADER_BOTTOM+hoist_offset-float(held.height),SPREADER_Z)
	node.rotation = Vector3.ZERO


func toggle_cargo() -> void:
	if not active or cab_transitioning:return
	if not held.is_empty():
		_release_cargo()
		return
	var candidate := _nearest_cargo()
	if candidate.is_empty():
		_notice_message("吊具没有对准箱体：移动车辆并把吊具降到箱顶。")
		return
	held = candidate
	if bool(held.on_rv):
		if GameState.roof_container_fixed:
			held={}
			_notice_message("集装箱已经与承重结构锁定，不能直接起吊。")
			return
		held.on_rv=false
		GameState.roof_container_id=""
	_set_collision(held,false)
	held.node.reparent(crane,true)
	_update_held_cargo()
	_notice_message("已锁定 %s。现在升起吊具并移动吊车。"%held.id)


func _nearest_cargo() -> Dictionary:
	var hook := crane.to_global(Vector3(0,SPREADER_BOTTOM+hoist_offset,SPREADER_Z))
	var best: Dictionary = {}
	var best_score := 999.0
	for cargo in cargoes:
		if cargo==held:continue
		if bool(cargo.on_rv) and GameState.roof_container_fixed:continue
		if _has_cargo_above(cargo):continue
		var node: Node3D = cargo.node
		var top := node.to_global(Vector3(0,float(cargo.height),0))
		var horizontal := Vector2(top.x,top.z).distance_to(Vector2(hook.x,hook.z))
		var vertical := absf(top.y-hook.y)
		var score := horizontal+vertical*1.8
		if horizontal<=0.55 and vertical<=0.55 and score<best_score:
			best=cargo
			best_score=score
	return best


func _has_cargo_above(cargo: Dictionary) -> bool:
	var node: Node3D=cargo.node
	for other in cargoes:
		if other==cargo or bool(other.on_rv):continue
		var above: Node3D=other.node
		if above.global_position.y < node.global_position.y+float(cargo.height)-0.15:continue
		if absf(above.global_position.x-node.global_position.x)<(float(cargo.length)+float(other.length))*0.5 and absf(above.global_position.z-node.global_position.z)<2.35:return true
	return false


func _release_cargo() -> void:
	var cargo := held
	var node: Node3D = cargo.node
	var bottom := node.global_position
	var rv_distance := Vector2(bottom.x,bottom.z).distance_to(Vector2(main.rv.global_position.x,main.rv.global_position.z))
	if rv_distance<4.3:
		if float(cargo.length)>7.0:
			_notice_message("40 尺箱超过房车车顶长度；请选择 20 尺集装箱。")
			return
		var alignment_error:=_roof_alignment_error(cargo)
		if not alignment_error.is_empty():
			_notice_message(alignment_error)
			return
		if not GameState.roof_container_id.is_empty() and GameState.roof_container_id!=cargo.id:
			_notice_message("第一层车顶目前只能临时试装一个集装箱。")
			return
		held={}
		_attach_to_rv(cargo,true)
		_record_state()
		return
	var landing_y := 0.16
	for other in cargoes:
		if other==cargo or bool(other.on_rv):continue
		var other_node: Node3D=other.node
		if Vector2(other_node.global_position.x,other_node.global_position.z).distance_to(Vector2(bottom.x,bottom.z))<2.4:
			landing_y=maxf(landing_y,other_node.global_position.y+float(other.height))
	if absf(bottom.y-landing_y)>1.0:
		_notice_message("请把箱底移到地面或堆叠箱顶附近再释放。")
		return
	held={}
	node.reparent(port_root,true)
	node.global_position=Vector3(bottom.x,landing_y,bottom.z)
	node.global_rotation=Vector3(0,0,0)
	cargo.on_rv=false
	_set_collision(cargo,true)
	_notice_message("%s 已放置。"%cargo.id)
	_record_state()


func _attach_to_rv(cargo: Dictionary,announce: bool) -> void:
	var node: Node3D = cargo.node
	node.reparent(main.rv,false)
	node.position=Vector3(0,ROOF_BOTTOM_LOCAL_Y,0.15)
	node.rotation=Vector3(0,PI/2,0)
	cargo.on_rv=true
	_set_collision(cargo,false)
	GameState.roof_container_id=str(cargo.id)
	if announce:
		GameState.roof_container_fixed=false
	_sync_roof_upgrade()
	if announce:
		_notice_message("20 尺集装箱已经落位。点击“固定承重结构”即可完成第一层扩建。")


func fix_roof_container() -> void:
	if GameState.roof_container_id.is_empty() or GameState.roof_container_fixed:return
	GameState.roof_container_fixed=true
	_sync_roof_upgrade()
	_record_state()
	_notice_message("承重框架已锁定！副驾驶侧梯子和箱底检修口已经打通。")
	AudioDirector.ui("confirm")


func _sync_roof_upgrade() -> void:
	var ready := not GameState.roof_container_id.is_empty() and GameState.roof_container_fixed
	# Shift the passenger seat back slightly to leave a walkable ladder landing
	# between it and the dashboard; preserve original positions for new games.
	for part in main.rv_interior.find_children("PassengerSeat*","Node3D",true,false):
		if not part.has_meta("ladder_original_position"):part.set_meta("ladder_original_position",part.position)
		part.position=part.get_meta("ladder_original_position")+Vector3(0,0,.20 if ready else 0.0)
	if is_instance_valid(roof_support):roof_support.visible=ready
	if is_instance_valid(rv_ladder):rv_ladder.visible=ready
	if is_instance_valid(roof_interior) and not roof_interior_active:roof_interior.hide()


func apply_hud() -> void:
	if not is_instance_valid(fix_button):return
	var can_fix := not GameState.roof_container_id.is_empty() and not GameState.roof_container_fixed
	can_fix = can_fix and main.controls_enabled and not main.dialog_panel.visible and not main.inside_store
	# It is intentionally available directly from the crane after landing, or
	# while standing in/near the RV: one click, no temporary hardware grind.
	var near_rv: bool = main.hotaru.visible and main.hotaru.global_position.distance_to(main.rv.global_position)<9.0
	fix_button.visible=can_fix and (active or main.inside_rv or near_rv)
	if is_instance_valid(_ladder_material):
		_ladder_material.emission_energy_multiplier=0.65 if near_interior_ladder() else 0.0


func near_interior_ladder() -> bool:
	if not GameState.roof_container_fixed or roof_interior_active or roof_transitioning or not main.inside_rv or main.seated_at_driver:return false
	var local: Vector3=main.rv_interior.to_local(main.hotaru.global_position)
	# Dedicated left-window zone: the centre aisle and right driver's seat
	# retain their original furniture interactions.
	return local.x < -0.15 and local.distance_to(RV_LADDER_ANCHOR)<=0.90


func enter_roof_interior() -> void:
	if not near_interior_ladder():return
	roof_interior_active=true
	main.rv_interior.clear_interaction_focus()
	main.hotaru.set_ground_height(ROOF_INTERIOR_ORIGIN.y+0.95)
	main.hotaru.global_position=ROOF_INTERIOR_ORIGIN+Vector3(-0.45,0.95,ROOF_HATCH_ANCHOR.z+0.80)
	main.hotaru.rotation.y=0.0
	_begin_floor_transition(1.0)
	_notice_message("房车上层：拖拽旋转，滚轮或双指缩放。")


func near_roof_hatch() -> bool:
	return roof_interior_active and not roof_transitioning and main.hotaru.global_position.distance_to(ROOF_INTERIOR_ORIGIN+ROOF_HATCH_ANCHOR)<=1.30


func interact_roof_interior() -> void:
	if not roof_interior_active or roof_transitioning:return
	if near_roof_hatch():exit_roof_interior()
	else:_notice_message("走回前端地板检修口，再从梯子下去。")


func exit_roof_interior(force: bool=false) -> void:
	if not roof_interior_active or (roof_transitioning and not force):return
	roof_interior_active=false
	if force:
		_cancel_floor_transition()
		return
	main.hotaru.set_ground_height(main.RV_INTERIOR_ORIGIN.y+1.13)
	main.hotaru.global_position=main.rv_interior.to_global(Vector3(-0.30,1.13,-4.57))
	main.hotaru.rotation.y=PI
	_begin_floor_transition(0.0)
	_notice_message("小萤沿左侧靠窗的梯子回到了驾驶舱。")


func _set_floor_blend(value: float) -> void:
	_floor_blend=value
	for mesh in main.rv_interior.find_children("*","GeometryInstance3D",true,false):
		mesh.transparency=value
	for mesh in roof_interior.find_children("*","GeometryInstance3D",true,false):
		mesh.transparency=1.0-value


func _begin_floor_transition(target: float) -> void:
	roof_transitioning=true
	main.hotaru.set_active(false)
	main.mobile_joystick.reset()
	main.rv_interior.set_active(true)
	roof_interior.show()
	_set_floor_blend(_floor_blend)
	_floor_tween=create_tween()
	_floor_tween.tween_method(_set_floor_blend,_floor_blend,target,0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_floor_tween.tween_callback(func():
		roof_transitioning=false
		main.rv_interior.set_active(target<0.5)
		roof_interior.visible=target>0.5
		main.hotaru.set_active(main.controls_enabled)
	)


func _cancel_floor_transition() -> void:
	if is_instance_valid(_floor_tween):_floor_tween.kill()
	roof_transitioning=false
	if is_instance_valid(roof_interior):
		_set_floor_blend(0.0)
		roof_interior.hide()


func update_roof_camera(delta: float) -> void:
	# Same orbit, zoom and focal X/Z as downstairs: only height changes.
	var center: Vector3=main.rv_interior.get_camera_pivot()+Vector3.UP*ROOF_INTERIOR_ORIGIN.y*_floor_blend
	main._update_rv_orbit_camera(delta,center)
	main.rv_interior.update_camera_cutaway(main.camera.global_position)
	var local: Vector3=roof_interior.to_local(main.camera.global_position)
	_roof_ceiling.hide()
	_roof_walls.left.visible=local.x>=0
	_roof_walls.right.visible=local.x<0
	_roof_walls.front.visible=local.z>=0
	_roof_walls.rear.visible=local.z<0


func _set_collision(cargo: Dictionary,enabled: bool) -> void:
	var collision: CollisionShape3D=cargo.collision
	collision.set_deferred("disabled",not enabled)


func _record_state() -> void:
	GameState.crane_position=crane.global_position
	GameState.crane_yaw=crane.rotation.y
	var states: Dictionary={}
	for cargo in cargoes:
		if bool(cargo.on_rv):states[cargo.id]={"on_rv":true}
		else:
			var node: Node3D=cargo.node
			states[cargo.id]={"position":node.global_position,"yaw":node.global_rotation.y,"on_rv":false}
	GameState.harbor_container_states=states


func _notice_message(value: String) -> void:
	_notice=value
	_notice_time=4.5
	if is_instance_valid(main.hint_label):main.hint_label.text=value


func update_hud() -> void:
	main.status_label.text="港口吊车  速度 %.1f m/s  吊具 %.1f m"%[speed,SPREADER_BOTTOM+hoist_offset]
	main.speed_label.text="载荷：%s"%("无" if held.is_empty() else str(held.id))
	main.objective_label.text="集装箱码头 · 驾驶吊车把 20 尺集装箱吊装到房车顶"
	main.attack_button.hide()
	main.interact_button.hide()
	main.vehicle_button.hide()
	main.upgrade_button.hide()
	for button in get_tree().get_nodes_in_group("movement_controls"):button.show()
	controls.visible=not cab_transitioning
	grab_button.text="释放 J" if not held.is_empty() else "抓取 J"
	apply_hud()
	if _notice_time>0.0:
		main.hint_label.text=_notice
	elif held.is_empty():
		main.hint_label.text="WASD/左摇杆移动吊车 · R/F 升降 · 将吊具对准箱顶后按 J 抓取"
	else:
		main.hint_label.text="载荷 %s · 把房车横停在青色框内，降低吊具后释放"%held.id


func update_camera(delta: float) -> void:
	main.camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	main.camera.keep_aspect=Camera3D.KEEP_WIDTH
	main.camera.size=42.0
	var focus := crane.global_position+Vector3(0,7.5,12.0)
	var desired := focus+Vector3(-33,31,-35)
	main.camera.global_position=main.camera.global_position.lerp(desired,1.0-exp(-delta*4.5))
	main.camera.look_at(focus,Vector3.UP)


func _box(title: String,size: Vector3,point: Vector3,color: Color,solid: bool=false,texture: Texture2D=null,rotation_value: Vector3=Vector3.ZERO) -> MeshInstance3D:
	return _box_to(port_root,title,size,point,color,solid,texture,rotation_value)


func _box_to(parent: Node,title: String,size: Vector3,point: Vector3,color: Color,solid: bool=false,texture: Texture2D=null,rotation_value: Vector3=Vector3.ZERO) -> MeshInstance3D:
	var mesh:=MeshInstance3D.new()
	mesh.name=title
	var shape_mesh:=BoxMesh.new()
	shape_mesh.size=size
	mesh.mesh=shape_mesh
	var material:=StandardMaterial3D.new()
	material.albedo_color=color
	material.roughness=.9
	if texture:
		material.albedo_texture=texture
		material.uv1_scale=Vector3(maxf(1,size.x/5.0),maxf(1,size.z/5.0),1)
	mesh.material_override=material
	mesh.position=point
	mesh.rotation=rotation_value
	parent.add_child(mesh)
	if solid:
		var body:=StaticBody3D.new()
		body.collision_layer=3
		body.collision_mask=0
		var collision:=CollisionShape3D.new()
		var shape:=BoxShape3D.new()
		shape.size=size
		collision.shape=shape
		body.add_child(collision)
		mesh.add_child(body)
	return mesh


func _box_with_material(parent: Node,title: String,size: Vector3,point: Vector3,material: Material) -> MeshInstance3D:
	var mesh:=MeshInstance3D.new()
	mesh.name=title
	var shape_mesh:=BoxMesh.new()
	shape_mesh.size=size
	mesh.mesh=shape_mesh
	mesh.position=point
	mesh.material_override=material
	parent.add_child(mesh)
	return mesh


func _cylinder_to(parent: Node,title: String,radius: float,height: float,point: Vector3,color: Color,unshaded: bool=false) -> MeshInstance3D:
	var mesh:=MeshInstance3D.new()
	mesh.name=title
	var cylinder:=CylinderMesh.new()
	cylinder.top_radius=radius
	cylinder.bottom_radius=radius
	cylinder.height=height
	cylinder.radial_segments=12
	mesh.mesh=cylinder
	var material:=StandardMaterial3D.new()
	material.albedo_color=color
	material.metallic=.58
	material.roughness=.38
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED if unshaded else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mesh.material_override=material
	mesh.position=point
	mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)
	return mesh


func _cylinder(title: String,radius: float,height: float,point: Vector3,color: Color,solid: bool=false) -> MeshInstance3D:
	var mesh:=MeshInstance3D.new()
	mesh.name=title
	var cylinder:=CylinderMesh.new()
	cylinder.top_radius=radius
	cylinder.bottom_radius=radius
	cylinder.height=height
	mesh.mesh=cylinder
	var material:=StandardMaterial3D.new()
	material.albedo_color=color
	material.roughness=.8
	mesh.material_override=material
	mesh.position=point
	port_root.add_child(mesh)
	if solid:
		var body:=StaticBody3D.new()
		body.collision_layer=3
		body.collision_mask=0
		var collision:=CollisionShape3D.new()
		var shape:=CylinderShape3D.new()
		shape.radius=radius
		shape.height=height
		collision.shape=shape
		body.add_child(collision)
		mesh.add_child(body)
	return mesh
