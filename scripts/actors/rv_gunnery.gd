extends Node3D
const RANGE:=100.0
const DAMAGE:=5
const INTERVAL:=.12
const WINDOW_Z:=1.45
var main
var active:=false
var side:=1
var yaw:=0.0
var pitch:=-.075
var firing:=false
var fire_finger:=-1
var aim_finger:=-1
var mouse_aim:=false
var touches: Dictionary={}
var cooldown:=0.0
var recoil:=0.0
var hit_time:=0.0
var proxy: Node3D
var gun: Node3D
var flash: MeshInstance3D
var animations: AnimationPlayer
var clips: Dictionary={}
var hud: CanvasLayer
var screen: Control
var ammo_label: Label
var fire_button: Button
var leave_button: Button
var unmount_button: Button
var mounted: Dictionary={}
var exterior_mounted: Dictionary={}
var return_position:=Vector3.ZERO
var shots:=0
class Reticle extends Control:
 var controller
 func _draw() -> void:
  var p:=Vector2(360,640)
  var color:=Color("f9b190") if controller.hit_time>0 else Color("fff3d7")
  for d in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:draw_line(p+d*7,p+d*19,color,2,true)
  draw_circle(p,2,color)
func build(owner_main) -> void:
 main=owner_main
 process_mode=Node.PROCESS_MODE_ALWAYS
 for s in [-1,1]:
  var model: Node3D=load("res://assets/weapon_shop/m60_mounted.glb").instantiate()
  main.rv_interior.add_child(model)
  model.position=Vector3(s*1.08,1.24,.91)
  model.rotation.y=s*PI/2
  model.scale=Vector3.ONE*.85
  mounted[s]=model
  var metal:=StandardMaterial3D.new()
  metal.albedo_color=Color("4d5b59")
  for y in [.49,1.02]:_box(main.rv,Vector3(.10,.045,.96),Vector3(s*1.10,y,WINDOW_Z),metal)
  for z in [.99,1.91]:_box(main.rv,Vector3(.10,.57,.045),Vector3(s*1.10,.755,z),metal)
  var exterior: Node3D=load("res://assets/weapon_shop/m60_mounted.glb").instantiate()
  exterior.name="ExteriorM60_"+("Left" if s<0 else "Right")
  main.rv.add_child(exterior)
  exterior.position=Vector3(s*.78,.60,WINDOW_Z)
  exterior.rotation.y=s*PI/2
  exterior.scale=Vector3.ONE*.85
  exterior_mounted[s]=exterior
  exterior.hide()
 proxy=Node3D.new()
 proxy.process_mode=Node.PROCESS_MODE_PAUSABLE
 add_child(proxy)
 var character: Node3D=load("res://assets/characters/anime-girl/hotaru_gunnery.glb").instantiate()
 proxy.add_child(character)
 for player in character.find_children("*","AnimationPlayer",true,false):
  animations=player
  for clip in player.get_animation_list():
   for state in ["GunHold","GunFire"]:
    if str(clip).ends_with(state):clips[state]=clip
  if clips.has("GunHold"):player.get_animation(clips.GunHold).loop_mode=Animation.LOOP_LINEAR
 gun=load("res://assets/weapon_shop/m60_mounted.glb").instantiate()
 proxy.add_child(gun)
 gun.position=Vector3(-.18,1.18,.28)
 flash=MeshInstance3D.new()
 var mesh:=SphereMesh.new()
 mesh.radius=.065
 mesh.height=.24
 flash.mesh=mesh
 flash.position=Vector3(0,.025,.91)
 flash.rotation.x=PI/2
 var glow:=StandardMaterial3D.new()
 glow.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 glow.albedo_color=Color("ffd58a")
 glow.emission_enabled=true
 glow.emission=Color("ffad3e")
 flash.material_override=glow
 flash.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 gun.add_child(flash)
 flash.hide()
 proxy.hide()
 hud=CanvasLayer.new()
 hud.layer=42
 add_child(hud)
 screen=Reticle.new()
 screen.controller=self
 screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 screen.mouse_filter=Control.MOUSE_FILTER_IGNORE
 hud.add_child(screen)
 var ammo_back=ColorRect.new()
 ammo_back.position=Vector2(24,242)
 ammo_back.size=Vector2(672,120)
 ammo_back.color=Color(0.04,0.09,0.10,0.78)
 ammo_back.mouse_filter=Control.MOUSE_FILTER_IGNORE
 screen.add_child(ammo_back)
 ammo_label=Label.new()
 ammo_label.position=Vector2(32,250)
 ammo_label.size=Vector2(656,110)
 ammo_label.add_theme_font_size_override("font_size",22)
 ammo_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 screen.add_child(ammo_label)
 fire_button=_button("按住开火",Vector2(32,1070),Vector2(190,110))
 leave_button=_button("收枪离开",Vector2(490,1070),Vector2(200,80))
 unmount_button=_button("拆卸机枪",Vector2(490,1170),Vector2(200,70))
 leave_button.pressed.connect(stop)
 unmount_button.pressed.connect(func():GameState.m60_window="";stop())
 for b in [fire_button,leave_button,unmount_button]:
  if main.mobile_joystick.mobile:b.mouse_filter=Control.MOUSE_FILTER_IGNORE
 screen.hide()
 _refresh_mounted_models()
