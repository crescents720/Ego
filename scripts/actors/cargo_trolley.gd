extends Node3D
const SPEED_FACTOR:=0.48
var main
var toggle_button: Button
var inventory_button: Button
var visual: Node3D
var cargo_visual: Node3D
var pushing:=false
var loading:=false
var panel: ColorRect
var inventory_label: Label
var _store_cart_position:=Vector3.ZERO
var _entered_with_cart:=false
var _last_hero:=Vector3.ZERO
var item_picker: OptionButton
var amount_picker: SpinBox
var selected_source:="bag"
var selected_item:=""
var lathe_visual: Node3D
var gun_visual: Node3D
var supply_box: MeshInstance3D
func build(owner_main) -> void:
 main=owner_main
 visual=Node3D.new()
 add_child(visual)
 var model: Node3D=load("res://assets/weapon_shop/trolley.glb").instantiate()
 visual.add_child(model)
 cargo_visual=Node3D.new()
 cargo_visual.position=Vector3(0,.38,0)
 visual.add_child(cargo_visual)
 gun_visual=load("res://assets/weapon_shop/m60.glb").instantiate()
 gun_visual.scale=Vector3.ONE*.65
 gun_visual.rotation.x=PI
 gun_visual.position.y=.35
 cargo_visual.add_child(gun_visual)
 lathe_visual=load("res://assets/factory/lathe.glb").instantiate()
 lathe_visual.position.y=.03
 cargo_visual.add_child(lathe_visual)
 supply_box=MeshInstance3D.new()
 var box_mesh:=BoxMesh.new()
 box_mesh.size=Vector3(.4,.23,.4)
 supply_box.mesh=box_mesh
 var box_material:=StandardMaterial3D.new()
 box_material.albedo_color=Color("7c7854")
 supply_box.material_override=box_material
 supply_box.position=Vector3(.1,.13,.2)
 cargo_visual.add_child(supply_box)
 var label:=Label3D.new()
 label.text="推车 · E 推行 / 松手"
 label.position.y=1.3
 label.font_size=25
 label.pixel_size=.01
 label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
 visual.add_child(label)
 # Independent cargo screen also works while away from the RV.
 var layer:=CanvasLayer.new()
 layer.layer=40
 layer.process_mode=Node.PROCESS_MODE_ALWAYS
 add_child(layer)
 panel=ColorRect.new()
 panel.color=Color("172a2d")
 panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 layer.add_child(panel)
 inventory_label=Label.new()
 inventory_label.position=Vector2(35,130)
 inventory_label.size=Vector2(650,560)
 inventory_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 inventory_label.add_theme_font_size_override("font_size",25)
 panel.add_child(inventory_label)
 var close:=Button.new()
 close.text="返回"
 close.position=Vector2(500,1050)
 close.size=Vector2(170,65)
 main._style_button(close,Color("3c5956"))
 panel.add_child(close)
 close.pressed.connect(func():panel.hide();get_tree().paused=false)
 item_picker=OptionButton.new()
 item_picker.position=Vector2(35,730)
 item_picker.size=Vector2(650,62)
 item_picker.add_theme_font_size_override("font_size",23)
 panel.add_child(item_picker)
 item_picker.item_selected.connect(func(i):
  var data: Dictionary=item_picker.get_item_metadata(i)
  selected_source=data.source
  selected_item=data.id
 )
 amount_picker=SpinBox.new()
 amount_picker.min_value=1
 amount_picker.max_value=500
 amount_picker.value=1
 amount_picker.position=Vector2(35,825)
 amount_picker.size=Vector2(250,62)
 panel.add_child(amount_picker)
 var move_button:=Button.new()
 move_button.text="转移所选数量"
 move_button.position=Vector2(320,825)
 move_button.size=Vector2(365,62)
 main._style_button(move_button,Color("3c5956"))
 panel.add_child(move_button)
 move_button.pressed.connect(func():
  if selected_item.is_empty():return
  if not GameState.move_stack(selected_item,selected_source,"cart" if selected_source=="bag" else "bag",int(amount_picker.value)):
   inventory_label.text+="\n无法转移：负重或数量不符合要求。"
   return
  show_inventory()
 )
 panel.hide()
 inventory_button=Button.new()
 inventory_button.text="推车货物"
 inventory_button.position=Vector2(28,236)
 inventory_button.size=Vector2(166,52)
 main._style_button(inventory_button,Color("304a50"))
 main.get_node("HUD").add_child(inventory_button)
 inventory_button.pressed.connect(show_inventory)
 inventory_button.set_meta("cart_button",true)
 toggle_button=Button.new()
 toggle_button.position=Vector2(370,1010)
 toggle_button.size=Vector2(140,80)
 main._style_button(toggle_button,Color("574733"))
 main.get_node("HUD").add_child(toggle_button)
 toggle_button.pressed.connect(interact)
 if main.mobile_joystick.mobile:
  toggle_button.mouse_filter=Control.MOUSE_FILTER_IGNORE
  inventory_button.mouse_filter=Control.MOUSE_FILTER_IGNORE
