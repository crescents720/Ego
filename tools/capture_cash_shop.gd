extends SceneTree
func _initialize() -> void:call_deferred("run")
func shot(name: String) -> void:
 for i in range(8):await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://artifacts/"+name+".png")
func run() -> void:
 root.size=Vector2i(720,1280)
 var main=load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 var state=root.get_node("GameState")
 state.suppress_save=true
 main._start_new_game()
 main.zombie_population.set_process(false)
 for z in get_nodes_in_group("zombies"):z.queue_free()
 await physics_frame
 main._set_phase(main.Phase.EXPLORE)
 state.world_seconds=60
 state.cash=1048
 main.hotaru.position=Vector3(99,.95,151)
 main.rv.position=Vector3(95,1.02,149)
 main.rv.rotation.y=0
 for p in [Vector3(100,.95,149),Vector3(98,.95,147),Vector3(101,.95,152)]:main.cash_drops.spawn_drop(p)
 main.camera.position=main.hotaru.position+main.TOWN_CAMERA_OFFSET
 await shot("cash_shop_street")
 main.hotaru.position=main.weapon_shop.door
 main.weapon_shop.enter()
 main.weapon_shop.advance()
 await shot("weapon_shop_dialogue")
 main.weapon_shop.leave()
 state.buy_m60()
 state.cart_position=Vector3(89,.08,149)
 main.hotaru.position=Vector3(89,.95,147.8)
 main.hotaru.rotation.y=0
 main.trolley.interact()
 await shot("trolley_push")
 main.trolley.release()
 main.in_vehicle=true
 main.rv_dashboard.open()
 main.cargo_organizer.open()
 await shot("trolley_inventory")
 root.get_node("AudioDirector").stop_all()
 quit()
