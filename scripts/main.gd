extends Node3D

const TownLayout = preload("res://scripts/environment/town_layout.gd")
const OutdoorMinimap = preload("res://scripts/ui/outdoor_minimap.gd")
const OutdoorCameraZoom = preload("res://scripts/ui/outdoor_camera_zoom.gd")
const OpeningStory = preload("res://scripts/story/opening.gd")
const StoryFire = preload("res://scripts/environment/story_fire.gd")

const BuildingOcclusion = preload("res://scripts/environment/building_occlusion.gd")

const HotaruController = preload("res://scripts/actors/hotaru.gd")
const StoreController = preload("res://scripts/environment/convenience_store.gd")
const STORE_ORIGIN := Vector3(2000, 0, 0)
const STORE_DOOR := Vector3(7.5, 0.95, 51.0)
const TOWN_CAMERA_OFFSET := Vector3(-20, 20, -20)

const RVController = preload("res://scripts/actors/rv.gd")
const ZombieController = preload("res://scripts/actors/zombie.gd")
const RVInteriorController = preload("res://scripts/environment/rv_interior.gd")
const ASSET_ROOT := "res://assets/third_party/quaternius_downtown/"
const RV_INTERIOR_ORIGIN := Vector3(1000.0, 0.0, 0.0)

enum Phase {
	TITLE,
	LEAVE_HOME,
	DRIVE_TO_STORE,
	CLEAR_ZOMBIES,
	SCAVENGE,
	RETURN_TO_RV,
	RETURN_HOME,
	UPGRADE,
	COMPLETE,
	EXPLORE,
	GAME_OVER,
}

var phase: Phase = Phase.TITLE
var hotaru
var rv
var rv_interior
var camera: Camera3D
var town_occlusion = BuildingOcclusion.new()
var opening
var home_fire: Node3D
var world_root: Node3D
var town_layout
var minimap
var outdoor_zoom
var mobile_joystick
var in_vehicle: bool = false
var mobile_driving
var fabrication
var factory
var temple
var hospital
var harbor
var inside_store: bool = false
var store_interior
var _store_return_position := Vector3.ZERO
var inside_rv: bool = false
var seated_at_driver: bool = false
var controls_enabled: bool = false
var home_parking_position := Vector3(-21.5, 1.02, -43.0)

var objective_label: Label
var status_label: Label
var hint_label: Label
var speed_label: Label
var interact_button: Button
var attack_button: Button
var vehicle_button: Button
var upgrade_button: Button
var dialog_panel: ColorRect
var dialog_title: Label
var dialog_body: Label
var dialog_item_image: TextureRect
var dialog_actions: HBoxContainer
var _capture_preview: bool = false
var _preview_frame_count: int = 0
var _preview_filename: String = "home_preview.png"
var _interior_camera_yaw: float = deg_to_rad(38.0)
var _interior_camera_pitch: float = deg_to_rad(42.0)
var _interior_camera_distance: float = 12.4
var _interior_camera_focus_override: Variant = null
var _camera_mouse_dragging: bool = false
var _camera_touch_points: Dictionary = {}
var title_screen: CanvasLayer
var equipment_screen
var rv_dashboard
var day_cycle
var sleep_controller
var save_slots
var service
var gas_station
var repair_shop
var cargo_organizer
var quantity_picker
var supply_quest
var zombie_population
var cash_drops
var trolley
var weapon_shop
var test_settings
var shooting


func _ready() -> void:
	add_to_group("game_session")
	_setup_input_actions()
	_create_environment()
	_create_world()
	_spawn_actors()
	_create_hud()
	opening = OpeningStory.new()
	add_child(opening)
	equipment_screen=load("res://scripts/ui/equipment_screen.gd").new()
	add_child(equipment_screen)
	equipment_screen.build(self)
	supply_quest=load("res://scripts/story/supply_tutorial.gd").new()
	add_child(supply_quest)
	supply_quest.build(self)
	zombie_population=load("res://scripts/environment/zombie_population.gd").new()
	add_child(zombie_population)
	zombie_population.build(self)
	rv_dashboard=load("res://scripts/ui/rv_dashboard.gd").new()
	add_child(rv_dashboard)
	rv_dashboard.build(self)
	cargo_organizer=load("res://scripts/ui/cargo_organizer.gd").new()
	add_child(cargo_organizer)
	cargo_organizer.build(self)
	quantity_picker=load("res://scripts/ui/quantity_picker.gd").new()
	add_child(quantity_picker)
	quantity_picker.build(self)
	day_cycle=load("res://scripts/environment/day_cycle.gd").new()
	add_child(day_cycle)
	day_cycle.build(self)
	sleep_controller=load("res://scripts/story/rv_sleep.gd").new()
	add_child(sleep_controller)
	sleep_controller.build(self)
	save_slots=load("res://scripts/ui/save_slots.gd").new()
	add_child(save_slots)
	save_slots.build(self)
	repair_shop=load("res://scripts/environment/repair_shop.gd").new()
	world_root.add_child(repair_shop)
	repair_shop.build(self)
	service=load("res://scripts/story/vehicle_service.gd").new()
	add_child(service)
	service.build(self)
	gas_station=load("res://scripts/environment/gas_station.gd").new()
	world_root.add_child(gas_station)
	gas_station.build(self)
	cash_drops=load("res://scripts/environment/cash_drops.gd").new()
	add_child(cash_drops)
	cash_drops.build(self)
	trolley=load("res://scripts/actors/cargo_trolley.gd").new()
	add_child(trolley)
	trolley.build(self)
	weapon_shop=load("res://scripts/story/weapon_shop.gd").new()
	add_child(weapon_shop)
	weapon_shop.build(self)
	test_settings=load("res://scripts/ui/test_settings.gd").new()
	add_child(test_settings)
	test_settings.build(self)
	shooting=load("res://scripts/actors/rv_gunnery.gd").new()
	add_child(shooting)
	shooting.build(self)
	factory=load("res://scripts/environment/factory.gd").new()
	add_child(factory)
	factory.build(self)
	temple=load("res://scripts/environment/temple.gd").new()
	add_child(temple)
	temple.build(self)
	hospital=load("res://scripts/environment/hospital.gd").new()
	add_child(hospital)
	hospital.build(self)
	harbor=load("res://scripts/environment/harbor.gd").new()
	add_child(harbor)
	harbor.build(self)
	fabrication=load("res://scripts/ui/vehicle_fabrication.gd").new()
	add_child(fabrication)
	fabrication.build(self)
	mobile_driving=load("res://scripts/ui/mobile_driving.gd").new()
	get_node("HUD").add_child(mobile_driving)
	mobile_driving.build(self)
	_show_title()
	AudioDirector.attach(self)
	var user_args := OS.get_cmdline_user_args()
	if user_args.has("--smoke-test"):
		call_deferred("_run_smoke_test")
	elif user_args.has("--capture-title"):
		_capture_preview = true
		_preview_filename = "title_preview.png"
	elif user_args.has("--capture-preview"):
		_capture_preview = true
		call_deferred("_start_new_game")
	elif user_args.has("--capture-street"):
		_capture_preview = true
		_preview_filename = "street_preview.png"
		call_deferred("_prepare_street_preview")
	elif user_args.has("--capture-interior"):
		_capture_preview = true
		_preview_filename = "rv_interior_godot.png"
		call_deferred("_prepare_interior_preview")
	elif user_args.has("--capture-interaction"):
		_capture_preview = true
		_preview_filename = "rv_interior_interaction.png"
		call_deferred("_prepare_interaction_preview")
	elif user_args.has("--capture-interior-reverse"):
		_capture_preview = true
		_preview_filename = "rv_interior_reverse.png"
		call_deferred("_prepare_reverse_interior_preview")
	elif user_args.has("--capture-store"):
		_capture_preview = true
		_preview_filename = "store_interior.png"
		call_deferred("_prepare_store_preview")
	elif user_args.has("--capture-storefront"):
		_capture_preview = true
		_preview_filename = "store_exterior.png"
		call_deferred("_prepare_storefront_preview")
	elif user_args.has("--capture-cockpit"):
		_capture_preview = true
		_preview_filename = "rv_cockpit_seated.png"
		call_deferred("_prepare_cockpit_preview")


