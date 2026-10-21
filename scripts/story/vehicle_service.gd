extends Node
var main
var active:=false
var kind:=""
var work_seconds:=0.0
var changed_amount:=0.0
var repair_rate:=0.0
var fence_start: Dictionary={}
var work_target:=Vector3.ZERO
var waypoints: Array[Vector3]=[]
var walking:=false
var stuck_seconds:=0.0
var stage:=0
var panel: PanelContainer
var heading: Label
var detail: Label
var progress: ProgressBar
var hose: MeshInstance3D
var nozzle: Node3D
var hand: BoneAttachment3D
var hose_clock:=0.0
var pump_point:=Vector3.ZERO
const REPAIR_SECONDS:=12.0
const FUEL_RATE:=3.0
func build(owner_main) -> void:
 main=owner_main
 var layer:=CanvasLayer.new()
 layer.layer=34
 add_child(layer)
 panel=PanelContainer.new()
 panel.position=Vector2(28,850)
 panel.size=Vector2(664,220)
 var style:=StyleBoxFlat.new()
 style.bg_color=Color("17282df0")
 style.set_content_margin_all(18)
 panel.add_theme_stylebox_override("panel",style)
 layer.add_child(panel)
 var box:=VBoxContainer.new()
 box.add_theme_constant_override("separation",12)
 panel.add_child(box)
 heading=Label.new()
 heading.add_theme_font_size_override("font_size",27)
 box.add_child(heading)
 detail=Label.new()
 detail.add_theme_font_size_override("font_size",21)
 box.add_child(detail)
 progress=ProgressBar.new()
 progress.custom_minimum_size=Vector2(600,22)
 box.add_child(progress)
 var cancel:=Button.new()
 cancel.text="中断操作 · Esc"
 cancel.custom_minimum_size=Vector2(600,52)
 main._style_button(cancel,Color("6b4b3f"))
 box.add_child(cancel)
 cancel.pressed.connect(func():stop("操作已中断，已完成的部分保留。"))
 panel.hide()
func reason(operation: String) -> String:
 if active:return "正在操作中。"
 if main.phase in [main.Phase.TITLE,main.Phase.GAME_OVER] or main.hotaru.dead:return "现在无法操作。"
 if not main.controls_enabled:return "请先结束当前操作。"
 if main.in_vehicle or main.inside_rv or main.inside_store:return "请先停车，下车到车辆旁操作。"
 if main.rv.wrecked:return "车辆已被摧毁。"
 if absf(main.rv.speed)>.3:return "请先将车辆停稳。"
 if main.is_under_attack():return "附近有攻击，请先确保安全。"
 if main.hotaru.global_position.distance_to(main.rv.global_position)>9:return "请先靠近停放的房车。"
 if operation=="repair":
  if not main.repair_shop.is_on_site():return "请将房车停入修理厂黄色检修位。"
  if main.rv.health>=main.rv.max_health and not GameState.fences_need_repair():return "房车耐久已满。"
 else:
  if not main.gas_station.is_parked():return "请把房车沿白线停到加油枪旁的车道内。"
  if GameState.fuel_l>=GameState.FUEL_CAPACITY_L-.001:return "油箱已满。"
 return ""
func begin(operation: String) -> bool:
 var blocked:=reason(operation)
 if not blocked.is_empty():main.rest_notice(blocked);return false
 kind=operation
 active=true
 work_seconds=0
 changed_amount=0
 stage=0
 stuck_seconds=0
 fence_start=GameState.fence_hp.duplicate(true)
 repair_rate=float(main.rv.max_health-main.rv.health)/REPAIR_SECONDS
 main.controls_enabled=false
 main.rv.set_active(false)
 main.hotaru.set_active(true)
 main.hotaru.sync_equipment()
 main.hotaru.servicing=true
 for attachment in main.hotaru._bat_attachments.values():attachment.hide()
 if kind=="fuel":
  pump_point=main.gas_station.nearest_pump()
  var local_pump: Vector3=main.rv.to_local(pump_point)
  var side:=1.0 if local_pump.x>=0 else -1.0
  work_target=main.rv.to_global(Vector3(side*1.75,-.07,clampf(local_pump.z,-2.5,2.5)))
  _create_nozzle()
 else:work_target=main.rv.to_global(Vector3(-1.7,-.07,-1.8))
 _plan_walk()
 heading.text="蛍正在检修房车" if kind=="repair" else "蛍正在加油"
 panel.show()
 return true
