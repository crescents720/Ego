extends SceneTree
func _initialize() -> void:call_deferred("run")
func capture(name: String) -> void:
 for i in range(8):await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://artifacts/"+name+".png")
func run() -> void:
 var main=load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 var state=root.get_node("GameState")
 state.suppress_save=true
 main._start_new_game()
 main.set_process(false)
 main.zombie_population.set_process(false)
 for actor in get_nodes_in_group("zombies"):actor.queue_free()
 state.world_seconds=90
 state.cargo={"water":4,"food":8}
 state._sync_resources()
 main.rv.position=Vector3(0,1.02,20)
 main.rv.rotation.y=0
 main.hotaru.position=main.rv.get_disembark_position()
 main.camera.projection=Camera3D.PROJECTION_ORTHOGONAL
 main.camera.size=10
 main.camera.position=main.rv.position+Vector3(-10,8,-16)
 main.camera.look_at(main.rv.position+Vector3(0,.9,-.7))
 await capture("rv_sealed_windshield")
 main.hotaru.position=main.rv.get_disembark_position()
 main._enter_rv_interior()
 main.hotaru.position=main.RV_INTERIOR_ORIGIN+Vector3(0,1.13,1.88)
 main.hotaru.health=2.0
 main.equipment_screen.update_health()
 main.sleep_controller.open()
 await capture("sleep_duration_menu")
 main.sleep_controller.begin(360)
 main._update_camera(100)
 main._update_hud()
 main.sleep_controller.info.text="睡眠中 · 世界正在快进"
 await capture("sleep_pose")
 main.sleep_controller.stop("预览结束")
 main.save_slots.open("save")
 await capture("six_save_slots")
 main.save_slots.close()
 main._exit_rv_interior()
 main.rv.position=main.repair_shop.BAY
 main.hotaru.position=main.rv.get_disembark_position()
 main.camera.projection=Camera3D.PROJECTION_ORTHOGONAL
 main.camera.size=25
 main.camera.position=Vector3(88,18,-108)
 main.camera.look_at(Vector3(105,2,-133))
 main.day_cycle._notice_time=0
 main._update_hud()
 await capture("town_repair_shop")
 quit()
