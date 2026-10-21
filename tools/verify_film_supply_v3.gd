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
 main._begin_story()
 check(main.opening.movie.stream.resource_path.ends_with("opening_v2.ogv") and main.opening.place.text=="","Wrong film/title")
 await create_timer(.3).timeout
 check(main.opening.movie.is_playing(),"New film does not play")
 main.opening.movie.stop()
 main.opening.set_beat(main.OpeningStory.Beat.DONE)
 main._start_new_game()
 main.zombie_population.set_process(false)
 for actor in get_nodes_in_group("zombies"):actor.set_physics_process(false)
 main.hotaru.position=main.rv.get_disembark_position()
 main._enter_rv_interior()
 main.hotaru.position=main.rv_interior.get_driver_stand_position()
 main._interact()
 main._toggle_vehicle()
 check(state.tutorial_step==1,"Driving no longer triggers tutorial")
 main.rv.position=Vector3(0,1.02,48)
 main._toggle_vehicle()
 main.hotaru.position=main.rv_interior.get_entry_position()
 main._interact()
 main.hotaru.position=main.STORE_DOOR
 main._interact()
 check(main.inside_store and state.tutorial_step==2,"Store entry failed")
 for entry in [["water",Vector3(0,1.08,.3),1],["food",Vector3(-1.75,1.08,.3),2]]:
  main.hotaru.position=main.STORE_ORIGIN+entry[1]
  main._interact()
  check(main.quantity_picker.veil.visible,"Shelf did not open quantity selector")
  main.quantity_picker.amount.value=entry[2]
  main.quantity_picker.take()
 check(state.tutorial_step==3 and state.carried_grams()==6000,"Partial shopping did not advance mission")
 main.hotaru.position=main.store_interior.get_entry_position()
 main._interact()
 main.hotaru.position=main.rv.get_disembark_position()
 main._enter_rv_interior()
 main.hotaru.position=main.rv_interior.get_driver_stand_position()
 main._interact()
 main.rv_dashboard.open()
 main.cargo_organizer.open()
 for id in ["water","food"]:
  main.cargo_organizer.amount.value=2 if id=="food" else 1
  main.cargo_organizer.perform_drop(main.cargo_organizer.drag_payload("bag",id),"cargo")
 check(state.tutorial_step==4 and state.cargo_grams()==6000,"Organizing supplies did not complete mission")
 main.cargo_organizer.close()
 check(paused,"Closing organizer should return to paused dashboard")
 main.rv_dashboard.close()
 check(not paused,"Closing dashboard should resume play")
 print("FILM_SUPPLY_V3_CHECK errors=",errors)
 main.opening.voice.stop()
 main.opening.music.stop()
 main.opening.fire_audio.stop()
 quit(0 if errors==0 else 1)
