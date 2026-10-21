extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var main=load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 root.get_node("GameState").suppress_save=true
 main._start_new_game()
 main.set_process(false)
 main.zombie_population.set_process(false)
 main.hotaru.set_active(false)
 main.camera.position=Vector3(1000,50,1000)
 main.camera.look_at(Vector3(1100,0,1100))
 await physics_frame
 var day:=get_nodes_in_group("town_wanderers").size()
 root.get_node("GameState").world_seconds=190
 main.day_cycle._process(.1)
 for i in range(8):
  main.zombie_population._process(.5)
  await physics_frame
 var night:=get_nodes_in_group("town_wanderers").size()
 print("NIGHT_POPULATION day=",day," night=",night)
 if night<day*2:push_error("Night density less than twice day");quit(1);return
 quit()
