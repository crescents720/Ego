extends Node

# Playable harbor: drive the mobile crane, hoist marked cargo, then turn a
# 20-foot container into the RV's first explorable upper floor.
const CRANE_START := Vector3(-122.0, 0.12, -216.0)
const CRANE_TRAVEL := Rect2(-145.0, -220.5, 270.0, 16.0)
const SPREADER_Z := 27.23
const SPREADER_BOTTOM := 8.72
const HOIST_MIN := -6.0
const HOIST_MAX := 0.0
const ROOF_BOTTOM_LOCAL_Y := 1.78
const CRANE_SPEED := 5.2
const RV_LIFT_BAY := Vector3(-45.0, 0.14, -186.0)
const ROOF_INTERIOR_ORIGIN := Vector3(4000.0, 0.0, 0.0)
const RV_LADDER_ANCHOR := Vector3(-0.88, 1.13, -4.02)
const ROOF_HATCH_ANCHOR := Vector3(-0.53, 0.95, -2.14)

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

	_box("PortApron", Vector3(310,0.24,58), Vector3(0,-0.015,-196), Color("6f7472"), false)
	_box("QuayWall", Vector3(310,2.8,2.6), Vector3(0,-1.15,-226.1), Color("4a5355"), true)
	_box("EastShore", Vector3(165,0.18,48), Vector3(237.5,-0.04,-202), Color("8b8069"), false, load("res://assets/harbor/shore_dirt.jpg"))
	for x in range(160,316,7):
		var z := -225.0 + sin(float(x)*0.18)*2.2
		_box("ShoreRock", Vector3(5.5,1.4,4.5), Vector3(x,-0.45,z), Color("777368"), true, load("res://assets/harbor/shore_rock.jpg"), Vector3(0,sin(float(x)*0.37)*0.24,0))
	# Keep only a restrained quay edge marker.  The old full-width yellow
	# parking stripes made the apron noisy and had no gameplay meaning.
	for x in range(-140,141,14):
		_box("QuayEdgeMark",Vector3(7.0,0.025,0.18),Vector3(x,0.13,-223.7),Color("aab8b2"))
	for line in [
		[RV_LIFT_BAY+Vector3(0,0,-6),Vector3(14,0.025,0.22)],
		[RV_LIFT_BAY+Vector3(0,0,6),Vector3(14,0.025,0.22)],
		[RV_LIFT_BAY+Vector3(-7,0,0),Vector3(0.22,0.025,12)],
		[RV_LIFT_BAY+Vector3(7,0,0),Vector3(0.22,0.025,12)],
	]:
		_box("RVLiftBayLine",line[1],line[0],Color("78d6cf"))
	main._add_label("房车吊装位 · 车身横向停入",RV_LIFT_BAY+Vector3(0,0.51,0),Color("a6fff4"),24).no_depth_test=false
	main._add_label("南部集装箱码头",Vector3(0,4.0,-219),Color("ffe6a1"),34).no_depth_test=false
	for x in range(-145,151,18):
		# Visual only: the crane's wide invisible body used to snag these while
		# travelling laterally along the quay.
		var bollard := _cylinder("MooringBollard",0.34,0.65,Vector3(x,0.43,-224.2),Color("30383a"),false)
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
			_cylinder_to(cable_root,"HoistCable",0.12,1.0,Vector3(x,18,z),Color("263238"),true)
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
	raise_button = _action_button("吊具升 R",Vector2(370,1010),_nudge_hoist.bind(0.8))
	lower_button = _action_button("吊具降 F",Vector2(540,1010),_nudge_hoist.bind(-0.8))
	exit_button = _action_button("离开吊车",Vector2(370,1120),exit_crane)
	grab_button = _action_button("抓取 J",Vector2(540,1120),toggle_cargo)
	raise_button.button_down.connect(func():_raise_held=true)
	raise_button.button_up.connect(func():_raise_held=false)
	lower_button.button_down.connect(func():_lower_held=true)
	lower_button.button_up.connect(func():_lower_held=false)
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
	for z in [-0.24,0.24]:
		_box_with_material(rv_ladder,"LadderRail",Vector3(0.075,2.20,0.075),Vector3(-1.20,1.20,-4.02+z),_ladder_material)
	for y in range(4,23,3):
		_box_with_material(rv_ladder,"LadderRung",Vector3(0.08,0.075,0.54),Vector3(-1.16,float(y)/10.0,-4.02),_ladder_material)
	var hatch_mat := StandardMaterial3D.new()
	hatch_mat.albedo_color = Color("10191b")
	hatch_mat.roughness = 0.82
	_box_with_material(rv_ladder,"CabRoofHatch",Vector3(0.72,0.035,0.82),Vector3(-0.95,2.30,-4.02),hatch_mat)
	_ladder_label = Label3D.new()
	_ladder_label.text = "上层集装箱"
	_ladder_label.position = Vector3(-1.05,1.78,-4.02)
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
	_box_to(roof_interior,"FloorRear",Vector3(2.12,0.12,4.58),Vector3(0,-0.06,0.585),floor_color,true)
	_box_to(roof_interior,"FloorNose",Vector3(2.12,0.12,0.25),Vector3(0,-0.06,-2.75),floor_color,true)
	_box_to(roof_interior,"FloorHatchLeft",Vector3(0.15,0.12,0.95),Vector3(-0.985,-0.06,-2.15),floor_color,true)
	_box_to(roof_interior,"FloorHatchRight",Vector3(1.18,0.12,0.95),Vector3(0.48,-0.06,-2.15),floor_color,true)
	_box_to(roof_interior,"LeftWall",Vector3(0.10,2.58,5.80),Vector3(-1.11,1.29,0),wall_color,true)
	_box_to(roof_interior,"RightWall",Vector3(0.10,2.58,5.80),Vector3(1.11,1.29,0),wall_color,true)
	_box_to(roof_interior,"FrontWall",Vector3(2.12,2.58,0.10),Vector3(0,1.29,-2.90),wall_color,true)
	_box_to(roof_interior,"RearWall",Vector3(2.12,2.58,0.10),Vector3(0,1.29,2.90),wall_color,true)
	_box_to(roof_interior,"Ceiling",Vector3(2.12,0.08,5.80),Vector3(0,2.62,0),Color("596568"),true)
	# Corrugation ribs make the empty first-stage room read as a container.
	for z in [-2.55,-2.05,-1.55,-1.05,-0.55,-0.05,0.45,0.95,1.45,1.95,2.45]:
		_box_to(roof_interior,"WallRibL",Vector3(0.06,2.40,0.055),Vector3(-1.045,1.27,z),Color("839093"))
		_box_to(roof_interior,"WallRibR",Vector3(0.06,2.40,0.055),Vector3(1.045,1.27,z),Color("839093"))
	# Hatch lip and a short continuation of the ladder inside the box.
	for x in [-0.94,-0.12]:
		_box_to(roof_interior,"HatchLip",Vector3(0.07,0.12,1.02),Vector3(x,0.06,-2.15),Color("a3a9a3"))
	for z in [-2.60,-1.70]:
		_box_to(roof_interior,"HatchLip",Vector3(0.89,0.12,0.07),Vector3(-0.53,0.06,z),Color("a3a9a3"))
	for x in [-0.78,-0.28]:
		_box_to(roof_interior,"UpperLadderRail",Vector3(0.07,1.10,0.07),Vector3(x,0.45,-2.50),Color("718282"))
	for y in [0.12,0.38,0.64,0.90]:
		_box_to(roof_interior,"UpperLadderRung",Vector3(0.56,0.065,0.07),Vector3(-0.53,y,-2.50),Color("718282"))
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
	room_label.position = Vector3(0,1.75,2.82)
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
	if active or main.inside_rv or main.inside_store or main.in_vehicle:return false
	return main.hotaru.global_position.distance_to(crane.to_global(Vector3(4.1,0.95,-2.3))) <= 3.4


