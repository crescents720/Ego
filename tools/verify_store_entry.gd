extends SceneTree
func _initialize() -> void:
 call_deferred("run")
func check(ok: bool, message: String) -> bool:
 if ok:
  return true
 push_error("STORE_ENTRY_FAIL: " + message)
 quit(1)
 return false
func run() -> void:
 var main = load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 main._start_new_game()
 main._set_phase(main.Phase.CLEAR_ZOMBIES)
 main.hotaru.set_active(false)
 main.hotaru.set_physics_process(false)
 main.hotaru.global_position = Vector3(4.8, 0.95, 51.0)
 for i in range(65):
  await physics_frame
  main.hotaru.velocity = Vector3(4, 0, 0)
  main.hotaru.move_and_slide()
 if not check(main.hotaru.global_position.x > 7.0, "cannot physically approach visible doorway"):
  return
 main._update_hud()
 if not check(main.interact_button.visible, "door interaction button hidden"):
  return
 var key := InputEventKey.new()
 key.pressed = true
 key.keycode = KEY_E
 key.physical_keycode = KEY_E
 main._unhandled_input(key)
 if not check(main.inside_store, "E blocked while enemies are still outside"):
  return
 main.hotaru.global_position = main.STORE_ORIGIN + main.StoreController.STATIONS.tools.anchor
 main._interact()
 if not check(main.phase == main.Phase.RETURN_TO_RV, "early clue must advance return objective"):
  return
 main._close_dialog_and_resume()
 main.hotaru.global_position = main.store_interior.get_entry_position()
 main._interact()
 if not check(not main.inside_store, "exit after early loot"):
  return
 main.rv.global_position = main.STORE_DOOR + Vector3(-1, 0, 0)
 main._update_hud()
 if not check(main.interact_button.text == "进店 E", "door hint must match action"):
  return
 main._unhandled_input(key)
 if not check(main.inside_store and not main.inside_rv, "nearby RV steals shop interaction"):
  return
 main.hotaru.global_position = main.store_interior.get_entry_position()
 main._interact()
 main._set_phase(main.Phase.LEAVE_HOME)
 main._unhandled_input(key)
 if not check(main.inside_store, "walking to the store early must allow entry"):
  return
 print("STORE_ENTRY_PASS: physical approach + E with enemies outside; early clue progression; parked RV priority; early walking entry")
 quit()

