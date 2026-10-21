extends CanvasLayer
var main
var launch: Button
var veil: ColorRect
var code: LineEdit
var result: Label
var was_paused:=false
func build(owner_main) -> void:
 main=owner_main
 layer=125
 process_mode=Node.PROCESS_MODE_ALWAYS
 launch=Button.new()
 launch.expand_icon=true
 launch.icon=load("res://assets/ui/icons/settings.svg")
 launch.tooltip_text="设置 / 测试作弊码（Enter）"
 launch.position=Vector2(648,28)
 launch.size=Vector2(48,34)
 main._style_button(launch,Color("35434b"))
 main.get_node("HUD").add_child(launch)
 launch.pressed.connect(open)
 if main.mobile_joystick.mobile:launch.mouse_filter=Control.MOUSE_FILTER_IGNORE
 veil=ColorRect.new()
 veil.color=Color(.025,.045,.055,.97)
 veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 add_child(veil)
 var box:=VBoxContainer.new()
 box.position=Vector2(50,190)
 box.size=Vector2(620,450)
 box.add_theme_constant_override("separation",22)
 veil.add_child(box)
 var title:=Label.new()
 title.text="设置 · 作弊码测试"
 title.add_theme_font_size_override("font_size",32)
 box.add_child(title)
 var help:=Label.new()
 help.text="输入作弊码后点击确认，或按回车。\nshowmethemoney  =  现金 +10,000"
 help.add_theme_font_size_override("font_size",23)
 box.add_child(help)
 code=LineEdit.new()
 code.placeholder_text="输入作弊码"
 code.custom_minimum_size=Vector2(620,66)
 code.add_theme_font_size_override("font_size",26)
 code.max_length=80
 box.add_child(code)
 code.text_submitted.connect(func(_text):submit())
 result=Label.new()
 result.custom_minimum_size=Vector2(620,80)
 result.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 result.add_theme_font_size_override("font_size",24)
 box.add_child(result)
 var apply:=Button.new()
 apply.text="确认作弊码"
 apply.custom_minimum_size=Vector2(620,65)
 main._style_button(apply,Color("42615a"))
 box.add_child(apply)
 apply.pressed.connect(submit)
 var close_button:=Button.new()
 close_button.text="返回游戏"
 close_button.custom_minimum_size=Vector2(620,65)
 main._style_button(close_button,Color("35434b"))
 box.add_child(close_button)
 close_button.pressed.connect(close)
 veil.hide()
func available() -> bool:
 return main.controls_enabled and main.phase not in [main.Phase.TITLE,main.Phase.GAME_OVER,main.Phase.COMPLETE] and not main.dialog_panel.visible and not main.opening.is_cinematic()
func _process(_delta: float) -> void:
 launch.visible=available() and not get_tree().paused
func open() -> void:
 if veil.visible or get_tree().paused or not available():return
 was_paused=get_tree().paused
 main.mobile_joystick.reset()
 for action in ["move_forward","move_backward","move_left","move_right"]:Input.action_release(action)
 code.text=""
 result.text="当前现金：%d 元"%GameState.cash
 veil.show()
 get_tree().paused=true
 code.grab_focus()
func submit() -> void:
 if GameState.apply_cheat(code.text):
  result.text="现金 +10,000\n当前现金：%d 元"%GameState.cash
  code.clear()
 else:result.text="作弊码无效，请检查拼写。"
func close() -> void:
 if not veil.visible:return
 code.release_focus()
 DisplayServer.virtual_keyboard_hide()
 veil.hide()
 get_tree().paused=was_paused
 main.mobile_joystick.reset()
func _input(event: InputEvent) -> void:
 if not event is InputEventKey or not event.pressed or event.echo:return
 if event.keycode==KEY_ESCAPE and veil.visible:
  close()
  get_viewport().set_input_as_handled()
 elif event.keycode in [KEY_ENTER,KEY_KP_ENTER] and not veil.visible:
  open()
  if veil.visible:get_viewport().set_input_as_handled()
