extends CanvasLayer
const SIDES: Array[String]=["front","back","left","right"]
const NAMES: Dictionary={"front":"前方","back":"后方","left":"左侧","right":"右侧"}
var main
var veil: ColorRect
var info: Label
var status: Label
var buttons: Dictionary={}
var visuals: Dictionary={}
var _paused_before:=false
var active:=false
var operation:=""
var install_button: Button
var work_panel: PanelContainer
var work_label: Label
var work_progress: ProgressBar
var work_target:=Vector3.ZERO
var waypoints: Array[Vector3]=[]
var walking:=false
var stuck:=0.0
var hand: BoneAttachment3D
var rv_anchor:=Vector3.ZERO
var _tool_clock:=0.0
func build(owner_main) -> void:
 main=owner_main;layer=38;process_mode=Node.PROCESS_MODE_ALWAYS
 veil=ColorRect.new();veil.color=Color(0.02,.04,.05,.92);veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(veil)
 var panel:=PanelContainer.new();panel.position=Vector2(24,100);panel.size=Vector2(672,1080)
 var style:=StyleBoxFlat.new();style.bg_color=Color("182d30");style.set_content_margin_all(22);style.set_corner_radius_all(18);panel.add_theme_stylebox_override("panel",style);veil.add_child(panel)
 var box:=VBoxContainer.new();box.add_theme_constant_override("separation",16);panel.add_child(box)
 var title:=Label.new();title.text="工作台 · 车床生产";title.add_theme_font_size_override("font_size",28);box.add_child(title)
 info=Label.new();info.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;info.add_theme_font_size_override("font_size",21);box.add_child(info)
 status=Label.new();status.custom_minimum_size=Vector2(0,92);status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;status.add_theme_font_size_override("font_size",22);box.add_child(status)
 for side in SIDES:
  var button:=Button.new();button.custom_minimum_size=Vector2(0,126);button.add_theme_font_size_override("font_size",21);main._style_button(button,Color("36534f"));box.add_child(button);buttons[side]=button
  button.pressed.connect(func():start(side))
 var help:=Label.new();help.text="每面加工1游戏小时(正常速度约15秒)。\n小萤必须在车床操作，中断后回来继续。\n完成后下车安装，安装也可中断并保留进度。\n每面500次防护；修理不复活已击毁的围栏。";help.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;help.add_theme_font_size_override("font_size",19);box.add_child(help)
 var close_button:=Button.new();close_button.text="关闭 · 返回车内";close_button.custom_minimum_size=Vector2(0,60);main._style_button(close_button,Color("574633"));box.add_child(close_button);close_button.pressed.connect(close)
 veil.hide()
 install_button=Button.new();install_button.text="安装围栏";install_button.position=Vector2(370,910);install_button.size=Vector2(150,72);main._style_button(install_button,Color("574633"));add_child(install_button);install_button.pressed.connect(begin_install);install_button.hide()
 if main.mobile_joystick.mobile:install_button.mouse_filter=Control.MOUSE_FILTER_IGNORE
 work_panel=PanelContainer.new();work_panel.position=Vector2(28,750);work_panel.size=Vector2(664,230);work_panel.add_theme_stylebox_override("panel",style);add_child(work_panel)
 var work_box:=VBoxContainer.new();work_box.add_theme_constant_override("separation",10);work_panel.add_child(work_box)
 work_label=Label.new();work_label.add_theme_font_size_override("font_size",22);work_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;work_box.add_child(work_label)
 work_progress=ProgressBar.new();work_progress.custom_minimum_size=Vector2(0,26);work_progress.show_percentage=true;work_box.add_child(work_progress)
 var pause_button:=Button.new();pause_button.text="暂停操作 · 保留进度 / Esc";pause_button.custom_minimum_size=Vector2(0,52);main._style_button(pause_button,Color("574633"));work_box.add_child(pause_button);pause_button.pressed.connect(func():stop_work("操作已暂停，进度保留。"));work_panel.hide()
 for side in SIDES:
  var root:=Node3D.new();root.name="WireFence_"+side;main.rv.add_child(root);visuals[side]=root
  if side in ["left","right"]:
   for z in [-2.08,0.0,2.08]:_panel(root,Vector3(-1.20 if side=="left" else 1.20,-.78,z),0)
  else:_panel(root,Vector3(0,-.78,-3.30 if side=="front" else 3.30),PI/2)
  root.hide()
