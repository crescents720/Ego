extends SceneTree
var errors:=0
func _initialize():call_deferred("run")
func check(ok: bool,message: String):
 if not ok:errors+=1;push_error(message)
func tap(point: Vector2):
 for down in [true,false]:
  var e:=InputEventMouseButton.new();e.position=point;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down;Input.parse_input_event(e);Input.flush_buffered_events()
func shot(name: String):
 for i in range(5):await process_frame
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://artifacts/"+name+".png")
func run():
 root.size=Vector2i(720,1280)
 var m=load("res://scenes/main.tscn").instantiate();root.add_child(m)
 var s=root.get_node("GameState");s.suppress_save=true
 m._start_new_game();m._set_phase(m.Phase.EXPLORE);m.zombie_population.set_process(false)
 for z in get_nodes_in_group("zombies"):z.queue_free()
 await physics_frame
 # Overlapping factory / RV triggers: labels and real button clicks must agree.
 m.rv.position=m.factory.DOOR-Vector3(m.rv.SIDE_DOOR.x,0,m.rv.SIDE_DOOR.z);m.rv.position.y=1.02;m.rv.rotation.y=0
 m.hotaru.position=m.rv.get_disembark_position()
 m._update_hud()
 check(m.factory.nearby() and m.interact_button.text=="进入工厂","RV label overwrites factory action")
 tap(m.vehicle_button.get_global_rect().get_center())
 check(m.inside_rv and not m.factory.active and not m.factory.transitioning,"Vehicle button enters factory")
 m.rv.position=Vector3(0,1.02,100)
 m.hotaru.cancel_boarding_step()
 s.lathe_installed=true;s.cargo={"wire":20,"food":20,"water":20}
 var f=m.fabrication
 check(m.hotaru._animation_names.has("LatheWork"),"Missing standing lathe animation")
 f.open();var clock: float=s.world_seconds
 await create_timer(.1,true,false,true).timeout
 check(is_equal_approx(s.world_seconds,clock),"Production menu does not pause day clock")
 await shot("manual_craft_menu")
 f.start("left")
 var work_clock: float=s.world_seconds
 await create_timer(.25).timeout
 check(s.world_seconds>work_clock and absf((s.world_seconds-work_clock)-float(s.fence_job.work))<.10,"Day clock and manual work diverge")
 f.set_process(false);s.fence_job.work=0.0
 check(f.active and m.hotaru.servicing and s.cargo.wire==14,"Manual work did not start / consume once")
 check(m.hotaru._current_animation_state=="LatheWork","Wrong crafting animation")
 f._process(6)
 check(is_equal_approx(s.fence_job.work,6),"Manual work not counted")
 paused=true;f._process(10);paused=false
 check(is_equal_approx(s.fence_job.work,6),"Pause advances work")
 f._process(0)
 await shot("manual_craft_work")
 f.stop_work("test")
 s.tick_survival(360)
 check(is_equal_approx(s.fence_job.work,6) and s.fence_hp.left==0,"Unattended / sleeping craft advances")
 check(s.save_game("user://manual_craft_test/slot.cfg")==OK,"Paused work save refused")
 s.fence_job={};s.load_completed_save("user://manual_craft_test/slot.cfg")
 check(is_equal_approx(s.fence_job.work,6),"Paused work not saved")
 f.open();f.start("left");f._process(9)
 check(not f.active and s.fence_job.stage=="install" and s.fence_hp.left==0,"Craft auto-installs or fails to finish")
 check(s.cargo.wire==14,"Resume consumed materials twice")
 m.hotaru.position=m.rv_interior.get_entry_position();m._exit_rv_interior()
 check(f.can_install(),"Cannot install after getting out")
 check(f.begin_install(),"Installation did not start")
 # Exercise real collision-aware movement around the bumper to the opposite side.
 for i in range(420):
  if not f.walking:break
  f._process(1.0/60)
  await physics_frame
 check(not f.walking and f.active,"Cannot walk around RV to install")
 f._process(3)
 check(is_equal_approx(s.fence_job.install_work,3),"Installation progress absent")
 check(s.fence_hp.left==0 and m.hotaru._current_animation_state=="RepairKneel","Fence protects before installation")
 f._process(0)
 await shot("manual_fence_install")
 f.stop_work("test")
 s.tick_survival(360)
 check(is_equal_approx(s.fence_job.install_work,3),"Installation advances while away")
 check(f.begin_install(),"Cannot resume installation")
 f.walking=false;f._process(5)
 check(s.fence_hp.left==500 and s.fence_job.is_empty() and not f.active,"Installation completion failed")
 s.fence_job={"side":"front","finish":s.world_seconds+10};s.normalize_fence_job()
 check(s.fence_job.stage=="craft" and is_equal_approx(s.fence_job.work,7.5),"Legacy timer progress migration failed")
 s.fence_job={"side":"front","finish":s.world_seconds-20};s.normalize_fence_job()
 check(s.fence_job.stage=="install" and s.fence_hp.front==0,"Legacy timer bypasses manual install")
 print("MANUAL_FABRICATION_CHECK errors=",errors)
 root.get_node("AudioDirector").stop_all();quit(errors)
