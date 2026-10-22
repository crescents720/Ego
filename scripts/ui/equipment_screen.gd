extends CanvasLayer

var main
var panel: Control
var avatar: Button
var face: TextureRect
var health_bar: ProgressBar
var rv_health_bar: ProgressBar
var health_state := "healthy"
var weight_label: Label
var item_list: GridContainer
var detail: Label
var detail_icon: TextureRect
var actions: VBoxContainer
var slot_buttons: Dictionary={}
var selected_id := ""
var selected_slot := ""
var bag_drop: Control
var _was_paused := false
var _touch_source: ItemTile
var _touch_origin := Vector2.ZERO
var _touch_data: Dictionary={}
var _touch_preview: TextureRect
var _portraits: Dictionary={}
var skill_panel: Control
var skill_level_label: Label
var skill_description: Label
var skill_level_buttons: Array[Button]=[]

const ODACHI_SKILL_DESCRIPTIONS := {
 1:"生疏挥击 · 一段\n像挥舞球棒一样使用大太刀。单次短硬直，丧尸仍会继续逼近。",
 2:"基础二连 · 两段\n斜斩接反向上挑。连续硬直可显著限制普通丧尸靠近。",
 3:"熟练连斩 · 三段\n追加横斩，扩大连续压制时间。",
 4:"精通连斩 · 四段\n追加举刀下劈，形成稳定的完整连段。",
 5:"最终奥义 · 五段\n以终结斜斩收尾，并释放明亮剑气。",
}

class ItemTile extends Button:
 var screen
 var item_id := ""
 var slot_id := ""
 var image: TextureRect
 func _get_drag_data(_point: Vector2) -> Variant:
  if item_id.is_empty():return null
  var preview:=TextureRect.new()
  preview.texture=screen.item_texture(item_id)
  preview.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
  preview.size=Vector2(90,90)
  preview.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
  set_drag_preview(preview)
  return {"kind":"personal_item","id":item_id,"source_slot":slot_id}
 func _can_drop_data(_point: Vector2,data: Variant) -> bool:
  return not slot_id.is_empty() and screen.can_equip_drop(slot_id,data)
 func _drop_data(_point: Vector2,data: Variant) -> void:
  screen.equip_drop(slot_id,data)

class BagDrop extends ColorRect:
 var screen
 func _can_drop_data(_point: Vector2,data: Variant) -> bool:
  return data is Dictionary and data.get("kind","")=="personal_item" and not str(data.get("source_slot","")).is_empty()
 func _drop_data(_point: Vector2,data: Variant) -> void:
  screen.return_to_bag(data)

class BackpackScroll extends ScrollContainer:
 var screen
 func _can_drop_data(_point: Vector2,data: Variant) -> bool:
  return data is Dictionary and data.get("kind","")=="personal_item" and not str(data.get("source_slot","")).is_empty()
 func _drop_data(_point: Vector2,data: Variant) -> void:
  screen.return_to_bag(data)