func _panel(parent: Node3D,point: Vector3,angle: float) -> void:
 var model: Node3D=load("res://assets/factory/fence.glb").instantiate();model.position=point;model.rotation.y=angle;parent.add_child(model)
 var shader:=Shader.new()
 shader.code="""shader_type spatial;
render_mode cull_disabled;
varying vec3 local_point;
void vertex(){local_point=VERTEX;}
void fragment(){float a=(local_point.y+local_point.z)*6.0;float b=(local_point.y-local_point.z)*6.0;float da=abs(fract(a)-.5);float db=abs(fract(b)-.5);float aa=max(fwidth(a),.005);float ab=max(fwidth(b),.005);float ca=1.0-smoothstep(max(.025,aa*.45),max(.025,aa*.45)+aa,da);float cb=1.0-smoothstep(max(.025,ab*.45),max(.025,ab*.45)+ab,db);ALBEDO=vec3(.47,.57,.52);METALLIC=.35;ROUGHNESS=.65;ALPHA=max(ca,cb);ALPHA_SCISSOR_THRESHOLD=.25;}
"""
 var net:=ShaderMaterial.new();net.shader=shader
 for node in model.find_children("*","MeshInstance3D",true,false):node.material_override=net
 var trim:=StandardMaterial3D.new();trim.albedo_color=Color("86978d");trim.metallic=.5;trim.roughness=.65
 for z in [-1.0,1.0]:_bar(model,Vector3(.035,1.02,.035),Vector3(0,.49,z),trim)
 for y in [.08,.96]:_bar(model,Vector3(.035,.035,2),Vector3(0,y,0),trim)
func open() -> void:
 if veil.visible or active or not GameState.lathe_installed or not main.inside_rv or main.in_vehicle or main.hotaru.dead or main.dialog_panel.visible:return
 GameState.normalize_fence_job()
 _paused_before=get_tree().paused
 main.mobile_joystick.reset()
 veil.show();refresh();get_tree().paused=true
func close() -> void:
 if not veil.visible:return
 veil.hide();get_tree().paused=_paused_before
func start(side: String) -> void:
 GameState.normalize_fence_job()
 if GameState.fence_job.is_empty():
  if not GameState.start_fence_job(side):refresh();return
 if str(GameState.fence_job.side)!=side:return
 if str(GameState.fence_job.stage)=="install":close();main.rest_notice("此面已加工完成，请下车到房车旁安装。");return
 close();begin_craft()
func _can_start() -> bool:
 return not active and main.controls_enabled and not get_tree().paused and not main.hotaru.dead and not main.rv.wrecked and not main.dialog_panel.visible and not GameState.fence_job.is_empty()
func begin_craft() -> bool:
 if not _can_start() or not main.inside_rv or GameState.fence_job.stage!="craft":return false
 operation="craft";_begin()
 main.hotaru.cancel_boarding_step()
 main.hotaru.position=main.RV_INTERIOR_ORIGIN+Vector3(.10,1.13,-2.04);main.hotaru.rotation.y=-PI/2
 walking=false
 main.hotaru._play_character_animation("LatheWork",true)
 return true
func can_install() -> bool:
 return not active and not GameState.fence_job.is_empty() and str(GameState.fence_job.get("stage",""))=="install" and not main.inside_rv and not main.inside_store and not main.factory.active and not main.in_vehicle and main.controls_enabled and not main.hotaru.dead and not main.rv.wrecked and absf(main.rv.speed)<.3 and main.hotaru.global_position.distance_to(main.rv.global_position)<7 and not main.trolley.pushing and not main.trolley.loading
