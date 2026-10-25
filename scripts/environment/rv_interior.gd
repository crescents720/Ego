extends Node3D

const MODEL_PATH := "res://assets/models/rv_interior_initial.glb"
# Same longitudinal fraction as exterior door Z=-1.05 on an 8.59 m RV.
const SIDE_DOOR_Z := -2.41
const SIDE_ENTRY := Vector3(0.70, 1.13, SIDE_DOOR_Z)

const INTERACTION_RANGE := 1.42

const MODULE_SLOTS := {
	"SOCKET_FLOOR_CENTER": {
		"type": "floor_module",
		"initial_use": "预留制造设备",
		"power_bus": true,
	},
	"SOCKET_WALL_LEFT": {
		"type": "wall_module",
		"initial_use": "预留储物或医疗墙",
		"power_bus": true,
	},
	"SOCKET_WALL_RIGHT": {
		"type": "wall_module",
		"initial_use": "预留生活设施",
		"power_bus": true,
	},
	"SOCKET_CEILING_REAR": {
		"type": "ceiling_module",
		"initial_use": "预留无人机/机械吊架",
		"power_bus": true,
	},
}

const INTERACTIVE_MODULES := {
 "gun_left":{"name":"左侧窗口","anchor":Vector3(-.55,1.13,1.12),"prefixes":["ShootingWindow_L"],"description":"通用窗口。当前可架设货舱中的机枪。"},
 "gun_right":{"name":"右侧窗口","anchor":Vector3(.87,1.13,.91),"prefixes":["ShootingWindow_R"],"description":"通用窗口。当前可将机枪移到此处使用。"},
	"fridge": {
		"name": "小冰箱",
		"anchor": Vector3(-0.90, 0.70, 1.03),
		"prefixes": ["Fridge"],
		"description": "制冷系统状态正常。初始容量为 18 升，之后可升级为药品冷藏柜。",
	},
	"wardrobe": {
		"name": "衣柜",
		"anchor": Vector3(-1.02, 1.00, -3.13),
		"prefixes": ["Wardrobe"],
		"description": "存放小萤的日常衣物与防护服。当前只有基础便装栏位。",
	},
	"power": {
		"name": "电力柜",
		"anchor": Vector3(-1.00, 0.78, -1.16),
		"prefixes": ["Power", "Battery"],
		"description": "剩余电量 62%。四条扩建母线已经接通，但大功率设备仍需要新的电池组。",
	},
	"galley": {
		"name": "厨房操作台",
		"anchor": Vector3(-0.88, 0.92, 0.10),
		"prefixes": ["Galley", "Sink", "Faucet", "Cooktop", "Induction", "Kettle"],
		"description": "这里可以烹饪、处理饮用水。净水滤芯已经接近寿命上限。",
	},
	"dinette": {
		"name": "折叠卡座",
		"anchor": Vector3(0.75, 0.82, 0.0),
		"prefixes": ["Dinette", "TeaMug"],
		"description": "既是餐桌，也是地图规划区；放平后可以作为一张临时床铺。",
	},
	"workbench": {
		"name": "基础维修台",
		"anchor": Vector3(-0.70, 0.92, -2.04),
		"prefixes": ["Workbench", "HandTool", "TaskLamp"],
		"description": "现阶段只能维修简单工具。安装加工模块后可以制作武器、装甲和机械零件。",
	},
	"storage": {
		"name": "生存物资箱",
		"anchor": Vector3(0.80, 0.52, -3.25),
		"prefixes": ["SurvivalCrate"],
		"description": "储物功能稍后开放。随身背包与装备请点击左上角小萤的头像。",
	},
	"bed": {
		"name": "睡眠舱",
		"anchor": Vector3(0.0, 0.92, 1.88),
		"prefixes": ["Bed", "Mattress", "Blanket", "Pillow", "UnderBed", "BrotherPhoto"],
		"description": "休息可以推进时间并恢复状态。哥哥的照片还放在原来的位置。",
	},
	"medical": {
		"name": "急救箱",
		"anchor": Vector3(-1.10, 1.28, -1.75),
		"prefixes": ["Medical"],
		"description": "里面只有少量绷带和消毒用品；升级医疗墙后可以处理更严重的伤势。",
	},
	"driver_seat": {
		"name": "驾驶座",
		"anchor": Vector3(0.72, 0.78, -4.04),
		"prefixes": ["DriverSeat"],
		"description": "坐上驾驶座后可以启动房车。",
	},
}