func _button(text_value: String,p: Vector2,dimensions: Vector2) -> Button:
 var b:=Button.new()
 b.text=text_value
 b.position=p
 b.size=dimensions
 main._style_button(b,Color("4d5347"))
 screen.add_child(b)
 return b
func _box(parent: Node,size_value: Vector3,p: Vector3,material: Material) -> void:
 var instance:=MeshInstance3D.new()
 var mesh:=BoxMesh.new()
 mesh.size=size_value
 instance.mesh=mesh
 instance.position=p
 instance.material_override=material
 parent.add_child(instance)
func start(window_side: int) -> bool:
 if active or not main.inside_rv or main.seated_at_driver or main.rv.wrecked or not main.controls_enabled or get_tree().paused:return false
 if int(GameState.cargo.get("m60",0))<1:
  main.rest_notice("需要先把 M60 运入房车货舱，才能在射击窗架设。")
  return false
 side=-1 if window_side<0 else 1
 GameState.m60_window="left" if side<0 else "right"
 return_position=main.hotaru.global_position
 main._camera_mouse_dragging=false
 main._camera_touch_points.clear()
 main.hotaru.cancel_boarding_step()
 main.hotaru.set_active(false)
 main.hotaru.hide()
 main.mobile_joystick.reset()
 active=true
 yaw=0
 pitch=-.075
 cooldown=.35
 recoil=0
 clear_input()
 main.rv_interior.hide()
 main.world_root.show()
 main.rv.show()
 proxy.show()
 _refresh_mounted_models()
 screen.show()
 _play("GunHold")
 for z in get_tree().get_nodes_in_group("zombies"):
  z.visible=not z.is_in_group("store_indoor_zombies")
 update_camera(0)
 return true
func stop(restore: bool=true) -> void:
 if not active:return
 active=false
 main.camera.fov=52
 main.camera.near=.15
 clear_input()
 screen.hide()
 proxy.hide()
 _refresh_mounted_models()
 if animations:animations.stop()
 main.mobile_joystick.reset()
 if restore and main.inside_rv and not main.rv.wrecked:
  main.world_root.hide()
  main.rv.hide()
  main.rv_interior.show()
  main.hotaru.global_position=return_position
  main.hotaru.show()
  main.hotaru.set_active(main.hotaru.health>0)
  main._update_camera(100)
func clear_input() -> void:
 firing=false
 fire_finger=-1
 aim_finger=-1
 mouse_aim=false
 touches.clear()
func _process(delta: float) -> void:
 if not is_instance_valid(main):return
 _refresh_mounted_models()
 if not active:return
 if get_tree().paused:clear_input();return
 if main.rv.wrecked or main.hotaru.health<=0 or not main.inside_rv:stop(false);return
 cooldown=maxf(0,cooldown-delta)
 recoil=move_toward(recoil,0,delta*8)
 hit_time=maxf(0,hit_time-delta)
 fire_button.modulate=Color("ffd38b") if firing else Color.WHITE
 flash.visible=recoil>.65
 if firing and cooldown<=0:fire_round()
 if cooldown<=0 and is_instance_valid(animations) and clips.has("GunHold") and animations.current_animation!=clips.GunHold:_play("GunHold")
 screen.queue_redraw()

