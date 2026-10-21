extends Node3D
const ORIGIN:=Vector3(3000,0,0)
const SITE:=Vector3(-66,.08,250)
const DOOR:=SITE+Vector3(2.75,.9,-7.4)
const ENTRY:=ORIGIN+Vector3(-.9,1.05,4.9)
# Original exterior includes projecting columns; usable hall is about 9.8 x 14.8m, double height.
const SHELL_OFFSET:=Vector3(1.85,0,1.67)
var main
var active:=false
var room: Node3D
var roller: Node3D
var wires: Node3D
var lathe: Node3D
var installed: Node3D
var enemies: Array=[]
var yaw:=PI
var pitch:=.17
var aim_finger:=-1
var dragging:=false
var return_position:=Vector3.ZERO
var cart_return:=Vector3.ZERO
var outdoor_states: Array=[]
var transitioning:=false
var generation:=0
var hidden_labels: Array=[]
func build(owner_main) -> void:
 main=owner_main
 process_mode=Node.PROCESS_MODE_ALWAYS
 var exterior: Node3D=load("res://assets/factory/factory_open.glb").instantiate()
 exterior.position=SITE
 exterior.rotation.y=PI
 main.world_root.add_child(exterior)
 _solid(main.world_root,Vector3(11.5,10,16.5),SITE+Vector3(1.8,5,1.7))
 main._add_label("缝纫工厂 · 铁丝 / 车床",DOOR+Vector3(0,3.4,0),Color("d9d1aa"),27)
 # Access lane from the west road across the reserved plot.
 main.town_layout._road(Vector2(-120,235),Vector2(-63,235),6)
 main.town_layout._road(Vector2(-63,235),Vector2(-63,240),6)
 roller=Node3D.new()
 roller.position=SITE+Vector3(2.95,0,-5.73)
 roller.rotation.y=PI
 main.world_root.add_child(roller)
 _box(roller,Vector3(3.98,2.55,.09),Vector3(0,1.44,0),Color("52645e"))
 for i in range(10):_box(roller,Vector3(3.98,.018,.11),Vector3(0,.28+i*.25,0),Color("78827a"))
 room=Node3D.new();room.position=ORIGIN;add_child(room)
 var original: Node3D=load("res://assets/factory/factory.glb").instantiate()
 original.name="OriginalFactoryInterior"
 original.position=SHELL_OFFSET
 room.add_child(original)
 # Collision follows the original building instead of replacing its visible shell.
 _solid(room,Vector3(9.5,.12,14.4),Vector3(0,-.03,0))
 for x in [-4.74,4.74]:_solid(room,Vector3(.18,7.4,14.6),Vector3(x,3.7,0))
 for z in [-7.20,7.20]:_solid(room,Vector3(9.6,7.4,.18),Vector3(0,3.7,z))
 _solid(room,Vector3(9.6,.15,14.6),Vector3(0,7.3,0))
 for x in [-3.1,3.1]:
  for z in [-5.0,-1.3,2.4]:
   _box(room,Vector3(1.5,.9,2.2),Vector3(x,.55,z),Color("536861"),true)
   _box(room,Vector3(1.6,.12,2.3),Vector3(x,1.05,z),Color("858a7b"))
   for d in [-.6,.6]:_box(room,Vector3(.8,.25,.35),Vector3(x,1.23,z+d),Color("656b5d"))
 for z in [-5.0,0.0,5.0]:
  var lamp:=OmniLight3D.new();lamp.position=Vector3(0,5.9,z);lamp.light_color=Color("eee4c6");lamp.light_energy=1.35;lamp.omni_range=12;room.add_child(lamp)
  _box(room,Vector3(2,.06,.2),Vector3(0,6.1,z),Color("e4dabc"))
 wires=Node3D.new();room.add_child(wires)
 lathe=load("res://assets/factory/lathe.glb").instantiate();lathe.position=Vector3(3.1,1.13,-1.3);room.add_child(lathe)
 var sign:=Label3D.new();sign.text="24kg车床 · 需推车装运";sign.position=Vector3(2.8,1.9,0);sign.pixel_size=.006;sign.billboard=BaseMaterial3D.BILLBOARD_ENABLED;lathe.add_child(sign);sign.position=Vector3(0,.8,0)
 installed=load("res://assets/factory/lathe.glb").instantiate();installed.position=Vector3(-.85,1.04,-2.04);installed.rotation.y=PI/2;installed.scale=Vector3.ONE*.8;main.rv_interior.add_child(installed)
 room.hide();room.process_mode=Node.PROCESS_MODE_DISABLED
