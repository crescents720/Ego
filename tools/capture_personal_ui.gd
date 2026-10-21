extends SceneTree
func _initialize() -> void:call_deferred("run")
func frame(path: String) -> void:
 await process_frame
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://artifacts/"+path)
func run() -> void:
 var main=load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 var state=root.get_node("GameState")
 state.suppress_save=true
 main._start_new_game()
 main._update_camera(100)
 main.minimap.sync_state()
 await frame("hud_healthy.png")
 main.hotaru.take_damage(1)
 await frame("hud_hurt.png")
 main.hotaru.take_damage(2)
 await frame("hud_critical.png")
 main.hotaru.health=5
 main.equipment_screen.update_health()
 main.hotaru.global_position=main.rv.get_disembark_position()
 main._enter_rv_interior()
 await create_timer(.6).timeout
 main.hotaru.global_position=main.RV_INTERIOR_ORIGIN+Vector3(-.1,1.13,-3.13)
 main._interact()
 await frame("bat_pickup_picture.png")
 main._take_starter_bat()
 state.try_add_items({"food":3,"water":4,"medicine":2,"scrap":5})
 main.equipment_screen.avatar.pressed.emit()
 main.equipment_screen.selected_id="bat"
 main.equipment_screen.refresh()
 await frame("personal_bag_icons.png")
 main.equipment_screen.equip_drop("right_hand",{"kind":"personal_item","id":"bat","source_slot":""})
 main.equipment_screen.select_slot("right_hand")
 await frame("personal_equipped_icons.png")
 main.equipment_screen.close()
 quit()
