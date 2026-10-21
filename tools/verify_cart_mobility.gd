extends SceneTree
var errors:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
 if not ok:errors+=1;push_error(message)
func run() -> void:
 root.size=Vector2i(720,1280)
 var main=load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 var state=root.get_node("GameState")
 state.suppress_save=true
 main._start_new_game()
 main.set_process(false)
 main.mobile_joystick.set_process(false)
 main.zombie_population.set_process(false)
 for z in get_nodes_in_group("zombies"):z.queue_free()
 await physics_frame
 main._set_phase(main.Phase.EXPLORE)
 main.hotaru.set_movement_camera(null)
 main.rv.position=Vector3(20,1.02,51)
 state.cart_owned=true
 state.cart_deployed=true
 main.hotaru.position=Vector3(0,.95,100)
 main.hotaru.rotation.y=0
 state.cart_position=Vector3(0,.08,101.05)
 main.trolley.interact()
 main.hotaru.touch_move=Vector2(0,1)
 var start: Vector3=main.hotaru.position
 await create_timer(.6).timeout
 var slow_distance: float=main.hotaru.position.distance_to(start)
 print("slow distance=",slow_distance)
 check(slow_distance>.8 and slow_distance<2,"Push speed is not reduced")
 check(state.cart_position.distance_to(main.hotaru.position+Vector3(0,-.87,1.05))<.2,"Cart does not follow")
 main.trolley.release()
 start=main.hotaru.position
 await create_timer(.6).timeout
 check(main.hotaru.position.distance_to(start)>slow_distance*1.5,"Release did not restore speed")
 main.hotaru.touch_move=Vector2.ZERO
 main.hotaru.position=main.STORE_DOOR
 main.hotaru.rotation.y=PI
 state.cart_position=main.hotaru.position+Vector3(0,-.87,-1.05)
 main.trolley.interact()
 main._enter_store()
 check(main.inside_store and main.trolley.pushing and state.cart_position.x>1500,"Cart did not enter with player")
 await physics_frame
 # Along the clear front aisle, then onto the central gap between shelves.
 main.hotaru.touch_move=Vector2(0,-1)
 start=main.hotaru.position
 await create_timer(.4).timeout
 check(main.hotaru.position.z<start.z-.5,"Cart cannot pass between shelves")
 main.hotaru.touch_move=Vector2.ZERO
 main.trolley.release()
 main.hotaru.position=main.store_interior.global_position+Vector3(0,1.08,.3)
 state.cart_position=main.hotaru.position+Vector3(0,-.92,.9)
 state.cart_items={}
 main.quantity_picker.open("water")
 main.quantity_picker.destination.select(1)
 main.quantity_picker.amount.value=4
 main.quantity_picker.refresh()
 check(not main.quantity_picker.confirm.disabled,"Nearby empty cart cannot take four water barrels")
 main.quantity_picker.take()
 check(state.cart_items.get("water",0)==4 and state.carried_grams()==0 and state.cart_grams()==20000,"Stock did not use separate cart compartment")
 # Leaving a released cart behind must not teleport it outside.
 var parked: Vector3=state.cart_position
 main.hotaru.position=main.store_interior.get_entry_position()
 main._exit_store()
 check(state.cart_position==parked,"Released cart was teleported on exit")
 main._enter_store()
 main.hotaru.position=state.cart_position+Vector3(0,.92,-1)
 main.trolley.toggle_button.pressed.emit()
 main.hotaru.position=main.store_interior.get_entry_position()
 state.cart_position=main.hotaru.position+Vector3(0,-.92,-1)
 main._exit_store()
 check(state.cart_position.x<1500 and not main.trolley.pushing,"Cannot bring cart back outside")
 # A second finger can release a cart while the first finger steers.
 var j=main.mobile_joystick
 j.setup(main,true)
 main.hotaru.position=Vector3(0,.95,100)
 main.hotaru.rotation.y=0
 state.cart_position=Vector3(0,.08,101.05)
 main.trolley.interact()
 main._update_hud()
 main.trolley._physics_process(0)
 var touch:=InputEventScreenTouch.new()
 touch.index=0
 touch.position=j.position+j.CENTER+Vector2(0,-70)
 touch.pressed=true
 Input.parse_input_event(touch)
 Input.flush_buffered_events()
 var b:=InputEventScreenTouch.new()
 b.index=1
 b.position=main.trolley.toggle_button.position+main.trolley.toggle_button.size/2
 b.pressed=true
 Input.parse_input_event(b)
 Input.flush_buffered_events()
 b=b.duplicate()
 b.pressed=false
 Input.parse_input_event(b)
 Input.flush_buffered_events()
 check(not main.trolley.pushing and j.finger==0,"Second finger failed to release cart during steering")
 j.reset()
 print("CART_MOBILITY_CHECK errors=",errors)
 root.get_node("AudioDirector").stop_all()
 main.queue_free()
 await create_timer(.2).timeout
 quit(1 if errors else 0)
