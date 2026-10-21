extends SceneTree
var errors:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool, message: String) -> void:
 if not ok:errors+=1;push_error(message)
func run() -> void:
 var main=load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 var state=root.get_node("GameState")
 state.suppress_save=true
 main._start_new_game()
 main.set_process(false)
 main.zombie_population.set_process(false)
 for z in get_nodes_in_group("zombies"):z.queue_free()
 await physics_frame
 main._set_phase(main.Phase.EXPLORE)
 main.in_vehicle=false
 main.inside_rv=false
 main.inside_store=false
 main.rv.set_active(false)
 main.rv.occupied=false
 main.rv.position=main.repair_shop.BAY
 main.rv.rotation.y=0
 main.rv.speed=0
 main.rv.last_hostile_attack_ms=-100000
 check(absf(main.repair_shop.BAY.z+135)<.01,"Repair bay must align with the shop facade")
 main.hotaru.position=main.rv.get_disembark_position()
 main.rv.take_damage(60)
 main.in_vehicle=true
 check(not main.service.begin("repair"),"Repair allowed while driving")
 main.in_vehicle=false
 var initial: int=main.rv.health
 check(main.service.begin("repair"),"On-foot repair rejected")
 check(main.rv.health==initial,"Repair completed instantly")
 check(not main.can_save_safely(),"Saving allowed during service")
 var deadline:=Time.get_ticks_msec()+6000
 while main.service.walking and Time.get_ticks_msec()<deadline:await physics_frame
 check(main.service.active and not main.service.walking,"Hero cannot reach repair position")
 main.service.set_process(false)
 main.service._process(2)
 check(main.rv.health>initial and main.rv.health<main.rv.max_health,"Repair is not gradual")
 var partial: int=main.rv.health
 main.service.stop("test")
 check(main.rv.health==partial and not main.hotaru.servicing and main.controls_enabled,"Cancelled repair loses work or controls")
 check(main.service.begin("repair"),"Repair cannot resume")
 main.service.walking=false
 main.service._process(12.1)
 check(main.rv.health==main.rv.max_health and not main.service.active,"Repair does not finish")
 main.rv.position=main.gas_station.BAY
 check(main.rv.position.x>main.gas_station.PUMPS[0].x and main.rv.position.x<54.637,"Fuel bay must sit between pumps and building")
 main.rv.position=Vector3(45.7,1.02,-136.5)
 check(not main.gas_station.is_parked(),"Roadside lane must not count as pump parking")
 main.rv.position=main.gas_station.BAY
 main.hotaru.position=main.rv.get_disembark_position()
 main.rv.rotation.y=PI/2
 state.fuel_l=10
 check(not main.service.begin("fuel"),"Sideways RV accepted by pump")
 main.rv.rotation.y=0
 main.rv.position.x+=1
 check(not main.service.begin("fuel"),"RV outside pump lane accepted")
 main.rv.position=main.gas_station.BAY
 check(main.service.begin("fuel"),"Correct parking rejected")
 main.service.set_process(true)
 deadline=Time.get_ticks_msec()+6000
 while main.service.walking and Time.get_ticks_msec()<deadline:await physics_frame
 check(main.service.active and not main.service.walking,"Hero cannot reach pump beside RV")
 main.service.set_process(false)
 main.service._process(2)
 var partial_fuel: float=state.fuel_l
 check(partial_fuel>10 and partial_fuel<60,"Fuel did not fill gradually")
 main.service.stop("test")
 check(state.fuel_l==partial_fuel,"Cancellation rolled back fuel")
 check(main.service.begin("fuel"),"Cannot resume fuel")
 main.service.walking=false
 main.service._process(30)
 check(state.fuel_l==60 and not main.service.active,"Tank does not finish exactly full")
 # Both travel directions are valid in the same lane. Walk around the rear
 # bumper from the RV's right-hand door to the pump-facing side.
 main.rv.rotation.y=PI
 main.hotaru.position=main.rv.get_disembark_position()
 state.fuel_l=20
 check(main.service.begin("fuel"),"Reverse-facing parking rejected")
 main.service.set_process(true)
 deadline=Time.get_ticks_msec()+8000
 while main.service.walking and Time.get_ticks_msec()<deadline:await physics_frame
 check(main.service.active and not main.service.walking,"Cannot reach pump when RV faces other direction")
 main.service.stop("test")
 main.service.set_process(false)
 state.fuel_l=20
 main.service.begin("fuel")
 main.rv.mark_hostile_attack()
 main.service._process(.1)
 check(not main.service.active and state.fuel_l==20,"Hostile attack fails to interrupt service")
 print("VEHICLE_SERVICES_CHECK errors=",errors)
 root.get_node("AudioDirector").stop_all()
 main.queue_free()
 await create_timer(.15).timeout
 quit(1 if errors else 0)