var _model: Node3D
var _replaced_shell: Array[Node3D] = []
var _driver_seat_marker: Node3D
var _driver_stand_marker: Node3D
var _lights: Array[OmniLight3D] = []
var _module_meshes: Dictionary = {}
var _focused_module_id: String = ""
var _highlight_material: StandardMaterial3D
var _highlight_time: float = 0.0
var _ceiling_cutaway_nodes: Array[Node3D] = []
var _left_cutaway_nodes: Array[Node3D] = []
var _right_cutaway_nodes: Array[Node3D] = []
var _front_cutaway_nodes: Array[Node3D] = []
var _rear_cutaway_nodes: Array[Node3D] = []
var wardrobe_open := false
var _wardrobe_hinges: Array[Node3D]=[]
var _wardrobe_tween: Tween
var wardrobe_bat: Node3D
var _bat_label: Label3D
var _wardrobe_light: OmniLight3D


func _ready() -> void:
	name = "RVInteriorInitial"
	_build_model()
	_adapt_side_door_layout()
	_adapt_shooting_windows()
	_build_openable_wardrobe()
	_build_highlight_material()
	_cache_model_groups()
	_build_collision_shell()
	_build_mobile_lighting()
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	GameState.inventory_changed.connect(sync_wardrobe)
	sync_wardrobe()

func _build_openable_wardrobe() -> void:
	var old_body: MeshInstance3D=_model.find_child("Wardrobe_Body",true,false)
	if not is_instance_valid(old_body):return
	var bounds: AABB=_model.global_transform.affine_inverse()*old_body.global_transform*old_body.get_aabb()
	var center:=bounds.get_center()
	var size:=bounds.size
	for node in _model.find_children("Wardrobe*","MeshInstance3D",true,false):
		node.hide()
		_replaced_shell.append(node)
	var wood:=_door_material(Color("8b8e7c"))
	var dark:=_door_material(Color("353e38"))
	var metal:=_door_material(Color("c6bf9f"))
	# Hollow cabinet replaces the original solid furniture block.
	for data in [
		[Vector3(0.045,size.y,size.z),center-Vector3(size.x/2-0.025,0,0)],
		[Vector3(size.x,0.045,size.z),center+Vector3(0,size.y/2-0.025,0)],
		[Vector3(size.x,0.045,size.z),center-Vector3(0,size.y/2-0.025,0)],
		[Vector3(size.x,size.y,0.045),center+Vector3(0,0,size.z/2-0.025)],
		[Vector3(size.x,size.y,0.045),center-Vector3(0,0,size.z/2-0.025)]]:
		_wardrobe_box(_model,data[0],data[1],dark)
	for side in range(2):
		var direction:=1.0 if side==0 else -1.0
		var hinge:=Node3D.new()
		hinge.name="WardrobeHinge"+str(side)
		hinge.position=Vector3(bounds.end.x+0.02,center.y,bounds.position.z if side==0 else bounds.end.z)
		_model.add_child(hinge)
		_wardrobe_hinges.append(hinge)
		_wardrobe_box(hinge,Vector3(0.035,size.y-0.06,size.z/2-0.015),Vector3(0,0,direction*size.z/4),wood)
		_wardrobe_box(hinge,Vector3(0.055,0.16,0.025),Vector3(0.04,0,direction*(size.z/2-0.07)),metal)
	wardrobe_bat=load("res://assets/items/baseball_bat/bat.glb").instantiate()
	wardrobe_bat.name="BrothersBaseballBat"
	wardrobe_bat.position=Vector3(center.x+0.05,bounds.position.y+0.08,center.z)
	wardrobe_bat.rotation.x=deg_to_rad(9)
	_model.add_child(wardrobe_bat)
	_wardrobe_light=OmniLight3D.new()
	_wardrobe_light.position=Vector3(bounds.end.x+0.20,center.y+0.35,center.z)
	_wardrobe_light.light_color=Color("ffdda5")
	_wardrobe_light.light_energy=0.65
	_wardrobe_light.omni_range=1.4
	_wardrobe_light.shadow_enabled=false
	_model.add_child(_wardrobe_light)
	_bat_label=Label3D.new()
	_bat_label.text="哥哥的棒球棍 · 0.90 kg"
	_bat_label.position=Vector3(bounds.end.x+0.03,center.y+0.75,center.z)
	_bat_label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	_bat_label.font_size=22
	_bat_label.modulate=Color("ffe3a4")
	_model.add_child(_bat_label)

