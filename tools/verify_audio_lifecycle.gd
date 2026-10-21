extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var main=load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 current_scene=main
 root.get_node("GameState").suppress_save=true
 var audio=root.get_node("AudioDirector")
 var vehicle=main.rv
 main.remove_child(vehicle)
 audio._process(.016)
 main.add_child(vehicle)
 if reload_current_scene()!=OK:quit(1);return
 await process_frame
 await process_frame
 if not is_instance_valid(audio.main) or audio.main!=current_scene or not audio.main.rv.is_inside_tree():
  push_error("Audio director did not attach to reloaded scene")
  quit(1)
  return
 audio._process(.016)
 audio.stop_all()
 print("AUDIO_SCENE_RELOAD_PASS")
 current_scene.queue_free()
 await process_frame
 quit()