func _process(delta: float) -> void:
 if not active:return
 if main.hotaru.dead or main.rv.wrecked or main.phase==main.Phase.GAME_OVER:stop("操作中断。");return
 if main.is_under_attack():stop("附近出现攻击，操作已中断。");return
 if absf(main.rv.speed)>.3:stop("车辆移动，操作已中断。");return
 if main.inside_rv or main.in_vehicle or main.inside_store:stop("离开操作位置，操作已中断。");return
 if kind=="fuel" and not main.gas_station.is_parked():stop("车辆偏离加油车道。");return
 if walking:
  _walk_to_work(delta)
 else:
  work_seconds+=delta
  main.hotaru._play_character_animation("RepairKneel" if kind=="repair" else "FuelHold")
  if kind=="repair":
   for side in fence_start:
    var hp:=int(fence_start[side])
    if hp>0 and int(GameState.fence_hp.get(side,0))>0:GameState.fence_hp[side]=mini(500,hp+int((500-hp)*minf(1,work_seconds/REPAIR_SECONDS)))
   var restore:=mini(main.rv.max_health-main.rv.health,int(floor(work_seconds*repair_rate))-int(changed_amount))
   if restore>0:
    main.rv.health+=restore
    changed_amount+=restore
    main.rv._update_damage_effects()
    main.rv.health_changed.emit(main.rv.health,main.rv.max_health)
   var next_stage:=mini(2,int(work_seconds/4.0))
   if next_stage>stage:
    stage=next_stage
    work_target=main.rv.to_global(Vector3(-1.7,-.07,1.8 if stage==1 else 0.0))
    _plan_walk()
   if work_seconds>=REPAIR_SECONDS:
    main.rv.repair_full()
    stop("现场检修完成，房车耐久已恢复。");return
   if AudioDirector._allow("service_tools",1.8):AudioDirector.sound("repair",main.hotaru.global_position,-22)
  else:
   var added:=minf(FUEL_RATE*delta,GameState.FUEL_CAPACITY_L-GameState.fuel_l)
   GameState.fuel_l+=added
   changed_amount+=added
   GameState.survival_changed.emit()
   if GameState.fuel_l>=GameState.FUEL_CAPACITY_L-.0001:
    GameState.fuel_l=GameState.FUEL_CAPACITY_L
    stop("加油完成，油箱已加满。");return
 if kind=="fuel":
  progress.value=GameState.fuel_l/GameState.FUEL_CAPACITY_L*100
  detail.text="%s · 油箱 %.1f / %.0f L · 已加 %.1f L"%["走向油泵" if walking else "加油中",GameState.fuel_l,GameState.FUEL_CAPACITY_L,changed_amount]
  nozzle.visible=not walking
  hose.visible=not walking
  hose_clock+=delta
  if hose_clock>=.1:
   hose_clock=0
   _draw_hose()
 else:
  progress.value=work_seconds/REPAIR_SECONDS*100
  detail.text="%s · 耐久 %d / %d · 剩余约 %.0f 秒"%["更换检修位置" if walking else "蹲下检修中",main.rv.health,main.rv.max_health,maxf(0,REPAIR_SECONDS-work_seconds)]
func _plan_walk() -> void:
 waypoints.clear()
 var here: Vector3=main.rv.to_local(main.hotaru.global_position)
 var target: Vector3=main.rv.to_local(work_target)
 # Walk around a bumper when switching sides; never cut through the hull.
 if here.x*target.x<0 and absf(here.z)<3.8:
  var end_z: float=-3.9 if here.z+target.z<0 else 3.9
  waypoints.append(main.rv.to_global(Vector3(signf(here.x)*1.95,-.07,end_z)))
  waypoints.append(main.rv.to_global(Vector3(target.x,-.07,end_z)))
 waypoints.append(work_target)
 walking=true
 stuck_seconds=0
