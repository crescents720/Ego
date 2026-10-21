extends CanvasLayer
var main
var veil: ColorRect
var bag_grid: GridContainer
var cart_grid: GridContainer
var cart_label: Label
var cargo_grid: GridContainer
var bag_label: Label
var cargo_label: Label
var detail: Label
var amount: SpinBox
var _was_paused:=false
var _zones: Dictionary={}
var _touch_start:=Vector2.ZERO
var _touch_tile: ItemTile
var _touch_data: Dictionary={}
var _touch_preview: TextureRect

class DropZone extends PanelContainer:
 var organizer
 var destination:=""
 func _can_drop_data(_point: Vector2,data: Variant) -> bool:
  return data is Dictionary and data.get("kind","")=="cargo_stack" and data.source!=destination
 func _drop_data(_point: Vector2,data: Variant) -> void:
  organizer.perform_drop(data,destination)

class ItemTile extends Button:
 var organizer
 var source:=""
 var item_id:=""
 func _get_drag_data(_point: Vector2) -> Variant:
  if item_id.is_empty():return null
  var data: Dictionary=organizer.drag_payload(source,item_id)
  if int(data.amount)<=0:return null
  var preview:=TextureRect.new()
  preview.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
  preview.custom_minimum_size=Vector2(80,80)
  preview.texture=organizer.main.equipment_screen.item_texture(item_id)
  set_drag_preview(preview)
  return data
 func _can_drop_data(_point: Vector2,data: Variant) -> bool:
  return data is Dictionary and data.get("kind","")=="cargo_stack" and data.source!=source
 func _drop_data(_point: Vector2,data: Variant) -> void:
  organizer.perform_drop(data,source)

func build(owner_main) -> void:
 main=owner_main
 process_mode=Node.PROCESS_MODE_ALWAYS
 layer=35
 veil=ColorRect.new()
 veil.color=Color("101f25")
 veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 add_child(veil)
 var title:=Label.new()
 title.text="货物整理"
 title.position=Vector2(32,115)
 title.add_theme_font_size_override("font_size",32)
 veil.add_child(title)
 var close_button:=Button.new()
 close_button.text="完成 ×"
 close_button.position=Vector2(548,110)
 close_button.size=Vector2(140,58)
 main._style_button(close_button,Color("355251"))
 veil.add_child(close_button)
 close_button.pressed.connect(close)
 bag_label=_label("",Vector2(20,210),Vector2(210,65),23)
 cargo_label=_label("",Vector2(255,210),Vector2(210,65),23)
 bag_grid=_grid("bag",Vector2(20,290))
 cargo_grid=_grid("cargo",Vector2(255,290))
 cart_label=_label("",Vector2(490,210),Vector2(210,65),23)
 cart_grid=_grid("cart",Vector2(490,290))
 _label("拖动数量",Vector2(32,850),Vector2(140,45),23)
 amount=SpinBox.new()
 amount.position=Vector2(260,840)
 amount.size=Vector2(140,60)
 amount.min_value=1
 amount.max_value=2000
 amount.step=1
 amount.value=1
 amount.add_theme_font_size_override("font_size",24)
 veil.add_child(amount)
 for entry in [["−",180,-1],["+",420,1]]:
  var button:=Button.new()
  button.text=entry[0]
  button.position=Vector2(entry[1],840)
  button.size=Vector2(65,60)
  main._style_button(button,Color("355451"))
  veil.add_child(button)
  var change: int=entry[2]
  button.pressed.connect(func():amount.value+=change)
 detail=_label("拖动物品到对应区域存取，或拖到下方丢弃。\n已装备物品不能存放或丢弃。",Vector2(32,925),Vector2(650,100),21)
 var trash:=DropZone.new()
 trash.organizer=self
 trash.destination="trash"
 _zones["trash"]=trash
 trash.position=Vector2(32,1060)
 trash.size=Vector2(656,100)
 var style:=StyleBoxFlat.new()
 style.bg_color=Color("593a3c")
 style.set_corner_radius_all(16)
 trash.add_theme_stylebox_override("panel",style)
 veil.add_child(trash)
 var text:=Label.new()
 text.text="拖到这里丢弃所选数量"
 text.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 text.add_theme_font_size_override("font_size",25)
 text.mouse_filter=Control.MOUSE_FILTER_IGNORE
 trash.add_child(text)
 veil.hide()

func _label(value: String,point: Vector2,dimensions: Vector2,font: int) -> Label:
 var label:=Label.new()
 label.text=value
 label.position=point
 label.size=dimensions
 label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 label.add_theme_font_size_override("font_size",font)
 veil.add_child(label)
 return label

func _grid(destination: String,point: Vector2) -> GridContainer:
 var zone:=DropZone.new()
 zone.organizer=self
 zone.destination=destination
 _zones[destination]=zone
 zone.position=point
 zone.size=Vector2(210,510)
 veil.add_child(zone)
 var grid:=GridContainer.new()
 grid.columns=2
 grid.add_theme_constant_override("h_separation",8)
 grid.add_theme_constant_override("v_separation",10)
 zone.add_child(grid)
 return grid

