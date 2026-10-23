extends Node3D

# The temple remains part of the town instead of loading a disconnected room.
# Only the marked front gate starts close third-person exploration.  Approaching
# the open veranda from either side never changes camera mode.
const SITE := Vector3(-94.0, 0.08, 345.0)
const MODEL_DECK_RISE := 1.60
const OUTDOOR_GROUND_Y := 0.95
const TEMPLE_GROUND_Y := SITE.y + MODEL_DECK_RISE + OUTDOOR_GROUND_Y
const EXIT_HALF := Vector2(7.75, 6.85)
const FRONT_DOOR_LOCAL := Vector3(0.0, OUTDOOR_GROUND_Y - SITE.y, -9.15)
const FRONT_ENTRY_LOCAL := Vector3(0.0, TEMPLE_GROUND_Y - SITE.y, -5.85)
const FRONT_DOOR_RANGE := 2.35
const FRONT_EXIT_RANGE := 2.10
const DOOR := SITE + FRONT_DOOR_LOCAL
const ALTAR_LOCAL := Vector3(0.0, MODEL_DECK_RISE, 2.15)
const RACK := SITE + ALTAR_LOCAL + Vector3(0.0, 0.78, 0.0)

var main
var active := false
var model: Node3D
var altar: Node3D
var sword: Node3D
var label: Label3D
var entrance_label: Label3D
var yaw := PI
var pitch := 0.20
var aim_finger := -1
var dragging := false
var return_position := Vector3.ZERO
var outdoor_states: Array = []
var population_was_processing := true
var _entry_lock := 0.0


func build(owner_main) -> void:
	main = owner_main
	name = "ShinobiTemple"
	process_mode = Node.PROCESS_MODE_ALWAYS

	main.town_layout._box("TempleForecourt", Vector3(25.0, 0.05, 10.0), SITE + Vector3(0.0, -0.025, -14.0), "77786a")
	model = load("res://assets/temple/temple.glb").instantiate()
	model.name = "OpenTempleShell"
	model.position = SITE
	model.rotation.y = PI
	main.world_root.add_child(model)
	main.town_occlusion.register_building(model)
	main.town_layout._add_building_collision(model, "ShinobiTemple")

	# A compact timber gate at the foot of the existing front stair makes the
	# single valid entrance legible in both the orthographic town view and on a
	# phone screen.  It is a marker, not another opaque wall.
	var gate := Node3D.new()
	gate.name = "TempleFrontGate"
	main.world_root.add_child(gate)
	for x in [-1.75, 1.75]:
		_box(gate, Vector3(0.28, 2.55, 0.28), DOOR + Vector3(x, 1.275, 0.0), Color("4a2924"), true)
	_box(gate, Vector3(4.15, 0.30, 0.34), DOOR + Vector3(0.0, 2.52, 0.0), Color("68352d"))
	_box(gate, Vector3(3.55, 0.16, 0.42), DOOR + Vector3(0.0, 2.83, 0.0), Color("2f2522"))
	entrance_label = Label3D.new()
	entrance_label.name = "TempleEntranceMarker"
	entrance_label.text = "寺庙正门 · E 进入"
	entrance_label.position = DOOR + Vector3(0.0, 3.25, 0.0)
	entrance_label.font_size = 30
	entrance_label.outline_size = 8
	entrance_label.modulate = Color("f2dfaa")
	entrance_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	gate.add_child(entrance_label)

	# A quiet central offering platform makes the first real weapon feel earned.
	# The odachi rests horizontally on a dark timber stand, lit by two warm lamps.
	altar = Node3D.new()
	altar.name = "OdachiOfferingAltar"
	main.world_root.add_child(altar)
	_box(altar, Vector3(3.20, 0.34, 1.45), SITE + ALTAR_LOCAL + Vector3(0.0, 0.17, 0.0), Color("3b2923"), true)
	_box(altar, Vector3(2.75, 0.035, 0.92), SITE + ALTAR_LOCAL + Vector3(0.0, 0.36, 0.0), Color("7f2630"))
	for x in [-0.72, 0.72]:
		_box(altar, Vector3(0.12, 0.50, 0.18), SITE + ALTAR_LOCAL + Vector3(x, 0.58, 0.0), Color("241d1a"))
	_box(altar, Vector3(1.68, 0.10, 0.20), SITE + ALTAR_LOCAL + Vector3(0.0, 0.78, 0.0), Color("241d1a"))
	for x in [-1.22, 1.22]:
		_box(altar, Vector3(0.28, 0.40, 0.28), SITE + ALTAR_LOCAL + Vector3(x, 0.55, 0.0), Color("5c392a"))
		var lamp := OmniLight3D.new()
		lamp.name = "OfferingLamp"
		lamp.position = SITE + ALTAR_LOCAL + Vector3(x, 0.88, 0.0)
		lamp.light_color = Color("ffd49a")
		lamp.light_energy = 1.15
		lamp.omni_range = 4.8
		lamp.shadow_enabled = false
		altar.add_child(lamp)

	sword = load("res://assets/temple/odachi.glb").instantiate()
	sword.name = "TempleOdachi"
	sword.position = RACK + Vector3(-0.47, 0.11, -0.01)
	sword.rotation.z = -PI / 2.0
	altar.add_child(sword)

	label = Label3D.new()
	label.name = "OdachiMarker"
	label.position = RACK + Vector3(0.0, 0.80, 0.0)
	label.font_size = 30
	label.outline_size = 7
	label.modulate = Color("f4dfa0")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	altar.add_child(label)
	GameState.inventory_changed.connect(refresh)
	refresh()


