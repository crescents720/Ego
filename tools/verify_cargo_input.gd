extends SceneTree
var errors:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
 if not ok:push_error(message);errors+=1
func mouse(point: Vector2,pressed: bool) -> void:
 var e:=InputEventMouseButton.new()
 e.position=point
 e.button_index=MOUSE_BUTTON_LEFT
 e.pressed=pressed
 Input.parse_input_event(e)
 for i in range(2):await process_frame
func drag(from: Vector2,to: Vector2,touch: bool=false) -> void:
 if touch:
  var down:=InputEventScreenTouch.new()
  down.index=0
  down.position=from
  down.pressed=true
  Input.parse_input_event(down)
  await process_frame
  var move:=InputEventScreenDrag.new()
  move.index=0
  move.position=to
  move.relative=to-from
  Input.parse_input_event(move)
  await process_frame
  down=InputEventScreenTouch.new()
  down.index=0
  down.position=to
  down.pressed=false
  Input.parse_input_event(down)
 else:
  var hover:=InputEventMouseMotion.new()
  hover.position=from
  Input.parse_input_event(hover)
  await process_frame
  await mouse(from,true)
  var move:=InputEventMouseMotion.new()
  move.position=from+Vector2(24,0)
  move.relative=Vector2(24,0)
  move.button_mask=MOUSE_BUTTON_MASK_LEFT
  Input.parse_input_event(move)
  await process_frame
  move=InputEventMouseMotion.new()
  move.position=to
  move.relative=to-from
  move.button_mask=MOUSE_BUTTON_MASK_LEFT
  Input.parse_input_event(move)
  await process_frame
  await mouse(to,false)
 for i in range(4):await process_frame
func tile(grid,id: String) -> Vector2:
 for item in grid.get_children():
  if item.item_id==id:return item.get_global_rect().get_center()
 return Vector2.ZERO
func run() -> void:
 root.size=Vector2i(720,1280)
 root.content_scale_size=root.size
 var main=load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 var state=root.get_node("GameState")
 state.suppress_save=true
 main._start_new_game()
 main.set_process(false)
 main.hotaru.set_active(false)
 state.items={"food":2,"bat":1}
 state.cargo={"food":4,"water":2}
 state.equipment.right_hand="bat"
 state._sync_resources()
 main.cargo_organizer.open()
 for i in range(6):await process_frame
 var ui=main.cargo_organizer
 await drag(tile(ui.bag_grid,"food"),ui.cargo_grid.get_global_rect().get_center())
 check(state.items.food==1 and state.cargo.food==5,"Native mouse drag failed to store one pack")
 await drag(tile(ui.cargo_grid,"water"),ui.bag_grid.get_global_rect().get_center(),true)
 check(state.items.get("water",0)==1 and state.cargo.water==1,"Touch drag failed to retrieve bucket")
 await drag(tile(ui.cargo_grid,"water"),ui.bag_grid.get_global_rect().get_center(),true)
 check(state.cargo.water==1,"Overweight touch drop lost cargo")
 await drag(tile(ui.bag_grid,"food"),ui._zones.trash.get_global_rect().get_center(),true)
 check(not state.items.has("food"),"Touch discard failed")
 await drag(tile(ui.bag_grid,"bat"),ui._zones.trash.get_global_rect().get_center(),true)
 check(state.items.bat==1,"Equipped bat could be discarded")
 ui.close()
 check(not paused,"Organizer failed to restore pause state")
 main.quantity_picker.open("food")
 main.quantity_picker.amount.value=2
 main.quantity_picker.take()
 check(state.items.food==2 and not main.quantity_picker.info.text.contains("剩余"),"Quantity menu failed to take chosen count")
 print("CARGO_NATIVE_INPUT_CHECK errors=",errors)
 quit(0 if errors==0 else 1)
