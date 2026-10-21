extends SceneTree
var main
var errors:=0
func _initialize() -> void:call_deferred("run")
func check(value: bool,message: String) -> void:
 if not value:
  push_error("SURVIVAL_FAIL: "+message)
  errors+=1
func run() -> void:
 main=load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 var state=root.get_node("GameState")
 state.suppress_save=true
 main._start_new_game()
 check(main.town_layout.lots.size()>320,"Town did not gain housing")
 check(main.town_layout.vegetation.placements.size()>3000,"Ground cover remains sparse")
 check(get_nodes_in_group("town_wanderers").size()>15,"No ambient street population")
 var district=main.zombie_population.districts[0]
 check(main.zombie_population.districts.size()>20,"Major roads not divided into spawn districts")
 main.zombie_population.set_process(false)
 for actor in get_nodes_in_group("zombies"):actor.set_physics_process(false)
 main.hotaru.global_position=main.rv.get_disembark_position()
 main._enter_rv_interior()
 main.hotaru.global_position=main.rv_interior.get_driver_stand_position()
 main._interact()
 check(main.seated_at_driver,"Could not sit in cockpit")
 main.rv_dashboard.open()
 check(paused and main.rv_dashboard.veil.visible,"Dashboard did not pause gameplay")
 main.rv_dashboard.close()
 check(not paused,"Dashboard did not resume gameplay")
 main._toggle_vehicle()
 check(main.in_vehicle and state.tutorial_step==1,"First drive did not start supply tutorial")
 check(main.supply_quest.route().size()>3,"Missing minimap route")
 # Check actual swept distance, with and without motion, rather than throttle alone.
 main.rv.global_position=Vector3(0,1.02,115)
 main.rv.rotation.y=PI
 var fuel_before: float=state.fuel_l
 var distance_before: float=state.distance_m
 Input.action_press("move_forward")
 for frame in range(45):await physics_frame
 Input.action_release("move_forward")
 main.rv.set_active(false)
 var travelled: float=state.distance_m-distance_before
 check(travelled>1 and is_equal_approx(fuel_before-state.fuel_l,travelled*state.FUEL_PER_M),"Fuel not based on actual distance")
 main.rv.set_active(true)
 state.fuel_l=0
 var stopped: Vector3=main.rv.position
 Input.action_press("move_forward")
 for frame in range(10):await physics_frame
 Input.action_release("move_forward")
 check(main.rv.position.distance_to(stopped)<.01,"Empty tank still drives")
 state.fuel_l=6
 main.rv.global_position=Vector3(0,1.02,48)
 main._toggle_vehicle()
 main.hotaru.global_position=main.rv_interior.get_entry_position()
 main._interact()
 main.hotaru.global_position=main.STORE_DOOR
 main._interact()
 check(main.inside_store and state.tutorial_step==2,"Store entry requires killing all outdoor zombies")
 check(get_nodes_in_group("store_indoor_zombies").size()==2,"Store needs two hostiles")
 for actor in get_nodes_in_group("store_indoor_zombies"):
  check(actor.visible and actor.ground_height==1.08,"Indoor enemy floor/visibility wrong")
  actor.set_physics_process(false)
 # These shelf sides are free navigation cells, rather than inside shelf collision boxes.
 for item in [["water",Vector3(0,1.08,.3)],["food",Vector3(-1.75,1.08,.3)]]:
  main.hotaru.global_position=main.STORE_ORIGIN+item[1]
  check(main.store_interior.focus(main.hotaru.global_position)==item[0],"Wrong shelf focus")
  main._interact()
  main._close_dialog_and_resume()
 check(state.items.get("water",0)==4 and state.items.get("food",0)==3,"Supply pickup not in personal backpack")
 check(state.tutorial_step==3,"Collecting both supplies did not enable return objective")
 check(state.carried_grams()==2750,"Water/bread weight incorrect")
 main.hotaru.global_position=main.store_interior.get_entry_position()
 main._interact()
 check(not main.inside_store,"Unable to leave store")
 for actor in get_nodes_in_group("store_indoor_zombies"):check(not actor.visible and not actor.is_physics_processing(),"Indoor enemies leaked outdoors")
 main.hotaru.global_position=main.rv.get_disembark_position()
 main._enter_rv_interior()
 main.hotaru.global_position=main.rv_interior.get_driver_stand_position()
 main._interact()
 main.rv_dashboard.open()
 main.rv_dashboard.deposit()
 check(state.tutorial_step==4 and state.cargo.get("water",0)==4 and state.items.is_empty(),"Cargo delivery did not complete tutorial")
 var clock_before: float=state.water_clock
 for frame in range(3):await process_frame
 check(is_equal_approx(clock_before,state.water_clock),"Paused dashboard consumes resources")
 main.rv_dashboard.close()
 state.water_clock=0
 state.food_clock=0
 state.tick_survival(240)
 check(state.cargo.water==3 and state.cargo.food==3,"Wrong 4-minute consumption")
 state.tick_survival(120)
 check(state.cargo.water==3 and state.cargo.food==2,"Wrong 6-minute consumption")
 state.tick_survival(600)
 check(state.water>=0 and state.food>=0,"Resource underflow")
 # Capacity must reject atomically; transferring to a full backpack must retain cargo.
 state.cargo={"water":2000}
 state.items={"food":1}
 check(state.cargo_grams()==state.CARGO_CAPACITY_G and not state.store_item("food"),"1000kg cargo boundary")
 check(state.items.food==1,"Failed store destroyed item")
 state.items={"water":20}
 check(not state.retrieve_item("water") and state.cargo.water==2000,"Overweight retrieve destroyed cargo")
 state.start_new_run()
 state.tutorial_step=2
 state.fuel_l=3.25
 state.water_clock=111
 state.vehicle_position=Vector3(0,1.02,48)
 var file: String="user://survival_verification.cfg"
 state.save_game(file)
 state.start_new_run()
 check(state.load_completed_save(file) and state.tutorial_step==2 and state.fuel_l==3.25 and state.water_clock==111 and state.vehicle_position.z==48,"New survival progress not restored")
 main._load_completed_save(file)
 check(main.rv.position.z==48 and main.phase==main.Phase.SCAVENGE and not main.dialog_panel.visible,"Main scene did not resume incomplete tutorial save")
 DirAccess.remove_absolute(ProjectSettings.globalize_path(file))
 # Fully cleared districts wait, then repopulate from actual nearby building approaches.
 var chosen: Dictionary={}
 for d in main.zombie_population.districts:
  if d.spawn_points.size()>=3:
   chosen=d
   break
 check(not chosen.is_empty(),"No building approaches available for respawn")
 if not chosen.is_empty():
  for actor in chosen.members:
   if is_instance_valid(actor):actor.take_damage(100)
  chosen.members=[]
  chosen.visited=true
  chosen.delay=-1.0
  main.inside_rv=false
  main.inside_store=false
  main.in_vehicle=true
  main.phase=main.Phase.DRIVE_TO_STORE
  main.rv.position=Vector3(chosen.center.x+45,1.02,chosen.center.y+45)
  main.rv.set_active(false)
  main.camera.position=main.rv.position+Vector3(0,15,20)
  main.camera.look_at(main.rv.position+Vector3(80,0,80))
  main.zombie_population._process(.5)
  for tick in range(15):main.zombie_population._process(.5)
  check(chosen.members.is_empty(),"District respawned before its delay")
  for tick in range(6):main.zombie_population._process(.5)
  check(chosen.members.size()>0,"Cleared district did not respawn")
  for actor in chosen.members:
   var p:=Vector2(actor.position.x,actor.position.z)
   var near_exit:=false
   for exit in chosen.spawn_points:
    if exit.distance_to(p)<.01:near_exit=true
   check(near_exit and p.distance_to(Vector2(main.rv.position.x,main.rv.position.z))>=18,"Respawn did not use a safe building approach")
 print("TOWN_SURVIVAL_CHECK: houses=",main.town_layout.lots.size()," flora=",main.town_layout.vegetation.placements.size()," districts=",main.zombie_population.districts.size()," errors=",errors)
 main.opening.voice.stop()
 main.opening.music.stop()
 main.opening.fire_audio.stop()
 await create_timer(.1).timeout
 quit(0 if errors==0 else 1)
