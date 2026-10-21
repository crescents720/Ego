extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 root.size=Vector2i(720,1280)
 var m=load("res://scenes/main.tscn").instantiate()
 root.add_child(m)
 var s=root.get_node("GameState")
 s.suppress_save=true
 m._start_new_game()
 m.set_process(false)
 m.mobile_joystick.setup(m,true)
 s.cash=1000
 m.hotaru.position=m.weapon_shop.door
 m.weapon_shop.enter()
 for i in range(6):m.weapon_shop.advance()
 for i in range(3):await process_frame
 var b: Button=m.weapon_shop.accept

 for press in [true,false]:
  var event:=InputEventMouseButton.new()
  event.device=InputEvent.DEVICE_ID_EMULATION
  event.position=b.get_global_rect().get_center()
  event.global_position=event.position
  event.button_index=MOUSE_BUTTON_LEFT
  event.pressed=press
  Input.parse_input_event(event)
  Input.flush_buffered_events()
  await process_frame
 var ok: bool=s.cash==0 and s.weapon_bought
 print("SHOP_MOBILE_DIALOGUE_CHECK errors=",0 if ok else 1)
 if not ok:push_error("Hidden joystick swallowed the paused shop purchase button")
 root.get_node("AudioDirector").stop_all()
 m.weapon_shop.leave()
 m.queue_free()
 await create_timer(.1).timeout
 quit(0 if ok else 1)