func _wardrobe_box(parent: Node,size: Vector3,point: Vector3,material: Material) -> void:
	var mesh:=MeshInstance3D.new()
	mesh.name="WardrobePanel"
	var box:=BoxMesh.new()
	box.size=size
	mesh.mesh=box
	mesh.position=point
	mesh.material_override=material
	parent.add_child(mesh)

func set_wardrobe_open(value: bool,instant: bool=false) -> void:
	wardrobe_open=value
	if is_instance_valid(_wardrobe_tween):_wardrobe_tween.kill()
	if not instant:_wardrobe_tween=create_tween().set_parallel()
	for i in range(_wardrobe_hinges.size()):
		var angle:=deg_to_rad(125)*(1 if i==0 else -1) if value else 0.0
		if instant:_wardrobe_hinges[i].rotation.y=angle
		else:_wardrobe_tween.tween_property(_wardrobe_hinges[i],"rotation:y",angle,0.48).set_trans(Tween.TRANS_SINE)
	sync_wardrobe()

func sync_wardrobe() -> void:
	if is_instance_valid(wardrobe_bat):wardrobe_bat.visible=not GameState.bat_taken
	if is_instance_valid(_bat_label):_bat_label.visible=wardrobe_open and not GameState.bat_taken
	if is_instance_valid(_wardrobe_light):_wardrobe_light.visible=wardrobe_open


func _process(delta: float) -> void:
	if _focused_module_id.is_empty():
		return
	_highlight_time += delta
	var pulse := 0.25 + sin(_highlight_time * 5.2) * 0.10
	_highlight_material.emission_energy_multiplier = pulse
	var color := _highlight_material.albedo_color
	color.a = 0.06 + (sin(_highlight_time * 5.2) + 1.0) * 0.025
	_highlight_material.albedo_color = color


func set_active(value: bool) -> void:
	visible = value
	process_mode = Node.PROCESS_MODE_INHERIT if value else Node.PROCESS_MODE_DISABLED
	for light in _lights:
		light.visible = value
	if not value:
		clear_interaction_focus()


func get_entry_position() -> Vector3:
	return to_global(SIDE_ENTRY)


func is_near_exit(player_position: Vector3) -> bool:
	var local_player := to_local(player_position)
	return local_player.x > 0.30 and absf(local_player.z - SIDE_DOOR_Z) < 0.62


func get_driver_seat_position() -> Vector3:
	if is_instance_valid(_driver_seat_marker):
		# The marker is the cushion surface; Sit places the pelvis 0.41 m above
		# the model feet origin, which is 0.93 m below the body root.
		return _driver_seat_marker.global_position + Vector3(0.0, 0.52, 0.0)
	return global_position + Vector3(0.68, 0.74, -4.60)