func _box(parent: Node,size: Vector3,point: Vector3,color: Color,solid: bool=false) -> Node3D:
 var mesh:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=size;mesh.mesh=box;mesh.position=point
 var mat:=StandardMaterial3D.new();mat.albedo_color=color;mat.roughness=.9;mesh.material_override=mat;parent.add_child(mesh)
 if solid:_solid(parent,size,point)
 return mesh
func _solid(parent: Node,size: Vector3,point: Vector3) -> void:
 var b:=StaticBody3D.new();b.collision_layer=3;b.collision_mask=0;var c:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=size;c.shape=shape;b.position=point;b.add_child(c);parent.add_child(b)
func nearby() -> bool:
 return not active and not transitioning and not main.in_vehicle and not main.inside_rv and not main.inside_store and main.trolley.near_door(DOOR,3)
func near_exit() -> bool:
 for point in main.trolley.doorway_points():
  var p: Vector3=point-ORIGIN
  if absf(p.x+.9)<2.3 and p.z>6.0:return true
 return false
func reset() -> void:
 generation+=1;transitioning=false
 if active:leave()
 roller.position.y=SITE.y
 dragging=false;aim_finger=-1
 for e in enemies:
  if is_instance_valid(e):e.queue_free()
 enemies=[]
func enter() -> void:
 if not nearby() or not main.controls_enabled:return
 transitioning=true;generation+=1
 var token:=generation
 main.controls_enabled=false;main.hotaru.set_active(false);main.mobile_joystick.reset()
 AudioDirector.sound("door",DOOR)
 var tween:=create_tween();tween.set_pause_mode(Tween.TWEEN_PAUSE_STOP);tween.tween_property(roller,"position:y",SITE.y+2.8,.55)
 await tween.finished
 if token!=generation:return
 if main.hotaru.dead:
  transitioning=false;return
 active=true;transitioning=false
 hidden_labels=[]
 for label in main.hotaru.find_children("*","Label3D",true,false)+main.trolley.visual.find_children("*","Label3D",true,false):
  if label.visible:hidden_labels.append(label);label.hide()
 return_position=main.hotaru.global_position
 var bring: bool=main.trolley.pushing and main.trolley.nearby()
 if bring:
  cart_return=GameState.cart_position
  GameState.cart_exterior_position=cart_return
  GameState.cart_position=ENTRY+Vector3(0,-.89,-1.1)
 main.trolley.release()
 main.world_root.hide();main.rv.hide()
 outdoor_states=[]
 for z in get_tree().get_nodes_in_group("zombies"):
  outdoor_states.append([z,z.visible,z.is_physics_processing()]);z.hide();z.set_physics_process(false)
 room.show();room.process_mode=Node.PROCESS_MODE_PAUSABLE
 main.hotaru.set_ground_height(1.05);main.hotaru.global_position=ENTRY;main.hotaru.rotation.y=PI
 main.hotaru.velocity=Vector3.ZERO;main.hotaru.set_active(true);main.controls_enabled=true
 if bring:main.trolley.interact()
 yaw=PI;pitch=.17;dragging=false;aim_finger=-1
 replenish();spawn_enemies();update_camera(0)
 main.rest_notice("工厂：铁丝可收集，车床需推车。
右侧拖动视角，门前交互离开。")
func replenish() -> void:
 if GameState.factory_refresh_at<0:
  GameState.factory_wire=4;GameState.factory_refresh_at=GameState.world_seconds
 else:
  var elapsed: float=maxf(0,GameState.world_seconds-GameState.factory_refresh_at)
  var gain:=int(elapsed/45)
  GameState.factory_wire=mini(6,GameState.factory_wire+gain)
  GameState.factory_refresh_at+=gain*45
 refresh_loot()
func refresh_loot() -> void:
 for child in wires.get_children():
  child.get_meta("label").queue_free();wires.remove_child(child);child.queue_free()
 var points: Array[Vector3]=[Vector3(-1.2,.12,4.6),Vector3(1.4,.12,3.6),Vector3(-4.6,.12,.6),Vector3(4.6,.12,-3.2),Vector3(-1.5,.12,-6.5),Vector3(1.5,.12,-6.5)]
 for i in range(GameState.factory_wire):
  var item: Node3D=load("res://assets/factory/wire.glb").instantiate();item.position=points[i];item.rotation.z=PI/2;wires.add_child(item)
  var halo:=MeshInstance3D.new();var ring:=TorusMesh.new();ring.inner_radius=.24;ring.outer_radius=.27;ring.rings=16;ring.ring_segments=6;halo.mesh=ring;halo.rotation.z=-PI/2
  var tint:=StandardMaterial3D.new();tint.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;tint.albedo_color=Color("b8b083");halo.material_override=tint;item.add_child(halo)
  _wire_glow(item)
  var marker:=Label3D.new();marker.name="WireMarker";marker.text="铁丝 · 0.5kg";marker.position=points[i]+Vector3(0,.65,0);marker.pixel_size=.0035;marker.billboard=BaseMaterial3D.BILLBOARD_ENABLED;room.add_child(marker);item.set_meta("label",marker)
 lathe.visible=not GameState.lathe_taken
func spawn_enemies() -> void:
 for e in enemies:
  if is_instance_valid(e):e.queue_free()
 enemies=[]
 for p in [Vector3(0,1.05,-3.7),Vector3(-3.8,1.05,-5.7),Vector3(3.8,1.05,-5.7)].slice(0,randi_range(2,3)):
  var z=main.ZombieController.new();room.add_child(z);z.position=p;z.ground_height=1.05;z.set_target(main.hotaru);z.aggro_range=20;z.add_to_group("factory_zombies");enemies.append(z)
func leave() -> void:
 if not active:return
 var bring: bool=main.trolley.pushing and main.trolley.nearby()
 if bring:GameState.cart_position=GameState.cart_exterior_position
 main.trolley.release();active=false;dragging=false;aim_finger=-1
 for mesh in main.hotaru._body_meshes:mesh.transparency=0.0
 for label in hidden_labels:
  if is_instance_valid(label):label.show()
 hidden_labels=[]
 for e in enemies:
  if is_instance_valid(e):e.queue_free()
 enemies=[]
 room.hide();room.process_mode=Node.PROCESS_MODE_DISABLED
 main.world_root.show();main.rv.show()
 for state in outdoor_states:
  if is_instance_valid(state[0]):state[0].visible=state[1];state[0].set_physics_process(state[2] and not state[0]._dying)
 outdoor_states=[]
 main.hotaru.set_ground_height(.95);main.hotaru.global_position=return_position;main.hotaru.velocity=Vector3.ZERO
 main.camera.fov=52;main.camera.near=.15;main._update_camera(100)
 roller.position.y=SITE.y
 if bring:main.trolley.interact()
 AudioDirector.sound("door",DOOR)
func focused() -> String:
 if near_exit():return "exit"
 if lathe.visible and main.hotaru.global_position.distance_to(ORIGIN+Vector3(3.1,1.05,.1))<1.6:return "lathe"
 for item in wires.get_children():
  if main.hotaru.global_position.distance_to(item.global_position+Vector3(0,.9,0))<1.6:return "wire"
 return ""
func interact() -> void:
 match focused():
  "exit":leave()
  "lathe":
   if not main.trolley.nearby():main.rest_notice("车床24kg，需把推车推到旁边装运。");return
   if GameState.cart_grams()+24000>GameState.CART_CAPACITY_G:main.rest_notice("推车空间不足，请至少留出24kg。");return
   GameState.cart_items.lathe=int(GameState.cart_items.get("lathe",0))+1
   GameState.lathe_taken=true;lathe.hide();GameState.inventory_changed.emit();main.rest_notice("已将车床装上推车。
运回房车卸货后，在基础维修台安装。")
  "wire":
   var destination: String="cart" if main.trolley.nearby() and GameState.cart_grams()+500<=25000 else "bag"
   var container: Dictionary=GameState.container_for(destination)
   if destination=="bag" and GameState.carried_grams()+500>GameState.CAPACITY_G:main.rest_notice("背包和附近推车没有足够空间。");return
   container.wire=int(container.get("wire",0))+1
   GameState.factory_wire-=1
   for item in wires.get_children():
    if main.hotaru.global_position.distance_to(item.global_position+Vector3(0,.9,0))<1.6:
     item.get_meta("label").queue_free();wires.remove_child(item);item.queue_free();break
   GameState.inventory_changed.emit();main.rest_notice("收集铁丝0.5kg → "+("推车" if destination=="cart" else "随身背包"))
  _:main.trolley.interact()
func workbench() -> void:
 if GameState.lathe_installed:main.fabrication.open();return
 if int(GameState.cargo.get("lathe",0))<1:main.rest_notice("先将工厂的车床用推车运回房车并卸进货舱，再来安装。");return
 main.hotaru.set_active(false)
 main._show_dialog("安装车床","将货舱里的24kg车床固定到维修台？安装后可生产铁丝围栏，每面分别加工。","安装",func():
  if int(GameState.cargo.get("lathe",0))>0 and not GameState.lathe_installed:
   GameState.cargo.lathe-=1
   if GameState.cargo.lathe<=0:GameState.cargo.erase("lathe")
   GameState.lathe_installed=true;GameState.inventory_changed.emit()
  main._close_dialog_and_resume()
 )
func _process(_delta: float) -> void:
 if is_instance_valid(installed):installed.visible=GameState.lathe_installed
 if not active:return
 if get_tree().paused or not main.controls_enabled:dragging=false;aim_finger=-1
func update_hud() -> void:
 main.vehicle_button.hide();main.upgrade_button.hide()
 main.attack_button.visible=main.controls_enabled and not main.hotaru.dead
 main.interact_button.visible=main.controls_enabled and not main.hotaru.dead
 main.interact_button.text={"exit":"离开工厂","lathe":"装运车床","wire":"收集铁丝"}.get(focused(),"交互 E")
 main.hint_label.text="工厂 · 右侧拖动视角 / 电脑右键拖动"
 main.objective_label.text=""
func update_camera(_delta: float) -> void:
 var center: Vector3=main.hotaru.global_position+Vector3(0,.75,0)
 var forward:=Vector3(sin(yaw),0,cos(yaw))
 var desired:=center-forward*2.65+Vector3(0,.65+pitch,0)
 var query:=PhysicsRayQueryParameters3D.create(center,desired,3,[main.hotaru.get_rid()])
 var hit:=get_world_3d().direct_space_state.intersect_ray(query)
 if not hit.is_empty():desired=hit.position+(center-hit.position).normalized()*.20
 main.camera.projection=Camera3D.PROJECTION_PERSPECTIVE;main.camera.fov=66;main.camera.near=.07
 main.camera.global_position=desired;main.camera.look_at(center+forward*.5)
 var fade: float=clampf((1.65-desired.distance_to(center))/.6,0,1)
 for mesh in main.hotaru._body_meshes:mesh.transparency=fade
func _unhandled_input(event: InputEvent) -> void:
 if not active or get_tree().paused or not main.controls_enabled:return
 if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT:dragging=event.pressed;get_viewport().set_input_as_handled()
 elif event is InputEventMouseMotion and dragging:yaw-=event.relative.x*.004;pitch=clampf(pitch+event.relative.y*.004,-.35,1.0);get_viewport().set_input_as_handled()
 elif event is InputEventScreenTouch:
  if event.index==aim_finger and not event.pressed:aim_finger=-1;get_viewport().set_input_as_handled()
  elif event.pressed and event.position.x>350 and event.position.y>260 and event.position.y<980 and aim_finger<0:aim_finger=event.index;get_viewport().set_input_as_handled()
 elif event is InputEventScreenDrag and event.index==aim_finger:yaw-=event.relative.x*.004;pitch=clampf(pitch+event.relative.y*.004,-.35,1.0);get_viewport().set_input_as_handled()

func _wire_glow(item: Node3D) -> void:
 var beam:=MeshInstance3D.new();var quad:=QuadMesh.new();quad.size=Vector2(.45,1.9);beam.mesh=quad
 var shader:=Shader.new()
 shader.code="""shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
void vertex(){MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0],vec4(0.0,1.0,0.0,0.0),vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz,vec3(0.0,1.0,0.0))),0.0),MODEL_MATRIX[3]);}
void fragment(){float core=pow(1.0-abs(UV.x-.5)*2.0,5.0);float pulse=.75+.25*sin(TIME*4.0);ALBEDO=vec3(.65,.92,1.0);EMISSION=vec3(.45,.8,1.0)*1.7;ALPHA=core*UV.y*pulse;}
"""
 var mat:=ShaderMaterial.new();mat.shader=shader;beam.material_override=mat;beam.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 item.add_child(beam);beam.global_position=item.global_position+Vector3(0,.9,0)
 beam.global_rotation=Vector3.ZERO
 var spark:=MeshInstance3D.new();var orb:=SphereMesh.new();orb.radius=.045;orb.height=.09;spark.mesh=orb
 var light:=StandardMaterial3D.new();light.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;light.albedo_color=Color("d9f6ff");light.emission_enabled=true;light.emission=Color("8edfff");spark.material_override=light;item.add_child(spark);spark.global_position=item.global_position+Vector3(0,.14,0)
 var pulse:=spark.create_tween().set_loops();pulse.tween_property(spark,"scale",Vector3.ONE*1.8,.6);pulse.tween_property(spark,"scale",Vector3.ONE,.6)