func reset() -> void:
 release()
 loading=false
 _entered_with_cart=false
 visual.scale=Vector3.ONE
 visual.rotation=Vector3.ZERO
 _last_hero=main.hotaru.global_position
func nearby() -> bool:
 return GameState.cart_owned and GameState.cart_deployed and main.hotaru.global_position.distance_to(GameState.cart_position+Vector3(0,.85,0))<2.3
func interact() -> bool:
 if loading:return true
 if pushing:release();return true
 if not nearby():return false
 pushing=true
 main.hotaru.pushing_cart=true
 main.hotaru.sync_equipment()
 _last_hero=main.hotaru.global_position
 main.rest_notice("推车中：速度降低，不能攻击。按交互松手。")
 return true
func release() -> void:
 pushing=false
 if is_instance_valid(main):
  main.hotaru.pushing_cart=false
  main.hotaru.sync_equipment()
func _physics_process(_delta: float) -> void:
 if not is_instance_valid(main):return
 if pushing and (main.hotaru.dead or main.in_vehicle or main.inside_rv):release()
 if pushing and main.controls_enabled:
  var forward: Vector3=Vector3(sin(main.hotaru.rotation.y),0,cos(main.hotaru.rotation.y))
  var desired: Vector3=main.hotaru.global_position+forward*1.05
  desired.y=.16 if main.inside_store or main.factory.active else .08
  var query:=PhysicsShapeQueryParameters3D.new()
  var box:=BoxShape3D.new()
  box.size=Vector3(.72,.65,1.08)
  query.shape=box
  query.transform=Transform3D(Basis(Vector3.UP,main.hotaru.rotation.y),desired+Vector3(0,.45,0))
  query.collision_mask=3
  query.exclude=[main.hotaru.get_rid()]
  if get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():
   GameState.cart_position=desired
   GameState.cart_yaw=main.hotaru.rotation.y
   _last_hero=main.hotaru.global_position
  else:
   main.hotaru.global_position=_last_hero
   main.hotaru.velocity=Vector3.ZERO
 if not loading:
  visual.position=GameState.cart_position
  visual.rotation.y=GameState.cart_yaw
 visual.visible=GameState.cart_deployed and GameState.cart_owned and not main.inside_rv and main.phase not in [main.Phase.TITLE,main.Phase.GAME_OVER] and (GameState.spatial_room_id(GameState.cart_position)==(3 if main.factory.active else (2 if main.inside_store else 0)))
 cargo_visual.visible=not GameState.cart_items.is_empty()
 lathe_visual.visible=GameState.cart_items.has("lathe")
 gun_visual.visible=GameState.cart_items.has("m60")
 supply_box.visible=not GameState.cart_items.is_empty() and (GameState.cart_items.size()>1 or not (GameState.cart_items.has("m60") or GameState.cart_items.has("lathe")))
 toggle_button.visible=GameState.cart_owned and not main.in_vehicle and not main.inside_rv and nearby() and main.controls_enabled and not loading
 toggle_button.text="松开推车" if pushing else "推行推车"
 for button in main.get_node("HUD").get_children():
  if button.has_meta("cart_button"):button.visible=GameState.cart_owned and not main.in_vehicle and not main.inside_rv and nearby() and main.controls_enabled
func prepare_boarding() -> bool:
 # A remote cart remains where it was left; boarding never teleports it.
 if loading:return true
 if not GameState.cart_deployed or not nearby() or main.hotaru.global_position.distance_to(main.rv.get_disembark_position())>3.5:return false
 if GameState.cargo_grams()+GameState.cart_grams()>GameState.CARGO_CAPACITY_G:
  main.rest_notice("房车货舱已满，请先腾出推车货物的空间。")
  return true
 release()
 loading=true
 main.controls_enabled=false
 main.hotaru.set_active(false)
 if is_instance_valid(main.mobile_joystick):main.mobile_joystick.reset()
 main.rest_notice("正在搬运推车货物，并折叠收起推车……")
 var tween:=create_tween()
 tween.tween_property(cargo_visual,"position",Vector3(0,1.2,0),.65)
 tween.tween_property(cargo_visual,"scale",Vector3.ONE*.01,.4)
 tween.tween_property(visual,"scale",Vector3(1,.15,1),.5)
 tween.tween_property(visual,"position",main.rv.get_disembark_position(),.45)
 tween.tween_callback(func():
  if main.hotaru.dead or main.rv.wrecked:
   if not main.hotaru.dead:main.controls_enabled=true;main.hotaru.set_active(true)
   loading=false
   visual.scale=Vector3.ONE
   cargo_visual.scale=Vector3.ONE
   cargo_visual.position=Vector3(0,.38,0)
   return
  GameState.unload_cart()
  visual.hide()
  visual.scale=Vector3.ONE
  cargo_visual.scale=Vector3.ONE
  cargo_visual.position=Vector3(0,.38,0)
  loading=false
  main.controls_enabled=true
  main.hotaru.set_active(true)
  main._enter_rv_interior()
  main.supply_quest.check_delivery()
 )
 return true