func get_driver_stand_position() -> Vector3:
	if is_instance_valid(_driver_stand_marker):
		return _driver_stand_marker.global_position + Vector3(0.0, 0.93, 0.0)
	return global_position + Vector3(0.10, 1.13, -4.32)


func get_camera_pivot() -> Vector3:
	return global_position + Vector3(0.0, 0.84, -1.15)


func get_module_slots() -> Dictionary:
	return MODULE_SLOTS.duplicate(true)


func update_interaction_focus(player_global_position: Vector3) -> String:
	var player_local_position := to_local(player_global_position)
	var nearest_id := ""
	var nearest_distance := INF
	for module_id in INTERACTIVE_MODULES:
		var module_data: Dictionary = INTERACTIVE_MODULES[module_id]
		var distance: float = player_local_position.distance_to(module_data.anchor)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_id = module_id
	if nearest_distance > INTERACTION_RANGE:
		nearest_id = ""
	_set_focused_module(nearest_id)
	if nearest_id.is_empty():
		return ""
	return str(INTERACTIVE_MODULES[nearest_id].name)


func clear_interaction_focus() -> void:
	_set_focused_module("")


func get_focused_interaction() -> Dictionary:
	if _focused_module_id.is_empty():
		return {}
	var result: Dictionary = INTERACTIVE_MODULES[_focused_module_id].duplicate(true)
	if _focused_module_id=="workbench" and GameState.lathe_installed:
		result["name"]="车床 · 生产铁丝围栏"
	result["id"] = _focused_module_id
	return result


func update_camera_cutaway(camera_global_position: Vector3) -> void:
	var camera_local_position := to_local(camera_global_position)
	for node in _ceiling_cutaway_nodes:
		node.visible = false
	var hide_right := camera_local_position.x >= 0.0
	for node in _right_cutaway_nodes:
		node.visible = not hide_right
	for node in _left_cutaway_nodes:
		node.visible = hide_right
	var hide_front := camera_local_position.z >= 0.0
	for node in _front_cutaway_nodes:
		node.visible = not hide_front
	for node in _rear_cutaway_nodes:
		node.visible = hide_front


func _build_model() -> void:
	if not ResourceLoader.exists(MODEL_PATH):
		push_error("Missing RV interior model: " + MODEL_PATH)
		return
	var resource := load(MODEL_PATH)
	if not resource is PackedScene:
		push_error("RV interior model was not imported as a PackedScene")
		return
	_model = resource.instantiate()
	_model.name = "DetailedInteriorModel"
	add_child(_model)
	# Module sockets are authoring markers, not visible furniture.
	for mesh in _model.find_children("SOCKET_*_Plate", "MeshInstance3D", true, false):
		mesh.hide()
	_driver_seat_marker = _find_descendant(_model, "MARKER_DRIVER_SEAT") as Node3D
	_driver_stand_marker = _find_descendant(_model, "MARKER_DRIVER_STAND") as Node3D


