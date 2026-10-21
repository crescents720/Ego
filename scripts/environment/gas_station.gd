extends Node3D
const ORIGIN:=Vector3(50,0,-135)
const BAY:=Vector3(51.5,1.02,-136.5)
const PUMPS: Array[Vector3]=[Vector3(48.45,0,-135.88),Vector3(48.45,0,-138)]
var main
var button: Button
var site_label: Label3D
func build(owner_main) -> void:
 main=owner_main
 name="OldGasStation"
 position=ORIGIN
 var model: Node3D=load("res://assets/environment/gas_station/gas_station_mobile.glb").instantiate()
 add_child(model)
 for mesh in model.find_children("*","MeshInstance3D",true,false):
  if mesh.get_aabb().size.y>1.0 or "ROOF" in mesh.name or "BILLBOARD" in mesh.name:
   main.town_occlusion.register_building(mesh)
 _collision(Vector3(9.4,3.6,13.7),Vector3(9.35,1.8,.4))
 # Narrow fixtures only. The pavement and drive-through lane remain traversable.
 for point in PUMPS:_collision(Vector3(.65,2.1,1.0),point-ORIGIN+Vector3(0,1.05,0))
 for point in [Vector3(-1.4,2,-4),Vector3(3.8,2,.1)]:_collision(Vector3(.3,4,.3),point)
 for x in [BAY.x-1.65,BAY.x+1.65]:
  var line:=MeshInstance3D.new()
  var shape:=BoxMesh.new()
  shape.size=Vector3(.12,.025,11)
  line.mesh=shape
  line.position=Vector3(x,.14,BAY.z)-ORIGIN
  var paint:=StandardMaterial3D.new()
  paint.albedo_color=Color("f2f0dc")
  line.material_override=paint
  add_child(line)
 var label:=Label3D.new()
 site_label=label
 label.text="加油站 · 油泵旁白线停车道"
 label.position=Vector3(-1,5,0)
 label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
 label.font_size=28
 label.pixel_size=.014
 add_child(label)
 button=Button.new()
 button.text="加油"
 button.position=Vector2(28,460)
 button.size=Vector2(190,60)
 main._style_button(button,Color("4c625b"))
 main.get_node("HUD").add_child(button)
 button.pressed.connect(open)
func _collision(size_value: Vector3, at: Vector3) -> void:
 var body:=StaticBody3D.new()
 body.collision_layer=3
 var shape:=BoxShape3D.new()
 shape.size=size_value
 var collider:=CollisionShape3D.new()
 collider.shape=shape
 body.add_child(collider)
 body.position=at
 add_child(body)
func is_parked() -> bool:
 var offset: Vector3=main.rv.global_position-BAY
 var along_lane: float=absf(cos(main.rv.rotation.y))
 return absf(offset.x)<.55 and absf(offset.z)<1.8 and along_lane>.94 and absf(main.rv.speed)<.3
func nearest_pump() -> Vector3:
 return PUMPS[0] if main.rv.global_position.distance_to(PUMPS[0])<main.rv.global_position.distance_to(PUMPS[1]) else PUMPS[1]
func _process(_delta: float) -> void:
 site_label.visible=not main.service.active
 button.visible=not main.service.active and not main.sleep_controller.sleeping and not main.inside_store and main.phase not in [main.Phase.TITLE,main.Phase.GAME_OVER] and main.rv.global_position.distance_to(BAY)<17 and not main.dialog_panel.visible
func open() -> void:
 if main.in_vehicle or main.inside_rv:main.rest_notice("请先停到油泵旁白线车道，再下车操作加油枪。");return
 var blocked: String=main.service.reason("fuel")
 if not blocked.is_empty():main.rest_notice(blocked);return
 main.service.begin("fuel")
