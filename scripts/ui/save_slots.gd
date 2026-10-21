extends CanvasLayer
var main
var veil: ColorRect
var heading: Label
var status: Label
var grid: GridContainer
var confirmation: Button
var mode:="save"
var pending:=0
var _paused:=false
func build(owner_main) -> void:
 main=owner_main
 layer=110
 process_mode=Node.PROCESS_MODE_ALWAYS
 veil=ColorRect.new()
 veil.color=Color("14262c")
 veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 add_child(veil)
 var column:=VBoxContainer.new()
 column.position=Vector2(42,155)
 column.size=Vector2(636,940)
 column.add_theme_constant_override("separation",22)
 veil.add_child(column)
 heading=Label.new()
 heading.add_theme_font_size_override("font_size",34)
 column.add_child(heading)
 status=Label.new()
 status.custom_minimum_size=Vector2(0,95)
 status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 status.add_theme_font_size_override("font_size",22)
 column.add_child(status)
 grid=GridContainer.new()
 grid.columns=2
 grid.add_theme_constant_override("h_separation",16)
 grid.add_theme_constant_override("v_separation",16)
 column.add_child(grid)
 confirmation=Button.new()
 confirmation.text="确认覆盖此存档"
 confirmation.custom_minimum_size=Vector2(0,65)
 main._style_button(confirmation,Color("685044"))
 confirmation.pressed.connect(func():write_slot(pending))
 column.add_child(confirmation)
 var close_button:=Button.new()
 close_button.text="返回"
 close_button.custom_minimum_size=Vector2(0,65)
 main._style_button(close_button,Color("36524e"))
 column.add_child(close_button)
 close_button.pressed.connect(close)
 veil.hide()
func open(value: String="save") -> bool:
 if value=="save" and not main.can_save_safely():
  main.rv_dashboard.status.text="正受到攻击或正在休息，无法存档。"
  main.rest_notice("受到攻击时不能存档。")
  return false
 mode=value
 _paused=get_tree().paused
 pending=0
 veil.show()
 get_tree().paused=true
 refresh()
 return true
func close() -> void:
 veil.hide()
 get_tree().paused=_paused
func refresh() -> void:
 heading.text="选择存档位" if mode=="save" else "读取存档"
 status.text="共六个存档位。1 号位同时接收安全状态下的自动存档。\n保存前必须没有敌人攻击。"
 confirmation.hide()
 for child in grid.get_children():grid.remove_child(child);child.queue_free()
 for index in range(1,7):
  var data: Dictionary=GameState.slot_info(index)
  var button:=Button.new()
  button.custom_minimum_size=Vector2(310,155)
  button.add_theme_font_size_override("font_size",22)
  main._style_button(button,Color("2c4649"))
  button.text="存档 %d%s\n"%[index," · 自动/手动" if index==1 else ""]
  if data.is_empty():button.text+="空存档"
  else:
   button.text+="第 %d 天  ·  HP %.0f%%\n燃油 %.1f L"%[data.day,data.health*100,data.fuel]
   if data.saved>0:button.text+="\n"+Time.get_datetime_string_from_unix_time(data.saved+8*3600).replace("T"," ")
  button.disabled=mode=="load" and data.is_empty()
  button.pressed.connect(func():select_slot(index))
  grid.add_child(button)
func select_slot(index: int) -> void:
 if mode=="load":
  close()
  main.rv_dashboard.close()
  get_tree().paused=false
  main._load_completed_save(GameState.slot_path(index))
 elif not GameState.slot_info(index).is_empty():
  pending=index
  status.text="将覆盖存档 %d。确认后保存当前状态。"%index
  confirmation.show()
 else:write_slot(index)
func write_slot(index: int) -> void:
 if not main.can_save_safely():status.text="敌人正在攻击，未保存。";return
 GameState.vehicle_position=main.rv.global_position
 GameState.vehicle_yaw=main.rv.rotation.y
 var result: Error=GameState.save_game(GameState.slot_path(index))
 AudioDirector.ui("complete" if result==OK else "reject")
 refresh()
 status.text="已保存到存档 %d。"%index if result==OK else "保存失败：%s"%error_string(result)
