extends SceneTree
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 var main = load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 main._start_new_game()
 main.hotaru.global_position = main.rv.get_disembark_position()
 main.camera.global_position = main.hotaru.global_position + main.TOWN_CAMERA_OFFSET
 main._capture_preview = true
 main._preview_filename = "bounder_game.png"
