extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var main=load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	root.get_node("GameState").suppress_save=true
	main._start_new_game()
	var driving:=OS.get_cmdline_user_args().has("drive")
	if driving:
		main.hotaru.global_position=main.rv.get_disembark_position()
		main._enter_rv_interior()
		main.hotaru.global_position=main.rv_interior.get_driver_stand_position()
		main._interact()
		main._toggle_vehicle()
		main.rv.global_position=Vector3(150,1.02,100)
		main.minimap.zoom_out()
	else:
		main.hotaru.global_position=Vector3(0,0.95,18)
	main._update_camera(100)
	main._capture_preview=true
	main._preview_filename="minimap_"+("driving" if driving else "walking")+".png"