func build(owner_main: Node) -> void:
 main=owner_main
 name="EquipmentScreen"
 layer=110
 process_mode=Node.PROCESS_MODE_ALWAYS
 var portrait: Texture2D=load("res://assets/ui/hotaru_equipment.png")
 var used:=Rect2i(328,34,406,1427)
 var portrait_crop:=AtlasTexture.new()
 portrait_crop.atlas=portrait
 portrait_crop.region=used
 var face_crop:=AtlasTexture.new()
 face_crop.atlas=portrait
 face_crop.region=Rect2(used.position,Vector2(used.size.x,used.size.y*0.27))
 for state in ["healthy","hurt","critical","dead"]:
  var path: String="res://assets/ui/avatars/"+state+("" if state in ["healthy","dead"] else "_v2")+".png"
  _portraits[state]=load(path) if ResourceLoader.exists(path) else face_crop
 avatar=Button.new()
 avatar.position=Vector2(26,26)
 avatar.size=Vector2(110,110)
 avatar.tooltip_text="小萤 · 装备与随身背包"
 main.get_node("HUD").add_child(avatar)
 face=TextureRect.new()
 face.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 face.texture=face_crop
 face.stretch_mode=TextureRect.STRETCH_SCALE
 face.position=Vector2(3,3)
 face.size=Vector2(104,104)
 face.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var mask:=Shader.new()
 mask.code="""shader_type canvas_item;
void fragment(){vec4 c=texture(TEXTURE,UV);float a=1.0-smoothstep(0.475,0.5,length(UV-vec2(0.5)));COLOR=vec4(c.rgb,c.a*a);}"""
 var material:=ShaderMaterial.new()
 material.shader=mask
 face.material=material
 avatar.add_child(face)
 avatar.pressed.connect(open)
 health_bar=ProgressBar.new()
 health_bar.position=Vector2(146,54)
 health_bar.size=Vector2(264,28)
 health_bar.show_percentage=false
 health_bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var bar_back:=StyleBoxFlat.new()
 bar_back.bg_color=Color("263538")
 bar_back.set_corner_radius_all(14)
 health_bar.add_theme_stylebox_override("background",bar_back)
 main.get_node("HUD").add_child(health_bar)
 main.hotaru.health_changed.connect(func(_hp,_max):update_health())
 var rv_badge:=Panel.new()
 rv_badge.position=Vector2(142,100)
 rv_badge.size=Vector2(44,44)
 rv_badge.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var badge_style:=StyleBoxFlat.new()
 badge_style.bg_color=Color("29393d")
 badge_style.border_color=Color("9dbfc5")
 badge_style.set_border_width_all(1)
 badge_style.set_corner_radius_all(22)
 rv_badge.add_theme_stylebox_override("panel",badge_style)
 main.get_node("HUD").add_child(rv_badge)
 var rv_icon:=TextureRect.new()
 rv_icon.name="RVHealthIcon"
 rv_icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 rv_icon.texture=load("res://assets/ui/icons/rv.png")
 rv_icon.position=Vector2(3,3)
 rv_icon.size=Vector2(38,38)
 rv_icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 rv_icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
 rv_badge.add_child(rv_icon)
 rv_health_bar=ProgressBar.new()
 rv_health_bar.position=Vector2(194,112)
 rv_health_bar.size=Vector2(216,20)
 rv_health_bar.show_percentage=false
 rv_health_bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
 rv_health_bar.add_theme_stylebox_override("background",bar_back)
 main.get_node("HUD").add_child(rv_health_bar)
 main.rv.health_changed.connect(func(_hp,_max):update_vehicle_health())
 panel=Control.new()
 panel.size=Vector2(720,1280)
 add_child(panel)
 var background:=ColorRect.new()
 background.size=Vector2(720,1280)
 background.color=Color("121e26")
 panel.add_child(background)
 _label(panel,"小萤 · 装备与背包",Vector2(28,36),Vector2(570,60),32)
 _button(panel,"×",Vector2(625,32),Vector2(64,64),close)
 _button(panel,"技能升级",Vector2(430,90),Vector2(180,48),open_skills)
 _rect(Vector2(16,145),Vector2(390,1080),Color("202e36"))
 bag_drop=BagDrop.new()
 bag_drop.screen=self
 bag_drop.position=Vector2(418,145)
 bag_drop.size=Vector2(286,1080)
 bag_drop.color=Color("27363c")
 panel.add_child(bag_drop)
 _label(panel,"当前装备",Vector2(36,157),Vector2(270,42),24)
 var art:=TextureRect.new()
 art.texture=portrait_crop
 art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 art.position=Vector2(98,224)
 art.size=Vector2(226,826)
 art.mouse_filter=Control.MOUSE_FILTER_IGNORE
 panel.add_child(art)
 var locations:={"head":Vector2(292,232),"upper":Vector2(28,398),"right_hand":Vector2(28,592),"left_hand":Vector2(292,592),"lower":Vector2(292,790),"feet":Vector2(28,970)}
 for slot in locations:
  var slot_id: String=slot
  _label(panel,GameState.SLOT_NAMES[slot],locations[slot]-Vector2(0,30),Vector2(100,28),19)
  var tile:=_tile(panel,"",slot,locations[slot],Vector2(100,100))
  tile.pressed.connect(func():select_slot(slot_id))
  slot_buttons[slot]=tile
 _label(panel,"拖动物品到装备栏\n点击图标查看说明",Vector2(36,1120),Vector2(355,80),22)
 _label(panel,"随身背包",Vector2(434,157),Vector2(250,40),25)
 weight_label=_label(panel,"",Vector2(434,206),Vector2(250,40),23)
 var scroll:=BackpackScroll.new()
 scroll.screen=self
 scroll.position=Vector2(434,268)
 scroll.size=Vector2(254,425)
 scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 panel.add_child(scroll)
 item_list=GridContainer.new()
 item_list.columns=2
 item_list.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 item_list.add_theme_constant_override("h_separation",14)
 item_list.add_theme_constant_override("v_separation",14)
 scroll.add_child(item_list)
 detail_icon=TextureRect.new()
 detail_icon.position=Vector2(490,736)
 detail_icon.size=Vector2(136,136)
 detail_icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 detail_icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 detail_icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
 panel.add_child(detail_icon)
 detail=_label(panel,"点击图标查看物品",Vector2(434,890),Vector2(250,205),22)
 detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 actions=VBoxContainer.new()
 actions.position=Vector2(434,1120)
 actions.size=Vector2(254,80)
 panel.add_child(actions)
 GameState.inventory_changed.connect(refresh)
 GameState.skills_changed.connect(refresh_skills)
 _build_skill_panel()
 panel.hide()
 refresh()
 update_health()
 update_vehicle_health()

