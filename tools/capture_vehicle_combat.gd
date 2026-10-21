extends SceneTree
func _initialize() -> void:call_deferred("run")
func capture(path: String) -> void:
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://artifacts/"+path)
func run() -> void:
 var main=load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 root.get_node("GameState").suppress_save=true
 main._start_new_game()
 for zombie in get_nodes_in_group("zombies"):zombie.queue_free()
 main.rv.position=Vector3(0,1.02,20)
 main.rv.rotation.y=PI
 main.hotaru.position=main.rv.get_disembark_position()
 main._update_camera(100)
 await capture("vehicle_hud_healthy.png")
 main.hotaru.take_damage(1)
 await capture("vehicle_hud_hurt.png")
 main.hotaru.take_damage(2)
 await capture("vehicle_hud_critical.png")
 main.in_vehicle=true
 main.hotaru.hide()
 main.rv.occupied=true
 main._update_camera(100)
 for local in [Vector3(1.95,-.12,-2),Vector3(1.95,-.12,0),Vector3(1.95,-.12,2),Vector3(-1.95,-.12,-2),Vector3(-1.95,-.12,0),Vector3(-1.95,-.12,2),Vector3(0,-.12,4.1)]:
  var actor=main.ZombieController.new()
  main.add_child(actor)
  actor.position=main.rv.to_global(local)
  actor.rotation.y=atan2(main.rv.position.x-actor.position.x,main.rv.position.z-actor.position.z)
  actor.set_physics_process(false)
  actor._animation_player.play("Bite",0)
  actor._animation_player.seek(.25,true)
  actor._animation_player.pause()
 main.rv.take_damage(92)
 await create_timer(.3).timeout
 await capture("rv_surrounded_fire.png")
 main.rv.take_damage(10000)
 await create_timer(.28).timeout
 await capture("rv_explosion.png")
 await create_timer(1.1).timeout
 await capture("rv_explosion_gameover.png")
 quit()



