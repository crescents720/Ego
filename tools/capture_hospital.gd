extends SceneTree
var main
func _initialize():call_deferred("run")
func shot(name):
 for i in range(8):
  if is_instance_valid(main.hospital) and main.hospital.active:main.hospital.update_camera(0)
  await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://artifacts/hospital_"+name+".png")
func run():
 root.size=Vector2i(900,1200);root.content_scale_size=Vector2i(720,1280)
 root.get_node("GameState").suppress_save=true
 main=load("res://scenes/main.tscn").instantiate();root.add_child(main);main._start_new_game();main._set_phase(main.Phase.EXPLORE)
 main.zombie_population.set_process(false)
 for z in get_nodes_in_group("zombies"):z.queue_free()
 main.set_process(false)
 var h=main.hospital
 main.camera.projection=Camera3D.PROJECTION_ORTHOGONAL;main.camera.size=95;main.camera.position=h.SITE+Vector3(50,55,78);main.camera.look_at(h.SITE+Vector3(0,2,0))
 await shot("exterior")
 h.in_campus=true;main.hotaru.global_position=h.DOOR+Vector3(0,0,1);main._interact()
 for entry in [["reception",Vector3(0,.95,-7),PI,0],["corridor",Vector3(-10.95,.95,4.7),PI,0],["ward",Vector3(-8.8,.95,-.2),PI/2,0],["single_ward",Vector3(-11.2,.95,-7.3),-PI/2,0],["operating",Vector3(12.9,.95,-2.4),0.0,0],["laboratory",Vector3(13,.95,-7.1),PI,0],["office",Vector3(-2.4,.95,-9.1),-PI/2,0],["morgue",Vector3(2.7,.95,10.5),0.0,0],["upstairs",Vector3(0,4.55,-7),PI,1],["triple_ward",Vector3(7,4.55,-3.4),0.0,1]]:
  main.day_cycle.notice.hide();main.day_cycle._notice_time=0
  main.hotaru.global_position=h.to_interior_world(entry[1]);main.hotaru.rotation.y=entry[2];h.yaw=entry[2];h.floor_index=entry[3];main.hotaru.set_ground_height(entry[1].y)
  for door in h.doors:
   door.open=true;door.body.collision_layer=0;door.pivot.position=door.open_position
  await physics_frame
  h.update_camera(100);main._update_hud();await shot(entry[0])
 h.leave(true)
 print("HOSPITAL_CAPTURE_PASS")
 root.get_node("AudioDirector").set_process(false);root.get_node("AudioDirector").stop_all()
 await create_timer(.12).timeout
 main.queue_free();await process_frame;await process_frame;quit()