func _process(delta: float) -> void:
	GameState.vehicle_position=rv.global_position
	GameState.vehicle_yaw=rv.rotation.y
	rv.occupied=(inside_rv or in_vehicle) and phase!=Phase.GAME_OVER and not rv.wrecked
	_update_camera(delta)
	town_occlusion.update(camera, harbor.crane if is_instance_valid(harbor) and harbor.active else (rv if in_vehicle or (is_instance_valid(shooting) and shooting.active) else hotaru), (not inside_rv or (is_instance_valid(shooting) and shooting.active)) and not inside_store and not factory.active and not temple.active and not hospital.active and not hospital.in_campus and not (is_instance_valid(harbor) and harbor.active))
	_update_phase_checks()
	_update_hud()
	if is_instance_valid(harbor):harbor.apply_hud()
	if is_instance_valid(fabrication):fabrication.apply_hud()
	if is_instance_valid(mobile_driving):mobile_driving.update_layout()
	if is_instance_valid(opening):
		opening.apply_escape_hud()
	if is_instance_valid(supply_quest):supply_quest.update(delta)
	if (controls_enabled or (is_instance_valid(fabrication) and fabrication.active) or (is_instance_valid(service) and service.active) or (is_instance_valid(sleep_controller) and sleep_controller.sleeping)) and phase not in [Phase.TITLE,Phase.GAME_OVER,Phase.COMPLETE] and not dialog_panel.visible and not opening.is_cinematic():
		var step: float=sleep_controller.limit_delta(delta)
		hotaru.take_survival_damage(GameState.tick_survival(step)*hotaru.max_health)
		sleep_controller.advance(step)
	if phase==Phase.GAME_OVER and is_instance_valid(rv_dashboard):rv_dashboard.close()
	if _capture_preview:
		_preview_frame_count += 1
		if _preview_frame_count >= 45:
			_capture_preview = false
			_capture_game_preview()


func _capture_game_preview() -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	DirAccess.make_dir_absolute(ProjectSettings.globalize_path("res://artifacts"))
	image.save_png("res://artifacts/" + _preview_filename)
	get_tree().quit()


func _prepare_street_preview() -> void:
	_start_new_game()
	hotaru.position = Vector3(0.0, 0.95, 39.0)
	_set_phase(Phase.CLEAR_ZOMBIES)


func _prepare_interior_preview() -> void:
	_start_new_game()
	hotaru.global_position = rv.get_disembark_position()
	_enter_rv_interior()


func _prepare_interaction_preview() -> void:
	_prepare_interior_preview()
	hotaru.global_position = RV_INTERIOR_ORIGIN + Vector3(-0.28, 1.13, 1.02)


func _prepare_reverse_interior_preview() -> void:
	_prepare_interior_preview()
	_interior_camera_yaw = deg_to_rad(-142.0)


func _prepare_cockpit_preview() -> void:
	_prepare_interior_preview()
	_interior_camera_focus_override = RV_INTERIOR_ORIGIN + Vector3(0.0, 0.88, -4.35)
	_interior_camera_yaw = deg_to_rad(38.0)
	_interior_camera_yaw = deg_to_rad(-142.0)
	_interior_camera_pitch = deg_to_rad(31.0)
	_interior_camera_distance = 5.6
	hotaru.global_position = rv_interior.get_driver_stand_position()
	rv_interior.update_interaction_focus(hotaru.global_position)
	_sit_at_driver()


func _prepare_storefront_preview() -> void:
	# Developer-only capture of a normal map location, not a player mode.
	_start_new_game()
	for zombie in get_tree().get_nodes_in_group("zombies"):
		zombie.queue_free()
	_set_phase(Phase.SCAVENGE)
	rv.global_position = Vector3(0, 1.02, 45)
	hotaru.global_position = STORE_DOOR + Vector3(-1.2, 0, 0)
	camera.global_position = hotaru.global_position + TOWN_CAMERA_OFFSET


func _prepare_store_preview() -> void:
	_prepare_storefront_preview()
	_enter_store()
	camera.global_position = store_interior.get_camera_pivot() + Vector3(10, 10, 10)


func _run_smoke_test() -> void:
	GameState.suppress_save = true
	_start_new_game()
	_assert_smoke(phase == Phase.LEAVE_HOME, "new game")
	_update_camera(1.0)
	_assert_smoke(camera.projection == Camera3D.PROJECTION_ORTHOGONAL, "town orthographic camera")
	hotaru.global_position = rv.get_disembark_position()
	_enter_rv_interior()
	_assert_smoke(inside_rv and rv_interior.visible, "enter RV interior")
	_update_camera(1.0)
	_assert_smoke(camera.projection == Camera3D.PROJECTION_PERSPECTIVE, "RV orbit camera preserved")
	_assert_smoke(hotaru._animation_names.size() >= 11, "Idle Walk Sit Punch Hit imported")
	_assert_smoke(absf(hotaru.global_position.y - 1.13) < 0.01, "interior floor height")
	hotaru.global_position = RV_INTERIOR_ORIGIN + Vector3(-0.28, 1.13, 1.02)
	var focused_module_name: String = rv_interior.update_interaction_focus(hotaru.global_position)
	_assert_smoke(focused_module_name == "小冰箱", "focus interactive module")
	_interact()
	_assert_smoke(dialog_panel.visible, "interact with RV module")
	_close_dialog_and_resume()
	hotaru.global_position = rv_interior.get_driver_stand_position()
	var focused_driver_name: String = rv_interior.update_interaction_focus(hotaru.global_position)
	_assert_smoke(focused_driver_name == "驾驶座", "focus driver seat")
	_interact()
	_assert_smoke(seated_at_driver and inside_rv, "sit in driver seat")
	_assert_smoke(hotaru.get_animation_state() == "Sit", "seated animation")
	_assert_smoke(hotaru.global_position.y > 1.2, "seat cushion alignment")
	_interact()
	_assert_smoke(not seated_at_driver and inside_rv, "stand from driver seat")
	hotaru.global_position = rv_interior.get_driver_stand_position()
	rv_interior.update_interaction_focus(hotaru.global_position)
	_interact()
	_toggle_vehicle()
	_assert_smoke(in_vehicle and not inside_rv and phase == Phase.DRIVE_TO_STORE, "drive from cockpit")
	rv.global_position = Vector3(0.0, 1.02, 45.0)
	_toggle_vehicle()
	_assert_smoke(not in_vehicle and inside_rv and phase == Phase.CLEAR_ZOMBIES, "park and return to cabin")
	hotaru.global_position = rv_interior.get_entry_position()
	_interact()
	_assert_smoke(not inside_rv and rv.is_near_side_door(hotaru.global_position), "disembark at right side door")
	for zombie in get_tree().get_nodes_in_group("zombies"):
		zombie.queue_free()
	await get_tree().process_frame
	_update_phase_checks()
	_assert_smoke(phase == Phase.SCAVENGE, "clear zombies")
	hotaru.global_position = STORE_DOOR
	_interact()
	_assert_smoke(inside_store and store_interior.visible, "enter supermarket")
	for station in ["food", "water", "medical", "tools"]:
		hotaru.global_position = STORE_ORIGIN + StoreController.STATIONS[station].anchor
		_interact()
		if quantity_picker.veil.visible:
			quantity_picker.amount.value=1 if station=="water" else 2
			quantity_picker.take()
		_close_dialog_and_resume()
	_assert_smoke(phase == Phase.RETURN_TO_RV and GameState.scrap == 5, "scavenge in store")
	_assert_smoke(GameState.food == 2 and GameState.water == 1 and GameState.medicine == 2, "survival inventory")
	_assert_smoke(GameState.store_looted.size() == 2, "loot state shared with save data")
	var scrap_before: int = GameState.scrap
	hotaru.global_position = STORE_ORIGIN + StoreController.STATIONS.tools.anchor
	_interact()
	_assert_smoke(GameState.scrap == scrap_before, "no duplicate loot")
	hotaru.global_position = store_interior.get_entry_position()
	_interact()
	_assert_smoke(not inside_store and world_root.visible, "exit supermarket")
	_interact()
	_assert_smoke(inside_store and store_interior.looted.size() == 2, "reenter preserves empty shelves")
	hotaru.global_position = store_interior.get_entry_position()
	_interact()
	hotaru.global_position = rv.get_disembark_position()
	_toggle_vehicle()
	_assert_smoke(inside_rv and not in_vehicle, "board through right side door")
	hotaru.global_position = rv_interior.get_driver_stand_position()
	rv_interior.update_interaction_focus(hotaru.global_position)
	_interact()
	_toggle_vehicle()
	_assert_smoke(in_vehicle and phase == Phase.RETURN_HOME, "return to RV")
	rv.global_position = home_parking_position
	_update_phase_checks()
	_assert_smoke(phase == Phase.UPGRADE, "return home")
	_upgrade_rv()
	_assert_smoke(phase == Phase.COMPLETE and GameState.rv_upgrade_level == 1, "upgrade RV")
	GameState.suppress_save = false
	print("SMOKE_TEST_PASS: full first-day gameplay loop")
	get_tree().quit()


func _assert_smoke(condition: bool, step_name: String) -> void:
	if condition:
		return
	push_error("SMOKE_TEST_FAIL: " + step_name)
	get_tree().quit(1)


func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(opening) and opening.is_cinematic():
		opening.handle_input(event)
		return
	if not controls_enabled or dialog_panel.visible:
		return
	if is_instance_valid(harbor) and harbor.active:
		harbor.handle_input(event)
		return
	if is_instance_valid(shooting) and shooting.active:return
	if inside_rv and _handle_interior_camera_input(event):
		return
	if not factory.active and not temple.active and not hospital.active and not hospital.in_campus and not (is_instance_valid(harbor) and harbor.active) and is_instance_valid(outdoor_zoom) and outdoor_zoom.handle_world_input(event):
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("toggle_vehicle"):
		_toggle_vehicle()
	elif event.is_action_pressed("interact"):
		_interact()
	elif event.is_action_pressed("attack"):
		_attack()
	elif event.is_action_pressed("upgrade"):
		_upgrade_rv()


