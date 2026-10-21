extends CanvasLayer
var main
var launch: Button
var veil: ColorRect
var panel: PanelContainer
var fuel_value: Label
var water_value: Label
var food_value: Label
var fuel_estimate: Label
var water_estimate: Label
var food_estimate: Label
var fuel_bar: ProgressBar
var cargo_bar: ProgressBar
var cargo_value: Label
var clock_value: Label
var rows: GridContainer
var status: Label
var _paused_before:=false
var _refresh_clock:=0.0

func build(owner_main) -> void:
 main=owner_main
 layer=24
 process_mode=Node.PROCESS_MODE_ALWAYS
 launch=Button.new()
 launch.text="房车管理"
 launch.position=Vector2(28,170)
 launch.size=Vector2(182,52)
 main._style_button(launch,Color("304a50"))
 main.get_node("HUD").add_child(launch)
 launch.pressed.connect(open)
 veil=ColorRect.new()
 veil.color=Color(0.02,0.05,0.07,0.88)
 veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 add_child(veil)
 panel=PanelContainer.new()
 panel.position=Vector2(22,100)
 panel.size=Vector2(676,1060)
 var style:=StyleBoxFlat.new()
 style.bg_color=Color("17282d")
 style.border_color=Color("668781")
 style.set_border_width_all(2)
 style.set_corner_radius_all(22)
 for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:style.set_content_margin(side,24)
 panel.add_theme_stylebox_override("panel",style)
 veil.add_child(panel)
 var column:=VBoxContainer.new()
 column.add_theme_constant_override("separation",12)
 panel.add_child(column)
 var header:=HBoxContainer.new()
 column.add_child(header)
 var title:=_label("房车管理",28)
 title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 header.add_child(title)
 header.add_child(_button("关闭 ×",close,Vector2(105,46)))
 column.add_child(_label("生存储备",21,Color("9bbcb6")))
 var cards:=HBoxContainer.new()
 cards.add_theme_constant_override("separation",12)
 column.add_child(cards)
 fuel_value=_card(cards,"燃油",Color("edc778"))
 water_value=_card(cards,"车存饮水",Color("8dd4de"))
 food_value=_card(cards,"车存食物",Color("b7d39c"))
 fuel_estimate=_label("",16,Color("91aaa2"))
 water_estimate=_label("",16,Color("91aaa2"))
 food_estimate=_label("",16,Color("91aaa2"))
 fuel_value.get_parent().add_child(fuel_estimate)
 water_value.get_parent().add_child(water_estimate)
 food_value.get_parent().add_child(food_estimate)
 fuel_bar=ProgressBar.new()
 fuel_bar.custom_minimum_size=Vector2(0,12)
 fuel_bar.max_value=60
 fuel_bar.show_percentage=false
 column.add_child(fuel_bar)
 column.add_child(_label("燃油 1 L / km  ·  油箱 60 L\n每日需要 5 L 水和 1 kg 面包",19,Color("c8d5cd")))
 clock_value=_label("",18,Color("91b7b5"))
 column.add_child(clock_value)
 column.add_child(HSeparator.new())
 cargo_value=_label("",23)
 column.add_child(cargo_value)
 cargo_bar=ProgressBar.new()
 cargo_bar.max_value=1000
 cargo_bar.show_percentage=false
 cargo_bar.custom_minimum_size=Vector2(0,18)
 column.add_child(cargo_bar)
 column.add_child(_label("货舱物品",20,Color("9bbcb6")))
 var scroll:=ScrollContainer.new()
 scroll.custom_minimum_size=Vector2(0,260)
 scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
 scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 column.add_child(scroll)
 rows=GridContainer.new()
 rows.columns=5
 rows.add_theme_constant_override("h_separation",10)
 rows.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 rows.add_theme_constant_override("separation",10)
 scroll.add_child(rows)
 var actions:=HBoxContainer.new()
 column.add_child(actions)
 actions.add_child(_button("货物整理",func():main.cargo_organizer.open(),Vector2(310,50)))
 actions.add_child(_button("保存进度",save_progress,Vector2(140,50)))
 var cart_button:=_button("使用推车 / 下车时自动部署",func():
  if not GameState.cart_owned:status.text="先去武器店取得推车。";return
  if GameState.cart_deployed:status.text="推车已在外面，请走到推车旁推回车门收起。";return
  GameState.cart_use_on_exit=not GameState.cart_use_on_exit
  status.text="下车时自动部署推车："+("开启" if GameState.cart_use_on_exit else "关闭")
 ,Vector2(580,46))
 column.add_child(cart_button)
 status=_label("点击物品查看说明，存取与丢弃请打开货物整理。",18,Color("b5c3ba"))
 status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 status.custom_minimum_size=Vector2(0,72)
 column.add_child(status)
 column.add_child(HSeparator.new())
 column.add_child(_label("后续改装空间",20,Color("9bbcb6")))
 column.add_child(_label("生产模块   ·   舱体扩展   ·   动力升级\n尚未安装  /  后续开放",19,Color("7c9694")))
 veil.hide()