func _adapt_side_door_layout() -> void:
	# Adapt the existing authored interior without overwriting its source GLB.
	for node in _model.find_children("*", "MeshInstance3D", true, false):
		var n := str(node.name)
		if n.begins_with("Wardrobe"):
			node.position.x -= 2.05
			node.position.z = -3.13 + (node.position.z + 1.83) * 0.70
			node.scale.z *= 0.70
		elif n.begins_with("Workbench") or n.begins_with("HandTool") or n.begins_with("TaskLamp"):
			node.position.z = -2.04 + (node.position.z + 2.15) * 0.80
			node.scale.z *= 0.80
			if n == "WorkbenchPegboard":
				node.position.x = -1.28
				node.position.z = -2.04
				node.rotation.y += PI / 2
			elif n == "WorkbenchScreen":
				node.position.x = -1.20
				node.position.z = -2.04
				node.rotation.y += PI / 2
		elif n.begins_with("Medical"):
			node.position.x -= 2.32
			node.position.z += 0.85
		elif n.begins_with("SurvivalCrate") and node.position.x > 0:
			node.position.z -= 0.31
		# Remove the continuous low sidewall and the one window pane/post
		# crossing the new doorway; replacement pieces keep the opening clear.
		if n == "LowerWall_R" or (n.begins_with("WindowPost_R") and absf(node.position.z - SIDE_DOOR_Z) < 0.6) or (n.begins_with("WindowGlass_R") and absf(node.position.z - SIDE_DOOR_Z) < 0.75):
			node.hide()
			_replaced_shell.append(node)
	var shell := _door_material(Color("c9c7b9"))
	var frame := _door_material(Color("47595c"))
	var glass := _door_material(Color("456e79"))
	# Existing right wall spans -5.90..3.50. Keep its low panels outside door.
	var front_end := SIDE_DOOR_Z - 0.55
	var rear_start := SIDE_DOOR_Z + 0.55
	_door_box("LowerWall_R_Cab", Vector3(0.12,0.68,front_end + 5.90), Vector3(1.37,0.52,(front_end-5.90)/2), shell)
	_door_box("LowerWall_R_Living", Vector3(0.12,0.68,3.50 - rear_start), Vector3(1.37,0.52,(rear_start+3.50)/2), shell)
	_door_box("SideDoor_Panel_R", Vector3(0.07,1.83,1.02), Vector3(1.35,1.11,SIDE_DOOR_Z), shell)
	_door_box("SideDoor_Window_R", Vector3(0.08,0.48,0.62), Vector3(1.30,1.58,SIDE_DOOR_Z), glass)
	for z in [SIDE_DOOR_Z-0.56, SIDE_DOOR_Z+0.56]:
		_door_box("SideDoor_Frame_R", Vector3(0.14,2.02,0.075), Vector3(1.34,1.19,z), frame)
	_door_box("SideDoor_Header_R", Vector3(0.14,0.09,1.20), Vector3(1.34,2.17,SIDE_DOOR_Z), frame)
	_door_box("SideDoor_Handle_R", Vector3(0.13,0.035,0.17), Vector3(1.25,1.0,SIDE_DOOR_Z+0.35), frame)
	_door_box("SideDoor_Step", Vector3(0.62,0.035,1.04), Vector3(1.02,0.20,SIDE_DOOR_Z), _door_material(Color("cf9a4e")))
	var label := Label3D.new()
	label.text = "右侧车门 · E 下车"
	label.position = Vector3(0.95,2.02,SIDE_DOOR_Z)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 26
	label.outline_size = 7
	label.modulate = Color("ffe0a0")
	add_child(label)


func _door_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	return material


func _door_box(node_name: String, size_value: Vector3, position_value: Vector3, material: Material) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	var box := BoxMesh.new()
	box.size = size_value
	mesh.mesh = box
	mesh.position = position_value
	mesh.material_override = material
	_model.add_child(mesh)


func _build_highlight_material() -> void:
	_highlight_material = StandardMaterial3D.new()
	_highlight_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_highlight_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_highlight_material.albedo_color = Color(1.0, 0.72, 0.28, 0.10)
	_highlight_material.emission_enabled = true
	_highlight_material.emission = Color(1.0, 0.63, 0.21)
	_highlight_material.emission_energy_multiplier = 0.3
	_highlight_material.cull_mode = BaseMaterial3D.CULL_DISABLED


func _cache_model_groups() -> void:
	for module_id in INTERACTIVE_MODULES:
		_module_meshes[module_id] = []
	_collect_model_nodes(_model)