func deploy_on_exit() -> void:
 if not GameState.cart_owned or GameState.cart_deployed or not GameState.cart_use_on_exit:return
 var door: Vector3=main.rv.get_disembark_position()
 # Place alongside, leaving the exact exit point and walking path clear.
 for local_offset in [Vector3(0,0,1.5),Vector3(0,0,-1.5),Vector3(1.5,0,1.5),Vector3(-1.5,0,-1.5)]:
  var p: Vector3=door+main.rv.global_transform.basis*local_offset
  p.y=.08
  var q:=PhysicsShapeQueryParameters3D.new()
  var box:=BoxShape3D.new()
  box.size=Vector3(.9,.8,1.3)
  q.shape=box
  q.transform=Transform3D(Basis.IDENTITY,p+Vector3(0,.5,0))
  q.collision_mask=3
  if get_world_3d().direct_space_state.intersect_shape(q,1).is_empty():
   GameState.cart_position=p
   GameState.cart_yaw=main.rv.rotation.y
   GameState.cart_deployed=true
   return
 main.rest_notice("车门旁没有安全空间部署推车，请换个位置。")
func enter_store() -> void:
 _entered_with_cart=pushing and nearby()
 if not _entered_with_cart:return
 _store_cart_position=GameState.cart_position
 GameState.cart_exterior_position=_store_cart_position
 GameState.cart_position=main.store_interior.get_entry_position()+Vector3(0,-.9,-1.2)
 _last_hero=main.store_interior.get_entry_position()
func exit_store() -> void:
 var bring_out: bool=pushing and nearby()
 release()
 if bring_out and GameState.cart_deployed and GameState.spatial_room_id(GameState.cart_position)==2:
  GameState.cart_position=GameState.cart_exterior_position
 _entered_with_cart=false
func show_inventory() -> void:
 if not nearby() and not main.inside_rv:return
 inventory_label.text="随身背包 · %.1f / 10 kg\n%s\n\n推车货物 · %.1f / 25 kg\n%s\n\n选择物品和数量，分别存放、分别计重；M60 无法放入随身背包。"%[GameState.carried_grams()/1000.0,_contents(GameState.items),GameState.cart_grams()/1000.0,_contents(GameState.cart_items)]
 item_picker.clear()
 for source in ["bag","cart"]:
  for id in GameState.container_for(source):
   if source=="bag" and int(GameState.items[id])-GameState.equipped_count(id)<=0:continue
   var i:=item_picker.item_count
   item_picker.add_item(("随身 → 推车：" if source=="bag" else "推车 → 随身：")+GameState.ITEMS[id].name)
   item_picker.set_item_metadata(i,{"source":source,"id":id})
 if item_picker.item_count>0:
  var data: Dictionary=item_picker.get_item_metadata(0)
  selected_source=data.source
  selected_item=data.id
 else:selected_item=""
 panel.show()
 get_tree().paused=true
func _contents(container: Dictionary) -> String:
 var lines:=PackedStringArray()
 for id in container:lines.append("%s ×%d"%[GameState.ITEMS[id].name,int(container[id])])
 return "空" if lines.is_empty() else "\n".join(lines)

func doorway_points() -> Array[Vector3]:
 var points: Array[Vector3]=[main.hotaru.global_position]
 if pushing and nearby():
  var front:=Vector3(sin(GameState.cart_yaw),0,cos(GameState.cart_yaw))
  var center: Vector3=GameState.cart_position
  center.y=main.hotaru.global_position.y
  points.append(center)
  points.append(center+front*.55)
  var right:=Vector3(front.z,0,-front.x)
  points.append(center+front*.55+right*.38)
  points.append(center+front*.55-right*.38)
 return points
func near_door(point: Vector3,radius: float) -> bool:
 for sample in doorway_points():
  if Vector2(sample.x,sample.z).distance_to(Vector2(point.x,point.z))<=radius:return true
 return false
