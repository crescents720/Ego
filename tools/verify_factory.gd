extends SceneTree
var errors:=0
func _initialize():call_deferred("run")
func check(ok: bool,text: String):
 if not ok:errors+=1;push_error(text)
func shot(name: String):
 for i in range(6):await process_frame
 if not DisplayServer.get_name()=="headless":
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://artifacts/"+name+".png")
func run():
 root.size=Vector2i(720,1280)
 var m=load("res://scenes/main.tscn").instantiate();root.add_child(m)
 var s=root.get_node("GameState");s.suppress_save=true
 m._start_new_game();m._set_phase(m.Phase.EXPLORE)
 m.zombie_population.set_process(false)
 for z in get_nodes_in_group("zombies"):z.queue_free()
 await physics_frame
 var f=m.factory
 m.hotaru.position=f.DOOR
 m.rv.position=f.DOOR+Vector3(9,.1,3)
 m._update_camera(100)
 await shot("factory_exterior")
 s.cart_owned=true;s.cart_deployed=true;s.cart_position=f.DOOR+Vector3(.9,-.8,0)
 m.trolley.interact()
 check(m.trolley.pushing,"Cannot push cart to factory")
 f.enter()
 await create_timer(.7).timeout
 check(f.active and m.hotaru.global_position.distance_to(f.ENTRY)<2,"Cannot enter factory")
 check(f.room.get_node_or_null("OriginalFactoryInterior")!=null,"Original factory interior missing")
 check(f.enemies.size()>=2 and f.enemies.size()<=3,"Enemy count incorrect")
 check(s.factory_wire==4,"First wire supply incorrect")
 check(m.trolley.pushing and s.cart_position.x>2900,"Cart did not enter")
 for z in f.enemies:z.set_physics_process(false)
 var mobile_before: bool=m.mobile_joystick.mobile
 m.mobile_joystick.mobile=true
 var e:=InputEventScreenTouch.new();e.index=0;e.position=Vector2(148,1120);e.pressed=true;Input.parse_input_event(e);Input.flush_buffered_events()
 var r:=InputEventScreenTouch.new();r.index=1;r.position=Vector2(550,600);r.pressed=true;Input.parse_input_event(r);Input.flush_buffered_events()
 var drag:=InputEventScreenDrag.new();drag.index=1;drag.position=Vector2(600,610);drag.relative=Vector2(50,10);Input.parse_input_event(drag);Input.flush_buffered_events()
 check(f.aim_finger==1 and not is_equal_approx(f.yaw,PI),"Touch camera drag failed")
 e=e.duplicate();r=r.duplicate();e.pressed=false;Input.parse_input_event(e);r.pressed=false;Input.parse_input_event(r);Input.flush_buffered_events()
 check(f.aim_finger==-1 and m.mobile_joystick.finger==-1,"Touch release sticks")
 f.aim_finger=2;f.dragging=true
 paused=true;f._process(0)
 check(f.aim_finger==-1 and not f.dragging,"Pause retains camera drag")
 check(not f.enemies[0].can_process(),"Factory enemies ignore pause")
 paused=false
 m.mobile_joystick.mobile=mobile_before;f.yaw=PI;f.pitch=.17
 m.trolley.release()
 m.day_cycle._notice_time=0
 await shot("factory_entry_original")
 m.hotaru.position=f.ORIGIN+Vector3(-.9,1.05,4.8)
 f.update_camera(0)
 await shot("factory_inside")
 var old_pitch: float=f.pitch
 f.pitch=1.0;f.update_camera(0)
 await shot("factory_original_in_game_height")
 f.pitch=old_pitch
 m.trolley.release()
 m.hotaru.position=f.ORIGIN+Vector3(3.1,1.05,.1)
 s.cart_position=m.hotaru.position+Vector3(.8,-.89,0)
 f.interact()
 check(s.lathe_taken and s.cart_items.get("lathe",0)==1,"Lathe not collected onto cart")
 f.interact()
 check(s.cart_items.get("lathe",0)==1,"Lathe duplicated")
 check(not s.move_stack("lathe","cart","bag",1),"24kg lathe fits backpack")
 m.hotaru.position=f.ORIGIN+Vector3(-1.2,1.05,4.6)
 s.cart_position=m.hotaru.position+Vector3(.8,-.89,0)
 f.interact()
 check(s.factory_wire==3 and s.cart_items.get("wire",0)==1,"Wire pickup failed")
 check(s.cart_grams()==24500,"Separate cargo weight incorrect")
 check(not m.can_save_safely(),"Unsafe indoor save allowed")
 m.trolley.release()
 m.hotaru.position=f.ORIGIN+Vector3(-.9,1.05,6.2);s.cart_position=m.hotaru.position+Vector3(0,-.89,-1)
 m.trolley.interact()
 f.interact()
 check(not f.active and s.cart_position.x<1000,"Cart not brought outside")
 m.trolley.release();m.hotaru.position=f.DOOR
 f.enter();await create_timer(.7).timeout
 check(s.factory_wire==3 and not f.lathe.visible,"Rapid reentry reset loot or lathe")
 for z in f.enemies:z.set_physics_process(false)
 f.leave();s.world_seconds+=180;m.hotaru.position=f.DOOR
 f.enter();await create_timer(.7).timeout
 check(s.factory_wire==6,"Long interval did not replenish with cap6")
 for z in f.enemies:z.set_physics_process(false)
 m.hotaru.position=f.ORIGIN+Vector3(4.25,1.05,5.8)
 f.yaw=PI/2;f.update_camera(0)
 check(m.camera.position.x<f.ORIGIN.x+4.74,"Camera crossed wall")
 f.leave();m.trolley.release()
 s.unload_cart()
 m.hotaru.position=m.rv.get_disembark_position();m._enter_rv_interior()
 f.workbench()
 check(m.dialog_panel.visible,"Installation prompt missing")
 m.dialog_actions.get_child(m.dialog_actions.get_child_count()-1).pressed.emit()
 check(s.lathe_installed and not s.cargo.has("lathe"),"Workbench installation failed")
 await shot("factory_lathe_installed")
 check(s.save_game("user://factory_test/slot.cfg")==OK,"Isolated save failed")
 s.lathe_installed=false;s.lathe_taken=false;s.factory_wire=0
 s.load_completed_save("user://factory_test/slot.cfg")
 check(s.lathe_installed and s.lathe_taken and s.factory_wire==6,"Factory save roundtrip failed")
 print("FACTORY_CHECK errors=",errors)
 root.get_node("AudioDirector").stop_all()
 quit(errors)
