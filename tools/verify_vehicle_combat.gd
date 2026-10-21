extends SceneTree
var main
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> bool:
 if ok:return true
 push_error("VEHICLE_COMBAT_FAIL: "+message)
 quit(1)
 return false
func spawn_zombie(point: Vector3):
 var zombie=main.ZombieController.new()
 main.add_child(zombie)
 zombie.global_position=point
 zombie.set_target(main.hotaru)
 zombie.set_vehicle_target(main.rv)
 return zombie
func clear_zombies() -> void:
 for zombie in get_nodes_in_group("zombies"):zombie.queue_free()
 await physics_frame
 await physics_frame
func run() -> void:
 main=load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 root.get_node("GameState").suppress_save=true
 main._begin_story()
 root.get_node("GameState").cargo={"water":100,"food":100}
 root.get_node("GameState")._sync_resources()
 main.opening.set_beat(main.OpeningStory.Beat.EXTERIOR)
 main.opening.set_beat(main.OpeningStory.Beat.ESCAPE)
 main._update_hud()
 main.opening.apply_escape_hud()
 if not check(main.attack_button.visible,"opening escape must expose attack button"):return
 main._attack()
 if not check(main.hotaru.get_animation_state()=="Punch","opening escape can actually attack"):return
 await clear_zombies()
 main.opening.set_beat(main.OpeningStory.Beat.DONE)
 main.rv.global_position=Vector3(0,1.02,20)
 main.rv.rotation.y=0
 main.hotaru.global_position=main.rv.get_disembark_position()
 main._enter_rv_interior()
 var zombie=spawn_zombie(main.rv.to_global(Vector3(1.85,-.12,0)))
 for frame in range(50):await physics_frame
 if not check(main.rv.health<120 and main.hotaru.health==5 and zombie._choose_target()==main.rv,"zombie attacks occupied parked RV instead of hidden character"):return
 var old_hp: int=main.rv.health
 main._exit_rv_interior()
 main.hotaru.set_active(false)
 for frame in range(75):await physics_frame
 if not check(main.rv.health==old_hp,"exiting cancels stale vehicle attacks"):return
 await clear_zombies()
 main.set_process(false)
 main.rv.reset_condition()
 main.rv.position=Vector3(0,1.02,20)
 main.rv.rotation.y=0
 main.rv.set_active(true)
 main.rv.speed=10
 zombie=spawn_zombie(Vector3(0,.9,15.9))
 zombie.set_physics_process(false)
 var hits: Array[float]=[]
 main.rv.rammed.connect(func(_speed):hits.append(absf(main.rv.speed)))
 for frame in range(15):await physics_frame
 if not check(zombie._dying and hits.size()==1 and hits[0]<9 and main.rv.health==118,"fast physical impact kills once, loses speed and damages hull"):return
 await clear_zombies()
 main.rv.reset_condition()
 main.rv.position=Vector3(0,1.02,20)
 main.rv.rotation.y=0
 main.rv.set_active(true)
 main.rv.speed=2
 zombie=spawn_zombie(Vector3(0,.9,15.9))
 zombie.set_physics_process(false)
 Input.action_press("move_forward")
 for frame in range(60):await physics_frame
 Input.action_release("move_forward")
 if not check(not zombie._dying and absf(main.rv.speed)<.3 and main.rv.position.z>19.2,"slow RV is blocked; cannot build speed through zombie"):return
 await clear_zombies()
 main.rv.reset_condition()
 main.rv.position=Vector3(0,1.02,20)
 main.rv.rotation.y=0
 main.rv.set_active(true)
 for x in [-.65,.65]:
  for z in [-3.65,3.65]:
   var actor=spawn_zombie(main.rv.to_global(Vector3(x,-.12,z)))
   actor.set_physics_process(false)
 var parked: Vector3=main.rv.position
 for action in ["move_forward","move_backward"]:
  Input.action_press(action)
  for frame in range(40):await physics_frame
  Input.action_release(action)
 if not check(main.rv.position.distance_to(parked)<.35 and absf(main.rv.speed)<.3,"front/rear crowd traps a standing vehicle"):return
 await clear_zombies()
 main.rv.set_active(false)
 main.rv.reset_condition()
 main.rv.take_damage(60)
 if not check(main.rv._damage_fire.visible and not main.rv._critical_fire.visible,"half health starts engine fire"):return
 main.rv.take_damage(30)
 if not check(main.rv._critical_fire.visible and main.equipment_screen.rv_health_bar.value==30,"quarter health expands fire and HUD updates"):return
 main.rv.reset_condition()
 main.rv.apply_first_upgrade()
 var armored: int=main.rv.health
 main.rv.take_damage(4)
 if not check(main.rv.max_health==160 and main.rv.health==armored-2,"armor adds durability and halves incoming damage"):return
 var state=root.get_node("GameState")
 var saved_health: int=main.rv.health
 var saved_ratio: float=state.rv_health_ratio
 state.demo_completed=true
 var save_path:="user://vehicle_combat_regression.cfg"
 state.save_game(save_path)
 state.start_new_run()
 if not check(state.load_completed_save(save_path) and is_equal_approx(state.rv_health_ratio,saved_ratio),"vehicle durability round trips through save"):return
 main.rv.reset_condition()
 main.rv.apply_first_upgrade()
 main.rv.restore_health_ratio(saved_ratio)
 if not check(main.rv.health==saved_health,"upgraded durability restores at correct maximum"):return
 DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
 var icon=main.get_node("HUD").find_child("RVHealthIcon",true,false)
 if not check(icon.size==Vector2(38,38),"RV HUD icon remains small instead of covering world"):return
 # An actual occupied explosion must leave the interior and kill the occupant.
 main.hotaru.global_position=main.rv.get_disembark_position()
 main._enter_rv_interior()
 main.rv.take_damage(10000)
 if not check(main.rv.wrecked and main.phase==main.Phase.GAME_OVER and main.hotaru.health==0 and not main.inside_rv and main.rv.visible,"occupied RV explodes into world view and game over"):return
 var wreck_hp: int=main.rv.health
 main.rv.take_damage(4)
 if not check(main.rv.health==wreck_hp,"wreck cannot take repeated fatal damage"):return
 await create_timer(2.1).timeout
 if not check(main.dialog_panel.visible and main.dialog_title.text=="房车被摧毁了","game-over dialog follows explosion effect"):return
 main._start_new_game()
 main._enter_rv_interior()
 main.hotaru.global_position=main.rv_interior.get_driver_stand_position()
 main._interact()
 main._toggle_vehicle()
 if not check(main.in_vehicle and main.rv.occupied,"driver counts as vehicle occupant"):return
 main.rv.take_damage(10000)
 if not check(main.phase==main.Phase.GAME_OVER and main.hotaru.health==0 and not main.rv.active,"driving explosion also kills driver"):return
 await create_timer(2.1).timeout
 main.opening.voice.stop()
 main.opening.music.stop()
 main.opening.fire_audio.stop()
 for sound in main.rv.find_children("*","AudioStreamPlayer3D",true,false):sound.stop()
 await create_timer(.15).timeout
 print("VEHICLE_COMBAT_PASS: escape attack; occupied RV target and exit cancellation; high/low speed hull collisions; impact speed loss; crowd trap; fire thresholds; armor; explosion and occupant game over")
 quit()