func _handle_interior_camera_input(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_interior_camera_distance = clampf(_interior_camera_distance - 0.75, 7.2, 16.0)
			return true
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_interior_camera_distance = clampf(_interior_camera_distance + 0.75, 7.2, 16.0)
			return true
		if event.button_index == MOUSE_BUTTON_LEFT:
			_camera_mouse_dragging = event.pressed
			return true
	elif event is InputEventMouseMotion and _camera_mouse_dragging:
		_orbit_interior_camera(event.relative)
		return true
	elif event is InputEventScreenTouch:
		if event.pressed:
			_camera_touch_points[event.index] = event.position
		else:
			_camera_touch_points.erase(event.index)
		return true
	elif event is InputEventScreenDrag:
		var previous_position: Vector2 = event.position - event.relative
		_camera_touch_points[event.index] = event.position
		if _camera_touch_points.size() == 1:
			_orbit_interior_camera(event.relative)
		else:
			for other_index in _camera_touch_points.keys():
				if int(other_index) == event.index:
					continue
				var other_position: Vector2 = _camera_touch_points[other_index]
				var previous_distance: float = previous_position.distance_to(other_position)
				var current_distance: float = event.position.distance_to(other_position)
				_interior_camera_distance = clampf(
					_interior_camera_distance - (current_distance - previous_distance) * 0.018,
					6.6,
					14.5
				)
				break
		return true
	return false


func _orbit_interior_camera(relative_motion: Vector2) -> void:
	_interior_camera_yaw = wrapf(_interior_camera_yaw - relative_motion.x * 0.008, -PI, PI)
	_interior_camera_pitch = clampf(
		_interior_camera_pitch + relative_motion.y * 0.006,
		deg_to_rad(28.0),
		deg_to_rad(68.0)
	)


func _setup_input_actions() -> void:
	_add_key_action("move_forward", [KEY_W, KEY_UP])
	_add_key_action("move_backward", [KEY_S, KEY_DOWN])
	_add_key_action("move_left", [KEY_A, KEY_LEFT])
	_add_key_action("move_right", [KEY_D, KEY_RIGHT])
	_add_key_action("interact", [KEY_E])
	_add_key_action("attack", [KEY_J])
	_add_key_action("toggle_vehicle", [KEY_SPACE])
	_add_key_action("upgrade", [KEY_Q])


func _add_key_action(action_name: StringName, keycodes: Array) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	for keycode in keycodes:
		var input_event := InputEventKey.new()
		input_event.physical_keycode = int(keycode)
		InputMap.action_add_event(action_name, input_event)


func _create_environment() -> void:
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("6986a2")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b9cad4")
	environment.ambient_light_energy = 0.72
	environment.fog_enabled = true
	environment.fog_light_color = Color("aab9c3")
	environment.fog_density = 0.0038
	environment_node.environment = environment
	add_child(environment_node)

	var sun := DirectionalLight3D.new()
	sun.name = "LateAfternoonSun"
	sun.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	sun.light_color = Color("ffe2b5")
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0
	add_child(sun)


func _create_world() -> void:
	world_root = Node3D.new()
	world_root.name = "FireflyTown"
	add_child(world_root)
	town_layout = TownLayout.new()
	world_root.add_child(town_layout)
	town_layout.build(self)
	_create_home()
	_create_storefront_and_cache()
	_add_asset("Decal_Crosswalk",Vector3(0,0.10,42))


func _create_home() -> void:
	var home: Node3D = load("res://assets/story/house/house.glb").instantiate()
	home.name = "HotaruAmericanHouse"
	home.position = Vector3(-11,0.08,-43)
	home.scale = Vector3.ONE*1.6
	home.rotation.y = PI/2
	world_root.add_child(home)
	town_occlusion.register_building(home)
	_add_static_collision(Vector3(6.6,4.2,9.2),Vector3(-11,2.1,-43),3)
	_add_box(world_root,"BackParking",Vector3(9,0.10,15),Vector3(-22,0,-43),Color("5c6060"))
	_add_box(world_root,"SideDriveway",Vector3(25,0.10,5),Vector3(-12,0,-33),Color("5c6060"))
	_add_label("后院停车场",Vector3(-23,2.0,-48.5),Color("ffdfa3"),28)
	home_fire = Node3D.new()
	home_fire.name = "HouseFire"
	world_root.add_child(home_fire)
	for point in [Vector3(-8.0,0.3,-45),Vector3(-8,2.5,-41),Vector3(-11,4.0,-43),Vector3(-13.5,0.2,-40.5)]:
		var fire := StoryFire.new()
		fire.position = point
		home_fire.add_child(fire)
	home_fire.hide()
	home_fire.process_mode = Node.PROCESS_MODE_DISABLED


func _create_storefront_and_cache() -> void:
	var storefront: Node3D = load(StoreController.MODEL_PATH).instantiate()
	storefront.name = "SupermarketExterior"
	storefront.position = Vector3(11.6, 0.16, 51.0)
	storefront.rotation.y = -PI / 2
	world_root.add_child(storefront)
	town_occlusion.register_building(storefront)
	_add_static_collision(Vector3(7.4, 3.0, 8.1), Vector3(11.6, 1.65, 51.0), 3)
	_add_label("便利店 · 入口 E", STORE_DOOR + Vector3(0, 3.1, 0), Color("fff0ad"), 28)


func _spawn_actors() -> void:
	hotaru = HotaruController.new()
	hotaru.position = Vector3(-6.7, 0.95, -43.0)
	hotaru.set_active(false)
	hotaru.health_changed.connect(_on_health_changed)
	hotaru.died.connect(_on_hotaru_died)
	hotaru.attacked.connect(_on_hotaru_attacked)
	add_child(hotaru)

	rv = RVController.new()
	rv.travel_bounds = TownLayout.DRIVE_BOUNDS
	rv.position = home_parking_position
	rv.rotation.y = PI
	rv.set_active(false)
	rv.speed_changed.connect(_on_speed_changed)
	rv.exploded.connect(_on_rv_exploded)
	rv.health_changed.connect(func(hp: int,maximum: int):GameState.rv_health_ratio=float(hp)/maximum)
	add_child(rv)

	rv_interior = RVInteriorController.new()
	rv_interior.position = RV_INTERIOR_ORIGIN
	add_child(rv_interior)
	rv_interior.set_active(false)

	store_interior = StoreController.new()
	store_interior.position = STORE_ORIGIN
	add_child(store_interior)

	for zombie_position in [Vector3(-0.8, 0.9, 47.0), Vector3(2.0, 0.9, 54.5), Vector3(-1.5, 0.9, 60.0)]:
		var zombie = ZombieController.new()
		zombie.position = zombie_position
		zombie.set_target(hotaru)
		zombie.set_vehicle_target(rv)
		add_child(zombie)
		zombie.add_to_group("store_zombies")

	camera = Camera3D.new()
	camera.name = "PortraitFollowCamera"
	camera.current = true
	camera.fov = 52.0
	camera.near = 0.15
	camera.far = 180.0
	add_child(camera)
	_set_town_projection()
	camera.global_position = hotaru.global_position + TOWN_CAMERA_OFFSET
	camera.look_at(hotaru.global_position + Vector3(0.0, 0.6, 0.0), Vector3.UP)
	hotaru.set_movement_camera(camera)


func _create_hud() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "HUD"
	add_child(canvas)

	var top_bar := ColorRect.new()
	top_bar.position = Vector2(18.0, 18.0)
	top_bar.size = Vector2(684.0, 132.0)
	top_bar.color = Color(0,0,0,0)
	top_bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
	canvas.add_child(top_bar)

	objective_label = Label.new()
	objective_label.position = Vector2(130.0, 32.0)
	objective_label.size = Vector2(552.0, 74.0)
	objective_label.add_theme_font_size_override("font_size", 28)
	objective_label.add_theme_color_override("font_color", Color("fff1c5"))
	objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objective_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	canvas.add_child(objective_label)
	objective_label.hide()

	status_label = Label.new()
	status_label.position = Vector2(130.0, 104.0)
	status_label.size = Vector2(345.0, 36.0)
	status_label.add_theme_font_size_override("font_size", 22)
	status_label.add_theme_color_override("font_color", Color("d9e7e8"))
	canvas.add_child(status_label)
	status_label.hide()

	speed_label = Label.new()
	speed_label.position = Vector2(480.0, 104.0)
	speed_label.size = Vector2(190.0, 36.0)
	speed_label.add_theme_font_size_override("font_size", 22)
	speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	speed_label.add_theme_color_override("font_color", Color("9dd5db"))
	canvas.add_child(speed_label)
	speed_label.hide()

	hint_label = Label.new()
	hint_label.position = Vector2(40.0, 902.0)
	hint_label.size = Vector2(640.0, 88.0)
	hint_label.add_theme_font_size_override("font_size", 24)
	hint_label.add_theme_color_override("font_color", Color("fff4ce"))
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	canvas.add_child(hint_label)

	if not OS.has_feature("android") and not DisplayServer.is_touchscreen_available():
		_create_hold_button(canvas, "↑", Vector2(105.0, 1010.0), "move_forward")
		_create_hold_button(canvas, "↓", Vector2(105.0, 1160.0), "move_backward")
		_create_hold_button(canvas, "←", Vector2(30.0, 1085.0), "move_left")
		_create_hold_button(canvas, "→", Vector2(180.0, 1085.0), "move_right")

	upgrade_button = _create_action_button(canvas, "改装 Q", Vector2(370.0, 1010.0), _upgrade_rv)
	vehicle_button = _create_action_button(canvas, "上/下车", Vector2(540.0, 1010.0), _toggle_vehicle)
	interact_button = _create_action_button(canvas, "交互 E", Vector2(370.0, 1120.0), _interact)
	attack_button = _create_action_button(canvas, "攻击 J", Vector2(540.0, 1120.0), _attack)
	upgrade_button.visible = false
	mobile_joystick=load("res://scripts/ui/mobile_joystick.gd").new()
	canvas.add_child(mobile_joystick)
	mobile_joystick.setup(self)

	dialog_panel = ColorRect.new()
	dialog_panel.position = Vector2(42.0, 212.0)
	dialog_panel.size = Vector2(636.0, 548.0)
	dialog_panel.color = Color(0.035, 0.045, 0.055, 0.96)
	canvas.add_child(dialog_panel)

	dialog_title = Label.new()
	dialog_title.position = Vector2(30.0, 28.0)
	dialog_title.size = Vector2(576.0, 76.0)
	dialog_title.add_theme_font_size_override("font_size", 40)
	dialog_title.add_theme_color_override("font_color", Color("ffd98d"))
	dialog_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialog_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dialog_panel.add_child(dialog_title)

	dialog_body = Label.new()
	dialog_body.position = Vector2(42.0, 118.0)
	dialog_body.size = Vector2(552.0, 270.0)
	dialog_body.add_theme_font_size_override("font_size", 26)
	dialog_body.add_theme_color_override("font_color", Color("e9eeee"))
	dialog_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialog_body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dialog_panel.add_child(dialog_body)
	dialog_item_image=TextureRect.new()
	dialog_item_image.position=Vector2(44,122)
	dialog_item_image.size=Vector2(158,245)
	dialog_item_image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	dialog_item_image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	dialog_item_image.mouse_filter=Control.MOUSE_FILTER_IGNORE
	dialog_item_image.hide()
	dialog_panel.add_child(dialog_item_image)

	dialog_actions = HBoxContainer.new()
	dialog_actions.position = Vector2(42.0, 420.0)
	dialog_actions.size = Vector2(552.0, 82.0)
	dialog_actions.alignment = BoxContainer.ALIGNMENT_CENTER
	dialog_actions.add_theme_constant_override("separation", 18)
	dialog_panel.add_child(dialog_actions)
	minimap=OutdoorMinimap.new()
	canvas.add_child(minimap)
	minimap.setup(self)
	outdoor_zoom=OutdoorCameraZoom.new()
	canvas.add_child(outdoor_zoom)
	outdoor_zoom.setup(self)


func _create_hold_button(parent: Node, text_value: String, position_value: Vector2, action_name: StringName) -> Button:
	var button := Button.new()
	button.add_to_group("movement_controls")
	button.text = text_value
	button.position = position_value
	button.size = Vector2(92.0, 92.0)
	button.focus_mode = Control.FOCUS_NONE
	_style_button(button, Color(0.14, 0.2, 0.23, 0.88))
	button.button_down.connect(func(): Input.action_press(action_name))
	button.button_up.connect(func(): Input.action_release(action_name))
	parent.add_child(button)
	return button


func _create_action_button(parent: Node, text_value: String, position_value: Vector2, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	button.position = position_value
	button.size = Vector2(140.0, 82.0)
	button.focus_mode = Control.FOCUS_NONE
	_style_button(button, Color(0.34, 0.22, 0.16, 0.91))
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _style_button(button: Button, color: Color) -> void:
	button.pressed.connect(func():AudioDirector.ui())
	button.add_theme_font_size_override("font_size", 24)
	button.add_theme_color_override("font_color", Color("fff4dc"))
	var normal := StyleBoxFlat.new()
	normal.bg_color = color
	normal.corner_radius_top_left = 18
	normal.corner_radius_top_right = 18
	normal.corner_radius_bottom_left = 18
	normal.corner_radius_bottom_right = 18
	normal.border_width_left = 2
	normal.border_width_top = 2
	normal.border_width_right = 2
	normal.border_width_bottom = 2
	normal.border_color = Color(1.0, 0.82, 0.48, 0.42)
	button.add_theme_stylebox_override("normal", normal)
	var pressed := normal.duplicate()
	pressed.bg_color = color.lightened(0.18)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("hover", pressed)


func _show_title() -> void:
	controls_enabled = false
	hotaru.set_active(false)
	rv.set_active(false)
	dialog_panel.hide()
	get_node("HUD").hide()
	title_screen=load("res://scripts/ui/title_screen.gd").new()
	add_child(title_screen)
	title_screen.build(self)


func _begin_story() -> void:
	_start_new_game()
	opening.start()


func _start_new_game() -> void:
	if is_instance_valid(fabrication):fabrication.stop_work("");fabrication.close()
	if is_instance_valid(factory):factory.reset()
	if is_instance_valid(temple):temple.reset()
	if is_instance_valid(hospital):hospital.reset()
	if is_instance_valid(shooting):shooting.stop(false)
	if is_instance_valid(title_screen):title_screen.hide()
	get_node("HUD").show()
	if is_instance_valid(service) and service.active:service.stop("操作结束。")
	AudioDirector.reset_run()
	GameState.start_new_run()
	if is_instance_valid(trolley):trolley.reset()
	if is_instance_valid(cash_drops):cash_drops.reset_visuals()
	if is_instance_valid(day_cycle):day_cycle.reset()
	if is_instance_valid(zombie_population):zombie_population.reset()
	if is_instance_valid(supply_quest):supply_quest.completion_time=0
	rv.reset_condition()
	rv_interior.set_wardrobe_open(false,true)
	inside_store = false
	store_interior.set_active(false)
	store_interior.reset_loot(GameState.store_looted)
	dialog_panel.visible = false
	controls_enabled = true
	inside_rv = false
	seated_at_driver = false
	rv_interior.set_active(false)
	world_root.visible = true
	hotaru.visible = true
	hotaru.health = hotaru.max_health
	hotaru.reset_death()
	for zombie in get_tree().get_nodes_in_group("zombies"):
		if not zombie._dying:zombie.set_physics_process(true)
	if is_instance_valid(equipment_screen):equipment_screen.update_health()
	hotaru.set_seated(false)
	hotaru.set_ground_height(0.95)
	hotaru.position = Vector3(-6.7, 0.95, -43.0)
	hotaru.set_active(true)
	rv.position = home_parking_position
	rv.rotation.y = PI
	rv.visible = true
	rv.set_active(false)
	in_vehicle = false
	if is_instance_valid(harbor):harbor.reset()
	_set_phase(Phase.LEAVE_HOME)


func _load_completed_save(path: String=GameState.SAVE_PATH) -> void:
	if is_instance_valid(fabrication):fabrication.stop_work("");fabrication.close()
	if is_instance_valid(factory):factory.reset()
	if is_instance_valid(temple):temple.reset()
	if is_instance_valid(hospital):hospital.reset()
	if is_instance_valid(shooting):shooting.stop(false)
	if not GameState.load_completed_save(path):
		return
	if is_instance_valid(trolley):trolley.reset()
	if is_instance_valid(cash_drops):cash_drops.reset_visuals()
	if is_instance_valid(service) and service.active:service.stop("操作结束。")
	AudioDirector.reset_run()
	var loaded_rv_ratio: float=GameState.rv_health_ratio
	rv.reset_condition()
	if is_instance_valid(title_screen):title_screen.hide()
	get_node("HUD").show()
	inside_store = false
	store_interior.set_active(false)
	store_interior.reset_loot(GameState.store_looted)
	dialog_panel.visible = false
	controls_enabled = true
	inside_rv = false
	seated_at_driver = false
	rv_interior.set_active(false)
	world_root.visible = true
	hotaru.visible = true
	hotaru.set_seated(false)
	hotaru.set_ground_height(0.95)
	hotaru.position = Vector3(-3.4, 0.95, -43.0)
	hotaru.set_active(true)
	rv.position = home_parking_position
	rv.rotation.y = PI
	rv.visible = true
	rv.set_active(false)
	if GameState.rv_upgrade_level>0:rv.apply_first_upgrade()
	rv.restore_health_ratio(loaded_rv_ratio)
	in_vehicle = false
	if GameState.demo_completed:
		_set_phase(Phase.COMPLETE)
		_show_completion_dialog()
	else:
		rv.global_position=GameState.vehicle_position
		rv.rotation.y=GameState.vehicle_yaw
		hotaru.global_position=rv.get_disembark_position()
		hotaru.reset_death()
		hotaru.health=hotaru.max_health*GameState.hero_health_ratio
		hotaru.health_changed.emit(hotaru.health,hotaru.max_health)
		_set_phase({0:Phase.LEAVE_HOME,1:Phase.DRIVE_TO_STORE,2:Phase.SCAVENGE,3:Phase.RETURN_TO_RV,4:Phase.EXPLORE}.get(GameState.tutorial_step,Phase.EXPLORE))
		zombie_population.reset(Vector2(rv.global_position.x,rv.global_position.z))
	if is_instance_valid(harbor):harbor.reset()


func _set_phase(value: Phase) -> void:
	phase = value
	match phase:
		Phase.LEAVE_HOME:
			objective_label.text = "目标：走出小萤的家，登上门外的房车"
		Phase.DRIVE_TO_STORE:
			objective_label.text = "目标：沿侧车道驶上主路，前往萤火便利店" if rv.global_position.x < -5 else "目标：沿街驶向前方的萤火便利店"
		Phase.CLEAR_ZOMBIES:
			objective_label.text = "目标：清理便利店周围的丧尸"
		Phase.SCAVENGE:
			objective_label.text = "目标：进入便利店，搜索生存物资和哥哥的线索"
		Phase.RETURN_TO_RV:
			objective_label.text = "目标：带着物资回到房车"
		Phase.RETURN_HOME:
			objective_label.text = "目标：把房车开回小萤家门口"
		Phase.UPGRADE:
			objective_label.text = "目标：使用 4 份废料安装一级防撞装甲"
		Phase.COMPLETE:
			objective_label.text = "原型完成：新的线索指向镇北的旧车站"
		Phase.EXPLORE:
			objective_label.text="探索小镇，留意房车储备。"
		Phase.GAME_OVER:
			objective_label.text = "小萤倒下了"
		_:
			pass
	upgrade_button.visible = phase == Phase.UPGRADE and not inside_rv


func _update_phase_checks() -> void:
	if not controls_enabled or inside_rv or inside_store or (is_instance_valid(temple) and temple.active) or (is_instance_valid(hospital) and hospital.active) or (is_instance_valid(harbor) and harbor.active):
		return
	if phase == Phase.CLEAR_ZOMBIES and _alive_zombie_count() == 0:
		_set_phase(Phase.SCAVENGE)
	elif phase == Phase.RETURN_HOME and in_vehicle:
		if rv.global_position.distance_to(home_parking_position) < 6.8:
			rv.set_active(false)
			_set_phase(Phase.UPGRADE)


func _toggle_vehicle() -> void:
	if is_instance_valid(harbor) and harbor.roof_transitioning:return
	if is_instance_valid(factory) and (factory.active or factory.transitioning):return
	if is_instance_valid(hospital) and (hospital.active or hospital.in_campus or hospital.gate_busy):return
	if is_instance_valid(temple) and temple.active:return
	if is_instance_valid(harbor) and harbor.active:return
	if rv.wrecked:return
	if inside_store or not controls_enabled or phase in [Phase.TITLE, Phase.GAME_OVER, Phase.COMPLETE]:
		return
	if inside_rv:
		if is_instance_valid(harbor) and harbor.roof_interior_active:
			harbor.interact_roof_interior()
			return
		if is_instance_valid(harbor) and harbor.near_interior_ladder():
			harbor.enter_roof_interior()
			return
		if seated_at_driver:
			_start_driving_from_cockpit()
		elif rv_interior.is_near_exit(hotaru.global_position):
			_exit_rv_interior()
		else:
			hint_label.text = "驾驶座按 E 坐下开车；到右侧车门按 E 下车"
		return
	if in_vehicle:
		in_vehicle = false
		rv.set_active(false)
		if phase == Phase.DRIVE_TO_STORE and Vector2(rv.global_position.x,rv.global_position.z).distance_to(Vector2(0,48)) < 20.0:
			_set_phase(Phase.CLEAR_ZOMBIES)
		_enter_rv_interior(true)
		return
	if not rv.is_near_side_door(hotaru.global_position):
		hint_label.text = "走到房车右侧中段的车门旁上车"
		return
	_enter_rv_interior()


func _interact() -> void:
	if is_instance_valid(hospital) and hospital.gate_busy:return
	if is_instance_valid(harbor) and harbor.roof_transitioning:return
	if controls_enabled and inside_rv and is_instance_valid(harbor):
		if harbor.roof_interior_active:
			harbor.interact_roof_interior()
			return
		if harbor.near_interior_ladder():
			harbor.enter_roof_interior()
			return
	if is_instance_valid(hospital) and (hospital.active or hospital.in_campus):
		if controls_enabled:hospital.interact()
		return
	if is_instance_valid(factory) and factory.active:
		if controls_enabled:factory.interact()
		return
	if is_instance_valid(temple) and temple.active:
		if controls_enabled:temple.interact()
		return
	if is_instance_valid(harbor) and harbor.active:
		return
	if not controls_enabled or in_vehicle:
		return
	if inside_store:
		_interact_store()
		return
	if inside_rv:
		if seated_at_driver:
			_stand_from_driver_seat()
			return
		if rv_interior.is_near_exit(hotaru.global_position):
			_exit_rv_interior()
			return
		rv_interior.update_interaction_focus(hotaru.global_position)
		var interaction: Dictionary = rv_interior.get_focused_interaction()
		if not interaction.is_empty():
			if str(interaction.get("id","")) in ["gun_left","gun_right"]:
				shooting.start(-1 if interaction.id=="gun_left" else 1)
				return
			if str(interaction.get("id",""))=="workbench":
				factory.workbench()
				return
			if str(interaction.get("id",""))=="bed":
				sleep_controller.open()
				return
			if str(interaction.get("id",""))=="wardrobe":
				_interact_wardrobe()
				return
			if str(interaction.get("id",""))=="storage":
				rv_dashboard.open()
				return
			if str(interaction.get("id", "")) == "driver_seat":
				_sit_at_driver()
				return
			hotaru.set_active(false)
			_show_dialog(str(interaction.name), str(interaction.description), "关闭", _close_dialog_and_resume)
		else:
			hint_label.text = "靠近带青色轮廓的家具后再交互"
		return
	if hospital.near_gate():hospital.use_gate();return
	if hospital.near_entrance():hospital.enter();return
	if factory.nearby():factory.enter();return
	if is_instance_valid(temple) and temple.near_entrance():temple.enter();return
	if is_instance_valid(harbor) and harbor.nearby():harbor.enter();return
	if weapon_shop.nearby():weapon_shop.enter();return
	if _is_near_store_door():_enter_store();return
	if rv.is_near_side_door(hotaru.global_position):
		_enter_rv_interior()
		return
	if trolley.interact():return


func _is_near_store_door() -> bool:
	return trolley.near_door(STORE_DOOR,2.2)

func _is_near_store_exit() -> bool:
	for point in trolley.doorway_points():
		if store_interior.is_near_exit(point):return true
	return false


func _enter_store() -> void:
	if inside_rv or in_vehicle or inside_store:
		return
	AudioDirector.sound("door",hotaru.global_position)
	trolley.enter_store()
	inside_store = true
	if is_instance_valid(supply_quest):supply_quest.on_enter_store()
	_store_return_position = hotaru.global_position
	world_root.hide()
	rv.hide()
	for zombie in get_tree().get_nodes_in_group("zombies"):
		zombie.hide()
	store_interior.set_active(true)
	hotaru.set_ground_height(1.08)
	hotaru.global_position = store_interior.get_entry_position()
	hotaru.rotation.y = PI
	hotaru.set_active(true)
	camera.global_position = store_interior.get_camera_pivot() + Vector3(10, 10, 10)
	if is_instance_valid(zombie_population):zombie_population.enter_store()


func _exit_store() -> void:
	trolley.exit_store()
	AudioDirector.sound("door",hotaru.global_position)
	inside_store = false
	store_interior.set_active(false)
	world_root.show()
	rv.show()
	for zombie in get_tree().get_nodes_in_group("zombies"):
		zombie.show()
	if is_instance_valid(zombie_population):zombie_population.exit_store()
	hotaru.set_ground_height(0.95)
	hotaru.global_position = _store_return_position
	camera.global_position = hotaru.global_position + TOWN_CAMERA_OFFSET
	_set_phase(phase)


func _interact_store() -> void:
	# The exit always wins near the doorway; shelves are farther inside.
	if _is_near_store_exit():
		_exit_store()
		return
	var focused: String=store_interior.focus(hotaru.global_position)
	if focused.is_empty() and trolley.interact():return
	if focused in ["water","food"]:
		quantity_picker.open(focused)
		return
	if not focused.is_empty() and not GameState.try_add_items(GameState.STORE_LOOT[focused]):
		hotaru.set_active(false)
		_show_dialog("背包已满","携带这些物品会超过 10 kg。\n物资仍留在货架上，可以先整理随身背包。","知道了",_close_dialog_and_resume)
		return
	var station: String = store_interior.take_focused()
	if station.is_empty():
		hint_label.text = "靠近彩色标记的货架，按 E 搜刮；入口处按 E 离开"
		return
	GameState.store_looted[station]=true
	if is_instance_valid(supply_quest):supply_quest.on_loot(station)
	var message := ""
	match station:
		"food":
			message = "已将所选面包放入背包。每包 0.5 kg。"
		"water":
			message = "已将所选饮水放入背包。每桶 5 L、5 kg。

水很重，小萤最多随身携带 10 kg。可以回房车存放多余补给。"
		"medical":
			message = "找到绷带与消毒用品。医疗用品 +2。"
		"tools":
			GameState.clue_found = true
			if phase in [Phase.LEAVE_HOME, Phase.DRIVE_TO_STORE, Phase.CLEAR_ZOMBIES, Phase.SCAVENGE]:
				_set_phase(Phase.RETURN_TO_RV)
			message = "维修材料 +5。货架夹缝里有哥哥的纸条：\n\n“去镇北旧车站。不要相信穿白色防护服的人。”\n\n可以继续搜索，也可以返回房车。"
	hotaru.set_active(false)
	_show_dialog(str(StoreController.STATIONS[station].name), message, "收进背包", _close_dialog_and_resume)

func _interact_wardrobe() -> void:
	AudioDirector.sound("door",hotaru.global_position,-18)
	rv_interior.set_wardrobe_open(not rv_interior.wardrobe_open)
	if not rv_interior.wardrobe_open:return
	if GameState.bat_taken:return
	hotaru.set_active(false)
	_show_dialog("哥哥的棒球棍","小萤：哥哥的棒球棍……\n先借我用，找到你就还给你。\n\n木制棒球棍 · 0.90 kg\n攻击 2 · 五次命中击倒丧尸","放入背包",_take_starter_bat)
	dialog_item_image.texture=load("res://assets/ui/icons/bat.png")
	dialog_item_image.show()
	dialog_body.position=Vector2(224,118)
	dialog_body.size=Vector2(370,270)
	_add_dialog_button("先放着",_close_dialog_and_resume)

func _take_starter_bat() -> void:
	if GameState.bat_taken:
		_close_dialog_and_resume()
		return
	if not GameState.try_add_items({"bat":1}):
		_show_dialog("背包已满","棒球棍仍在衣柜里。先整理随身背包，腾出 0.90 kg。","知道了",_close_dialog_and_resume)
		return
	GameState.bat_taken=true
	GameState.inventory_changed.emit()
	rv_interior.sync_wardrobe()
	_close_dialog_and_resume()


func _enter_rv_interior(from_driving: bool = false) -> void:
	if inside_rv or in_vehicle or rv.wrecked:
		return
	if not from_driving and trolley.prepare_boarding():return
	AudioDirector.sound("door",hotaru.global_position)
	inside_rv = true
	rv.occupied=true
	seated_at_driver = false
	world_root.visible = false
	rv.visible = false
	rv_interior.set_active(true)
	hotaru.set_seated(false)
	hotaru.set_ground_height(RV_INTERIOR_ORIGIN.y + 1.13)
	hotaru.global_position = rv_interior.get_driver_stand_position() if from_driving else rv_interior.get_entry_position()
	hotaru.visible = true
	hotaru.set_active(true)
	hotaru.rotation.y = PI if from_driving else -PI / 2
	objective_label.text = "房车内部 · 初始生活基地"
	hint_label.text = "探索各功能区；走到右侧车门按 E 下车"
	# Cut directly to the final interior view instead of flying from town.
	_update_camera(100.0)
	if not from_driving:hotaru.play_boarding_step()


func _exit_rv_interior() -> void:
	if not inside_rv:
		return
	if is_instance_valid(harbor) and harbor.roof_interior_active:
		harbor.exit_roof_interior()
		return
	var exit_position := _find_rv_exit_position()
	if exit_position == Vector3.INF:
		hint_label.text = "右侧车门被挡住了，请换个停车位置再下车"
		return
	AudioDirector.sound("door",hotaru.global_position)
	inside_rv = false
	rv.occupied=false
	hotaru.cancel_boarding_step()
	seated_at_driver = false
	_camera_mouse_dragging = false
	_camera_touch_points.clear()
	rv_interior.set_active(false)
	world_root.visible = true
	rv.visible = true
	hotaru.set_ground_height(0.95)
	hotaru.set_seated(false)
	hotaru.global_position = exit_position
	hotaru.set_active(true)
	_set_phase(phase)
	camera.global_position = hotaru.global_position + TOWN_CAMERA_OFFSET
	trolley.deploy_on_exit()


func _find_rv_exit_position() -> Vector3:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = hotaru.get_child(0).shape
	query.collision_mask = 3
	query.exclude = [hotaru.get_rid()]
	var exit_position: Vector3 = rv.get_disembark_position()
	query.transform = Transform3D(Basis.IDENTITY, exit_position)
	if get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
		return exit_position
	return Vector3.INF


func _sit_at_driver() -> void:
	if not inside_rv or seated_at_driver:
		return
	seated_at_driver = true
	rv_interior.clear_interaction_focus()
	hotaru.set_seated(true)
	hotaru.global_position = rv_interior.get_driver_seat_position()
	# The cab points toward local -Z; the character model's forward axis is +Z.
	hotaru.rotation.y = PI
	hint_label.text = "已坐上驾驶座 · Space/上车 开始驾驶 · E 起身"


func _stand_from_driver_seat() -> void:
	if not seated_at_driver:
		return
	seated_at_driver = false
	hotaru.set_seated(false)
	hotaru.set_ground_height(RV_INTERIOR_ORIGIN.y + 1.13)
	hotaru.global_position = rv_interior.get_driver_stand_position()
	hotaru.rotation.y = PI
	hotaru.set_active(true)
	hint_label.text = "已离开驾驶座"


func _start_driving_from_cockpit() -> void:
	seated_at_driver = false
	inside_rv = false
	_camera_mouse_dragging = false
	_camera_touch_points.clear()
	rv_interior.set_active(false)
	world_root.visible = true
	rv.visible = true
	hotaru.set_seated(false)
	hotaru.set_ground_height(0.95)
	hotaru.set_active(false)
	hotaru.visible = false
	in_vehicle = true
	rv.set_active(true)
	if phase == Phase.LEAVE_HOME:
		_set_phase(Phase.DRIVE_TO_STORE)
	if is_instance_valid(zombie_population):zombie_population.register_authored()
	if is_instance_valid(supply_quest):supply_quest.begin()
	if phase == Phase.RETURN_TO_RV:
		_set_phase(Phase.RETURN_HOME if GameState.clue_found else Phase.EXPLORE)


func _attack() -> void:
	if is_instance_valid(trolley) and trolley.pushing:trolley.release();return
	if not controls_enabled or in_vehicle or inside_rv or phase == Phase.GAME_OVER:
		return
	hotaru.attack()


func _upgrade_rv() -> void:
	if not controls_enabled or phase != Phase.UPGRADE:
		return
	if not GameState.buy_first_upgrade():
		hint_label.text = "废料不足：需要 4 份"
		return
	rv.apply_first_upgrade()
	_set_phase(Phase.COMPLETE)
	_show_completion_dialog()


func _show_completion_dialog() -> void:
	controls_enabled = false
	hotaru.set_active(false)
	rv.set_active(false)
	_show_dialog(
		"第一天结束",
		"一级防撞装甲安装完成。\n房车获得了前保险杠、侧面装甲和车顶行李架。\n\n小萤决定天亮后前往镇北旧车站，继续寻找哥哥。",
		"再玩一次",
		_restart_scene
	)


func _show_dialog(title_text: String, body_text: String, primary_text: String, primary_callback: Callable) -> void:
	dialog_panel.visible = true
	dialog_title.text = title_text
	dialog_body.text = body_text
	dialog_body.position=Vector2(42,118)
	dialog_body.size=Vector2(552,270)
	dialog_item_image.hide()
	for child in dialog_actions.get_children():
		child.queue_free()
	_add_dialog_button(primary_text, primary_callback)


func _add_dialog_button(text_value: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(238.0, 72.0)
	button.focus_mode = Control.FOCUS_NONE
	_style_button(button, Color(0.34, 0.22, 0.16, 0.96))
	button.pressed.connect(callback)
	dialog_actions.add_child(button)


func _close_dialog_and_resume() -> void:
	dialog_panel.visible = false
	controls_enabled = true
	hotaru.set_active(true)


func _restart_scene() -> void:
	for action_name in ["move_forward", "move_backward", "move_left", "move_right"]:
		Input.action_release(action_name)
	get_tree().reload_current_scene()


func _on_hotaru_died() -> void:
	if is_instance_valid(shooting):shooting.stop()
	if is_instance_valid(sleep_controller) and sleep_controller.sleeping:sleep_controller.stop("休息中断。")
	controls_enabled = false
	phase = Phase.GAME_OVER
	rv.set_active(false)
	_set_phase(Phase.GAME_OVER)
	_update_hud()
	dialog_panel.hide()
	for zombie in get_tree().get_nodes_in_group("zombies"):
		zombie.set_physics_process(false)
		zombie.velocity=Vector3.ZERO
		zombie._play_animation("Bite" if zombie==hotaru.death_source else "Idle",true)
	if is_instance_valid(hotaru.death_source):
		var attacker: Node3D=hotaru.death_source
		var facing: Vector3=hotaru.global_position-attacker.global_position
		attacker.rotation.y=atan2(facing.x,facing.z)
		var push: Vector3=attacker.global_basis.inverse()*(hotaru.global_position-attacker.global_position).normalized()*0.28
		var rest: Vector3=attacker._visual.position
		var pounce:=create_tween()
		pounce.tween_property(attacker._visual,"position",rest+push,0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		pounce.tween_property(attacker._visual,"position",rest,0.5).set_trans(Tween.TRANS_SINE)

	await get_tree().create_timer(hotaru.DEATH_DURATION+0.3).timeout
	if not is_inside_tree():return
	_show_dialog("蛍倒下了" if hotaru.survival_death else "小萤被包围了", "长期缺水或饥饿耗尽了体力。记得及时寻找饮水与食物。" if hotaru.survival_death else "丧尸抓住了小萤。调整距离，在攻击后及时后退，再试一次。", "重新开始", _restart_scene)

func _on_rv_exploded(was_occupied: bool) -> void:
	if is_instance_valid(shooting):shooting.stop(false)
	if is_instance_valid(sleep_controller) and sleep_controller.sleeping:sleep_controller.stop("房车受损，休息中断。")
	var lethal: bool=was_occupied or hotaru.global_position.distance_to(rv.global_position)<6.0
	if not lethal:
		hint_label.text="房车被摧毁了，无法再次驾驶。"
		return
	if is_instance_valid(equipment_screen):equipment_screen.close()
	inside_rv=false
	inside_store=false
	in_vehicle=false
	seated_at_driver=false
	rv_interior.set_active(false)
	store_interior.set_active(false)
	world_root.show()
	rv.show()
	hotaru.cancel_boarding_step()
	hotaru.set_seated(false)
	hotaru.set_ground_height(0.95)
	hotaru.global_position=rv.get_disembark_position()
	hotaru.show()
	hotaru.health=0
	hotaru.set_active(false)
	hotaru.health_changed.emit(0,hotaru.max_health)
	controls_enabled=false
	phase=Phase.GAME_OVER
	_set_town_projection()
	camera.global_position=rv.global_position+TOWN_CAMERA_OFFSET
	camera.look_at(rv.global_position+Vector3(0,0.6,0))
	hotaru.play_death()
	_update_hud()
	await get_tree().create_timer(hotaru.DEATH_DURATION+0.3).timeout
	_show_dialog("房车被摧毁了","尸群撕开了车身，爆炸吞没了小萤。\n\n留出加速距离，别让尸群围住车辆。防撞装甲能让下一次突围更有把握。","重新开始",_restart_scene)


func _on_hotaru_attacked(hit_something: bool) -> void:
	if hit_something:
		hint_label.text = "命中！继续攻击或后退拉开距离"
	else:
		hint_label.text = "攻击落空：再靠近一点"


func _on_health_changed(_current: float, _maximum: float) -> void:
	_update_hud()


func _on_speed_changed(_speed_kph: int) -> void:
	_update_hud()


func _update_hud() -> void:
	if not is_instance_valid(hotaru) or not is_instance_valid(rv) or not is_instance_valid(rv_interior):
		return
	if is_instance_valid(hospital) and (hospital.active or hospital.in_campus):
		hospital.update_hud()
		return
	if is_instance_valid(factory) and factory.active:
		factory.update_hud()
		return
	if is_instance_valid(temple) and temple.active:
		temple.update_hud()
		return
	if is_instance_valid(harbor) and harbor.active:
		harbor.update_hud()
		return
	if is_instance_valid(shooting) and shooting.active:
		shooting.update_hud()
		return
	status_label.text = "生命%d/%d  料%d  食%d  水%d  药%d" % [hotaru.health, hotaru.max_health, GameState.scrap, GameState.food, GameState.water, GameState.medicine]
	if inside_store:
		speed_label.text = "店内"
	elif inside_rv and is_instance_valid(harbor) and harbor.roof_interior_active:
		speed_label.text = "上层扩展舱"
	elif inside_rv:
		speed_label.text = "驾驶席" if seated_at_driver else "室内"
	else:
		speed_label.text = "%d km/h" % int(round(absf(rv.speed) * 3.6)) if in_vehicle else "步行"
	var near_rv: bool = not inside_rv and rv.is_near_side_door(hotaru.global_position)
	var can_enter_interior: bool = near_rv
	attack_button.visible = not service.active and not in_vehicle and not inside_rv and phase not in [Phase.TITLE, Phase.COMPLETE, Phase.GAME_OVER]
	for button in get_tree().get_nodes_in_group("movement_controls"):button.visible=phase!=Phase.GAME_OVER and not sleep_controller.sleeping
	if sleep_controller.sleeping:
		attack_button.hide()
		interact_button.hide()
		vehicle_button.hide()
		upgrade_button.hide()
		hint_label.text=""
		return
	if phase==Phase.GAME_OVER:
		interact_button.hide()
		vehicle_button.hide()
		upgrade_button.hide()
		hint_label.text=""
		return
	var near_store: bool = not inside_rv and not inside_store and _is_near_store_door()
	var near_temple: bool = is_instance_valid(temple) and temple.near_entrance()
	var near_harbor: bool = is_instance_valid(harbor) and harbor.nearby()
	interact_button.visible = not in_vehicle and (inside_rv or near_store or near_temple or near_harbor or factory.nearby() or phase == Phase.SCAVENGE or can_enter_interior)
	interact_button.text = "进入工厂" if factory.nearby() else ("进入寺庙" if near_temple else ("驾驶吊车" if near_harbor else ("进店 E" if near_store else "交互 E")))
	vehicle_button.visible = not service.active and ((inside_rv and seated_at_driver) or (not inside_rv and phase not in [Phase.TITLE, Phase.COMPLETE, Phase.GAME_OVER, Phase.UPGRADE]))
	vehicle_button.text = "开始驾驶" if inside_rv and seated_at_driver else ("停车/起身" if in_vehicle else "侧门上车")
	upgrade_button.visible = not inside_rv and phase == Phase.UPGRADE

	if inside_store:
		vehicle_button.hide()
		upgrade_button.hide()
		interact_button.show()
		interact_button.text="离开便利店" if _is_near_store_exit() else "交互 E"
	if dialog_panel.visible:
		return
	if inside_store:
		objective_label.text = "便利店 · 搜索生存物资 %d / 4" % store_interior.looted.size()
		var focused: String = store_interior.focus(hotaru.global_position)
		if _is_near_store_exit():
			hint_label.text = "便利店入口：E / 交互返回街道"
		elif not focused.is_empty():
			hint_label.text = "可搜刮：%s · E / 交互" % StoreController.STATIONS[focused].name
		else:
			hint_label.text = "沿货架间通道搜索 · 彩色圆环标记货架，可重复取货"
		return
	if inside_rv:
		if is_instance_valid(harbor) and harbor.roof_interior_active:
			rv_interior.clear_interaction_focus()
			objective_label.text = "房车上层 · 第一层集装箱扩展舱"
			vehicle_button.hide()
			if harbor.near_roof_hatch():
				interact_button.text = "下梯子 E"
				hint_label.text = "地板检修口：按 E / 交互沿梯子返回驾驶舱"
			else:
				interact_button.text = "交互 E"
				hint_label.text = "这是第一层可扩建空间；走到前端地板检修口可返回"
			return
		objective_label.text = "房车内部 · 驾驶 / 睡眠 / 烹饪 / 维修 / 储物"
		if not GameState.bat_taken and not GameState.odachi_taken:objective_label.text="小萤：不能再空着手了……\n哥哥的棒球棍还在衣柜里。"
		if seated_at_driver:
			rv_interior.clear_interaction_focus()
			hint_label.text = "驾驶座：Space/“开始驾驶”启动车辆 · E/交互起身"
		elif rv_interior.is_near_exit(hotaru.global_position):
			rv_interior.clear_interaction_focus()
			interact_button.text = "下车 E"
			hint_label.text = "右侧车门：E / 下车返回车外"
		else:
			var focused_module_name: String = rv_interior.update_interaction_focus(hotaru.global_position)
			if is_instance_valid(harbor) and harbor.near_interior_ladder():
				rv_interior.clear_interaction_focus()
				interact_button.text = "爬上去 E"
				hint_label.text = "副驾驶侧梯子：按 E / 交互进入上层集装箱"
			elif not focused_module_name.is_empty():
				hint_label.text = "可交互：%s · 按 E 或“交互”" % focused_module_name
			else:
				hint_label.text = "拖拽旋转 · 滚轮/双指缩放 · 靠近家具可交互"
		if not seated_at_driver:
			if not GameState.bat_taken:hint_label.text+="\n小萤：哥哥的棒球棍还在衣柜里。"
			elif GameState.weapon_hand().is_empty() and int(GameState.items.get("bat",0))>0:hint_label.text+="\n点击左上头像，将棒球棍拖到手部栏位。"
	elif in_vehicle:
		hint_label.text = "摇杆上推前进、下拉倒车，斜推边开边转弯" if OS.has_feature("android") else "WASD/方向键驾驶 · Space 停车回车内，再到右侧门下车"
	elif near_store:
		hint_label.text = "便利店正门：按 E / 进店进入，返回入口可离开"
	elif near_temple:
		hint_label.text = "寺庙正门：按 E / 交互进入安全区域；从侧面靠近不会切换镜头"
	elif near_harbor:
		interact_button.text = "驾驶吊车"
		hint_label.text = "港口吊车驾驶室：按 E / 交互启动吊装作业"
	elif near_rv:
		interact_button.text = "上车 E"
		hint_label.text = "房车右侧车门：E / Space 进入车内"
	elif phase == Phase.CLEAR_ZOMBIES:
		hint_label.text = "靠近后按 J/攻击；剩余丧尸：%d" % _alive_zombie_count()
	elif phase == Phase.UPGRADE:
		hint_label.text = "点击“改装”或按 Q，消耗 4 份废料"
	else:
		hint_label.text = "拖动左下摇杆移动" if OS.has_feature("android") else "WASD/方向按钮移动"

	if hospital.near_gate():
		interact_button.show();interact_button.text="推开院门 E"
		hint_label.text="医院园区 · 推开院门进入"
	elif hospital.near_entrance():
		interact_button.show()
		interact_button.text="进入医院"
		hint_label.text="医院正门：交互进入 · 主楼两层 / 附楼一层"
	elif factory.nearby():
		interact_button.show()
		interact_button.text="进入工厂"
		hint_label.text="工厂正门：交互进入；右侧上车按钮进入房车"
	elif near_temple:
		interact_button.show()
		interact_button.text="进入寺庙"
		hint_label.text="寺庙正门：交互进入"
	elif near_harbor:
		interact_button.show()
		interact_button.text="驾驶吊车"
		hint_label.text="港口吊车：交互进入驾驶室"
	elif is_instance_valid(weapon_shop) and weapon_shop.nearby():
		interact_button.show()
		interact_button.text="进入武器店"
		hint_label.text="武器店正门：交互进入"
	elif is_instance_valid(trolley) and not in_vehicle and not inside_rv and trolley.nearby() and not near_rv and not near_store and not factory.nearby() and not inside_store:
		interact_button.show()
		interact_button.hide()
		hint_label.text="推车 %.1f / 25 kg · 交互松手/推行"%(GameState.cart_grams()/1000.0)
	if is_instance_valid(trolley) and trolley.pushing:attack_button.hide()


func _set_town_projection() -> void:
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	var zoom_factor: float=outdoor_zoom.current_factor if is_instance_valid(outdoor_zoom) else 1.0
	camera.size = (15.0 if not in_vehicle else 20.0)*zoom_factor


func _update_camera(delta: float) -> void:
	if is_instance_valid(opening) and opening.is_cinematic():
		return
	if not is_instance_valid(camera) or not is_instance_valid(hotaru) or not is_instance_valid(rv) or not is_instance_valid(rv_interior):
		return
	if is_instance_valid(shooting) and shooting.active:
		shooting.update_camera(delta)
		return
	if is_instance_valid(hospital) and (hospital.active or hospital.in_campus):
		hospital.update_camera(delta)
		return
	if is_instance_valid(factory) and factory.active:
		factory.update_camera(delta)
		return
	if is_instance_valid(temple) and temple.active:
		temple.update_camera(delta)
		return
	if is_instance_valid(harbor) and harbor.active:
		harbor.update_camera(delta)
		return
	if is_instance_valid(harbor) and (harbor.roof_interior_active or harbor.roof_transitioning):
		harbor.update_roof_camera(delta)
		return
	if inside_store:
		_set_town_projection()
		camera.size = 10.8
		var center: Vector3 = store_interior.get_camera_pivot()
		camera.global_position = center + Vector3(10, 10, 10)
		camera.look_at(center, Vector3.UP)
		store_interior.update_cutaway(camera.global_position)
		return
	if inside_rv:
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.keep_aspect = Camera3D.KEEP_HEIGHT
		var interior_center: Vector3 = _interior_camera_focus_override if _interior_camera_focus_override is Vector3 else rv_interior.get_camera_pivot()
		_update_rv_orbit_camera(delta,interior_center)
		rv_interior.update_camera_cutaway(camera.global_position)
		return
	var target: Node3D = rv if in_vehicle else hotaru
	_set_town_projection()
	var offset := TOWN_CAMERA_OFFSET
	var desired := target.global_position + offset
	camera.global_position = camera.global_position.lerp(desired, 1.0 - exp(-delta * 5.2))
	camera.look_at(target.global_position + Vector3(0.0, 0.6, 0.0), Vector3.UP)


func _update_rv_orbit_camera(delta: float,center: Vector3) -> void:
	camera.projection=Camera3D.PROJECTION_PERSPECTIVE
	camera.keep_aspect=Camera3D.KEEP_HEIGHT
	var horizontal: float=cos(_interior_camera_pitch)*_interior_camera_distance
	var offset:=Vector3(sin(_interior_camera_yaw)*horizontal,sin(_interior_camera_pitch)*_interior_camera_distance,cos(_interior_camera_yaw)*horizontal)
	camera.global_position=camera.global_position.lerp(center+offset,1.0-exp(-delta*7.0))
	camera.look_at(center,Vector3.UP)


func _alive_zombie_count() -> int:
	var count := 0
	for zombie in get_tree().get_nodes_in_group("store_zombies"):
		if is_instance_valid(zombie) and not zombie.is_queued_for_deletion():
			count += 1
	return count


func _add_asset(model_name: String, position_value: Vector3, rotation_y: float = 0.0, scale_value: Vector3 = Vector3.ONE) -> Node3D:
	var path := ASSET_ROOT + model_name + ".gltf"
	if not ResourceLoader.exists(path):
		push_warning("Missing optional city asset: " + path)
		return null
	var resource := load(path)
	if not resource is PackedScene:
		push_warning("City asset was not imported as PackedScene: " + path)
		return null
	var instance: Node3D = resource.instantiate()
	instance.name = model_name
	instance.position = position_value
	instance.rotation.y = rotation_y
	instance.scale = scale_value
	world_root.add_child(instance)
	if model_name.begins_with("Building_"):
		town_occlusion.register_building(instance)
	return instance


func _add_box(
	parent: Node,
	node_name: String,
	size_value: Vector3,
	position_value: Vector3,
	color: Color,
	with_collision: bool = false,
	collision_layer_value: int = 3,
	alpha: float = 1.0
) -> Node3D:
	var container := Node3D.new()
	container.name = node_name
	container.position = position_value
	parent.add_child(container)

	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size_value
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color.r, color.g, color.b, alpha)
	material.roughness = 0.88
	if alpha < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_instance.material_override = material
	container.add_child(mesh_instance)

	if with_collision:
		var body := StaticBody3D.new()
		body.collision_layer = collision_layer_value
		body.collision_mask = 0
		var shape_node := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size_value
		shape_node.shape = shape
		body.add_child(shape_node)
		container.add_child(body)
	return container


func _add_static_collision(size_value: Vector3, position_value: Vector3, layer_value: int) -> void:
	var body := StaticBody3D.new()
	body.position = position_value
	body.collision_layer = layer_value
	body.collision_mask = 0
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size_value
	shape_node.shape = shape
	body.add_child(shape_node)
	world_root.add_child(body)


func _add_label(text_value: String, position_value: Vector3, color: Color, font_size_value: int) -> Label3D:
	var label := Label3D.new()
	label.text = text_value
	label.position = position_value
	label.font_size = font_size_value
	label.outline_size = 8
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	world_root.add_child(label)
	return label








func is_under_attack() -> bool:
	if Time.get_ticks_msec()-rv.last_hostile_attack_ms<3000:return true
	for actor in get_tree().get_nodes_in_group("zombies"):
		if actor._dying or actor.is_queued_for_deletion():continue
		var victim: Node3D=actor._choose_target()
		if not is_instance_valid(victim):continue
		var point: Vector3=rv.closest_hull_point(actor.global_position) if victim==rv else victim.global_position
		point.y=actor.global_position.y
		if actor.global_position.distance_to(point)<=actor.ATTACK_RANGE+.15:return true
	return false

func can_save_safely() -> bool:
	if is_instance_valid(fabrication) and fabrication.active:return false
	if is_instance_valid(factory) and (factory.active or factory.transitioning):return false
	if is_instance_valid(hospital) and (hospital.active or hospital.in_campus or hospital.gate_busy):return false
	if is_instance_valid(temple) and temple.active:return false
	if is_instance_valid(harbor) and (harbor.active or harbor.roof_interior_active or harbor.roof_transitioning):return false
	if is_instance_valid(shooting) and shooting.active:return false
	if is_instance_valid(trolley) and trolley.loading:return false
	if is_instance_valid(weapon_shop) and weapon_shop.active:return false
	return phase not in [Phase.TITLE,Phase.GAME_OVER] and hotaru.health>0 and not (is_instance_valid(sleep_controller) and sleep_controller.sleeping) and not (is_instance_valid(service) and service.active) and not is_under_attack()

func rest_notice(message: String) -> void:
	day_cycle.notice.text=message
	day_cycle._notice_time=4