func _label(text_value: String,font: int,color: Color=Color("e9e8d7")) -> Label:
 var label:=Label.new()
 label.text=text_value
 label.add_theme_font_size_override("font_size",font)
 label.add_theme_color_override("font_color",color)
 return label

func _button(text_value: String,callback: Callable,minimum: Vector2) -> Button:
 var button:=Button.new()
 button.text=text_value
 button.custom_minimum_size=minimum
 button.add_theme_font_size_override("font_size",18)
 main._style_button(button,Color("30494b"))
 button.pressed.connect(callback)
 return button

func _card(parent: HBoxContainer,title: String,color: Color) -> Label:
 var box:=VBoxContainer.new()
 box.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 box.custom_minimum_size=Vector2(0,100)
 parent.add_child(box)
 box.add_child(_label(title,18,color))
 var value:=_label("",28,color)
 box.add_child(value)
 return value

func _process(delta: float) -> void:
 if not is_instance_valid(main):return
 launch.visible=not (is_instance_valid(main.shooting) and main.shooting.active) and (main.in_vehicle or main.inside_rv) and main.phase!=main.Phase.GAME_OVER and not main.dialog_panel.visible
 if veil.visible:
  _refresh_clock+=delta
  if _refresh_clock>.25:
   _refresh_clock=0
   refresh(false)

func open() -> void:
 if not (main.in_vehicle or main.inside_rv) or main.hotaru.dead:return
 for action in ["move_forward","move_backward","move_left","move_right"]:Input.action_release(action)
 _paused_before=get_tree().paused
 veil.show()
 refresh()
 get_tree().paused=true

func close() -> void:
 if not veil.visible:return
 veil.hide()
 get_tree().paused=_paused_before

func deposit() -> void:
 var moved: int=GameState.deposit_all()
 status.text="已存入 %d 件物资。"%moved if moved>0 else "没有可存入的物品，或货舱空间不足。"
 if is_instance_valid(main.supply_quest):main.supply_quest.check_delivery()
 refresh()

func transfer(id: String,to_cargo: bool) -> void:
 var ok: bool=GameState.store_item(id) if to_cargo else GameState.retrieve_item(id)
 status.text="已存入房车。" if ok and to_cargo else ("已放入随身背包。" if ok else "无法转移：检查负重、货舱空间及装备状态。")
 if is_instance_valid(main.supply_quest):main.supply_quest.check_delivery()
 refresh()

func refresh(rebuild: bool=true) -> void:
 fuel_value.text="%.2f L"%GameState.fuel_l
 var stored_water: int=int(GameState.cargo.get("water",0))
 var stored_food: int=int(GameState.cargo.get("food",0))
 water_value.text="%.1f L"%maxf(0,stored_water*5.0-(GameState.water_clock/360.0*5.0 if int(GameState.items.get("water",0))==0 else 0.0))
 food_value.text="%.1f kg"%maxf(0,stored_food*0.5-(GameState.food_clock/180.0*0.5 if int(GameState.items.get("food",0))==0 else 0.0))
 fuel_estimate.text="约可行驶 %.1f km"%GameState.fuel_l
 water_estimate.text="约可维持 %.0f 分钟"%maxf(0,(stored_water*GameState.WATER_INTERVAL-GameState.water_clock)/60)
 food_estimate.text="约可维持 %.0f 分钟"%maxf(0,(stored_food*GameState.FOOD_INTERVAL-GameState.food_clock)/60)
 fuel_bar.value=GameState.fuel_l
 cargo_value.text="货舱 %.2f / 1000 kg  ·  剩余 %.2f kg"%[GameState.cargo_grams()/1000.0,(GameState.CARGO_CAPACITY_G-GameState.cargo_grams())/1000.0]
 cargo_bar.value=GameState.cargo_grams()/1000.0
 clock_value.text="第 %d 天 · %s  /  每天 6 分钟（白昼、夜晚各 3 分钟）\n累计行驶 %.0f m · 菜单暂停时间"%[int(GameState.world_seconds/360)+1,"夜晚" if GameState.is_night() else "白昼",GameState.distance_m]
 if not rebuild:return
 for child in rows.get_children():rows.remove_child(child);child.queue_free()
 var ids: Array=GameState.cargo.keys()
 for i in range(maxi(10,ids.size())):
  var tile:=Button.new()
  tile.custom_minimum_size=Vector2(104,110)
  main._style_button(tile,Color("2b4145"))
  rows.add_child(tile)
  if i>=ids.size():continue
  var id: String=ids[i]
  var icon:=TextureRect.new()
  icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
  icon.position=Vector2(12,8)
  icon.size=Vector2(80,74)
  icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
  icon.texture=main.equipment_screen.item_texture(id)
  icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
  tile.add_child(icon)
  var count:=_label("%d%s"%[int(GameState.cargo[id]),"桶" if id=="water" else ("包" if id=="food" else ("发" if id=="m60_ammo" else "件"))],18)
  count.position=Vector2(2,83)
  count.size=Vector2(96,24)
  count.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
  count.mouse_filter=Control.MOUSE_FILTER_IGNORE
  tile.add_child(count)
  tile.pressed.connect(func():status.text=GameState.ITEMS[id].description)

func save_progress() -> void:
 main.save_slots.open("save")