func enter() -> void:
	if active or not nearby():return
	if is_instance_valid(main.trolley):main.trolley.release()
	active = true
	main.hotaru.set_active(false)
	main.hotaru.hide()
	main.mobile_joystick.reset()
	controls.show()
	cab_label.hide()
	_notice_message("吊车已启动。左侧移动，右侧控制吊具。")


func exit_crane(force: bool=false) -> void:
	if not active:return
	if not held.is_empty() and not force:
		_notice_message("先把集装箱安全放下，再离开驾驶室。")
		return
	active = false
	_raise_held = false
	_lower_held = false
	touch_move = Vector2.ZERO
	crane.velocity = Vector3.ZERO
	main.mobile_joystick.reset()
	if not force:
		main.hotaru.global_position = crane.to_global(Vector3(4.7,0.83,-2.5))
		main.hotaru.show()
		main.hotaru.set_active(true)
	controls.hide()
	cab_label.show()
	if not force:_record_state()


func handle_input(event: InputEvent) -> void:
	if not active:return
	if event.is_action_pressed("attack"):
		toggle_cargo()
	elif event.is_action_pressed("interact") or event.is_action_pressed("toggle_vehicle"):
		exit_crane()


func _physics_process(delta: float) -> void:
	if _notice_time>0.0:_notice_time=maxf(0.0,_notice_time-delta)
	if not active:
		return
	var movement := Vector2(
		Input.get_axis("move_left","move_right") + touch_move.x,
		Input.get_axis("move_backward","move_forward") + touch_move.y
	).limit_length(1.0)
	var desired := Vector3(movement.x,0,movement.y)*CRANE_SPEED
	crane.velocity = crane.velocity.lerp(desired,1.0-exp(-delta*7.0))
	crane.move_and_slide()
	crane.global_position.x = clampf(crane.global_position.x,CRANE_TRAVEL.position.x,CRANE_TRAVEL.end.x)
	crane.global_position.z = clampf(crane.global_position.z,CRANE_TRAVEL.position.y,CRANE_TRAVEL.end.y)
	crane.global_position.y = CRANE_START.y
	speed = Vector2(crane.velocity.x,crane.velocity.z).length()
	var hoist_axis := (1.0 if Input.is_key_pressed(KEY_R) or _raise_held else 0.0) - (1.0 if Input.is_key_pressed(KEY_F) or _lower_held else 0.0)
	if not is_zero_approx(hoist_axis):
		hoist_offset = clampf(hoist_offset+hoist_axis*delta*2.8,HOIST_MIN,HOIST_MAX)
	_update_spreader()
	if not held.is_empty():_update_held_cargo()


