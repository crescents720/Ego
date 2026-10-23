extends SceneTree


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	root.size = Vector2i(720, 1280)
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var state = root.get_node("GameState")
	state.suppress_save = true
	main._start_new_game()
	main._set_phase(main.Phase.EXPLORE)
	main.zombie_population.set_process(false)
	for zombie in get_nodes_in_group("zombies"):
		zombie.queue_free()
	await physics_frame
	main.hotaru.global_position = main.temple.DOOR + Vector3(0.0, 0.0, -1.15)
	main.hotaru.rotation.y = 0.0
	main.temple._entry_lock = 0.0
	main._update_hud()
	main.set_process(false)
	main.camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	main.camera.keep_aspect = Camera3D.KEEP_WIDTH
	main.camera.size = 13.5
	main.camera.global_position = main.temple.DOOR + Vector3(9.5, 8.5, -11.0)
	main.camera.look_at(main.temple.SITE + Vector3(0.0, 2.1, -2.7), Vector3.UP)
	for i in range(10):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/temple_front_gate.png")
	root.get_node("AudioDirector").stop_all()
	quit()