func open() -> void:
 _was_paused=get_tree().paused
 veil.show()
 refresh()
 get_tree().paused=true
func close() -> void:
 _clear_touch()
 veil.hide()
 get_tree().paused=_was_paused
 main.rv_dashboard.refresh()
func drag_payload(source: String,id: String) -> Dictionary:
 var container: Dictionary=GameState.container_for(source)
 var available: int=int(container.get(id,0))-(GameState.equipped_count(id) if source=="bag" else 0)
 return {"kind":"cargo_stack","source":source,"id":id,"amount":mini(int(amount.value),available)}
func perform_drop(data: Dictionary,destination: String) -> void:
 if data.id=="m60" and data.source=="cargo" and not GameState.m60_window.is_empty():
  detail.text="请先到射击窗拆卸机枪，再转移或丢弃。"
  AudioDirector.ui("reject")
  return
 if (data.source=="cart" or destination=="cart") and GameState.cart_deployed:
  detail.text="请先将推车推回车门，装卸收起后再整理货舱。"
  return
 var ok: bool=GameState.move_stack(data.id,data.source,destination,int(data.amount))
 if not ok:AudioDirector.ui("reject")
 detail.text="已丢弃 %d 件。"%data.amount if ok and destination=="trash" else ("物品已转移。" if ok else "无法移动：负重、货舱空间或可用数量不足。")
 main.supply_quest.check_delivery()
 call_deferred("refresh")
func refresh() -> void:
 bag_label.text="随身物品\n%.1f / 10 kg"%(GameState.carried_grams()/1000.0)
 cargo_label.text="房车货舱\n%.1f / 1000 kg"%(GameState.cargo_grams()/1000.0)
 _fill(bag_grid,GameState.items,"bag")
 _fill(cargo_grid,GameState.cargo,"cargo")
 cart_label.text="推车货物\n%.1f / 25 kg"%(GameState.cart_grams()/1000.0) if GameState.cart_owned else "推车\n尚未获得"
 _fill(cart_grid,GameState.cart_items,"cart")
func _fill(grid: GridContainer,container: Dictionary,source: String) -> void:
 for child in grid.get_children():grid.remove_child(child);child.queue_free()
 var ids: Array=container.keys()
 for i in range(maxi(8,ids.size())):
  var tile:=ItemTile.new()
  tile.organizer=self
  tile.source=source
  tile.custom_minimum_size=Vector2(94,110)
  main._style_button(tile,Color("2b4145"))
  grid.add_child(tile)
  if i>=ids.size():continue
  var id: String=ids[i]
  tile.item_id=id
  tile.tooltip_text=GameState.ITEMS[id].description
  var icon:=TextureRect.new()
  icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
  icon.texture=main.equipment_screen.item_texture(id)
  icon.position=Vector2(10,8)
  icon.size=Vector2(74,74)
  icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
  icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
  tile.add_child(icon)
  var count:=Label.new()
  count.text="%d%s"%[int(container[id]),"桶" if id=="water" else ("包" if id=="food" else ("发" if id=="m60_ammo" else "件"))]
  count.position=Vector2(2,83)
  count.size=Vector2(88,23)
  count.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
  count.add_theme_font_size_override("font_size",18)
  count.mouse_filter=Control.MOUSE_FILTER_IGNORE
  tile.add_child(count)
  tile.pressed.connect(func():detail.text=GameState.ITEMS[id].description)

func _input(event: InputEvent) -> void:
 if not veil.visible:return
 if event is InputEventScreenTouch and event.index==0:
  if event.pressed:
   _touch_start=event.position
   _touch_tile=_tile_at(event.position)
  else:
   if not _touch_data.is_empty():
    for destination in _zones:
     if _zones[destination].get_global_rect().has_point(event.position):
      perform_drop(_touch_data,destination)
      break
    get_viewport().set_input_as_handled()
   _clear_touch()
 elif event is InputEventScreenDrag and event.index==0 and is_instance_valid(_touch_tile):
  if _touch_data.is_empty() and event.position.distance_to(_touch_start)>14 and not _touch_tile.item_id.is_empty():
   _touch_data=drag_payload(_touch_tile.source,_touch_tile.item_id)
   _touch_preview=TextureRect.new()
   _touch_preview.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
   _touch_preview.texture=main.equipment_screen.item_texture(_touch_tile.item_id)
   _touch_preview.size=Vector2(80,80)
   _touch_preview.mouse_filter=Control.MOUSE_FILTER_IGNORE
   veil.add_child(_touch_preview)
  if is_instance_valid(_touch_preview):_touch_preview.position=event.position-Vector2(40,40)
func _tile_at(point: Vector2) -> ItemTile:
 for tile in bag_grid.get_children()+cargo_grid.get_children()+cart_grid.get_children():
  if tile.get_global_rect().has_point(point):return tile
 return null
func _clear_touch() -> void:
 _touch_data={}
 _touch_tile=null
 if is_instance_valid(_touch_preview):_touch_preview.queue_free()
 _touch_preview=null
