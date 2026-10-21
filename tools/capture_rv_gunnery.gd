extends SceneTree
func _initialize() -> void:call_deferred("run")
func shot(name: String) -> void:
 for i in range(8):await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://artifacts/"+name+".png")
func run() -> void:
 root.size=Vector2i(720,1280)
 var m=load("res://scenes/main.tscn").instantiate()
 root.add_child(m)
 var s=root.get_node("GameState")
 s.suppress_save=true
 m._start_new_game()
 m.zombie_population.set_process(false)
 for z in get_nodes_in_group("zombies"):z.queue_free()
 await physics_frame
 m._set_phase(m.Phase.EXPLORE)
 s.world_seconds=60
 m.rv.position=Vector3(0,1.02,100)
 m.rv.rotation.y=0
 m.hotaru.position=m.rv.get_disembark_position()
 m._enter_rv_interior()
 s.cargo={"m60":1,"m60_ammo":500}
 m._interior_camera_focus_override=m.RV_INTERIOR_ORIGIN+Vector3(0,.9,.3)
 m._interior_camera_distance=7
 m._update_camera(100)
 await shot("gunnery_interior_right")
 m._interior_camera_yaw=-.8
 m._update_camera(100)
 await shot("gunnery_interior_left")
 for p in [Vector3(14,.95,101.45),Vector3(18,.95,103.5),Vector3(-13,.95,101.45)]:
  var z=m.ZombieController.new()
  m.add_child(z)
  z.position=p
  z.set_target(m.hotaru)
  z.set_vehicle_target(m.rv)
  z.set_physics_process(false)
 m.shooting.start(1)
 await shot("gunnery_shoulder_right")
 m.shooting.stop()
 m.shooting.start(-1)
 await shot("gunnery_shoulder_left")
 m.shooting.stop()
 m.rv_dashboard.open()
 m.rv_dashboard.status.text=s.ITEMS.m60.description
 await shot("gunnery_dashboard_wrapped")
 print("Dashboard bounds: ",m.rv_dashboard.panel.get_global_rect())
 m.rv_dashboard.close()
 m.inside_rv=false
 m.rv_interior.hide()
 m.world_root.show()
 m.rv.show()
 m.hotaru.hide()
 m.set_process(false)
 m.camera.projection=Camera3D.PROJECTION_ORTHOGONAL
 m.camera.size=7
 m.camera.position=m.rv.position+Vector3(-7,4,7)
 m.camera.look_at(m.rv.position+Vector3(0,.45,.6))
 await shot("gunnery_exterior_mounted")
 root.get_node("AudioDirector").stop_all()
 quit()
