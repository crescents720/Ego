extends SceneTree
var main
var state
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> bool:
 if ok:return true
 push_error("PERSONAL_UI_FAIL: "+message)
 paused=false
 quit(1)
 return false
func send_mouse(point: Vector2,pressed: bool) -> void:
 var event:=InputEventMouseButton.new()
 event.button_index=MOUSE_BUTTON_LEFT
 event.pressed=pressed
 event.position=point
 Input.parse_input_event(event)
 await process_frame
 await process_frame
func drag_mouse(from: Vector2,to: Vector2) -> void:
 var hover:=InputEventMouseMotion.new()
 hover.position=from
 Input.parse_input_event(hover)
 await process_frame
 await send_mouse(from,true)
 var motion:=InputEventMouseMotion.new()
 motion.button_mask=MOUSE_BUTTON_MASK_LEFT
 motion.position=from+Vector2(18,0)
 motion.relative=Vector2(18,0)
 Input.parse_input_event(motion)
 await process_frame
 await process_frame
 motion=InputEventMouseMotion.new()
 motion.button_mask=MOUSE_BUTTON_MASK_LEFT
 motion.position=to
 motion.relative=to-from
 Input.parse_input_event(motion)
 await process_frame
 await process_frame
 await send_mouse(to,false)
func run() -> void:
 root.size=Vector2i(720,1280)
 root.content_scale_size=Vector2i(720,1280)
 main=load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 state=root.get_node("GameState")
 state.suppress_save=true
 main._start_new_game()
 var ui=main.equipment_screen
 if not check(state.items.is_empty() and state.carried_grams()==0,"casual outfit is not inventory"):return
 for slot in state.equipment:
  if not check(state.equipment[slot]=="","all slots initially empty"):return
 if not check(not main.objective_label.visible and not main.status_label.visible and not main.speed_label.visible,"old status labels removed"):return
 main.hotaru.take_damage(3)
 if not check(ui.health_state=="hurt" and ui.health_bar.value==2,"yellow hurt face and bar"):return
 main.hotaru.take_damage(1)
 if not check(ui.health_state=="critical" and ui.health_bar.value==1,"red critical face and bar"):return
 main._start_new_game()
 if not check(ui.health_state=="healthy" and ui.health_bar.value==5,"new game restores green healthy face"):return

 # Open by an actual avatar mouse click while outside.
 await process_frame
 await create_timer(0.2).timeout
 var hover:=InputEventMouseMotion.new()
 hover.position=Vector2(72,72)
 Input.parse_input_event(hover)
 await process_frame
 await send_mouse(Vector2(72,72),true)
 await send_mouse(Vector2(72,72),false)
 if not check(ui.panel.visible and paused,"avatar click opens personal panel outdoors"):return
 if not check(ui.panel.find_children("*cargo*","",true,false).is_empty(),"no RV cargo UI"):return
 ui.close()
 main.hotaru.global_position=main.rv.get_disembark_position()
 main._enter_rv_interior()
 await create_timer(.6).timeout
 main.hotaru.global_position=main.RV_INTERIOR_ORIGIN+Vector3(-.1,1.13,-3.13)
 main._interact()
 if not check(main.dialog_item_image.visible and main.dialog_item_image.texture!=null,"wardrobe pickup includes bat picture"):return
 main._take_starter_bat()
 if not check(state.items.get("bat",0)==1 and state.weapon_hand().is_empty() and main.hotaru._weapon_hand.is_empty(),"pickup stays in backpack unarmed"):return
 ui.avatar.pressed.emit()
 await process_frame
 await process_frame
 var tile=ui.item_list.get_child(0)
 var start: Vector2=tile.get_global_rect().get_center()
 var target: Vector2=ui.slot_buttons.right_hand.get_global_rect().get_center()
 await drag_mouse(start,target)
 if not check(state.equipment.right_hand=="bat" and main.hotaru._weapon_hand=="R","native mouse drag equips right hand"):return
 if not check(ui.slot_buttons.right_hand.text.is_empty() and ui.slot_buttons.right_hand.image.texture!=null,"equipped slot uses picture, no text"):return
 var data:={"kind":"personal_item","id":"bat","source_slot":"right_hand"}
 if not check(not ui.equip_drop("head",data) and state.equipment.right_hand=="bat","wrong slot drop preserves item"):return
 # A phone drag moves the actual item from right to left hand.
 var touch:=InputEventScreenTouch.new()
 touch.index=0;touch.pressed=true;touch.position=target
 ui._input(touch)
 var slide:=InputEventScreenDrag.new()
 slide.index=0;slide.position=ui.slot_buttons.left_hand.get_global_rect().get_center()
 ui._input(slide)
 touch=InputEventScreenTouch.new()
 touch.index=0;touch.pressed=false;touch.position=slide.position
 ui._input(touch)
 if not check(state.equipment.left_hand=="bat" and state.equipment.right_hand=="" and state.carried_grams()==900,"phone drag swaps hands without duplication or weight change"):return
 ui.select_slot("left_hand")
 if not check(ui.detail.text.contains("哥哥的棒球棍"),"click icon reveals item description"):return
 state.unequip_item("left_hand")
 ui.close()
 # Storage furniture never opens the equipment screen.
 main.hotaru.global_position=main.RV_INTERIOR_ORIGIN+main.RVInteriorController.INTERACTIVE_MODULES.storage.anchor
 main._interact()
 if not check(not ui.panel.visible,"furniture is not equipment entry"):return
 main._close_dialog_and_resume()
 if not check(state.try_add_items({"water":18}) and state.carried_grams()==9900 and not state.try_add_items({"water":1}),"personal 10kg limit remains enforced"):return
 print("PERSONAL_UI_PASS: actual outdoor avatar click; HP faces; no cargo/clothes; pickup picture; bag first; native mouse and phone drag; invalid drop; icon descriptions; no furniture entry; weight")
 quit()



