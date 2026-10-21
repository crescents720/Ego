extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var main=load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 root.get_node("GameState").suppress_save=true
 main._start_new_game()
 main.set_process(false)
 main.hotaru.position=Vector3(-6.7,.95,-43)
 main.camera.size=48
 main.camera.global_position=main.hotaru.position+Vector3(-30,30,-30)
 main.camera.look_at(main.hotaru.position)
 main.get_node("HUD").hide()
 for frame in range(10):await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://artifacts/town_dense_lawns.png")
 main.get_node("HUD").show()
 main.hotaru.global_position=main.rv.get_disembark_position()
 main._enter_rv_interior()
 main.hotaru.global_position=main.rv_interior.get_driver_stand_position()
 main._interact()
 main._toggle_vehicle()
 main.supply_quest.update(0)
 main.camera.size=24
 main._update_camera(100)
 for frame in range(8):await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://artifacts/supply_route.png")
 main._toggle_vehicle()
 main.hotaru.global_position=main.rv_interior.get_driver_stand_position()
 main._interact()
 root.get_node("GameState").try_add_items({"water":4,"food":3,"scrap":5})
 main.rv_dashboard.open()
 main.rv_dashboard.deposit()
 main.rv_dashboard.transfer("water",false)
 main.rv_dashboard.transfer("food",false)
 for frame in range(8):await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://artifacts/rv_dashboard.png")
 print("DASHBOARD_PANEL_RECT ",main.rv_dashboard.panel.get_global_rect())
 main.rv_dashboard.close()
 main._stand_from_driver_seat()
 main.hotaru.global_position=main.rv_interior.get_entry_position()
 main._interact()
 main.hotaru.global_position=main.STORE_DOOR
 main._interact()
 main.supply_quest.update(0)
 main.camera.global_position=main.store_interior.get_camera_pivot()+Vector3(10,10,10)
 main.camera.look_at(main.store_interior.get_camera_pivot())
 main._update_camera(100)
 main._update_hud()
 main.supply_quest.update(0)
 main.camera.size=9.8
 for frame in range(8):await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://artifacts/supply_store_hostiles.png")
 quit()