func _refresh_mounted_models() -> void:
 if not is_instance_valid(main):return
 var has_weapon:=int(GameState.cargo.get("m60",0))>0
 for mounted_side in mounted:
  var matches:=has_weapon and GameState.m60_window==("left" if mounted_side<0 else "right")
  # Exactly one representation is allowed in each view: cabin display while
  # walking inside, exterior display in town, proxy gun while actively aiming.
  mounted[mounted_side].visible=matches and not active
  exterior_mounted[mounted_side].visible=matches and not active and not main.inside_rv
 if is_instance_valid(gun):gun.visible=active
func update_camera(_delta: float) -> void:
 var angle: float=main.rv.rotation.y+side*PI/2+yaw
 var direction:=Vector3(sin(angle)*cos(pitch),sin(pitch),cos(angle)*cos(pitch))
 var shoulder: Vector3=main.rv.to_global(Vector3(side*.62,-.62,WINDOW_Z))
 var eye: Vector3=shoulder-Vector3(sin(angle),0,cos(angle))*.78+Vector3(-cos(angle),0,sin(angle))*.19+Vector3.UP*1.52
 main.camera.projection=Camera3D.PROJECTION_PERSPECTIVE
 main.camera.keep_aspect=Camera3D.KEEP_HEIGHT
 main.camera.fov=62
 main.camera.near=.035
 main.camera.global_position=eye
 main.camera.look_at(main.camera.global_position+direction,Vector3.UP)
 proxy.global_position=main.rv.to_global(Vector3(side*.62,-.62,WINDOW_Z))
 proxy.rotation.y=angle
 gun.position=Vector3(-.18,1.18,.28-recoil*.055)
 gun.rotation.x=-pitch
func muzzle() -> Vector3:
 return main.rv.to_global(Vector3(side*1.15,.60,WINDOW_Z))
func fire_round() -> bool:
 if not active or get_tree().paused or cooldown>0 or main.rv.wrecked:return false
 if int(GameState.cargo.get("m60",0))<1 or int(GameState.cargo.get("m60_ammo",0))<=0:
  firing=false
  main.rest_notice("M60 弹药耗尽。请先补充房车货舱中的弹药。")
  return false
 GameState.cargo.m60_ammo-=1
 if GameState.cargo.m60_ammo<=0:GameState.cargo.erase("m60_ammo")
 GameState.inventory_changed.emit()
 cooldown=INTERVAL
 recoil=1
 shots+=1
 _play("GunFire")
 var camera: Camera3D=main.camera
 var origin:=camera.project_ray_origin(Vector2(360,640))
 var direction:=camera.project_ray_normal(Vector2(360,640))
 var excluded: Array[RID]=[main.rv.get_rid(),main.hotaru.get_rid()]
 var space:=get_world_3d().direct_space_state
 var aim:=space.intersect_ray(PhysicsRayQueryParameters3D.create(origin,origin+direction*(RANGE+5),7,excluded))
 var point: Vector3=aim.position if not aim.is_empty() else origin+direction*(RANGE+5)
 var start:=muzzle()
 var ray: Vector3=(point-start).normalized()
 var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(start,start+ray*RANGE,7,excluded))
 var end: Vector3=start+ray*RANGE
 if not hit.is_empty():
  end=hit.position
  if hit.collider.is_in_group("zombies") and not hit.collider._dying:
   hit.collider.take_damage(DAMAGE)
   hit_time=.15
   AudioDirector.sound("bat_hit",end,-22)
 _tracer(start,end)
 AudioDirector.sound("m60_shot",start,-5)
 return true
