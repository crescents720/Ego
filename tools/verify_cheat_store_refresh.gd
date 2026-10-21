extends SceneTree
var errors:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
 if not ok:errors+=1;push_error(message)
func key(value: int) -> void:
 for pressed in [true,false]:
  var e:=InputEventKey.new()
  e.keycode=value
  e.pressed=pressed
  Input.parse_input_event(e)
  Input.flush_buffered_events()
  await process_frame
func run() -> void:
 root.size=Vector2i(720,1280)
 var m=load("res://scenes/main.tscn").instantiate()
 root.add_child(m)
 var s=root.get_node("GameState")
 s.suppress_save=true
 m._start_new_game()
 m.set_process(false)
 m.zombie_population.set_process(false)
 for z in get_nodes_in_group("zombies"):z.queue_free()
 await physics_frame
 m._set_phase(m.Phase.EXPLORE)
 await key(KEY_ENTER)
 check(m.test_settings.veil.visible and paused,"Enter did not open settings")
 m.test_settings.code.text="wrong"
 m.test_settings.submit()
 check(s.cash==0,"Invalid code awarded cash")
 m.test_settings.code.text="showmethemoney"
 await key(KEY_ENTER)
 check(s.cash==10000,"Enter submission did not award exactly 10000")
 m.test_settings.code.text="showmethemoney"
 m.test_settings.submit()
 check(s.cash==20000,"Code cannot be reused for testing")
 await key(KEY_ESCAPE)
 check(not paused and not m.test_settings.veil.visible,"Closing settings did not resume game")
 m.mobile_joystick.setup(m,true)
 m.test_settings._process(0)
 var center: Vector2=m.mobile_joystick.position+m.mobile_joystick.CENTER
 for entry in [[0,center,true],[1,m.test_settings.launch.get_global_rect().get_center(),true],[1,m.test_settings.launch.get_global_rect().get_center(),false]]:
  var e:=InputEventScreenTouch.new()
  e.index=entry[0]
  e.position=entry[1]
  e.pressed=entry[2]
  Input.parse_input_event(e)
  Input.flush_buffered_events()
 check(paused and m.test_settings.veil.visible and m.hotaru.touch_move==Vector2.ZERO,"Second finger gear does not pause/reset joystick")
 m.test_settings.close()
 # Old depleted shelves stay available, with actual carrying limits.
 s.store_stock={"water":0,"food":0}
 s.store_looted={"water":true,"food":true,"tools":true,"medical":true}
 for i in range(5):
  s.items={}
  check(s.take_stock("food",20),"Food supply ran out")
  s.items={}
  check(s.take_stock("water",2),"Water supply ran out")
 s.items={}
 check(not s.take_stock("water",3),"Unlimited supply bypassed backpack weight")
 m.store_interior.reset_loot(s.store_looted)
 check(m.store_interior.focus(m.STORE_ORIGIN+Vector3(-.875,1.08,.3))=="water","Old looted shelf is unavailable")
 check(m.store_interior.take_focused()=="water","Cannot take stocked shelf")
 check(m.store_interior.focus(m.STORE_ORIGIN+Vector3(-.875,1.08,.3))=="water","Taking shelf hides infinite supply")
 # No instant replacement, then 1-2 per half-day, bounded even after sleep.
 var pop=m.zombie_population
 s.world_seconds=179.9
 pop._refresh_store()
 check(s.store_residents==2,"Indoor refresh happened before half day")
 s.world_seconds=180
 pop._refresh_store()
 var count: int=s.store_residents
 check(count in [3,4],"Half-day did not add 1-2")
 pop._refresh_store()
 check(s.store_residents==count,"Repeated refresh in same interval duplicated spawns")
 s.world_seconds=3600
 pop._refresh_store()
 check(s.store_residents==6,"Fast-forward exceeded or failed to fill cap")
 m.hotaru.position=m.STORE_DOOR
 m._enter_store()
 check(pop.indoor.size()==6,"Store did not materialize bounded residents")
 for z in pop.indoor:z.set_physics_process(false)
 pop.indoor[0].take_damage(100)
 check(s.store_residents==5,"Indoor kill did not update population")
 pop._refresh_store()
 pop._sync_indoor()
 check(pop.indoor.size()==5,"Indoor kill was replaced immediately")
 s.world_seconds=3780
 pop._refresh_store()
 pop._sync_indoor()
 check(s.store_residents==6 and pop.indoor.size()==6,"Next half day did not replenish to cap")
 for z in pop.indoor:z.set_physics_process(false)
 m._exit_store()
 check(s.save_game("user://testing_store_revision/test.cfg")==OK,"Population schedule save failed")
 var saved_time: float=s.store_next_refresh
 s.store_residents=0
 s.store_next_refresh=0
 check(s.load_completed_save("user://testing_store_revision/test.cfg"),"Cannot reload schedule")
 check(s.cash==20000 and s.store_residents==6 and s.store_next_refresh==saved_time,"Cash/population schedule save lost data")
 print("CHEAT_STORE_REFRESH_CHECK errors=",errors)
 root.get_node("AudioDirector").stop_all()
 m.queue_free()
 await create_timer(.15).timeout
 quit(1 if errors else 0)