func begin_install() -> bool:
 if not can_install() or get_tree().paused:return false
 if main.is_under_attack():main.rest_notice("附近有攻击，请先确保安装安全。");return false
 operation="install";_begin()
 var side: String=GameState.fence_job.side
 var point: Vector3={"front":Vector3(0,-.07,-4),"back":Vector3(0,-.07,4),"left":Vector3(-1.95,-.07,0),"right":Vector3(1.95,-.07,0)}[side]
 work_target=main.rv.to_global(point);rv_anchor=main.rv.global_position
 waypoints=[]
 var here: Vector3=main.rv.to_local(main.hotaru.global_position)
 if is_zero_approx(point.x):
  var side_x: float=1.95 if here.x>=0 else -1.95
  waypoints.append(main.rv.to_global(Vector3(side_x,-.07,point.z)))
 elif here.x*point.x<0:
  var end_z: float=-4.0 if here.z<0 else 4.0
  waypoints.append(main.rv.to_global(Vector3(signf(here.x)*1.95,-.07,end_z)))
  waypoints.append(main.rv.to_global(Vector3(point.x,-.07,end_z)))
 elif absf(here.x)<1.2:
  waypoints.append(main.rv.to_global(Vector3(point.x,-.07,-4 if here.z<0 else 4)))
 waypoints.append(work_target);walking=true;stuck=0
 return true
func _begin() -> void:
 active=true;main.controls_enabled=false;main.mobile_joystick.reset();main.trolley.release()
 main.hotaru.set_active(true);main.hotaru.servicing=true;main.hotaru.velocity=Vector3.ZERO;main.hotaru.sync_equipment()
 for attachment in main.hotaru._bat_attachments.values():attachment.hide()
 _make_tool();work_panel.show();install_button.hide()
func stop_work(message: String="") -> void:
 if not active:return
 active=false;walking=false;work_panel.hide()
 main.hotaru.servicing=false;main.hotaru.velocity=Vector3.ZERO
 if is_instance_valid(hand):hand.queue_free()
 if not main.hotaru.dead:
  main.controls_enabled=true;main.hotaru.sync_equipment();main.hotaru.set_active(true)
 if not message.is_empty():main.rest_notice(message)
func refresh() -> void:
 GameState.normalize_fence_job()
 info.text="唯一安装位：基础维修台(车床已固定)\n材料：货舱铁丝 %d 份(%.1f kg)\n每面加工1游戏小时 · 完成后下车安装"%[int(GameState.cargo.get("wire",0)),int(GameState.cargo.get("wire",0))*.5]
 status.text="选择一面，小萤将在工作台亲自加工。"
 if not GameState.fence_job.is_empty():
  var job: Dictionary=GameState.fence_job
  status.text=NAMES[job.side]+("围栏待继续加工 · %.0f%%"%(float(job.work)/15*100) if job.stage=="craft" else "围栏已加工好 · 下车安装 %.0f%%"%(float(job.get("install_work",0))/8*100))
 for side in SIDES:
  var recipe:=GameState.fence_recipe(side);var hp:=int(GameState.fence_hp.get(side,0));var same: bool=not GameState.fence_job.is_empty() and str(GameState.fence_job.side)==side
  var action: String="已安装" if hp>0 else ("继续加工" if same and GameState.fence_job.stage=="craft" else ("下车安装" if same else "开始加工"))
  buttons[side].text="%s围栏 · %s\n铁丝 %d 份(%.1f kg) · 1游戏小时\n%s"%[NAMES[side],"耐久 %d / 500"%hp if hp>0 else "无围栏防护",int(recipe.wire),int(recipe.wire)*.5,action]
  buttons[side].disabled=hp>0 or (not GameState.fence_job.is_empty() and not same) or (not same and int(GameState.cargo.get("wire",0))<int(recipe.wire))
func apply_hud() -> void:
 install_button.visible=can_install() and not veil.visible and not get_tree().paused
 if active:
  for button in [main.interact_button,main.attack_button,main.vehicle_button,main.upgrade_button]:button.hide()
  for button in get_tree().get_nodes_in_group("movement_controls"):button.hide()
  main.hint_label.text="";main.objective_label.text=""