func item_texture(id: String) -> Texture2D:
 var path: String="res://assets/ui/icons/"+id+(".png" if id=="bat" else ".svg")
 return load(path) if ResourceLoader.exists(path) else null

func _tile(parent: Node,id: String,slot: String,point: Vector2,dimensions: Vector2) -> ItemTile:
 var tile:=ItemTile.new()
 tile.screen=self
 tile.item_id=id
 tile.slot_id=slot
 tile.position=point
 tile.size=dimensions
 tile.custom_minimum_size=dimensions
 main._style_button(tile,Color("35474e"))
 parent.add_child(tile)
 tile.image=TextureRect.new()
 tile.image.position=Vector2(9,9)
 tile.image.size=dimensions-Vector2(18,18)
 tile.image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 tile.image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 tile.image.mouse_filter=Control.MOUSE_FILTER_IGNORE
 tile.add_child(tile.image)
 return tile

func update_health() -> void:
 var previous:=health_state
 var previous_texture=face.texture
 var ratio:=float(main.hotaru.health)/maxi(1,main.hotaru.max_health)
 health_state="dead" if ratio<=0 else ("healthy" if ratio>0.5 else ("hurt" if ratio>main.hotaru.CRITICAL_HEALTH_RATIO else "critical"))
 var color: Color={"healthy":Color("7acda1"),"hurt":Color("efc568"),"critical":Color("e58b96"),"dead":Color("8b939e")}[health_state]
 avatar.disabled=ratio<=0
 face.texture=_portraits[health_state]
 health_bar.max_value=main.hotaru.max_health
 health_bar.value=main.hotaru.health
 if previous==health_state and previous_texture==face.texture:return
 var fill:=StyleBoxFlat.new()
 fill.bg_color=color
 fill.set_corner_radius_all(14)
 health_bar.add_theme_stylebox_override("fill",fill)
 var ring:=StyleBoxFlat.new()
 ring.bg_color=Color("29393d")
 ring.border_color=color
 ring.set_corner_radius_all(55)
 ring.set_border_width_all(2)
 for state in ["normal","hover","pressed","focus","disabled"]:avatar.add_theme_stylebox_override(state,ring)

func update_vehicle_health() -> void:
 var ratio: float=float(main.rv.health)/main.rv.max_health
 rv_health_bar.max_value=main.rv.max_health
 rv_health_bar.value=main.rv.health
 var fill:=StyleBoxFlat.new()
 fill.bg_color=Color("96c9d0") if ratio>0.5 else (Color("edbd69") if ratio>0.25 else Color("e58b86"))
 fill.set_corner_radius_all(10)
 rv_health_bar.add_theme_stylebox_override("fill",fill)

func _rect(point: Vector2,size_value: Vector2,color: Color) -> void:
 var rect:=ColorRect.new()
 rect.position=point
 rect.size=size_value
 rect.color=color
 rect.mouse_filter=Control.MOUSE_FILTER_IGNORE
 panel.add_child(rect)

func _label(parent: Node,text: String,point: Vector2,size_value: Vector2,font: int) -> Label:
 var label:=Label.new()
 label.text=text
 label.position=point
 label.size=size_value
 label.add_theme_font_size_override("font_size",font)
 label.add_theme_color_override("font_color",Color("f4e8ce"))
 label.mouse_filter=Control.MOUSE_FILTER_IGNORE
 parent.add_child(label)
 return label

