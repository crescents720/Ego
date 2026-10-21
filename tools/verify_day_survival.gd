extends SceneTree
var errors:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
 if not ok:push_error(message);errors+=1
func run() -> void:
 var main=load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 var state=root.get_node("GameState")
 state.suppress_save=true
 main._start_new_game()
 main.zombie_population.set_process(false)
 main.set_process(false)
 for actor in get_nodes_in_group("zombies"):actor.set_physics_process(false)
 state.try_add_items({"bat":1})
 state.equip_item("bat","right_hand")
 main.hotaru.global_position=main.STORE_DOOR
 main._enter_store()
 main.quantity_picker.open("water")
 main.quantity_picker.amount.value=2
 main.quantity_picker.refresh()
 check(main.quantity_picker.confirm.disabled,"Two buckets plus bat exceed 10kg")
 main.quantity_picker.amount.value=1
 main.quantity_picker.take()
 check(state.items.water==1 and main.store_interior.focus(main.STORE_ORIGIN+Vector3(-.875,1.08,.3))=="water","Water pickup must leave shelf available")
 main.quantity_picker.open("food")
 main.quantity_picker.amount.value=2
 main.quantity_picker.take()
 check(state.carried_grams()==6900 and state.items.food==2,"New units do not weigh correctly")
 check(state.tutorial_step==0,"Tutorial should not begin before first drive")
 check(state.move_stack("water","bag","cargo",1),"Cannot store bucket")
 check(state.move_stack("food","bag","trash",1) and state.items.food==1,"Discard does not remove selected quantity")
 check(not state.move_stack("bat","bag","trash",1),"Equipped weapon discarded")
 check(state.move_stack("water","cargo","bag",1),"Cannot retrieve bucket")
 main._exit_store()
 main.hotaru.reset_death()
 state.start_new_run()
 state.cargo={"water":5,"food":20}
 state._sync_resources()
 var damage: float=state.tick_survival(360)
 check(damage==0 and state.cargo.water==4 and state.cargo.food==18,"One day must consume one bucket and two bread packs")
 state.start_new_run()
 state.cargo={"food":50}
 state._sync_resources()
 main.hotaru.health=5.0
 main.hotaru.take_survival_damage(state.tick_survival(540)*5)
 check(is_equal_approx(main.hotaru.health,2.5),"Water HP decline not linear after 1.5 days")
 main.hotaru.take_survival_damage(state.tick_survival(540)*5)
 check(main.hotaru.dead and main.hotaru.health==0,"Three days without water must kill")
 main.hotaru.reset_death()
 main.hotaru.health=5
 state.start_new_run()
 state.cargo={"water":50}
 state._sync_resources()
 main.hotaru.take_survival_damage(state.tick_survival(900)*5)
 check(is_equal_approx(main.hotaru.health,2.5),"Food HP decline not linear after 2.5 days")
 main.hotaru.take_survival_damage(state.tick_survival(900)*5)
 check(main.hotaru.dead,"Five days without food must kill")
 main.hotaru.reset_death()
 main.hotaru.health=5
 main.phase=main.Phase.EXPLORE
 state.world_seconds=179.9
 main.day_cycle._process(.1)
 state.world_seconds=180
 main.day_cycle._process(.1)
 check(state.is_night() and main.zombie_population.night and main.day_cycle.notice.visible,"Missing sunset trigger")
 for actor in get_nodes_in_group("zombies"):
  if not actor.is_in_group("store_indoor_zombies"):check(actor.move_speed==main.hotaru.MOVE_SPEED,"Night chase must match heroine")
 state.world_seconds=360
 main.day_cycle._process(.1)
 check(not state.is_night() and not main.zombie_population.night and main.day_cycle.notice.visible,"Missing dawn trigger")
 var label: Label3D=main.hotaru.find_children("*","Label3D",true,false)[0]
 check(label.text=="蛍","Hero name was not corrected")
 check(main.opening.place.text!="序章 · 萤火未熄","Opening title remains")
 state.world_seconds=222
 state.store_stock={"water":3,"food":7}
 state.tutorial_step=2
 var path: String="user://day_rules_test.cfg"
 state.save_game(path)
 state.start_new_run()
 check(state.load_completed_save(path) and state.world_seconds==222 and state.store_stock.water==3,"Clock/shelf persistence failed")
 DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
 # Allow pending death callbacks to settle before terminating this synthetic test.
 await create_timer(2.1).timeout
 main.opening.voice.stop()
 main.opening.music.stop()
 main.opening.fire_audio.stop()
 print("DAY_SURVIVAL_CHECK errors=",errors)
 quit(0 if errors==0 else 1)
