extends SceneTree
var errors:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
 if not ok:push_error(message);errors+=1
func run() -> void:
 var main=load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 var state=root.get_node("GameState")
 state.suppress_save=true
 main._start_new_game()
 main.zombie_population.set_process(false)
 for actor in get_nodes_in_group("zombies"):actor.queue_free()
 await physics_frame
 for entry in [[.51,"healthy"],[.50,"hurt"],[.251,"hurt"],[.25,"critical"],[.20,"critical"],[0,"dead"]]:
  main.hotaru.health=float(entry[0])*5
  main.equipment_screen.update_health()
  check(main.equipment_screen.health_state==entry[1],"Health boundary "+str(entry))
 main.hotaru.health=1
 state.cargo={"water":2,"food":4}
 state._sync_resources()
 main.hotaru.global_position=main.rv.get_disembark_position()
 main._enter_rv_interior()
 main.hotaru.global_position=main.RV_INTERIOR_ORIGIN+Vector3(0,1.13,1.88)
 main._interact()
 check(main.sleep_controller.veil.visible,"Bed interaction does not open rest menu")
 var start_time: float=state.world_seconds
 check(main.sleep_controller.begin(180),"Safe half-day sleep rejected")
 check(main.hotaru.get_animation_state()=="Sleep" and main.hotaru.sleeping,"Hero does not lie on bed")
 var deadline: int=Time.get_ticks_msec()+8500
 while main.sleep_controller.sleeping and Time.get_ticks_msec()<deadline:await process_frame
 check(not main.sleep_controller.sleeping,"Sleep did not finish in accelerated real time")
 check(absf(state.world_seconds-start_time-180)<.1,"Half-day sleep did not advance exactly 180 seconds")
 check(absf(main.hotaru.health-3.5)<.01,"Half-day sleep must recover 50% maximum HP")
 check(Engine.time_scale==1.0,"Time scale not restored after sleep")
 # A real approaching attacker must interrupt accelerated recovery.
 var zombie=main.ZombieController.new()
 main.add_child(zombie)
 zombie.global_position=main.rv.to_global(Vector3(7,-.12,0))
 zombie.set_target(main.hotaru)
 zombie.set_vehicle_target(main.rv)
 main.hotaru.global_position=main.RV_INTERIOR_ORIGIN+Vector3(0,1.13,1.88)
 main.sleep_controller.open()
 check(main.sleep_controller.begin(360),"Distant enemy incorrectly prevents sleeping")
 deadline=Time.get_ticks_msec()+2500
 while main.sleep_controller.sleeping and Time.get_ticks_msec()<deadline:await process_frame
 check(not main.sleep_controller.sleeping and main.is_under_attack(),"Approaching zombie failed to wake sleeping heroine")
 check(not main.can_save_safely(),"Combat does not block saving")
 var denied: String="user://unsafe_rest_test.cfg"
 check(state.save_game(denied)==ERR_BUSY and not FileAccess.file_exists(denied),"Direct serializer bypasses combat restriction")
 zombie.queue_free()
 await physics_frame
 main.rv.last_hostile_attack_ms=-100000
 # Food ending halfway through a full-day request must stop recovery at half a day.
 main.set_process(false)
 state.cargo={"water":2,"food":1}
 state.items={}
 state.water_clock=0
 state.food_clock=0
 state._sync_resources()
 main.hotaru.health=1
 main.sleep_controller.open()
 check(main.sleep_controller.begin(360),"Rest with nonempty supplies rejected")
 var dt: float=main.sleep_controller.limit_delta(360)
 check(dt==180,"Rest overshoots food depletion")
 main.hotaru.take_survival_damage(state.tick_survival(dt)*5)
 main.sleep_controller.advance(dt)
 check(not main.sleep_controller.sleeping and state.cargo.get("food",0)==0 and absf(main.hotaru.health-3.5)<.01,"Food depletion did not stop healing")
 check(not main.sleep_controller.begin(180),"Empty cargo allows rest")
 main.sleep_controller.veil.hide()
 paused=false
 check(main.can_save_safely(),"Quiet safe state cannot save")
 var save_file: String="user://rest_save_test.cfg"
 check(state.save_game(save_file)==OK,"Safe state save failed")
 state.start_new_run()
 check(state.load_completed_save(save_file) and absf(state.hero_health_ratio-.7)<.01,"Saved health not restored")
 DirAccess.remove_absolute(ProjectSettings.globalize_path(save_file))
 # On-site repairs require position and safety, never collected materials.
 main.rv.position=main.repair_shop.BAY
 main.hotaru.global_position=main.rv.get_disembark_position()
 main.rv.take_damage(80)
 state.cargo={"scrap":5}
 state._sync_resources()
 check(main.repair_shop.repair_cost()==0,"Garage must not charge materials")
 main.in_vehicle=false
 main.inside_rv=false
 main.hotaru.position=main.rv.get_disembark_position()
 check(main.repair_shop.repair(),"Repair at garage rejected")
 main.service.walking=false
 main.service._process(12.1)
 check(main.rv.health==main.rv.max_health and not main.rv._damage_fire.visible and state.scrap==5,"Repair did not restore HP without consuming materials")
 main.rv.take_damage(30)
 main.rv.mark_hostile_attack()
 var before: int=state.scrap
 check(not main.repair_shop.repair() and state.scrap==before,"Attacked repair spent resources")
 print("REST_SAVE_REPAIR_CHECK errors=",errors)
 main.opening.voice.stop()
 main.opening.music.stop()
 main.opening.fire_audio.stop()
 await create_timer(.1).timeout
 quit(0 if errors==0 else 1)