func _button(parent: Node,text: String,point: Vector2,size_value: Vector2,callback: Callable) -> Button:
 var button:=Button.new()
 button.text=text
 button.position=point
 button.size=size_value
 button.custom_minimum_size=size_value
 main._style_button(button,Color("35474e"))
 button.add_theme_font_size_override("font_size",24)
 button.pressed.connect(callback)
 parent.add_child(button)
 return button

func _build_skill_panel() -> void:
 skill_panel=Control.new()
 skill_panel.name="WeaponSkills"
 skill_panel.size=Vector2(720,1280)
 panel.add_child(skill_panel)
 var veil:=ColorRect.new()
 veil.size=skill_panel.size
 veil.color=Color("101a21")
 skill_panel.add_child(veil)
 var card:=ColorRect.new()
 card.position=Vector2(42,150)
 card.size=Vector2(636,850)
 card.color=Color("22313a")
 skill_panel.add_child(card)
 _label(skill_panel,"小萤 · 武器技术",Vector2(65,178),Vector2(480,60),34)
 _label(skill_panel,"当前为开发阶段，可自由调整技能等级。",Vector2(66,244),Vector2(580,44),20)
 _button(skill_panel,"返回",Vector2(535,174),Vector2(112,58),close_skills)
 _label(skill_panel,"太刀术",Vector2(76,326),Vector2(230,52),30)
 skill_level_label=_label(skill_panel,"",Vector2(350,326),Vector2(270,52),27)
 for level in range(1,6):
  var chosen_level:=level
  var button:=_button(skill_panel,str(level),Vector2(76+(level-1)*114,404),Vector2(96,96),func():
   GameState.set_odachi_skill_level(chosen_level)
  )
  button.name="OdachiLevel%d"%level
  button.tooltip_text="将太刀术调整到第%d层"%level
  skill_level_buttons.append(button)
 skill_description=_label(skill_panel,"",Vector2(76,552),Vector2(568,260),25)
 skill_description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 _label(skill_panel,"等级决定下一次拔刀时使用的连段。\n已经开始的攻击不会被面板中途改变。",Vector2(76,838),Vector2(568,110),21)
 skill_panel.hide()
 refresh_skills()

func open_skills() -> void:
 if not panel.visible:return
 _clear_touch()
 refresh_skills()
 skill_panel.show()

func close_skills() -> void:
 if is_instance_valid(skill_panel):skill_panel.hide()

func refresh_skills() -> void:
 if not is_instance_valid(skill_panel):return
 var current:=clampi(GameState.odachi_skill_level,1,5)
 skill_level_label.text="当前：第%d层 / 五层"%current
 skill_description.text=str(ODACHI_SKILL_DESCRIPTIONS[current])
 for index in range(skill_level_buttons.size()):
  var selected:=index+1==current
  main._style_button(skill_level_buttons[index],Color("9b7440") if selected else Color("35474e"))
  skill_level_buttons[index].text=("✓ " if selected else "")+str(index+1)

func open() -> void:
 if panel.visible:return
 if main.phase==main.Phase.TITLE or main.phase==main.Phase.GAME_OVER or main.dialog_panel.visible:return
 if main.opening.is_cinematic():return
 for action in ["move_forward","move_backward","move_left","move_right"]:Input.action_release(action)
 _was_paused=get_tree().paused
 panel.show()
 close_skills()
 refresh()
 get_tree().paused=true

func close() -> void:
 if not panel.visible:return
 panel.hide()
 close_skills()
 _clear_touch()
 get_tree().paused=_was_paused

func can_equip_drop(slot: String,data: Variant) -> bool:
 if not data is Dictionary or data.get("kind","")!="personal_item":return false
 var id: String=data.get("id","")
 if not GameState.ITEMS.has(id) or not slot in GameState.ITEMS[id].slots:return false
 var source: String=data.get("source_slot","")
 return GameState.equipment.get(source,"")==id if not source.is_empty() else int(GameState.items.get(id,0))-GameState.equipped_count(id)>0

func equip_drop(slot: String,data: Dictionary) -> bool:
 if not can_equip_drop(slot,data):
  AudioDirector.ui("reject")
  return false
 return GameState.equip_item(data.id,slot,str(data.get("source_slot","")))