func _process(delta: float) -> void:
 for side in SIDES:visuals[side].visible=int(GameState.fence_hp.get(side,0))>0
 if veil.visible:refresh()
 if not active or get_tree().paused:return
 if main.hotaru.dead or main.rv.wrecked or main.phase in [main.Phase.TITLE,main.Phase.GAME_OVER] or GameState.fence_job.is_empty():stop_work("");return
 if operation=="craft" and not main.inside_rv:stop_work("加工暂停，回到车床可继续。");return
 if operation=="install" and (main.rv.global_position.distance_to(rv_anchor)>.1 or main.is_under_attack()):stop_work("安装中断，进度保留。");return
 var job: Dictionary=GameState.fence_job
 var key: String="work" if operation=="craft" else "install_work"
 var duration:=15.0 if operation=="craft" else 8.0
 work_progress.value=float(job.get(key,0))/duration*100
 work_label.text=("正在前往安装位置 · " if walking else ("小萤正在操作车床 · " if operation=="craft" else "小萤正在固定围栏 · "))+NAMES[job.side]+"\n"+("剩余游戏 %.0f 分钟(正常速度 %.1f 秒)"%[(15-float(job.work))*4,15-float(job.work)] if operation=="craft" else "剩余 %.1f 秒 · 中断后可继续"%(8-float(job.get(key,0))))
 if walking:_walk(delta);return
 main.hotaru._play_character_animation("LatheWork" if operation=="craft" else "RepairKneel")
 _tool_clock+=delta
 if _tool_clock>1.8:_tool_clock=0;AudioDirector.sound("repair",main.hotaru.global_position,-25)
 var completed_side: String=job.side
 if GameState.advance_fence_work(delta,operation):
  stop_work(NAMES[completed_side]+("围栏加工完成，请下车安装。" if operation=="craft" else "围栏已安装完成。"))
func _walk(delta: float) -> void:
 var offset: Vector3=waypoints[0]-main.hotaru.global_position;offset.y=0
 if offset.length()<.15:
  waypoints.pop_front()
  if waypoints.is_empty():
   walking=false;main.hotaru.velocity=Vector3.ZERO
   var facing: Vector3=main.rv.global_position-main.hotaru.global_position;main.hotaru.rotation.y=atan2(facing.x,facing.z)
   main.hotaru._play_character_animation("RepairKneel",true)
  return
 var before: Vector3=main.hotaru.global_position
 main.hotaru.rotation.y=atan2(offset.x,offset.z);main.hotaru._play_character_animation("Walk")
 main.hotaru.velocity=offset.normalized()*minf(3,offset.length()/maxf(.001,delta));main.hotaru.move_and_slide();main.hotaru.global_position.y=.95
 stuck=stuck+delta if before.distance_to(main.hotaru.global_position)<.01 else 0
 if stuck>2.5:stop_work("安装位置被挡住，进度保留；请移动房车后重试。")
func _make_tool() -> void:
 var skeletons: Array=main.hotaru._character_model.find_children("*","Skeleton3D",true,false)
 if skeletons.is_empty():return
 hand=BoneAttachment3D.new();hand.bone_name="Hand.R";skeletons[0].add_child(hand)
 var material:=StandardMaterial3D.new();material.albedo_color=Color("657c78");material.metallic=.6
 _bar(hand,Vector3(.06,.08,.16),Vector3(0,0,.06),material)
 _bar(hand,Vector3(.025,.025,.09),Vector3(0,0,.17),material)
func _input(event: InputEvent) -> void:
 if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:
  if active:stop_work("操作已暂停，进度保留。");get_viewport().set_input_as_handled()
  elif veil.visible:close();get_viewport().set_input_as_handled()
func _notification(what: int) -> void:
 if what in [NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_WM_WINDOW_FOCUS_OUT] and active:stop_work("操作已暂停，进度保留。")

func _bar(parent: Node3D,size: Vector3,point: Vector3,material: Material) -> void:
 var node:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=size;node.mesh=mesh;node.position=point;node.material_override=material;parent.add_child(node)
