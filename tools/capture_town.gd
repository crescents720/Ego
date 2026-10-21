extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var overview:=not OS.get_cmdline_user_args().has("street")
	if overview:
		root.size=Vector2i(1200,1400)
		root.content_scale_size=Vector2i(1200,1400)
	var main=load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	root.get_node("GameState").suppress_save=true
	main._start_new_game()
	main.set_process(false)
	main.hotaru.set_active(false)
	main.get_node("HUD").hide()
	main.town_layout.set_overview(overview)
	main.camera.far=1200
	main.camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	if overview:
		for child in main.get_children():
			if child is WorldEnvironment: child.environment.fog_enabled=false
		main.camera.size=610
		main.camera.global_position=Vector3(70,700,120)
		main.camera.look_at(Vector3(70,0,120),Vector3(0,0,-1))
		for label in main.find_children("*","Label3D",true,false): label.hide()
		for i in range(main.town_layout.site_labels.size()):
			var label=main.town_layout.site_labels[i]
			label.text=main.TownLayout.SITES[i].name+"\n场地预留"
			label.pixel_size=0.15
			label.font_size=42
			label.show()
	else:
		main.hotaru.global_position=Vector3(-60,0.95,26)
		main.camera.size=37
		main.camera.global_position=main.hotaru.global_position+Vector3(-24,24,-24)
		main.camera.look_at(main.hotaru.global_position)
	for frame in range(35): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/town_"+("framework" if overview else "street_buildings")+".png")
	quit()
