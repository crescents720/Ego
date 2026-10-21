extends SceneTree
var errors:=0
func _initialize():call_deferred("run")
func check(ok: bool,msg: String):
 if not ok:errors+=1;push_error(msg)
func touch(id: int,p: Vector2,down: bool):
 var e:=InputEventScreenTouch.new();e.index=id;e.position=p;e.pressed=down;Input.parse_input_event(e);Input.flush_buffered_events()
func drag(id: int,p: Vector2):
 var e:=InputEventScreenDrag.new();e.index=id;e.position=p;Input.parse_input_event(e);Input.flush_buffered_events()
func shot(name: String):
 for i in range(5):await process_frame
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://artifacts/"+name+".png")
func run():
 root.size=Vector2i(720,1280)
 var m=load("res://scenes/main.tscn").instantiate();root.add_child(m)
 var s=root.get_node("GameState");s.suppress_save=true
 m._start_new_game();m._set_phase(m.Phase.EXPLORE);m.set_process(false);m.zombie_population.set_process(false)
 for z in get_nodes_in_group("zombies"):z.queue_free()
 await physics_frame
 m.mobile_joystick.mobile=true
 m.in_vehicle=true;m.inside_rv=false;m.hotaru.set_active(false);m.rv.position=Vector3(0,1.02,100);m.rv.rotation.y=0;m.rv.set_active(true);m.rv.set_physics_process(false);s.fuel_l=60
 var d=m.mobile_driving
 m._update_hud();d._process(0);m.mobile_joystick._process(0);m._update_camera(100)
 check(d.visible and not m.mobile_joystick.visible,"Driving still shows walking joystick")
 var visible_buttons: Array=[m.vehicle_button]
 visible_buttons.append_array(d.buttons.values())
 for i in range(visible_buttons.size()):
  var r: Rect2=visible_buttons[i].get_global_rect()
  check(r.position.x>=0 and r.position.y>=0 and r.end.x<=720 and r.end.y<=1280,"Control outside screen")
  for j in range(i+1,visible_buttons.size()):check(not r.intersects(visible_buttons[j].get_global_rect()),"Driving buttons overlap")
 check(not m.attack_button.visible and not m.interact_button.visible and not m.upgrade_button.visible,"Driving exposes overlapping action controls")
 var left: Vector2=d.buttons.left.get_global_rect().get_center()
 var gas: Vector2=d.buttons.gas.get_global_rect().get_center()
 var brake: Vector2=d.buttons.brake.get_global_rect().get_center()
 var gear_button: Vector2=d.buttons.gear.get_global_rect().get_center()
 touch(0,left,true);touch(1,gas,true)
 check(m.rv.touch_driving and m.rv.touch_throttle==1 and m.rv.touch_steer==-1,"Two-finger gas and steering conflict")
 for i in range(30):m.rv._physics_process(1.0/60)
 check(m.rv.speed>2 and m.rv.rotation.y>0,"Pedals and body-relative steering fail")
 drag(0,Vector2(340,800));check(m.rv.touch_steer==0 and m.rv.touch_throttle==1,"Sliding away retains steering or clears gas")
 drag(0,left);check(m.rv.touch_steer==-1,"Cannot return finger onto steering button")
 touch(0,Vector2(340,800),false)
 check(m.rv.touch_throttle==1 and m.rv.touch_steer==0,"Release steering cancels gas")
 touch(2,brake,true)
 check(m.rv.touch_brake and m.rv.touch_throttle==0,"Brake does not override throttle")
 for i in range(120):m.rv._physics_process(1.0/60)
 check(is_zero_approx(m.rv.speed),"Brake reverses instead of stopping")
 touch(1,gas,false);touch(2,brake,false)
 m.rv.speed=2;touch(3,gear_button,true);touch(3,gear_button,false)
 check(d.gear==1,"Can shift while moving")
 m.rv.speed=0;touch(3,gear_button,true);touch(3,gear_button,false)
 check(d.gear==-1,"Cannot select reverse at rest")
 touch(1,gas,true)
 for i in range(120):m.rv._physics_process(1.0/60)
 check(m.rv.speed<0 and absf(m.rv.speed)<=2.5,"Reverse speed limit fails")
 paused=true;d._process(0)
 check(d.fingers.is_empty() and not m.rv.touch_driving,"Pause retains pedals")
 paused=false;d._process(0);check(m.rv.touch_throttle==0,"Unpause resumes held throttle")
 touch(1,gas,true);d._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
 check(not m.rv.touch_driving and d.fingers.is_empty(),"Focus loss leaves input held")
 m.rv.speed=0;d.gear=1;d._process(0);await shot("mobile_driving_layout")
 m.in_vehicle=false;m.hotaru.set_active(true);m.hotaru.position=m.rv.get_disembark_position();m.rv.set_active(false)
 m._update_hud();d._process(0);m.mobile_joystick._process(0)
 check(not d.visible and m.mobile_joystick.visible and m.vehicle_button.position==Vector2(540,1010),"Walking layout not restored")
 m.mobile_joystick.mobile=false;m.rv.set_active(true);m.rv.speed=0;m.rv.clear_touch_drive();Input.action_press("move_forward");m.rv._physics_process(.1);Input.action_release("move_forward")
 check(m.rv.speed>0,"Desktop keyboard driving regressed")
 print("MOBILE_DRIVING_CHECK errors=",errors)
 root.get_node("AudioDirector").stop_all();quit(errors)


