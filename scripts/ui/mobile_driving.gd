extends Control
var main
var buttons: Dictionary={}
var fingers: Dictionary={}
var touch_groups: Dictionary={}
var gear:=1
var last_driving:=false
func build(owner_main) -> void:
 main=owner_main;process_mode=Node.PROCESS_MODE_ALWAYS
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mouse_filter=Control.MOUSE_FILTER_IGNORE
 for data in [["left","左转",Vector2(28,1080),Vector2(132,140)],["right","右转",Vector2(180,1080),Vector2(132,140)],["brake","刹车",Vector2(370,1080),Vector2(130,140)],["gas","油门",Vector2(530,1080),Vector2(162,140)],["gear","D 前进",Vector2(370,980),Vector2(130,72)]]:
  var b:=Button.new();b.text=data[1];b.position=data[2];b.size=data[3];b.focus_mode=Control.FOCUS_NONE;b.mouse_filter=Control.MOUSE_FILTER_IGNORE
  main._style_button(b,Color("365650") if data[0]!="brake" else Color("705144"));add_child(b);buttons[data[0]]=b
 hide()
func available() -> bool:
 return main.mobile_joystick.mobile and main.in_vehicle and not main.inside_rv and main.mobile_joystick.can_act() and not main.rv.wrecked
func update_layout() -> void:
 var driving: bool=main.mobile_joystick.mobile and main.in_vehicle
 if driving:
  for b in [main.interact_button,main.attack_button,main.upgrade_button,main.trolley.toggle_button,main.trolley.inventory_button,main.fabrication.install_button]:b.hide()
  for b in get_tree().get_nodes_in_group("movement_controls"):b.hide()
  main.vehicle_button.position=Vector2(530,980);main.vehicle_button.size=Vector2(162,72)
  if available():main.hint_label.text="左手转向 · 右手油门/刹车 · 停稳后切换 D/R"
 elif last_driving:
  main.vehicle_button.position=Vector2(540,1010);main.vehicle_button.size=Vector2(140,82)
  gear=1
 last_driving=driving
 visible=available()
 if not visible:reset()
func _process(_delta: float) -> void:
 update_layout()
 if visible:_apply()
func reset() -> void:
 fingers.clear();touch_groups.clear()
 if main.rv.touch_driving:main.rv.clear_touch_drive()
 for b in buttons.values():b.modulate=Color.WHITE
func _apply() -> void:
 var left:=false;var right:=false;var gas:=false;var brake:=false
 for action in fingers.values():
  left=left or action=="left";right=right or action=="right";gas=gas or action=="gas";brake=brake or action=="brake"
 main.rv.set_touch_drive(float(int(right)-int(left)),1.0 if gas and not brake else 0.0,brake,gear)
 for key in buttons:buttons[key].modulate=Color("f0d895") if fingers.values().has(key) else Color.WHITE
 buttons.gear.text="D 前进" if gear==1 else "R 倒车"
func shift() -> void:
 if absf(main.rv.speed)>.2:main.rest_notice("请先刹车停稳，再切换 D/R 挡。");return
 gear=-gear;main.rv.speed=0;fingers.clear();touch_groups.clear();_apply()
func _input(event: InputEvent) -> void:
 if event is InputEventScreenTouch and not event.pressed and fingers.has(event.index):
  var previous: String=fingers[event.index];fingers.erase(event.index);touch_groups.erase(event.index)
  if available():
   if previous=="gear" and buttons.gear.get_global_rect().has_point(event.position):shift()
   _apply()
  get_viewport().set_input_as_handled();return
 if not available():return
 if event is InputEventMouse and event.device==InputEvent.DEVICE_ID_EMULATION:
  for b in buttons.values():
   if b.get_global_rect().has_point(event.position):get_viewport().set_input_as_handled();return
 if event is InputEventScreenTouch and event.pressed:
  for key in buttons:
   if buttons[key].get_global_rect().has_point(event.position):fingers[event.index]=key;touch_groups[event.index]="steer" if key in ["left","right"] else ("gear" if key=="gear" else "pedal");_apply();get_viewport().set_input_as_handled();return
 elif event is InputEventScreenDrag and fingers.has(event.index):
  var previous: String=fingers[event.index]
  if previous!="gear":
   fingers[event.index]="none"
   for key in (["left","right"] if touch_groups.get(event.index,"")=="steer" else ["gas","brake"]):
    if buttons[key].get_global_rect().has_point(event.position):fingers[event.index]=key;break
   _apply()
  get_viewport().set_input_as_handled()
func _notification(what: int) -> void:
 if what in [NOTIFICATION_WM_WINDOW_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED] and is_instance_valid(main):reset()
