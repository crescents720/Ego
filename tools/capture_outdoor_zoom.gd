extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var main=load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	root.get_node("GameState").suppress_save=true
	main._start_new_game()
	main.hotaru.global_position=Vector3(-60,0.95,26)
	main.outdoor_zoom.target_factor=1.8
	main.outdoor_zoom.current_factor=1.8
	main._update_camera(100)
	main._capture_preview=true
	main._preview_filename="outdoor_camera_zoom.png"