func return_to_bag(data: Dictionary) -> void:
 var source: String=data.get("source_slot","")
 if GameState.equipment.get(source,"")==data.get("id",""):GameState.unequip_item(source)

func _input(event: InputEvent) -> void:
 if not panel.visible:return
 if event.is_action_pressed("ui_cancel"):
  if is_instance_valid(skill_panel) and skill_panel.visible:close_skills()
  else:close()
  get_viewport().set_input_as_handled()
  return
 if is_instance_valid(skill_panel) and skill_panel.visible:return
 if event is InputEventScreenTouch and event.index==0:
  if event.pressed:
   _touch_origin=event.position
   _touch_source=_tile_at(event.position)
  else:
   if not _touch_data.is_empty():
    var target:=_tile_at(event.position)
    if is_instance_valid(target) and not target.slot_id.is_empty():equip_drop(target.slot_id,_touch_data)
    elif bag_drop.get_global_rect().has_point(event.position):return_to_bag(_touch_data)
    get_viewport().set_input_as_handled()
   _clear_touch()
 elif event is InputEventScreenDrag and event.index==0 and is_instance_valid(_touch_source):
  if _touch_data.is_empty() and event.position.distance_to(_touch_origin)>14 and not _touch_source.item_id.is_empty():
   _touch_data={"kind":"personal_item","id":_touch_source.item_id,"source_slot":_touch_source.slot_id}
   _touch_preview=TextureRect.new()
   _touch_preview.texture=item_texture(_touch_source.item_id)
   _touch_preview.size=Vector2(90,90)
   _touch_preview.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
   _touch_preview.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
   _touch_preview.mouse_filter=Control.MOUSE_FILTER_IGNORE
   panel.add_child(_touch_preview)
  if is_instance_valid(_touch_preview):_touch_preview.position=event.position-Vector2(45,45)

func _tile_at(point: Vector2) -> ItemTile:
 for tile in slot_buttons.values()+item_list.get_children():
  if tile is ItemTile and tile.get_global_rect().has_point(point):return tile
 return null

func _clear_touch() -> void:
 _touch_data={}
 _touch_source=null
 if is_instance_valid(_touch_preview):_touch_preview.queue_free()
 _touch_preview=null

func _clear(container: Node) -> void:
 for child in container.get_children():
  container.remove_child(child)
  child.queue_free()

func select_slot(slot: String) -> void:
 selected_slot=slot
 selected_id=str(GameState.equipment[slot])
 refresh()

func refresh() -> void:
 if not is_instance_valid(panel):return
 weight_label.text="%.2f / 10 kg"%(float(GameState.carried_grams())/1000)
 for slot in slot_buttons:
  var tile: ItemTile=slot_buttons[slot]
  tile.item_id=GameState.equipment[slot]
  tile.image.texture=item_texture(slot if tile.item_id.is_empty() else tile.item_id)
  tile.image.modulate=Color(1,1,1,0.38) if tile.item_id.is_empty() else Color.WHITE
 _clear(item_list)
 for id in GameState.items:
  var count: int=int(GameState.items[id])-GameState.equipped_count(id)
  if count<=0:continue
  var item_id: String=id
  var tile:=_tile(item_list,id,"",Vector2.ZERO,Vector2(112,112))
  tile.image.texture=item_texture(id)
  if count>1:_label(tile,"×%d"%count,Vector2(65,76),Vector2(44,30),20)
  tile.pressed.connect(func():
   selected_id=item_id
   selected_slot=""
   refresh()
  )
 _clear(actions)
 detail_icon.texture=null
 if selected_id.is_empty():
  detail.text=(GameState.SLOT_NAMES[selected_slot]+"\n尚未装备") if not selected_slot.is_empty() else "按住物品拖到左侧栏位。\n点击图标查看说明。"
  return
 if not GameState.ITEMS.has(selected_id):return
 var data: Dictionary=GameState.ITEMS[selected_id]
 detail_icon.texture=item_texture(selected_id)
 detail.text="%s\n%.2f kg\n\n%s"%[data.name,float(data.grams)/1000,data.description]
 if not selected_slot.is_empty():
  _button(actions,"卸下至背包",Vector2.ZERO,Vector2(254,62),func():
   GameState.unequip_item(selected_slot)
   selected_slot=""
   refresh()
  )


