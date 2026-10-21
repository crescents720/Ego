extends SceneTree
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 if not OS.get_user_data_dir().contains(".test_userdata"):
  push_error("Save regression requires an isolated test user-data directory")
  quit(1)
  return
 var state = root.get_node("GameState")
 state.start_new_run()
 state.try_add_items({"scrap":5,"food":3,"water":4,"medicine":2})
 state.store_looted = {"food": true, "water": true, "medical": true, "tools": true}
 state.demo_completed = true
 state.save_game()
 state.start_new_run()
 if not state.load_completed_save() or state.water != 4 or state.medicine != 2 or state.store_looted.size() != 4:
  push_error("STORE_SAVE_FAIL")
  quit(1)
  return
 print("STORE_SAVE_PASS: survival resources and empty shelf flags round-trip through save file")
 quit()
