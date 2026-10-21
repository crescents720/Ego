extends Control

const RADIUS:=100.0
const CENTER:=Vector2(120,120)
const DEAD_ZONE:=0.15
var main
var mobile:=false
var finger: int=-1
var stick:=Vector2.ZERO
var action_touches: Dictionary={}

func setup(owner_main, force_mobile: bool=false) -> void:
 main=owner_main
 mobile=force_mobile or OS.has_feature("android") or DisplayServer.is_touchscreen_available()
 name="MobileJoystick"
 position=Vector2(28,1000)
 size=Vector2(240,240)
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 process_mode=Node.PROCESS_MODE_ALWAYS
 if mobile:
  # ScreenTouch is routed by finger ID, independently of the mouse-emulation
  # finger. This lets the other thumb press an action while steering.
  for button in _buttons():button.mouse_filter=Control.MOUSE_FILTER_IGNORE
 hide()

func _buttons() -> Array:
 var buttons: Array=[main.interact_button,main.attack_button,main.vehicle_button,main.upgrade_button]
 if is_instance_valid(main.trolley) and is_instance_valid(main.trolley.toggle_button):buttons.append(main.trolley.toggle_button);buttons.append(main.trolley.inventory_button)
 if is_instance_valid(main.test_settings):buttons.append(main.test_settings.launch)
 if is_instance_valid(main.fabrication):buttons.append(main.fabrication.install_button)
 return buttons

func can_act() -> bool:
 if not mobile or not is_instance_valid(main) or get_tree().paused:return false
 if not main.controls_enabled or main.dialog_panel.visible:return false
 if main.phase in [main.Phase.TITLE,main.Phase.GAME_OVER,main.Phase.COMPLETE]:return false
 if is_instance_valid(main.opening) and main.opening.is_cinematic():return false
 if is_instance_valid(main.service) and main.service.active:return false
 if is_instance_valid(main.sleep_controller) and main.sleep_controller.sleeping:return false
 return true

func can_control() -> bool:
 return can_act() and not main.in_vehicle and not main.seated_at_driver and main.hotaru.active

func _process(_delta: float) -> void:
 visible=can_control()
 if not visible:reset_stick()
 if not can_act():action_touches.clear()

func _input(event: InputEvent) -> void:
 if not mobile:return
 if event is InputEventMouse and event.device==InputEvent.DEVICE_ID_EMULATION:
  # Paused modal screens must receive their normal emulated mouse clicks.
  if not can_act():return
  if finger!=-1 or not action_touches.is_empty() or get_global_rect().has_point(event.position):
   get_viewport().set_input_as_handled()
  return
 if event is InputEventScreenTouch:
  if not event.pressed:
   if event.index==finger:
    reset_stick()
    get_viewport().set_input_as_handled()
   elif action_touches.has(event.index):
    var button: Button=action_touches[event.index]
    action_touches.erase(event.index)
    get_viewport().set_input_as_handled()
    if can_act() and is_instance_valid(button) and button.is_visible_in_tree() and not button.disabled and button.get_global_rect().has_point(event.position):
     button.pressed.emit()
    if not can_act():reset()
   return
  if not can_act():return
  var local: Vector2=get_global_transform_with_canvas().affine_inverse()*event.position
  if can_control() and finger==-1 and local.distance_to(CENTER)<=RADIUS+22:
   finger=event.index
   update_stick(local)
   get_viewport().set_input_as_handled()
   return
  for button in _buttons():
   if button.is_visible_in_tree() and not button.disabled and button.get_global_rect().has_point(event.position):
    action_touches[event.index]=button
    get_viewport().set_input_as_handled()
    return
 elif event is InputEventScreenDrag and event.index==finger:
  if can_control():update_stick(get_global_transform_with_canvas().affine_inverse()*event.position)
  else:reset()
  get_viewport().set_input_as_handled()

func update_stick(local: Vector2) -> void:
 stick=((local-CENTER)/RADIUS).limit_length(1)
 var strength:=clampf((stick.length()-DEAD_ZONE)/(1-DEAD_ZONE),0,1)
 var direction:=stick.normalized()*strength
 main.hotaru.touch_move=Vector2(direction.x,-direction.y)
 main.rv.touch_move=main.hotaru.touch_move
 queue_redraw()

func reset_stick() -> void:
 finger=-1
 stick=Vector2.ZERO
 if is_instance_valid(main):
  if is_instance_valid(main.hotaru):main.hotaru.touch_move=Vector2.ZERO
  if is_instance_valid(main.rv):main.rv.touch_move=Vector2.ZERO
 queue_redraw()

func reset() -> void:
 reset_stick()
 action_touches.clear()

func _notification(what: int) -> void:
 if what in [NOTIFICATION_WM_WINDOW_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED]:reset()

func _exit_tree() -> void:reset()

func _draw() -> void:
 draw_circle(CENTER,RADIUS+10,Color("182e38b0"))
 draw_arc(CENTER,RADIUS+10,0,TAU,64,Color("d4c58d99"),3,true)
 draw_arc(CENTER,55,0,TAU,48,Color("c4d7d52d"),1.5,true)
 for direction in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT]:
  var point: Vector2=CENTER+direction*83
  var side: Vector2=direction.orthogonal()*6
  draw_colored_polygon(PackedVector2Array([point+direction*6,point-direction*4+side,point-direction*4-side]),Color("fff1c2a0"))
 var knob:=CENTER+stick*65
 draw_circle(knob,40,Color("537a82e8") if finger!=-1 else Color("3b5a65d9"))
 draw_arc(knob,40,0,TAU,48,Color("eee0ada6"),2,true)