func _collect_model_nodes(node: Node) -> void:
	if node in _replaced_shell:
		return
	var node_name := str(node.name)
	if node is Node3D:
		if (
			node_name.begins_with("CeilingRib_")
			or node_name.begins_with("CockpitRoof")
			or node_name == "CabTransitionHeader"
		):
			_ceiling_cutaway_nodes.append(node)
		if node_name.contains("_L") and (
			node_name.begins_with("LowerWall_")
			or node_name.begins_with("UpperRail_")
			or node_name.begins_with("LEDChannel_")
			or node_name.begins_with("WindowPost_")
			or node_name.begins_with("WindowGlass_")
			or node_name.begins_with("CockpitSideWindow_")
			or node_name.begins_with("CockpitA_Pillar_")
			or node_name.begins_with("CockpitB_Pillar_")
			or node_name.begins_with("CockpitDoorSill_")
			or node_name.begins_with("CabTransitionPost_")
			or node_name.begins_with("SideDoor_")
		):
			_left_cutaway_nodes.append(node)
		if node_name.contains("_R") and (
			node_name.begins_with("LowerWall_")
			or node_name.begins_with("UpperRail_")
			or node_name.begins_with("LEDChannel_")
			or node_name.begins_with("WindowPost_")
			or node_name.begins_with("WindowGlass_")
			or node_name.begins_with("CockpitSideWindow_")
			or node_name.begins_with("CockpitA_Pillar_")
			or node_name.begins_with("CockpitB_Pillar_")
			or node_name.begins_with("CockpitDoorSill_")
			or node_name.begins_with("CabTransitionPost_")
			or node_name.begins_with("SideDoor_")
		):
			_right_cutaway_nodes.append(node)
		if node_name in ["FrontBulkhead", "FrontWindow"]:
			_front_cutaway_nodes.append(node)
		if node_name.begins_with("RearWall") or node_name == "RearDoorHeader":
			_rear_cutaway_nodes.append(node)
		if node_name in ["CockpitWindshield", "CockpitWindshieldHeader", "CockpitNoseLower"]:
			_rear_cutaway_nodes.append(node)
	if node is MeshInstance3D:
		for module_id in INTERACTIVE_MODULES:
			var prefixes: Array = INTERACTIVE_MODULES[module_id].prefixes
			for prefix in prefixes:
				if node_name.begins_with(str(prefix)):
					(_module_meshes[module_id] as Array).append(node)
					break
	for child in node.get_children():
		_collect_model_nodes(child)


func _set_focused_module(module_id: String) -> void:
	if module_id == _focused_module_id:
		return
	if not _focused_module_id.is_empty():
		for mesh in _module_meshes.get(_focused_module_id, []):
			if is_instance_valid(mesh):
				mesh.material_overlay = null
	_focused_module_id = module_id
	_highlight_time = 0.0
	if _focused_module_id.is_empty():
		return
	for mesh in _module_meshes.get(_focused_module_id, []):
		if is_instance_valid(mesh):
			mesh.material_overlay = _highlight_material


func _find_descendant(parent: Node, target_name: String) -> Node:
	if parent.name == target_name:
		return parent
	for child in parent.get_children():
		var result := _find_descendant(child, target_name)
		if result:
			return result
	return null


