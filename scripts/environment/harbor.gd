extends Node

# First playable harbor slice: drive the mobile crane, hoist any marked cargo,
# and temporarily place one 20-foot container on the RV roof.
const CRANE_START := Vector3(-122.0, 0.12, -216.0)
const CRANE_TRAVEL := Rect2(-145.0, -221.0, 270.0, 16.0)
const SPREADER_Z := 27.23
const SPREADER_BOTTOM := 8.72
const HOIST_MIN := -6.0
const HOIST_MAX := 0.0
const ROOF_BOTTOM_LOCAL_Y := 1.58
const CRANE_SPEED := 5.2

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

var _cargo_specs := [
	{"id":"C20-A", "model":"container_20_old", "length":6.06, "height":2.766, "position":Vector3(-126,0.16,-188)},
	{"id":"C20-B", "model":"container_20_blue", "length":6.06, "height":2.766, "position":Vector3(-118.6,0.16,-188)},
	{"id":"C20-C", "model":"container_20_red", "length":6.06, "height":2.766, "position":Vector3(-118.6,2.926,-188)},
	{"id":"C20-D", "model":"container_20_blue", "length":6.06, "height":2.766, "position":Vector3(-111.2,0.16,-188)},
	{"id":"C20-E", "model":"container_20_red", "length":6.06, "height":2.766, "position":Vector3(-126,0.16,-196)},
	{"id":"C20-F", "model":"container_20_old", "length":6.06, "height":2.766, "position":Vector3(-118.6,0.16,-196)},
	{"id":"C40-A", "model":"container_40_blue", "length":12.19, "height":2.954, "position":Vector3(-91,0.16,-190)},
	{"id":"C40-B", "model":"container_40_blue", "length":12.19, "height":2.954, "position":Vector3(-75.5,0.16,-190)},
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
	# Painted cargo lanes and an RV alignment bay below the crane's fixed boom.
	for z in [-204.0,-196.0,-188.0,-180.0,-172.0]:
		_box("CargoLane",Vector3(292,0.018,0.16),Vector3(0,0.125,z),Color("c5bb82"))
	for x in range(-140,141,10):
		_box("QuayEdgeMark",Vector3(5.5,0.025,0.55),Vector3(x,0.13,-223.5),Color("e2c74d"))
	for line in [
		[Vector3(68,0.14,-192),Vector3(14,0.025,0.22)],
		[Vector3(68,0.14,-180),Vector3(14,0.025,0.22)],
		[Vector3(61,0.14,-186),Vector3(0.22,0.025,12)],
		[Vector3(75,0.14,-186),Vector3(0.22,0.025,12)],
	]:
		_box("RVLiftBayLine",line[1],line[0],Color("78d6cf"))
	main._add_label("房车吊装位 · 车身横向停入",Vector3(68,0.65,-186),Color("a6fff4"),24).no_depth_test=false
	main._add_label("南部集装箱码头",Vector3(0,4.0,-219),Color("ffe6a1"),34).no_depth_test=false
	for x in range(-145,151,18):
		var bollard := _cylinder("MooringBollard",0.34,0.65,Vector3(x,0.43,-222.5),Color("30383a"),true)
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
	for x in [-2.7,2.7]:
		for z in [26.75,27.75]:
			_box_to(cable_root,"HoistCable",Vector3(0.045,1,0.045),Vector3(x,18,z),Color("202526"))
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
	_update_spreader()
	controls.hide()
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
		_notice_message("20 尺集装箱已临时落在车顶！尚未获得五金件，当前为试装状态。")


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
