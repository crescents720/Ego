extends SceneTree
var errors:=0
func _initialize() -> void:call_deferred("run")
func click(point: Vector2) -> void:
 var hover:=InputEventMouseMotion.new()
 hover.position=point
 Input.parse_input_event(hover)
 await process_frame
 for pressed in [true,false]:
  var e:=InputEventMouseButton.new()
  e.button_index=MOUSE_BUTTON_LEFT
  e.pressed=pressed
  e.position=point
  Input.parse_input_event(e)
  await process_frame
  await process_frame
func check(ok: bool,message: String) -> void:
 if not ok:push_error(message);errors+=1
func run() -> void:
 root.size=Vector2i(720,1280)
 root.content_scale_size=root.size
 var main=load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 var state=root.get_node("GameState")
 state.suppress_save=true
 main._start_new_game()
 main.hotaru.global_position=main.rv.get_disembark_position()
 main._enter_rv_interior()
 main.hotaru.global_position=main.rv_interior.get_driver_stand_position()
 main._interact()
 await create_timer(.25).timeout
 var ui=main.rv_dashboard
 check(ui.launch.visible,"Dashboard option missing while seated")
 await click(ui.launch.get_global_rect().get_center())
 check(ui.veil.visible and paused,"Native click did not open dashboard")
 check(ui.panel.get_global_rect().end.y<=1280,"Dashboard overflows portrait screen")
 state.try_add_items({"food":2,"water":2})
 ui.refresh()
 await process_frame
 var food_row: HBoxContainer=ui.rows.get_child(1)
 var food_store: Button=food_row.get_child(2)
 await click(food_store.get_global_rect().get_center())
 check(state.cargo.get("food",0)==1 and state.items.get("food",0)==1,"Click did not deposit the correct item")
 await process_frame
 food_row=ui.rows.get_child(1)
 var food_take: Button=food_row.get_child(3)
 await click(food_take.get_global_rect().get_center())
 check(state.cargo.get("food",0)==0 and state.items.get("food",0)==2,"Click did not retrieve the correct item")
 var close_button: Button=ui.panel.get_child(0).get_child(0).get_child(1)
 await click(close_button.get_global_rect().get_center())
 check(not paused and not ui.veil.visible,"Close button did not resume game")
 print("DASHBOARD_NATIVE_UI_CHECK errors=",errors)
 quit(0 if errors==0 else 1)