func _box(parent: Node, size: Vector3, point: Vector3, color: Color, solid: bool = false) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = point
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	mesh.material_override = material
	parent.add_child(mesh)
	if solid:
		var body := StaticBody3D.new()
		body.collision_layer = 3
		body.collision_mask = 0
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		body.position = point
		body.add_child(collision)
		parent.add_child(body)
	return mesh


func refresh() -> void:
	if not is_instance_valid(sword) or not is_instance_valid(label):
		return
	sword.visible = not GameState.odachi_taken
	label.visible = active
	entrance_label.visible = not active
	label.text = "奉纳台 · 大太刀 E 拾取" if not GameState.odachi_taken else "奉纳台 · 空刀架"


func _process(delta: float) -> void:
	_entry_lock = maxf(0.0, _entry_lock - delta)
	if not is_instance_valid(main) or not is_instance_valid(main.hotaru):
		return
	if active:
		if get_tree().paused or not main.controls_enabled:
			dragging = false
			aim_finger = -1
			return
		var local := _flat_local(main.hotaru.global_position)
		if absf(local.x) > EXIT_HALF.x or absf(local.y) > EXIT_HALF.y:
			leave()
		return
	# Entry is interaction-only.  Merely walking around the open sides must not
	# toggle perspective back and forth.


func _can_enter() -> bool:
	return (
		main.controls_enabled
		and not main.in_vehicle
		and not main.inside_rv
		and not main.inside_store
		and not main.factory.active
		and not main.factory.transitioning
		and (not is_instance_valid(main.weapon_shop) or not main.weapon_shop.active)
		and main.phase not in [main.Phase.TITLE, main.Phase.GAME_OVER, main.Phase.COMPLETE]
	)


func _flat_local(point: Vector3) -> Vector2:
	return Vector2(point.x - SITE.x, point.z - SITE.z)


func near_entrance() -> bool:
	if active or _entry_lock > 0.0 or not _can_enter():
		return false
	var delta := Vector2(main.hotaru.global_position.x - DOOR.x, main.hotaru.global_position.z - DOOR.z)
	return delta.length() <= FRONT_DOOR_RANGE


func near_exit() -> bool:
	if not active:
		return false
	var local := _flat_local(main.hotaru.global_position)
	return absf(local.x) <= FRONT_EXIT_RANGE and local.y <= -5.15


func enter() -> void:
	if not near_entrance():
		return
	active = true
	return_position = main.hotaru.global_position

	main.mobile_joystick.reset()
	# The raised wooden veranda is intentionally pedestrian-only. The trolley
	# remains safely at the approach point and can be picked up again on exit.
	if is_instance_valid(main.trolley) and main.trolley.pushing:
		main.trolley.release()
	main.hotaru.velocity = Vector3.ZERO
	main.hotaru.set_ground_height(TEMPLE_GROUND_Y)
	main.hotaru.global_position = SITE + FRONT_ENTRY_LOCAL
	main.hotaru.rotation.y = 0.0
	yaw = main.hotaru.rotation.y
	pitch = 0.20
	dragging = false
	aim_finger = -1
	_pause_outdoor_zombies()
	refresh()
	update_camera(0.0)
	main.rest_notice("寺庙是安全区域。大太刀供奉在正殿中央，从正门交互离开。")


func leave(silent: bool = false) -> void:
	if not active:
		return
	active = false
	dragging = false
	aim_finger = -1
	for mesh in main.hotaru._body_meshes:
		mesh.transparency = 0.0
	main.hotaru.set_ground_height(OUTDOOR_GROUND_Y)
	main.hotaru.global_position = return_position + Vector3(0.0, 0.0, -0.70)
	main.hotaru.velocity = Vector3.ZERO
	_restore_outdoor_zombies()
	refresh()
	main.camera.fov = 52.0
	main.camera.near = 0.15
	_entry_lock = 0.65
	main._update_camera(100.0)
	if not silent:
		main.rest_notice("离开寺庙，返回小镇。")


