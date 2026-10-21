extends SceneTree
func _initialize() -> void:call_deferred("run")
func capture(path: String) -> void:
 for frame in range(5):await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://artifacts/"+path+".png")
func run() -> void:
 var main=load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 var state=root.get_node("GameState")
 state.suppress_save=true
 main._start_new_game()
 main.set_process(false)
 for actor in get_nodes_in_group("zombies"):actor.set_physics_process(false)
 main.rv.position=Vector3(0,1.02,20)
 main.hotaru.position=main.rv.get_disembark_position()
 main.camera.size=13
 main.camera.position=main.rv.position+Vector3(-17,17,-17)
 main.camera.look_at(main.rv.position+Vector3(0,.6,0))
 state.world_seconds=90
 await capture("rv_roof_fixed")
 state.world_seconds=270
 await capture("town_night")
 state.world_seconds=90
 main._enter_rv_interior()
 main.hotaru.global_position=main.rv_interior.get_driver_stand_position()
 main._interact()
 state.cargo={"water":4,"food":8,"scrap":5}
 state.items={"water":1,"food":3}
 state._sync_resources()
 main.rv_dashboard.open()
 await capture("rv_dashboard_v3")
 main.cargo_organizer.open()
 await capture("cargo_organizer")
 main.cargo_organizer.close()
 main.rv_dashboard.close()
 main._stand_from_driver_seat()
 main.hotaru.global_position=main.rv_interior.get_entry_position()
 main._interact()
 main.hotaru.global_position=main.STORE_DOOR
 main._interact()
 main.quantity_picker.open("water")
 await capture("water_quantity_picker")
 main.quantity_picker.close()
 quit()
