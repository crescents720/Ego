extends SceneTree
var main
func _initialize() -> void:call_deferred("run")
func shot(label: String) -> void:
 main._update_hud()
 main.town_occlusion.update(main.camera,main.hotaru,true)
 for i in range(8):await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://artifacts/"+label+".png")
func run() -> void:
 main=load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 var state=root.get_node("GameState")
 state.suppress_save=true
 main._start_new_game()
 main.set_process(false)
 main.zombie_population.set_process(false)
 for z in get_nodes_in_group("zombies"):z.queue_free()
 await physics_frame
 main._set_phase(main.Phase.EXPLORE)
 state.world_seconds=90
 main.in_vehicle=false
 main.inside_rv=false
 main.rv.set_active(false)
 main.rv.occupied=false
 main.rv.position=main.repair_shop.BAY
 main.rv.rotation.y=0
 main.rv.last_hostile_attack_ms=-100000
 main.hotaru.position=main.rv.get_disembark_position()
 main.rv.take_damage(50)
 main.camera.size=22
 main.camera.position=Vector3(87,22,-157)
 main.camera.look_at(Vector3(108,2,-131))
 await shot("repair_facade_fixed")
 main.service.begin("repair")
 var deadline:=Time.get_ticks_msec()+6000
 while main.service.walking and Time.get_ticks_msec()<deadline:await physics_frame
 main.service.set_process(false)
 main.camera.size=7
 main.camera.position=main.hotaru.position+Vector3(-6,4,-5)
 main.camera.look_at(main.hotaru.position+Vector3(0,.1,0))
 await shot("repair_kneel")
 main.service.stop("preview")
 main.rv.position=main.gas_station.BAY
 main.hotaru.position=main.rv.get_disembark_position()
 main.camera.size=25
 main.camera.position=main.rv.position+Vector3(-20,22,-20)
 main.camera.look_at(main.rv.position+Vector3(6,1,0))
 await shot("gas_station_integrated")
 state.fuel_l=20
 main.service.set_process(true)
 main.service.begin("fuel")
 deadline=Time.get_ticks_msec()+6000
 while main.service.walking and Time.get_ticks_msec()<deadline:await physics_frame
 main.service.set_process(false)
 main.service._process(.1)
 main.camera.size=7
 main.camera.position=main.hotaru.position+Vector3(-5,4,4)
 main.camera.look_at(main.hotaru.position+Vector3(0,.5,0))
 await shot("fuel_nozzle")
 main.service.stop("preview")
 main.rv.position=Vector3(0,1.02,200)
 main.hotaru.position=main.rv.position+Vector3(8,0,0)
 main.camera.size=7
 main.camera.position=main.rv.position+Vector3(-6,4,-12)
 main.camera.look_at(main.rv.position+Vector3(0,.5,-1.5))
 await shot("windshield_gap_fixed")
 root.get_node("AudioDirector").stop_all()
 main.queue_free()
 await create_timer(.15).timeout
 quit()
