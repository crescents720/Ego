extends SceneTree

var errors := 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, text: String) -> void:
	if not ok:
		errors += 1
		push_error(text)


func shot() -> void:
	for i in range(8):
		await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/temple_safe_interior.png")


func run() -> void:
	root.size = Vector2i(720, 1280)
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var state = root.get_node("GameState")
	state.suppress_save = true
	main._start_new_game()
	main._set_phase(main.Phase.EXPLORE)
	state.odachi_taken = false
	state.items.erase("odachi")
	state.equipment.right_hand = ""
	state.equipment.left_hand = ""
	state.inventory_changed.emit()
	await physics_frame

	var temple = main.temple
	check(temple.get_parent() == main, "Temple controller must stay active outside world_root")
	check(temple.model.get_parent() == main.world_root, "Temple shell is not part of town world")
	check(temple.altar.get_parent() == main.world_root, "Odachi altar is not inside town temple")
	check(temple.RACK.z > temple.SITE.z, "Odachi is not displayed inside the central hall")

	# The open sides and rear are scenery only: proximity must never switch camera.
	for approach in [Vector2(-8.0, 0.0), Vector2(8.0, 0.0), Vector2(0.0, 7.0)]:
		temple._entry_lock = 0.0
		main.hotaru.set_ground_height(temple.OUTDOOR_GROUND_Y)
		main.hotaru.global_position = temple.SITE + Vector3(approach.x, temple.OUTDOOR_GROUND_Y - temple.SITE.y, approach.y)
		temple._process(0.01)
		check(not temple.active and not temple.near_entrance(), "Temple side/rear approach incorrectly activated close camera: %s" % approach)

	# Even at the front gate entry is explicit, matching the factory interaction.
	temple._entry_lock = 0.0
	main.hotaru.global_position = temple.DOOR
	temple._process(0.01)
	check(not temple.active and temple.near_entrance(), "Temple front gate was not focused")
	main._interact()
	check(temple.active, "Temple front-gate interaction did not enter")
	check(is_equal_approx(main.hotaru.global_position.y, temple.TEMPLE_GROUND_Y), "Temple did not raise Hotaru to veranda floor")
	await physics_frame
	check(not main.hotaru.test_move(main.hotaru.global_transform,Vector3(0,0,2.4)),"temple centre entry corridor has no column collision")
	temple.leave(true)

	# An outdoor zombie already near the temple must disappear and stop completely.
	var zombie = main.ZombieController.new()
	main.add_child(zombie)
	zombie.global_position = temple.SITE + Vector3(0.0, 0.82, -3.0)
	zombie.set_target(main.hotaru)
	zombie.visible = true
	zombie.set_physics_process(true)
	await physics_frame
	temple._entry_lock = 0.0
	main.hotaru.set_ground_height(temple.OUTDOOR_GROUND_Y)
	main.hotaru.global_position = temple.DOOR
	temple.enter()
	check(temple.active, "Temple safe exploration did not activate")
	check(not zombie.visible and not zombie.is_physics_processing() and not zombie.is_in_group("zombies"), "Zombie remained targetable inside temple safe area")
	check(not main.zombie_population.is_processing(), "Town population can spawn zombies while temple is active")
	main._update_camera(0.0)
	check(main.camera.projection == Camera3D.PROJECTION_PERSPECTIVE, "Temple did not switch to third-person perspective")
	check(not main.can_save_safely(), "Temple transition state incorrectly allows saving")

	# The unique odachi is presented on the offering stand, within normal reach.
	main.hotaru.global_position = temple.RACK + Vector3(0.0, temple.TEMPLE_GROUND_Y - temple.RACK.y, -1.15)
	check(temple.nearby(), "Offering-stand odachi is unreachable")
	var yaw_before: float = temple.yaw
	temple.dragging = true
	var drag := InputEventMouseMotion.new()
	drag.relative = Vector2(50.0, 8.0)
	temple._unhandled_input(drag)
	check(not is_equal_approx(temple.yaw, yaw_before), "Temple third-person mouse camera does not rotate")
	temple.interact()
	check(state.odachi_taken and state.weapon_id() == "odachi", "Temple odachi pickup/equip failed")
	check(not temple.sword.visible and temple.label.text.contains("空刀架"), "Offering stand did not become empty")
	var odachi_count := int(state.items.get("odachi", 0))
	temple.interact()
	check(int(state.items.get("odachi", 0)) == odachi_count, "Temple odachi duplicated")
	temple.yaw = 0.0
	temple.pitch = 0.35
	temple.update_camera(0.0)
	await shot()

	# The marked front doorway is the normal exit and restores the outdoor state.
	main.hotaru.global_position = temple.SITE + Vector3(0.0, temple.TEMPLE_GROUND_Y - temple.SITE.y, -5.55)
	check(temple.near_exit(), "Temple front exit was not focused")
	main._interact()
	check(not temple.active, "Temple front-gate interaction did not leave")
	check(is_equal_approx(main.hotaru.global_position.y, temple.OUTDOOR_GROUND_Y), "Temple exit did not restore town floor")
	check(zombie.visible and zombie.is_physics_processing() and zombie.is_in_group("zombies"), "Outdoor zombie state was not restored on exit")
	check(main.zombie_population.is_processing(), "Town population stayed paused after temple exit")
	main._update_camera(100.0)
	check(main.camera.projection == Camera3D.PROJECTION_ORTHOGONAL, "Temple exit did not restore town camera")

	print("TEMPLE_INTERIOR_CHECK errors=", errors)
	root.get_node("AudioDirector").stop_all()
	quit(errors)
