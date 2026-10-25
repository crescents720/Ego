extends SceneTree
var main
func _initialize():call_deferred("run")
func shot(label):
 for i in range(12):await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://artifacts/hospital_campus_"+label+".png")
func run():
 root.size=Vector2i(900,1200);root.content_scale_size=Vector2i(720,1280)
 root.get_node("GameState").suppress_save=true
 main=load("res://scenes/main.tscn").instantiate();root.add_child(main);main._start_new_game();main._set_phase(main.Phase.EXPLORE)
 main.zombie_population.set_process(false)
 for z in get_nodes_in_group("zombies"):z.queue_free()
 main.set_process(false)
 var h=main.hospital
 main.camera.projection=Camera3D.PROJECTION_ORTHOGONAL;main.camera.size=115;main.camera.position=h.SITE+Vector3(65,75,63);main.camera.look_at(h.SITE)
 await shot("overview")
 main.hotaru.global_position=h.GATE+Vector3(2.4,.87,0);main._interact();await create_timer(2).timeout
 h.update_camera(0);main._update_hud();await shot("entrance")
 main.hotaru.global_position=Vector3(43,.95,258);h.yaw=PI;h.update_camera(0);await shot("courtyard")
 main.hotaru.global_position=h.DOOR+Vector3(0,0,1);main._interact();await physics_frame
 main.hotaru.global_position=h.to_interior_world(Vector3(0,.95,-8));h.yaw=0;h.update_camera(0);main._update_hud();await shot("exit")
 root.get_node("AudioDirector").set_process(false);root.get_node("AudioDirector").stop_all()
 await create_timer(.12).timeout
 main.queue_free();await process_frame;await process_frame;quit()
