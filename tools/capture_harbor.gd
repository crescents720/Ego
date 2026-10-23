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
	harbor.update_camera(100)
	harbor.update_hud()
	await shot("res://artifacts/harbor_crane_overview.png")

	var cargo: Dictionary=harbor.cargoes[0]
	var hook=harbor.crane.to_global(Vector3(0,harbor.SPREADER_BOTTOM+harbor.hoist_offset,harbor.SPREADER_Z))
	cargo.node.global_position=hook-Vector3(0,float(cargo.height),0)
	harbor.toggle_cargo()
	harbor.hoist_offset=-3.65
	harbor._update_spreader()
	harbor._update_held_cargo()
	var bottom: Vector3=cargo.node.global_position
	main.rv.global_position=Vector3(bottom.x,1.02,bottom.z)
	main.rv.rotation.y=PI/2
	harbor.toggle_cargo()
	harbor.exit_crane()
	main.set_process(false)
	main.camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	main.camera.keep_aspect=Camera3D.KEEP_WIDTH
	main.camera.size=13.5
	var focus=main.rv.global_position+Vector3(0,2.8,0)
	main.camera.global_position=focus+Vector3(-15,12,-15)
	main.camera.look_at(focus,Vector3.UP)
	main.objective_label.text="房车扩展原型 · 20 尺集装箱临时试装"
	main.hint_label.text="尚未安装固定五金与层间通道；下一阶段解锁永久固定"
	await shot("res://artifacts/harbor_rv_container.png")
	print("HARBOR_CAPTURE_PASS")
	quit()