func _tracer(a: Vector3,b: Vector3) -> void:
 if a.distance_to(b)<.05:return
 var line:=MeshInstance3D.new()
 var mesh:=CylinderMesh.new()
 mesh.top_radius=.009
 mesh.bottom_radius=.009
 mesh.height=a.distance_to(b)
 mesh.radial_segments=4
 line.mesh=mesh
 var mat:=StandardMaterial3D.new()
 mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 mat.albedo_color=Color("ffdb8a")
 line.material_override=mat
 line.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 add_child(line)
 line.global_position=(a+b)*.5
 line.quaternion=Quaternion(Vector3.UP,(b-a).normalized())
 var tween:=create_tween()
 tween.tween_interval(.045)
 tween.tween_callback(line.queue_free)
func _play(state: String) -> void:
 if is_instance_valid(animations) and clips.has(state):
  animations.play(clips[state],.035)
  animations.advance(0)
func aim_by(relative: Vector2) -> void:
 yaw=clampf(yaw-relative.x*.003,-.78,.78)
 pitch=clampf(pitch-relative.y*.0025,-.68,.35)
 update_camera(0)
func update_hud() -> void:
 for b in [main.interact_button,main.attack_button,main.vehicle_button,main.upgrade_button]:b.hide()
 for b in get_tree().get_nodes_in_group("movement_controls"):b.hide()
 main.hint_label.text=""
 main.objective_label.text=""
 ammo_label.text=("左" if side<0 else "右")+"侧射击窗 · M60\n弹药 %d 发 · 房车耐久 %d%%\n"%[int(GameState.cargo.get("m60_ammo",0)),int(main.rv.health*100.0/main.rv.max_health)]+("拖动屏幕瞄准 · 左下按住开火" if main.mobile_joystick.mobile else "右键拖动瞄准 · 按住左键开火 · E / Esc 离开")
func _input(event: InputEvent) -> void:
 if not active or get_tree().paused:return
 if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_E,KEY_ESCAPE]:
  stop()
  get_viewport().set_input_as_handled()
 elif event is InputEventMouse and event.device==InputEvent.DEVICE_ID_EMULATION:
  # Mobile buttons are dispatched independently from mouse emulation.
  if main.mobile_joystick.mobile and event.position.y>230:get_viewport().set_input_as_handled()
 elif event is InputEventMouseButton:
  if event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:
   var was_firing:=firing
   firing=false
   if was_firing:get_viewport().set_input_as_handled()
   return
  if event.position.y<230:return
  if event.button_index==MOUSE_BUTTON_RIGHT:mouse_aim=event.pressed;get_viewport().set_input_as_handled()
  elif event.button_index==MOUSE_BUTTON_LEFT and not leave_button.get_global_rect().has_point(event.position) and not unmount_button.get_global_rect().has_point(event.position):
   firing=event.pressed
   get_viewport().set_input_as_handled()
 elif event is InputEventMouseMotion and mouse_aim:
  aim_by(event.relative)
  get_viewport().set_input_as_handled()
 elif event is InputEventScreenTouch:
  if not event.pressed:
   if event.index==fire_finger:fire_finger=-1;firing=false
   elif event.index==aim_finger:aim_finger=-1
   elif touches.has(event.index):
    var b: Button=touches[event.index]
    touches.erase(event.index)
    if b.get_global_rect().has_point(event.position):b.pressed.emit()
   else:return
   get_viewport().set_input_as_handled()
  elif fire_button.get_global_rect().has_point(event.position):
   fire_finger=event.index
   firing=true
   get_viewport().set_input_as_handled()
  elif leave_button.get_global_rect().has_point(event.position) or unmount_button.get_global_rect().has_point(event.position):
   touches[event.index]=leave_button if leave_button.get_global_rect().has_point(event.position) else unmount_button
   get_viewport().set_input_as_handled()
  elif event.position.y>230 and aim_finger<0:
   aim_finger=event.index
   get_viewport().set_input_as_handled()
 elif event is InputEventScreenDrag and event.index==aim_finger:
  aim_by(event.relative)
  get_viewport().set_input_as_handled()
func _notification(what: int) -> void:
 if what in [NOTIFICATION_WM_WINDOW_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED]:clear_input()
