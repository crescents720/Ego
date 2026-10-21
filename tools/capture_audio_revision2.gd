extends SceneTree
func _initialize() -> void:call_deferred("run")
func shot(path: String) -> void:
 await process_frame
 await process_frame
 root.get_texture().get_image().save_png("res://artifacts/"+path)
func run() -> void:
 var main=load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 root.get_node("GameState").suppress_save=true
 main._start_new_game()
 main.zombie_population.set_process(false)
 for actor in get_nodes_in_group("zombies"):actor.queue_free()
 await physics_frame
 main._set_phase(main.Phase.EXPLORE)
 main.rv.global_position=Vector3(0,1.02,200)
 main.rv.rotation.y=0
 main.hotaru.global_position=Vector3(8,.95,200)
 main.hotaru.set_active(false)
 main.set_process(false)
 main.rv.occupied=true
 var zombie=main.ZombieController.new()
 main.add_child(zombie)
 zombie.global_position=main.rv.to_global(Vector3(-1.85,-.12,0))
 zombie.set_vehicle_target(main.rv)
 zombie.set_target(main.hotaru)
 zombie._physics_process(0)
 zombie.set_physics_process(false)
 zombie._animation_player.play(zombie._animations.VehicleAttack,0)
 zombie._animation_player.advance(.24)
 zombie._animation_player.pause()
 main.camera.global_position=main.rv.global_position+Vector3(-10,7,-10)
 main.camera.size=11
 main.camera.look_at(main.rv.global_position+Vector3(0,.5,0))
 zombie._animation_player.seek(.24,true)
 zombie._animation_player.advance(0)
 await shot("vehicle_attack_windup.png")
 zombie._animation_player.seek(.60,true)
 zombie._animation_player.advance(0)
 await shot("vehicle_attack_contact.png")
 main.rv.occupied=false
 zombie.queue_free()
 main.rv.global_position=main.repair_shop.BAY
 main.hotaru.global_position=main.rv.get_disembark_position()
 main.rv.take_damage(40)
 main.rv.last_hostile_attack_ms=-100000
 await physics_frame
 main.repair_shop.open()
 await shot("free_garage_repair.png")
 root.get_node("AudioDirector").stop_all()
 main.queue_free()
 await create_timer(.15).timeout
 quit()
