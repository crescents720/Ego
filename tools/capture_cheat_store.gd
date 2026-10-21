extends SceneTree
func _initialize() -> void:call_deferred("run")
func shot(path: String) -> void:
 for i in range(5):await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://artifacts/"+path+".png")
func run() -> void:
 root.size=Vector2i(720,1280)
 var m=load("res://scenes/main.tscn").instantiate()
 root.add_child(m)
 var s=root.get_node("GameState")
 s.suppress_save=true
 m._start_new_game()
 m.zombie_population.set_process(false)
 m._set_phase(m.Phase.EXPLORE)
 m.test_settings.open()
 m.test_settings.code.text="showmethemoney"
 m.test_settings.submit()
 await shot("cheat_settings")
 m.test_settings.close()
 m.mobile_joystick.setup(m,true)
 m.hotaru.position=m.STORE_DOOR
 m.camera.position=m.hotaru.position+m.TOWN_CAMERA_OFFSET
 await shot("settings_gear_hud")
 m._enter_store()
 for i in range(6):await process_frame
 m.hotaru.position=m.STORE_ORIGIN+Vector3(0,1.08,.3)
 m.quantity_picker.open("water")
 await shot("infinite_store_supply")
 m.quantity_picker.close()
 root.get_node("AudioDirector").stop_all()
 quit()
