extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var main=load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 root.get_node("GameState").suppress_save=true
 main._start_new_game()
 for zombie in get_nodes_in_group("zombies"):zombie.queue_free()
 main.set_process(false)
 main.hotaru.position=Vector3(-60,.95,26)
 main.camera.size=7.5
 main.camera.position=main.hotaru.position+Vector3(-10,10,-10)
 main.camera.look_at(main.hotaru.position+Vector3(0,0.15,-.5))
 var zombie=main.ZombieController.new()
 main.add_child(zombie)
 zombie.position=main.hotaru.position+Vector3(0,0,1.1)
 zombie.set_physics_process(false)
 main.hotaru.take_damage(100,zombie)
 await create_timer(1.7).timeout
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://artifacts/hotaru_death_gameplay.png")
 await create_timer(.5).timeout
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://artifacts/hotaru_death_result.png")
 quit()
