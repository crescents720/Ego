extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var main=load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 root.get_node("GameState").suppress_save=true
 main._start_new_game()
 main.hotaru.global_position=main.rv.get_disembark_position()
 main._enter_rv_interior()
 await create_timer(0.6).timeout
 main.hotaru.global_position=main.RV_INTERIOR_ORIGIN+Vector3(-0.1,1.13,-3.13)
 main._interact()
 await create_timer(0.6).timeout
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://artifacts/starter_bat_story.png")
 main._close_dialog_and_resume()
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://artifacts/wardrobe_bat.png")
 main.hotaru.hide()
 for label in main.rv_interior.find_children("*","Label3D",true,false):label.hide()
 main._interior_camera_focus_override=main.RV_INTERIOR_ORIGIN+Vector3(-0.7,1.1,-3.13)
 main._interior_camera_distance=3.2
 main._interior_camera_yaw=PI/2
 main._update_camera(100)
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://artifacts/wardrobe_bat_closeup.png")
 main.hotaru.show()
 main._take_starter_bat()
 root.get_node("GameState").try_add_items({"food":3,"water":4,"medicine":2,"scrap":5})
 main.equipment_screen.open()
 main.equipment_screen.select_slot("right_hand")
 await process_frame
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://artifacts/equipment_screen.png")
 main.equipment_screen.close()
 quit()



