extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var main=load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 root.get_node("GameState").suppress_save=true
 root.get_node("AudioDirector").settings.open()
 await process_frame
 await process_frame
 await process_frame
 root.get_texture().get_image().save_png("res://artifacts/audio_settings.png")
 quit()
