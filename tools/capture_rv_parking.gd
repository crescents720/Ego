extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var main=load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 root.get_node("GameState").suppress_save=true
 main._start_new_game()
 main.rv.global_position=Vector3(-134.3,1.02,-29.65)
 main.rv.rotation.y=-PI/2
 main.rv.set_physics_process(false)
 main.in_vehicle=true
 main.hotaru.hide()
 main._update_camera(100)
 main._capture_preview=true
 main._preview_filename="rv_parking_scale.png"

