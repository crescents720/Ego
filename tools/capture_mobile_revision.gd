extends SceneTree
func _initialize() -> void:call_deferred("run")
func shot(label: String) -> void:
 for i in range(8):await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://artifacts/"+label+".png")
func run() -> void:
 var main=load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 root.get_node("GameState").suppress_save=true
 await shot("mobile_cover_revision2")
 main._start_new_game()
 main.set_process(false)
 main.zombie_population.set_process(false)
 for z in get_nodes_in_group("zombies"):z.queue_free()
 await physics_frame
 main._set_phase(main.Phase.EXPLORE)
 main.mobile_joystick.setup(main,true)
 for button in get_nodes_in_group("movement_controls"):button.hide()
 main.hotaru.position=Vector3(0,.95,200)
 main.rv.position=Vector3(4,1.02,200)
 main._update_camera(1)
 main._update_hud()
 for button in get_nodes_in_group("movement_controls"):button.hide()
 await shot("mobile_joystick_walk")
 main.hotaru.position=main.STORE_DOOR
 main._enter_store()
 for z in get_nodes_in_group("zombies"):z.queue_free()
 main.hotaru.position=main.STORE_ORIGIN+Vector3(2.7,1.08,3.12)
 main._update_camera(1)
 main._update_hud()
 for button in get_nodes_in_group("movement_controls"):button.hide()
 await shot("mobile_store_exit_zone")
 root.get_node("AudioDirector").stop_all()
 main.queue_free()
 await process_frame
 quit()
