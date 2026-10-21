extends CanvasLayer
var main
var sleeping:=false
var remaining:=0.0
var elapsed:=0.0
var veil: ColorRect
var title: Label
var info: Label
var hours: SpinBox
var actions: HBoxContainer
var box: VBoxContainer
var _position:=Vector3.ZERO
var _scale:=1.0
var _paused:=false
var _camera_focus: Variant
func build(owner_main) -> void:
 main=owner_main
 layer=42
 process_mode=Node.PROCESS_MODE_ALWAYS
 veil=ColorRect.new()
 veil.color=Color(.025,.04,.06,.78)
 veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 add_child(veil)
 box=VBoxContainer.new()
 box.position=Vector2(65,390)
 box.size=Vector2(590,400)
 box.add_theme_constant_override("separation",24)
 veil.add_child(box)
 title=Label.new()
 title.text="在床上休息"
 title.add_theme_font_size_override("font_size",32)
 box.add_child(title)
 info=Label.new()
 info.custom_minimum_size=Vector2(590,130)
 info.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 info.add_theme_font_size_override("font_size",23)
 box.add_child(info)
 hours=SpinBox.new()
 hours.min_value=1
 hours.max_value=24
 hours.value=12
 hours.custom_minimum_size=Vector2(0,65)
 hours.suffix="游戏小时"
 hours.add_theme_font_size_override("font_size",26)
 box.add_child(hours)
 hours.value_changed.connect(func(_v):update_info())
 actions=HBoxContainer.new()
 actions.add_theme_constant_override("separation",14)
 box.add_child(actions)
 _button("睡半天",func():begin(180))
 _button("睡一天",func():begin(360))
 _button("按所选时长",func():begin(hours.value*15))
 var cancel:=Button.new()
 cancel.text="取消 / 起床"
 cancel.custom_minimum_size=Vector2(0,65)
 main._style_button(cancel,Color("4a4243"))
 box.add_child(cancel)
 cancel.pressed.connect(func():
  if sleeping:stop("已经起床。")
  else:veil.hide();get_tree().paused=_paused
 )
 main.rv.hostile_attack.connect(func():
  if sleeping:stop("丧尸正在攻击房车，休息被中断！")
 )
 veil.hide()
func _button(text_value: String,callback: Callable) -> void:
 var button:=Button.new()
 button.text=text_value
 button.custom_minimum_size=Vector2(183,65)
 main._style_button(button,Color("37524f"))
 button.pressed.connect(callback)
 actions.add_child(button)
func reason() -> String:
 if not main.inside_rv or main.seated_at_driver or main.rv.wrecked:return "请先在房车床边休息。"
 if main.is_under_attack():return "房车正在受到攻击，暂时无法睡眠。"
 if int(GameState.cargo.get("water",0))<=0 or int(GameState.cargo.get("food",0))<=0:return "车内食物或饮水已耗尽，请先存入补给。"
 return ""
func open() -> void:
 _paused=get_tree().paused
 veil.show()
 title.text="在床上休息"
 box.position.y=390
 hours.show()
 actions.show()
 update_info()
 get_tree().paused=true
func update_info() -> void:
 var blocked:=reason()
 info.text=blocked if not blocked.is_empty() else "选择时长，世界和尸群会一起快进。\n半天恢复 50% HP，一天恢复 100% HP。\n遇袭或车内食水耗尽会立即起床。"
 for button in actions.get_children():button.disabled=not blocked.is_empty()
func begin(seconds: float) -> bool:
 if not reason().is_empty():update_info();return false
 get_tree().paused=false
 sleeping=true
 remaining=seconds
 elapsed=0
 _scale=Engine.time_scale
 Engine.time_scale=30.0
 _position=main.hotaru.global_position
 _camera_focus=main._interior_camera_focus_override
 main._interior_camera_focus_override=main.RV_INTERIOR_ORIGIN+Vector3(0,.95,2.5)
 main.controls_enabled=false
 main.hotaru.cancel_boarding_step()
 main.hotaru.set_active(false)
 main.hotaru.sleeping=true
 main.hotaru.global_position=main.RV_INTERIOR_ORIGIN+Vector3(0,2.0,3.4)
 main.hotaru.rotation.y=0
 for side in main.hotaru._bat_attachments:main.hotaru._bat_attachments[side].hide()
 for label in main.hotaru.find_children("*","Label3D",true,false):label.hide()
 main.hotaru._play_character_animation("Sleep",true)
 veil.color=Color(.025,.04,.06,.20)
 hours.hide()
 actions.hide()
 box.position.y=700
 title.text="蛍正在休息"
 info.text="时间正在快进……"
 return true
func limit_delta(delta: float) -> float:
 if not sleeping:return delta
 if not reason().is_empty():stop(reason());return 0
 var water_time: float=GameState.water*GameState.WATER_INTERVAL-GameState.water_clock
 var food_time: float=GameState.food*GameState.FOOD_INTERVAL-GameState.food_clock
 return maxf(0,minf(delta,minf(remaining,minf(water_time,food_time))))
func advance(delta: float) -> void:
 if not sleeping:return
 elapsed+=delta
 remaining=maxf(0,remaining-delta)
 main.hotaru.health=minf(main.hotaru.max_health,main.hotaru.health+delta/360.0*main.hotaru.max_health)
 main.hotaru.health_changed.emit(main.hotaru.health,main.hotaru.max_health)
 info.text="已休息 %.1f 游戏小时\n生命 %.0f%% · 剩余 %.1f 游戏小时"%[elapsed/15.0,main.hotaru.health/main.hotaru.max_health*100,remaining/15.0]
 if remaining<=0.00001:stop("休息结束。")
 elif not reason().is_empty():stop(reason())
func stop(message: String) -> void:
 if not sleeping:return
 sleeping=false
 Engine.time_scale=_scale
 main.hotaru.sleeping=false
 main.hotaru.global_position=_position
 main._interior_camera_focus_override=_camera_focus
 main.hotaru._current_animation_state=""
 main.hotaru.sync_equipment()
 if not main.hotaru.dead:
  for label in main.hotaru.find_children("*","Label3D",true,false):label.show()
  main.controls_enabled=true
  main.hotaru.set_active(true)
 veil.hide()
 veil.color=Color(.025,.04,.06,.78)
 main.hint_label.text=message
 main.rest_notice(message)
func _exit_tree() -> void:
 if sleeping:Engine.time_scale=_scale

func _process(_delta: float) -> void:
 if veil.visible and not sleeping:update_info()