func reset() -> void:
	if active:
		leave(true)
	_entry_lock = 0.0
	dragging = false
	aim_finger = -1
	refresh()


func _pause_outdoor_zombies() -> void:
	outdoor_states = []
	for zombie in get_tree().get_nodes_in_group("zombies"):
		outdoor_states.append([zombie, zombie.visible, zombie.is_physics_processing(), zombie.is_in_group("zombies")])
		zombie.hide()
		zombie.set_physics_process(false)
		# Combat target searches use the group rather than visibility. Temporarily
		# removing the actors prevents attacks from locking onto invisible enemies.
		zombie.remove_from_group("zombies")
	if is_instance_valid(main.zombie_population):
		population_was_processing = main.zombie_population.is_processing()
		main.zombie_population.set_process(false)


func _restore_outdoor_zombies() -> void:
	for state in outdoor_states:
		if is_instance_valid(state[0]):
			if state[3]:
				state[0].add_to_group("zombies")
			state[0].visible = state[1]
			state[0].set_physics_process(state[2] and not state[0]._dying)
	outdoor_states = []
	if is_instance_valid(main.zombie_population):
		main.zombie_population.set_process(population_was_processing)


func nearby() -> bool:
	return (
		active
		and main.controls_enabled
		and not GameState.odachi_taken
		and main.hotaru.global_position.distance_to(RACK + Vector3(0.0, 0.12, 0.0)) < 2.45
	)


func interact() -> void:
	if near_exit():
		leave()
		return
	if not nearby():
		return
	if not GameState.try_add_items({"odachi": 1}):
		main.rest_notice("背包需要 2.2 kg 空间，腾出位置后再来取刀。")
		return
	GameState.odachi_taken = true
	GameState.equip_item("odachi", "right_hand")
	refresh()
	main.rest_notice("获得大太刀，已双手持握。太刀术将随修炼逐级掌握。")


func update_hud() -> void:
	main.vehicle_button.hide()
	main.upgrade_button.hide()
	main.attack_button.visible = main.controls_enabled and not main.hotaru.dead
	main.interact_button.visible = near_exit() or nearby()
	main.interact_button.text = "离开寺庙" if near_exit() else "拾取大太刀"
	main.speed_label.text = "寺内"
	main.objective_label.text = "寺庙 · 安全区域 · 寻找正殿供奉的大太刀" if not GameState.odachi_taken else "寺庙 · 安全区域"
	main.hint_label.text = "正门：E / 交互离开寺庙" if near_exit() else ("供奉台：E / 交互拾取大太刀" if nearby() else "第三人称探索 · 右键/右侧拖动视角 · 从正门离开")


func update_camera(_delta: float) -> void:
	var center: Vector3 = main.hotaru.global_position + Vector3(0.0, 0.72, 0.0)
	var forward := Vector3(sin(yaw), 0.0, cos(yaw))
	var desired := center - forward * 3.05 + Vector3(0.0, 0.72 + pitch, 0.0)
	var query := PhysicsRayQueryParameters3D.create(center, desired, 3, [main.hotaru.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		desired = hit.position + (center - hit.position).normalized() * 0.20
	main.camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	main.camera.keep_aspect = Camera3D.KEEP_HEIGHT
	main.camera.fov = 66.0
	main.camera.near = 0.07
	main.camera.global_position = desired
	main.camera.look_at(center + forward * 0.52, Vector3.UP)
	var fade: float = clampf((1.70 - desired.distance_to(center)) / 0.62, 0.0, 1.0)
	for mesh in main.hotaru._body_meshes:
		mesh.transparency = fade


func _unhandled_input(event: InputEvent) -> void:
	if not active or get_tree().paused or not main.controls_enabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		dragging = event.pressed
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and dragging:
		yaw -= event.relative.x * 0.004
		pitch = clampf(pitch + event.relative.y * 0.004, -0.35, 1.0)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		if event.index == aim_finger and not event.pressed:
			aim_finger = -1
			get_viewport().set_input_as_handled()
		elif event.pressed and event.position.x > 350.0 and event.position.y > 260.0 and event.position.y < 980.0 and aim_finger < 0:
			aim_finger = event.index
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == aim_finger:
		yaw -= event.relative.x * 0.004
		pitch = clampf(pitch + event.relative.y * 0.004, -0.35, 1.0)
		get_viewport().set_input_as_handled()