func _nudge_hoist(amount: float) -> void:
	if not active:return
	hoist_offset = clampf(hoist_offset+amount,HOIST_MIN,HOIST_MAX)
	_update_spreader()
	if not held.is_empty():_update_held_cargo()


func _update_spreader() -> void:
	if not is_instance_valid(spreader):return
	spreader.position.y = hoist_offset
	var top_y := 25.0
	var spreader_top := 11.98+hoist_offset
	var cable_height := maxf(0.2,top_y-spreader_top)
	for cable in cable_root.get_children():
		if not str(cable.name).begins_with("HoistCable"):continue
		cable.scale.y = cable_height
		cable.position.y = spreader_top+cable_height*0.5


func _update_held_cargo() -> void:
	var node: Node3D = held.node
	if node.get_parent()!=crane:node.reparent(crane,false)
	node.position = Vector3(0,SPREADER_BOTTOM+hoist_offset-float(held.height),SPREADER_Z)
	node.rotation = Vector3.ZERO


func toggle_cargo() -> void:
	if not active:return
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
		var node: Node3D = cargo.node
		var top := node.to_global(Vector3(0,float(cargo.height),0))
		var horizontal := Vector2(top.x,top.z).distance_to(Vector2(hook.x,hook.z))
		var vertical := absf(top.y-hook.y)
		var score := horizontal+vertical*1.8
		if horizontal<=3.8 and vertical<=1.35 and score<best_score:
			best=cargo
			best_score=score
	return best


func _release_cargo() -> void:
	var cargo := held
	var node: Node3D = cargo.node
	var bottom := node.global_position
	var rv_distance := Vector2(bottom.x,bottom.z).distance_to(Vector2(main.rv.global_position.x,main.rv.global_position.z))
	if rv_distance<4.3:
		if float(cargo.length)>7.0:
			_notice_message("40 尺箱超过房车车顶长度；请选择 20 尺集装箱。")
			return
		if bottom.y>main.rv.global_position.y+2.25:
			_notice_message("继续降低吊具，让箱底贴近房车顶。")
			return
		if not GameState.roof_container_id.is_empty() and GameState.roof_container_id!=cargo.id:
			_notice_message("第一层车顶目前只能临时试装一个集装箱。")
			return
		held={}
		_attach_to_rv(cargo,true)
		_record_state()
		return
	if bottom.y>1.15:
		_notice_message("吊具仍然太高；降到码头地面附近再释放。")
		return
	var landing_y := 0.16
	for other in cargoes:
		if other==cargo or bool(other.on_rv):continue
		var other_node: Node3D=other.node
		if Vector2(other_node.global_position.x,other_node.global_position.z).distance_to(Vector2(bottom.x,bottom.z))<2.4:
			landing_y=maxf(landing_y,other_node.global_position.y+float(other.height))
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
	if is_instance_valid(roof_support):roof_support.visible=ready
	if is_instance_valid(rv_ladder):rv_ladder.visible=ready
	if is_instance_valid(roof_interior) and not roof_interior_active:roof_interior.hide()


