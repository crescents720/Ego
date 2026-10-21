extends SceneTree
var errors:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
 if not ok:errors+=1;push_error(message)
func touch(joystick,index: int,point: Vector2,pressed: bool) -> void:
 var event:=InputEventScreenTouch.new()
 event.index=index
 event.position=point
 event.pressed=pressed
 Input.parse_input_event(event)
 Input.flush_buffered_events()
func drag(joystick,index: int,point: Vector2) -> void:
 var event:=InputEventScreenDrag.new()
 event.index=index
 event.position=point
 Input.parse_input_event(event)
 Input.flush_buffered_events()
func run() -> void:
 root.size=Vector2i(720,1280)
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
 var joystick=main.mobile_joystick
 joystick.setup(main,true)
 joystick._process(0)
 var center: Vector2=joystick.position+joystick.CENTER
 main.hotaru.position=Vector3(0,.95,200)
 main.rv.position=Vector3(15,1.02,200)
 main._update_camera(1)
 var before: Vector3=main.hotaru.position
 touch(joystick,0,center,true)
 drag(joystick,0,center+Vector2(75,-75))
 check(main.hotaru.touch_move.x>.6 and main.hotaru.touch_move.y>.6,"Diagonal thumb input missing an axis")
 for i in range(8):await physics_frame
 check(main.hotaru.position.distance_to(before)>.25,"Thumbstick does not move heroine")
 var pressed: Array[int]=[0]
 main.attack_button.show()
 main.attack_button.pressed.connect(func():pressed[0]+=1)
 var action: Vector2=main.attack_button.get_global_rect().get_center()
 touch(joystick,1,action,true)
 touch(joystick,1,action,false)
 check(pressed[0]==1 and joystick.finger==0 and main.hotaru.touch_move.length()>.9,"Second finger action cancels steering or duplicates press")
 touch(joystick,0,center+Vector2(500,0),false)
 check(main.hotaru.touch_move==Vector2.ZERO and main.rv.touch_move==Vector2.ZERO,"Release outside stick leaves input stuck")
 main.in_vehicle=true
 main.hotaru.set_active(false)
 main.rv.set_active(true)
 main.rv.speed=0
 main.rv.rotation.y=0
 touch(joystick,2,center,true)
 drag(joystick,2,center+Vector2(-75,-75))
 for i in range(18):await physics_frame
 check(is_zero_approx(main.rv.speed) and joystick.finger==-1,"Walking joystick still drives vehicle")
 paused=true
 joystick._process(0)
 check(main.rv.touch_move==Vector2.ZERO and joystick.finger==-1,"Pausing retains throttle")
 paused=false
 main.in_vehicle=false
 main.rv.set_active(false)
 main.hotaru.set_active(true)
 main.hotaru._combat_action=""
 main.hotaru.position=main.STORE_DOOR
 main.supply_quest.begin()
 main._enter_store()
 for z in get_nodes_in_group("zombies"):z.queue_free()
 await physics_frame
 for item in ["water","food"]:
  main.quantity_picker.open(item)
  main.quantity_picker.amount.value=1
  main.quantity_picker.take()
 check(not paused and state.tutorial_step==3,"Taking supplies fails to resume the game")
 main.hotaru.position=main.STORE_ORIGIN+Vector3(2.7,1.08,3.12)
 main._update_hud()
 check(main.store_interior.is_near_exit(main.hotaru.position) and main.interact_button.text=="离开便利店","Visible front doorway is outside exit zone")
 check(not main.store_interior.is_near_exit(main.STORE_ORIGIN+Vector3(0,1.08,.3)),"Shelf aisle incorrectly exits the shop")
 joystick._process(0)
 touch(joystick,4,center,true)
 var leave: Vector2=main.interact_button.get_global_rect().get_center()
 touch(joystick,5,leave,true)
 touch(joystick,5,leave,false)
 check(not main.inside_store and main.controls_enabled and main.hotaru.active,"Second-finger exit after collecting supplies failed")
 joystick.reset()
 main._enter_rv_interior()
 main._sit_at_driver()
 main._update_hud()
 joystick._process(0)
 check(not joystick.visible,"Walking joystick should hide while seated")
 var stand: Vector2=main.interact_button.get_global_rect().get_center()
 touch(joystick,6,stand,true)
 joystick._process(0)
 touch(joystick,6,stand,false)
 check(not main.seated_at_driver,"Mobile action button fails while joystick is hidden at driver seat")
 main._sit_at_driver()
 main._update_hud()
 var drive: Vector2=main.vehicle_button.get_global_rect().get_center()
 touch(joystick,7,drive,true)
 joystick._process(0)
 touch(joystick,7,drive,false)
 check(main.in_vehicle and main.rv.active,"Cannot start driving using a touch action")
 print("MOBILE_INPUT_STORE_CHECK errors=",errors)
 root.get_node("AudioDirector").stop_all()
 main.queue_free()
 await process_frame
 quit(1 if errors else 0)
