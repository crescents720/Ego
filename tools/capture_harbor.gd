extends SceneTree


func _initialize() -> void:
	call_deferred("run")


func shot(path: String) -> void:
	for i in range(24):await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)


func run() -> void:
	root.size=Vector2i(720,1280)
	var main=load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var state=root.get_node("GameState")
	state.suppress_save=true
	main._start_new_game()
	main._set_phase(main.Phase.EXPLORE)
	main.zombie_population.set_process(false)
	for zombie in get_nodes_in_group("zombies"):zombie.queue_free()
	var harbor=main.harbor
	main.hotaru.global_position=harbor.crane.to_global(Vector3(4.1,.95,-2.3))
	harbor.enter()
	await create_timer(2.0).timeout
	harbor.update_camera(100)
	harbor.update_hud()
	await shot("res://artifacts/harbor_crane_overview.png")

	var cargo: Dictionary=harbor.cargoes[0]
	harbor.crane.global_position=Vector3(cargo.node.global_position.x,.12,cargo.node.global_position.z-harbor.SPREADER_Z)
	harbor.hoist_offset=harbor.HOIST_MIN
	harbor._update_spreader()
	harbor.toggle_cargo()
	harbor.hoist_offset=0.0
	harbor._update_held_cargo()
	harbor.crane.global_position=Vector3(harbor.RV_LIFT_BAY.x,.12,harbor.RV_LIFT_BAY.z-harbor.SPREADER_Z)
	harbor.hoist_offset=-3.26
	harbor._update_spreader()
	harbor._update_held_cargo()
	var bottom: Vector3=cargo.node.global_position
	main.rv.global_position=Vector3(bottom.x,1.02,bottom.z)
	main.rv.rotation.y=PI/2
	harbor.toggle_cargo()
	harbor.hoist_offset=0.0
	harbor._update_spreader()
	harbor.exit_crane()
	await create_timer(2.0).timeout
	harbor.fix_roof_container()
	main.set_process(false)
	main.camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	main.camera.keep_aspect=Camera3D.KEEP_WIDTH
	main.camera.size=13.5
	var focus=main.rv.global_position+Vector3(0,2.8,0)
	main.camera.global_position=focus+Vector3(-15,12,-15)
	main.camera.look_at(focus,Vector3.UP)
	main.objective_label.text="房车扩展原型 · 20 尺集装箱已固定"
	main.hint_label.text="承重框已固定 · 从副驾驶侧梯子进入上层"
	await shot("res://artifacts/harbor_rv_container.png")
	main._enter_rv_interior(true)
	main.hotaru.global_position=main.rv_interior.get_driver_stand_position()
	main._update_hud()
	main._update_camera(100)
	await shot("res://artifacts/harbor_driver_interaction.png")
	main.hotaru.global_position=main.rv_interior.to_global(Vector3(-.30,1.13,-4.57))
	main._update_hud()
	main._update_camera(100)
	await shot("res://artifacts/harbor_passenger_ladder.png")
	main._interact()
	await create_timer(.8).timeout
	main._update_hud()
	harbor.update_roof_camera(100)
	await shot("res://artifacts/harbor_upper_interior.png")
	main._interior_camera_yaw+=PI
	main.hotaru.global_position=harbor.ROOF_INTERIOR_ORIGIN+Vector3(.4,.95,1.5)
	main.hotaru.rotation.y=PI
	main._update_hud()
	harbor.update_roof_camera(100)
	await shot("res://artifacts/harbor_upper_hatch.png")
	print("HARBOR_CAPTURE_PASS")
	quit()