func apply_hud() -> void:
	if not is_instance_valid(fix_button):return
	var can_fix := not GameState.roof_container_id.is_empty() and not GameState.roof_container_fixed
	can_fix = can_fix and main.controls_enabled and not main.dialog_panel.visible and not main.inside_store
	# It is intentionally available directly from the crane after landing, or
	# while standing in/near the RV: one click, no temporary hardware grind.
	var near_rv := main.hotaru.global_position.distance_to(main.rv.global_position)<9.0 if main.hotaru.visible else false
	fix_button.visible=can_fix and (active or main.inside_rv or near_rv)
	if is_instance_valid(_ladder_material):
		_ladder_material.emission_energy_multiplier=0.65 if near_interior_ladder() else 0.0


func near_interior_ladder() -> bool:
	if not GameState.roof_container_fixed or roof_interior_active or not main.inside_rv:return false
	return main.hotaru.global_position.distance_to(main.rv_interior.to_global(RV_LADDER_ANCHOR))<=1.48


func enter_roof_interior() -> void:
	if roof_interior_active or not near_interior_ladder():return
	roof_interior_active=true
	main.rv_interior.clear_interaction_focus()
	main.rv_interior.set_active(false)
	roof_interior.show()
	main.hotaru.set_ground_height(ROOF_INTERIOR_ORIGIN.y+0.95)
	main.hotaru.global_position=ROOF_INTERIOR_ORIGIN+Vector3(-0.53,0.95,-1.40)
	main.hotaru.rotation.y=0.0
	main.hotaru.set_active(true)
	_notice_message("小萤爬进了刚固定好的上层扩展舱。")


func near_roof_hatch() -> bool:
	return roof_interior_active and main.hotaru.global_position.distance_to(ROOF_INTERIOR_ORIGIN+ROOF_HATCH_ANCHOR)<=1.30


func interact_roof_interior() -> void:
	if not roof_interior_active:return
	if near_roof_hatch():
		exit_roof_interior()
	else:
		_notice_message("走回前端地板检修口，再从梯子下去。")


func exit_roof_interior(force: bool=false) -> void:
	if not roof_interior_active:return
	roof_interior_active=false
	roof_interior.hide()
	if not force:
		main.rv_interior.set_active(true)
		main.hotaru.set_ground_height(main.RV_INTERIOR_ORIGIN.y+1.13)
		main.hotaru.global_position=main.rv_interior.to_global(Vector3(-0.52,1.13,-3.72))
		main.hotaru.rotation.y=PI
		main.hotaru.set_active(true)
		_notice_message("小萤沿副驾驶侧梯子回到了驾驶舱。")


func update_roof_camera(delta: float) -> void:
	main.camera.projection=Camera3D.PROJECTION_PERSPECTIVE
	main.camera.keep_aspect=Camera3D.KEEP_HEIGHT
	main.camera.fov=58.0
	var target: Vector3=main.hotaru.global_position+Vector3(0,0.55,0)
	var forward: Vector3=-main.hotaru.global_transform.basis.z
	var desired:=target-forward*2.25+Vector3(0,1.05,0)
	# Keep the camera inside the narrow steel shell.
	desired.x=clampf(desired.x,ROOF_INTERIOR_ORIGIN.x-0.88,ROOF_INTERIOR_ORIGIN.x+0.88)
	desired.z=clampf(desired.z,ROOF_INTERIOR_ORIGIN.z-2.55,ROOF_INTERIOR_ORIGIN.z+2.55)
	desired.y=clampf(desired.y,1.20,2.35)
	main.camera.global_position=main.camera.global_position.lerp(desired,1.0-exp(-delta*8.0))
	main.camera.look_at(target,Vector3.UP)


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
	controls.show()
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