func _walk_to_work(delta: float) -> void:
 var offset: Vector3=waypoints[0]-main.hotaru.global_position
 offset.y=0
 if offset.length()<.12:
  waypoints.pop_front()
  if not waypoints.is_empty():return
  walking=false
  main.hotaru.velocity=Vector3.ZERO
  var facing: Vector3=main.rv.global_position-main.hotaru.global_position
  main.hotaru.rotation.y=atan2(facing.x,facing.z)
  main.hotaru._play_character_animation("RepairKneel" if kind=="repair" else "FuelHold",true)
  return
 main.hotaru._play_character_animation("Walk")
 main.hotaru.rotation.y=atan2(offset.x,offset.z)
 main.hotaru._step_last_position=main.hotaru.global_position
 main.hotaru.velocity=offset.normalized()*minf(3.0,offset.length()/maxf(.001,delta))
 main.hotaru.move_and_slide()
 main.hotaru.global_position.y=.95
 if main.hotaru.global_position.distance_to(main.hotaru._step_last_position)<.01:stuck_seconds+=delta
 else:stuck_seconds=0
 if stuck_seconds>2.5:stop("操作位置被挡住，请换一个停车位置。")
func stop(message: String) -> void:
 if not active:return
 active=false
 panel.hide()
 main.hotaru.servicing=false
 main.hotaru.velocity=Vector3.ZERO
 if is_instance_valid(hand):hand.queue_free()
 if is_instance_valid(hose):hose.queue_free()
 if not main.hotaru.dead:
  main.controls_enabled=true
  main.hotaru.sync_equipment()
  main.hotaru.set_active(true)
 main.rest_notice(message)
func _unhandled_input(event: InputEvent) -> void:
 if active and event.is_action_pressed("ui_cancel"):
  stop("操作已中断，已完成的部分保留。")
  get_viewport().set_input_as_handled()
func _create_nozzle() -> void:
 var skeleton: Skeleton3D=main.hotaru._character_model.find_children("*","Skeleton3D",true,false)[0]
 hand=BoneAttachment3D.new()
 hand.bone_name="Hand.R"
 skeleton.add_child(hand)
 nozzle=Node3D.new()
 hand.add_child(nozzle)
 var grip:=MeshInstance3D.new()
 var shape:=BoxMesh.new()
 shape.size=Vector3(.09,.19,.06)
 grip.mesh=shape
 grip.position.y=-.06
 var mat:=StandardMaterial3D.new()
 mat.albedo_color=Color("333c34")
 grip.material_override=mat
 nozzle.add_child(grip)
 var spout:=MeshInstance3D.new()
 var tube:=CylinderMesh.new()
 tube.top_radius=.018
 tube.bottom_radius=.018
 tube.height=.23
 spout.mesh=tube
 spout.rotation.z=PI/2
 spout.position=Vector3(.10,.015,0)
 spout.material_override=mat
 nozzle.add_child(spout)
 hose=MeshInstance3D.new()
 var material:=StandardMaterial3D.new()
 material.albedo_color=Color("171a18")
 material.cull_mode=BaseMaterial3D.CULL_DISABLED
 hose.material_override=material
 nozzle.hide()
 hose.hide()
 main.add_child(hose)
func _draw_hose() -> void:
 if not is_instance_valid(hose) or not is_instance_valid(hand):return
 var surface:=SurfaceTool.new()
 surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 var start:=pump_point+Vector3(0,1.5,0)
 var end:=hand.global_position
 for i in range(12):
  var ta:=float(i)/12
  var tb:=float(i+1)/12
  var a:=start.lerp(end,ta)+Vector3.DOWN*sin(ta*PI)*.55
  var b:=start.lerp(end,tb)+Vector3.DOWN*sin(tb*PI)*.55
  var side: Vector3=(b-a).normalized().cross(Vector3.UP).normalized()*.025
  for p in [a-side,b-side,a+side,a+side,b-side,b+side]:surface.add_vertex(p)
 surface.generate_normals()
 hose.mesh=surface.commit()
