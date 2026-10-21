extends SceneTree
var errors:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
 if not ok:push_error(message);errors+=1
func click(point: Vector2) -> void:
 var hover:=InputEventMouseMotion.new()
 hover.position=point
 Input.parse_input_event(hover)
 await process_frame
 for pressed in [true,false]:
  var event:=InputEventMouseButton.new()
  event.button_index=MOUSE_BUTTON_LEFT
  event.position=point
  event.pressed=pressed
  Input.parse_input_event(event)
  await process_frame
  await process_frame
func run() -> void:
 root.size=Vector2i(720,1280)
 root.content_scale_size=root.size
 var main=load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 var state=root.get_node("GameState")
 state.suppress_save=true
 main._start_new_game()
 main.set_process(false)
 main.zombie_population.set_process(false)
 for actor in get_nodes_in_group("zombies"):actor.queue_free()
 await physics_frame
 state.slot_directory="user://test_rest_six_slots"
 for index in range(1,7):
  if FileAccess.file_exists(state.slot_path(index)):DirAccess.remove_absolute(ProjectSettings.globalize_path(state.slot_path(index)))
 var ui=main.save_slots
 main.hotaru.health=3.0
 check(ui.open("save"),"Safe state did not open save slot page")
 for frame in range(5):await process_frame
 check(ui.grid.get_child_count()==6,"Slot selector does not have six slots")
 await click(ui.grid.get_child(5).get_global_rect().get_center())
 check(not state.slot_info(6).is_empty(),"Native click did not save selected slot")
 for index in range(1,6):ui.select_slot(index)
 for index in range(1,7):check(not state.slot_info(index).is_empty(),"Missing written slot "+str(index))
 main.hotaru.health=1.0
 ui.select_slot(6)
 check(ui.confirmation.visible and state.slot_info(6).health>.5,"Existing slot overwritten without confirmation")
 ui.confirmation.pressed.emit()
 check(absf(state.slot_info(6).health-.2)<.01,"Overwrite confirmation did not save updated HP")
 ui.close()
 ui.open("load")
 ui.select_slot(6)
 check(not paused and absf(main.hotaru.health-1.0)<.01,"Selected slot did not resume saved health")
 main.rv.mark_hostile_attack()
 check(not ui.open("save") and not ui.veil.visible,"Attacks do not block opening save selector")
 for index in range(1,7):DirAccess.remove_absolute(ProjectSettings.globalize_path(state.slot_path(index)))
 DirAccess.remove_absolute(ProjectSettings.globalize_path(state.slot_directory))
 state.slot_directory="user://saves"
 print("SIX_SLOT_NATIVE_UI_CHECK errors=",errors)
 quit(0 if errors==0 else 1)