func _build_collision_shell() -> void:
	_add_collision("Floor", Vector3(2.68, 0.16, 9.50), Vector3(0.0, 0.06, -1.25))
	_add_collision("LeftWall", Vector3(0.12, 2.4, 9.50), Vector3(-1.37, 1.2, -1.25))
	_add_collision("RightWall", Vector3(0.12, 2.4, 9.50), Vector3(1.37, 1.2, -1.25))
	_add_collision("FrontWall", Vector3(2.7, 2.4, 0.12), Vector3(0.0, 1.2, 3.50))
	_add_collision("CockpitNose", Vector3(2.7, 1.45, 0.16), Vector3(0.0, 0.72, -6.00))
	_add_collision("Dashboard", Vector3(2.42, 0.86, 0.50), Vector3(0.0, 0.65, -5.20))
	# The decorative passenger seat must not obstruct the ladder access route.
	# Keep its visual model, but allow Hotaru to walk through it.
	_add_collision("DriverSeat", Vector3(0.64, 0.88, 0.70), Vector3(0.67, 0.44, -4.04))

	# Coarse furniture collision keeps navigation stable on mobile while the
	# visual GLB can continue gaining small detail without rebuilding physics.
	_add_collision("Bed", Vector3(2.45, 1.02, 1.72), Vector3(0.0, 0.60, 2.58))
	_add_collision("Galley", Vector3(0.70, 1.10, 1.70), Vector3(-1.0, 0.55, -0.25))
	_add_collision("DinetteRear", Vector3(0.72, 1.25, 0.72), Vector3(0.96, 0.62, -0.70))
	_add_collision("Workbench", Vector3(0.92, 1.15, 1.34), Vector3(-0.78, 0.58, -2.04))
	_add_collision("Wardrobe", Vector3(0.58, 2.05, 0.66), Vector3(-1.02, 1.03, -3.13))


func _add_collision(node_name: String, size_value: Vector3, position_value: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position_value
	body.collision_layer = 1
	body.collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size_value
	collision.shape = shape
	body.add_child(collision)
	add_child(body)


func _build_mobile_lighting() -> void:
	for light_data in [
		{"position": Vector3(-0.72, 2.18, 1.35), "energy": 1.35, "color": Color("ffc985")},
		{"position": Vector3(0.72, 2.18, -0.15), "energy": 1.15, "color": Color("ffd9a5")},
		{"position": Vector3(-0.48, 2.12, -2.25), "energy": 1.25, "color": Color("ffb46f")},
		{"position": Vector3(0.35, 2.05, -4.65), "energy": 1.05, "color": Color("ffd7a0")},
	]:
		var light := OmniLight3D.new()
		light.position = light_data.position
		light.light_color = light_data.color
		light.light_energy = light_data.energy
		light.omni_range = 4.6
		light.shadow_enabled = false
		add_child(light)
		_lights.append(light)




func _adapt_shooting_windows() -> void:
	for node in _model.find_children("*","MeshInstance3D",true,false):
		var n:=str(node.name)
		var remove: bool=n.begins_with("GalleyOverhead_A") or n.begins_with("RouteMap") or n.begins_with("MapRoute_") or (n.begins_with("Dinette") and n.ends_with("_Front")) or n=="DinetteWallShelf" or (n.begins_with("WindowGlass_") and absf(node.position.z-.91)<.1)
		if remove:
			node.hide()
			_replaced_shell.append(node)
			continue
		if n.begins_with("Galley") or n.begins_with("Cooktop") or n.begins_with("Induction") or n.begins_with("Sink") or n.begins_with("Faucet") or n.begins_with("Kettle") or n.begins_with("Fridge"):
			node.position.z=-.25+(node.position.z-.27)*.75
			node.scale.z*=.75
	var metal:=_door_material(Color("42585a"))
	var trim:=_door_material(Color("b4b49a"))
	for side in [-1,1]:
		var prefix: String="ShootingWindow_"+("L" if side<0 else "R")
		for z in [.12,1.70]:_door_box(prefix+"_Jamb",Vector3(.14,1.10,.075),Vector3(side*1.33,1.58,z),metal)
		for y in [1.05,2.11]:_door_box(prefix+"_Frame",Vector3(.15,.08,1.65),Vector3(side*1.33,y,.91),metal)
		_door_box(prefix+"_Mount",Vector3(.36,.08,.65),Vector3(side*1.13,1.13,.91),trim)
		_door_box(prefix+"_Rest",Vector3(.11,.22,.14),Vector3(side*1.10,1.25,.91),metal)
		var label:=Label3D.new()
		label.text=("左" if side<0 else "右")+"侧窗口"
		label.position=Vector3(side*.90,2.15,.91)
		label.font_size=24
		label.pixel_size=.0035
		label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
		add_child(label)
