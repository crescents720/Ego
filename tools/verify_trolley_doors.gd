extends SceneTree
var errors:=0
func _initialize():call_deferred("run")
func check(ok: bool,message: String):
 if not ok:errors+=1;push_error(message)
func run():
 var m=load("res://scenes/main.tscn").instantiate();root.add_child(m)
 var s=root.get_node("GameState");s.suppress_save=true
 m._start_new_game();m._set_phase(m.Phase.EXPLORE);m.zombie_population.set_process(false)
 for z in get_nodes_in_group("zombies"):z.queue_free()
 await physics_frame
 s.cart_owned=true;s.cart_deployed=true;s.cart_items={"wire":2}
 m.hotaru.position=m.STORE_DOOR-Vector3(0,0,3.1);m.hotaru.rotation.y=0
 s.cart_position=m.hotaru.position+Vector3(0,-.87,1.05);s.cart_yaw=0;m.trolley.interact()
 m.trolley.release()
 check(not m._is_near_store_door(),"Parked cart remotely triggers door")
 m.trolley.interact()
 check(m.hotaru.position.distance_to(m.STORE_DOOR)>2.2 and m._is_near_store_door(),"Cart-led store entrance rejected")
 m._update_hud();check(m.interact_button.visible and m.interact_button.text=="进店 E","Cart UI hides store entry")
 m._interact();check(m.inside_store,"Cart-led store interaction failed")
 for z in get_nodes_in_group("zombies"):z.set_physics_process(false)
 m.hotaru.position=m.STORE_ORIGIN+Vector3(0,1.08,1.4);s.cart_position=m.hotaru.position+Vector3(0,-.92,1.05);s.cart_yaw=0
 check(not m.store_interior.is_near_exit(m.hotaru.position) and m._is_near_store_exit(),"Cart-led store exit rejected")
 m._interact();check(not m.inside_store and s.spatial_room_id(s.cart_position)==0,"Cannot bring cart out from leading edge")
 m.trolley.release()
 m.hotaru.position=m.factory.DOOR+Vector3(0,0,-3.8);m.hotaru.rotation.y=0
 s.cart_position=m.hotaru.position+Vector3(0,-.8,1.05);s.cart_yaw=0;m.trolley.interact()
 check(m.factory.nearby(),"Cart-led factory entrance rejected")
 m._update_hud();check(m.interact_button.visible and m.interact_button.text=="进入工厂","Cart UI hides factory entry")
 m._interact();await create_timer(.7).timeout
 check(m.factory.active,"Factory enter failed")
 for z in m.factory.enemies:z.set_physics_process(false)
 m.trolley.release()
 var parked: Vector3=m.factory.ORIGIN+Vector3(-2.0,.16,4.3)
 s.cart_position=parked;s.cart_yaw=.4
 m.trolley._physics_process(0)
 check(m.trolley.visual.visible,"West-half factory cart is invisible")
 m.hotaru.position=m.factory.ORIGIN+Vector3(-.9,1.05,6.3);m.factory.interact()
 check(not m.factory.active and s.cart_position==parked,"Leaving without cart moved it")
 m.trolley._physics_process(0);check(not m.trolley.visual.visible,"Indoor cart leaked outdoors")
 for visit in range(2):
  m.hotaru.position=m.factory.DOOR;m.factory.enter();await create_timer(.7).timeout
  for z in m.factory.enemies:z.set_physics_process(false)
  m.trolley._physics_process(0)
  check(s.cart_position==parked and m.trolley.visual.visible and s.cart_items.wire==2,"Parked cart or cargo lost on reentry")
  if visit==0:
   m.hotaru.position=m.factory.ORIGIN+Vector3(-.9,1.05,6.3);m.factory.interact()
 m.hotaru.position=parked+Vector3(0,.89,-1);m.trolley.interact()
 check(m.trolley.pushing,"Cannot recover parked cart")
 m.hotaru.position=m.factory.ORIGIN+Vector3(-.9,1.05,5.3);s.cart_position=m.hotaru.position+Vector3(0,-.89,1.05);s.cart_yaw=0
 check(m.factory.near_exit(),"Cart-led factory exit rejected")
 m.factory.interact()
 check(not m.factory.active and s.spatial_room_id(s.cart_position)==0 and s.cart_items.wire==2,"Recovered cart failed to leave")
 m.trolley.release()
 m._enter_store();m.trolley.release()
 var store_parked: Vector3=m.STORE_ORIGIN+Vector3(-2,.16,1.5);s.cart_position=store_parked
 m.trolley._physics_process(0);check(m.trolley.visual.visible,"West-half store cart invisible")
 m.hotaru.position=m.store_interior.get_entry_position();m._exit_store()
 check(s.cart_position==store_parked,"Store parked cart teleported")
 m._enter_store();m.trolley._physics_process(0)
 check(m.trolley.visual.visible and s.cart_position==store_parked,"Store cart lost on reentry")
 m.hotaru.position=m.store_interior.get_entry_position();m._exit_store()
 check(s.save_game("user://trolley_doors_test/slot.cfg")==OK,"Cart save failed")
 s.cart_position=Vector3.ZERO;s.cart_items={};s.load_completed_save("user://trolley_doors_test/slot.cfg")
 check(s.cart_position==store_parked and s.cart_items.wire==2,"Parked cart save lost cargo or position")
 print("TROLLEY_DOORS_CHECK errors=",errors)
 root.get_node("AudioDirector").stop_all();quit(errors)
