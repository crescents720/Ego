extends CanvasLayer
var main
var veil: ColorRect
var amount: SpinBox
var info: Label
var destination: OptionButton
var confirm: Button
var item_id:=""
var _was_paused:=false
func build(owner_main) -> void:
 main=owner_main
 layer=38
 process_mode=Node.PROCESS_MODE_ALWAYS
 veil=ColorRect.new()
 veil.color=Color(0.02,.04,.06,.88)
 veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 add_child(veil)
 var panel:=PanelContainer.new()
 panel.position=Vector2(60,360)
 panel.size=Vector2(600,500)
 var style:=StyleBoxFlat.new()
 style.bg_color=Color("23383c")
 style.set_corner_radius_all(18)
 for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:style.set_content_margin(side,28)
 panel.add_theme_stylebox_override("panel",style)
 veil.add_child(panel)
 var box:=VBoxContainer.new()
 box.add_theme_constant_override("separation",22)
 panel.add_child(box)
 var title:=Label.new()
 title.text="选择拿取数量"
 title.add_theme_font_size_override("font_size",30)
 box.add_child(title)
 info=Label.new()
 info.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 info.custom_minimum_size=Vector2(520,120)
 info.add_theme_font_size_override("font_size",23)
 box.add_child(info)
 destination=OptionButton.new()
 destination.add_item("放入随身背包 · 10 kg")
 destination.add_item("放入推车 · 25 kg")
 destination.add_theme_font_size_override("font_size",23)
 destination.item_selected.connect(func(_index):refresh())
 box.add_child(destination)
 var counter:=HBoxContainer.new()
 counter.add_theme_constant_override("separation",12)
 box.add_child(counter)
 var minus:=Button.new()
 minus.text="−"
 minus.custom_minimum_size=Vector2(80,64)
 main._style_button(minus,Color("355451"))
 counter.add_child(minus)
 amount=SpinBox.new()
 amount.min_value=0
 amount.step=1
 amount.custom_minimum_size=Vector2(0,64)
 amount.add_theme_font_size_override("font_size",28)
 amount.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 counter.add_child(amount)
 var plus:=Button.new()
 plus.text="+"
 plus.custom_minimum_size=Vector2(80,64)
 main._style_button(plus,Color("355451"))
 counter.add_child(plus)
 minus.pressed.connect(func():amount.value-=1)
 plus.pressed.connect(func():amount.value+=1)
 amount.value_changed.connect(func(_value):refresh())
 var row:=HBoxContainer.new()
 box.add_child(row)
 confirm=Button.new()
 confirm.text="放入随身背包"
 confirm.custom_minimum_size=Vector2(290,64)
 main._style_button(confirm,Color("355451"))
 row.add_child(confirm)
 confirm.pressed.connect(take)
 var cancel:=Button.new()
 cancel.text="先不拿"
 cancel.custom_minimum_size=Vector2(180,64)
 main._style_button(cancel,Color("3b494d"))
 row.add_child(cancel)
 cancel.pressed.connect(close)
 veil.hide()
func open(id: String) -> void:
 item_id=id
 destination.select(0)
 destination.set_item_disabled(1,not main.trolley.nearby())
 _was_paused=get_tree().paused
 amount.max_value=int(GameState.CART_CAPACITY_G/GameState.ITEMS[id].grams)
 var fit:=maxi(0,int((GameState.CAPACITY_G-GameState.carried_grams())/GameState.ITEMS[id].grams))
 amount.value=mini(1,mini(fit,int(amount.max_value)))
 veil.show()
 refresh()
 get_tree().paused=true
func refresh() -> void:
 if item_id.is_empty():return
 var count:=int(amount.value)
 var use_cart: bool=destination.selected==1
 var weight: float=((GameState.cart_grams() if use_cart else GameState.carried_grams())+count*GameState.ITEMS[item_id].grams)/1000.0
 var limit: float=25.0 if use_cart else 10.0
 info.text="%s · 单件 %.1f kg\n货架持续供货 · 随时可取\n拿取后负重 %.1f / %.0f kg"%[GameState.ITEMS[item_id].name,GameState.ITEMS[item_id].grams/1000.0,weight,limit]
 confirm.text="放入推车" if use_cart else "放入随身背包"
 confirm.disabled=count<=0 or weight>limit
func take() -> void:
 if destination.selected==1 and not main.trolley.nearby():refresh();return
 if not GameState.take_stock(item_id,int(amount.value),"cart" if destination.selected==1 else "bag"):
  refresh()
  return
 main.supply_quest.on_loot(item_id)
 main.store_interior.reset_loot(GameState.store_looted)
 close()
func close() -> void:
 veil.hide()
 get_tree().paused=_was_paused
