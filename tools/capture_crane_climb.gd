extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(720,1280)
 root.get_node("GameState").suppress_save=true
 var m=load("res://scenes/main.tscn").instantiate()
 root.add_child(m)
 m._start_new_game();m._set_phase(m.Phase.EXPLORE)
 m.set_process(false)
 var h=m.harbor
 m.hotaru.global_position=h.crane.to_global(Vector3(4.1,.95,-2.3))
 h.enter()
 var center: Vector3=h.crane.to_global(Vector3(3.5,2,-2.3))
 m.camera.projection=Camera3D.PROJECTION_ORTHOGONAL;m.camera.size=5
 m.camera.global_position=center+Vector3(7,4,5);m.camera.look_at(center)
 await create_timer(.8).timeout
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://artifacts/harbor_climb_pose.png")
 quit()
