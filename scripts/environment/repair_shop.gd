extends Node3D
const BAY:=Vector3(105,1.02,-135)
var main
var button: Button
var site_label: Label3D
func build(owner_main) -> void:
 main=owner_main
 name="TownAutoRepair"
 var model: Node3D=load("res://assets/environment/repair_shop/repair_shop_mobile.glb").instantiate()
 model.scale=Vector3.ONE*10
 model.position=Vector3(113,.07,-135)
 model.rotation.y=-PI/2
 add_child(model)
 main.town_occlusion.register_building(model)
 var body:=StaticBody3D.new()
 body.collision_layer=3
 body.collision_mask=0
 var collision:=CollisionShape3D.new()
 var shape:=BoxShape3D.new()
 shape.size=Vector3(6.8,7.4,6.8)
 collision.shape=shape
 body.position=Vector3(113,3.77,-135)
 body.add_child(collision)
 add_child(body)
 var pavement:=MeshInstance3D.new()
 var slab:=BoxMesh.new()
 slab.size=Vector3(20,.05,26)
 pavement.mesh=slab
 pavement.position=Vector3(105,.035,-132)
 var material:=StandardMaterial3D.new()
 material.albedo_color=Color("686f6a")
 pavement.material_override=material
 add_child(pavement)
 for x in [BAY.x-2.5,BAY.x+2.5]:
  var stripe:=MeshInstance3D.new()
  var box:=BoxMesh.new()
  box.size=Vector3(.15,.015,9)
  stripe.mesh=box
  stripe.position=Vector3(x,.075,BAY.z)
  var paint:=StandardMaterial3D.new()
  paint.albedo_color=Color("e8cc72")
  stripe.material_override=paint
  add_child(stripe)
 var label:=Label3D.new()
 site_label=label
 label.text="汽车修理厂 · 黄色车位检修"
 label.position=Vector3(BAY.x,3,BAY.z-4.5)
 label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
 label.font_size=30
 label.pixel_size=.012
 label.outline_size=6
 add_child(label)
 var sign:=Label3D.new()
 sign.text="汽车修理厂"
 sign.position=Vector3(109.5,2.0,-135)
 sign.rotation.y=-PI/2
 sign.font_size=45
 sign.pixel_size=.012
 sign.outline_size=4
 add_child(sign)
 button=Button.new()
 button.text="检修房车"
 button.position=Vector2(28,390)
 button.size=Vector2(190,60)
 main._style_button(button,Color("59634b"))
 main.get_node("HUD").add_child(button)
 button.pressed.connect(open)
func _process(_delta: float) -> void:
 site_label.visible=not main.service.active
 if not is_instance_valid(main):return
 button.visible=not main.service.active and not main.sleep_controller.sleeping and main.phase not in [main.Phase.TITLE,main.Phase.GAME_OVER] and not main.inside_store and not main.rv.wrecked and is_on_site() and not main.dialog_panel.visible
func is_on_site() -> bool:
 if main.rv.global_position.distance_to(BAY)>=8 or main.inside_store:return false
 return main.in_vehicle or main.inside_rv or main.hotaru.global_position.distance_to(BAY)<12
func repair_cost() -> int:
 return 0
func open() -> void:
 if main.in_vehicle or main.inside_rv:main.rest_notice("请停车并下车，走到房车旁检修。");return
 if not is_on_site():main.rest_notice("请把房车停入检修位，并到现场操作。");return
 if absf(main.rv.speed)>.5 or main.is_under_attack():main.rest_notice("请先停稳车辆，确认周围安全。");return
 if main.rv.health>=main.rv.max_health and not GameState.fences_need_repair():main.rest_notice("房车状况良好，无需检修。");return
 main.controls_enabled=false
 main.hotaru.set_active(false)
 main._show_dialog("汽车修理厂","蛍需要在车旁蹲下检修，大约需要 12 秒操作时间。\n无需维修材料；同时修复未被击毁的围栏。可以中断，已完成的修复会保留。","开始检修",repair)
 main._add_dialog_button("取消",close)
func repair() -> bool:
 main.dialog_panel.hide()
 main.controls_enabled=true
 main.hotaru.set_active(true)
 return main.service.begin("repair")
func close() -> void:
 main.dialog_panel.hide()
 main.controls_enabled=true
 main.hotaru.set_active(not main.in_vehicle and not main.seated_at_driver)
