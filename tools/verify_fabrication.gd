extends SceneTree
var errors:=0
func _initialize():call_deferred("run")
func check(ok: bool,message: String):
 if not ok:errors+=1;push_error(message)
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
 m.rv.position=Vector3(0,1.02,100);m.rv.rotation.y=0
 m.hotaru.position=m.rv.get_disembark_position();m._enter_rv_interior()
 check(not s.start_fence_job("front"),"Production possible without lathe")
 s.lathe_installed=true;s.cargo={"wire":20}
 m.fabrication.open();await shot("fabrication_menu")
 check(paused and m.fabrication.veil.visible,"Production UI does not pause")
 var panel=m.fabrication.veil.get_child(0)
 print("Fabrication bounds ",panel.get_global_rect())
 check(panel.get_global_rect().end.x<=720 and panel.get_global_rect().end.y<=1280,"Production menu overflows")
 m.fabrication.start("front")
 m.fabrication.stop_work("")
 check(not paused and not m.fabrication.veil.visible and s.cargo.wire==16,"Start does not consume materials / close")
 check(not s.start_fence_job("back"),"Parallel duplicate job allowed")
 s.tick_survival(19)
 check(s.fence_hp.front==0 and s.fence_job.work==0,"Unattended work advances")
 s.advance_fence_work(14,"craft")
 check(s.fence_hp.front==0 and s.fence_job.stage=="craft","Production finished early")
 s.advance_fence_work(1,"craft")
 check(s.fence_hp.front==0 and s.fence_job.stage=="install","Craft auto-installed fence")
 s.advance_fence_work(8,"install")
 check(s.fence_hp.front==500 and s.fence_job.is_empty(),"Manual install missing")
 check(not s.start_fence_job("front"),"Duplicate installed panel allowed")
 for side in ["back","left","right"]:
  check(s.start_fence_job(side),"Cannot produce "+side)
  s.advance_fence_work(15,"craft")
  s.advance_fence_work(8,"install")
 check(s.cargo.get("wire",0)==0,"Recipe total incorrect")
 for side in s.fence_hp:check(s.fence_hp[side]==500,"Panel not installed "+side)
 m.fabrication.open();await shot("fabrication_completed");m.fabrication.close()
 m.inside_rv=false;m.rv_interior.hide();m.world_root.show();m.rv.show();m.hotaru.hide();m.set_process(false)
 m.camera.projection=Camera3D.PROJECTION_ORTHOGONAL;m.camera.size=10
 m.camera.position=m.rv.position+Vector3(8,5,-8);m.camera.look_at(m.rv.position)
 await shot("vehicle_fences")
 m.rv.occupied=true
 var biter=m.ZombieController.new();m.add_child(biter);biter.position=m.rv.position+Vector3(0,-.07,4);biter.set_target(m.hotaru);biter.set_vehicle_target(m.rv);biter.set_physics_process(false)
 biter._physics_process(.01)
 check(s.fence_hp.back==500,"Zombie hit before windup")
 biter._physics_process(.61)
 check(s.fence_hp.back==499,"Real zombie bite did not hit rear fence")
 biter.queue_free()
 var before: int=m.rv.health
 var point: Vector3=m.rv.to_global(Vector3(0,0,-4))
 m.rv.take_zombie_hit(point)
 check(s.fence_hp.front==499 and m.rv.health==before,"First hit not absorbed")
 for i in range(499):m.rv.take_zombie_hit(point)
 check(s.fence_hp.front==0 and m.rv.health==before,"500 hits did not destroy panel exactly")
 m.rv.take_zombie_hit(point)
 check(m.rv.health<before,"Destroyed panel still protects")
 s.fence_hp.left=480;s.fence_hp.right=300
 m.rv.repair_full()
 check(s.fence_hp.front==0 and s.fence_hp.left==500 and s.fence_hp.right==500,"Repair resurrected or failed surviving panels")
 s.fence_hp.left=400
 m.rv.position=m.repair_shop.BAY;m.hotaru.position=m.rv.get_disembark_position();m.hotaru.show();m.controls_enabled=true;m.hotaru.set_active(true)
 m.rv.last_hostile_attack_ms=-100000
 check(m.service.reason("repair")=="","Fence-only repair refused at full hull health")
 check(m.service.begin("repair"),"Cannot begin fence repair")
 m.service.walking=false;m.service._process(6)
 check(s.fence_hp.left>=450 and s.fence_hp.left<500,"Partial fence repair not retained")
 m.service.stop("test")
 s.cargo={"wire":6};check(s.start_fence_job("front"),"Cannot rebuild destroyed panel")
 s.advance_fence_work(3,"craft")
 var saved_work: float=s.fence_job.work
 check(s.save_game("user://fabrication_test/slot.cfg")==OK,"Production save failed")
 s.fence_hp={};s.fence_job={};s.load_completed_save("user://fabrication_test/slot.cfg")
 check(s.fence_hp.front==0 and s.fence_job.work==saved_work,"Fence state / timer not saved")
 s.advance_fence_work(12,"craft")
 s.advance_fence_work(8,"install")
 check(s.fence_hp.front==500,"Saved production did not complete")
 print("FABRICATION_CHECK errors=",errors)
 root.get_node("AudioDirector").stop_all();quit(errors)

