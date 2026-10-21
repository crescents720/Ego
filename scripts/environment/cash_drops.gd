extends Node3D
# All deadlines use the survival world clock, including accelerated sleep.
const LIFETIME:=180.0
const PICKUP_RADIUS:=1.25
var main
var nodes: Dictionary={}
var cash_label: Label
var _scan:=0.0
var note_mesh: BoxMesh
var beam_mesh: QuadMesh
var note_material: StandardMaterial3D
var beam_material: ShaderMaterial
func build(owner_main) -> void:
 main=owner_main
 note_mesh=BoxMesh.new()
 note_mesh.size=Vector3(.48,.045,.24)
 note_material=StandardMaterial3D.new()
 note_material.albedo_color=Color("9acd79")
 note_material.emission_enabled=true
 note_material.emission=Color("3c6630")
 note_material.albedo_texture=load("res://assets/ui/icons/cash.svg")
 beam_mesh=QuadMesh.new()
 beam_mesh.size=Vector2(.6,2.7)
 var shader:=Shader.new()
 shader.code="""shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
void vertex(){MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0],vec4(0.0,1.0,0.0,0.0),vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz,vec3(0.0,1.0,0.0))),0.0),MODEL_MATRIX[3]);}
void fragment(){float x=abs(UV.x-.5)*2.0;float a=pow(1.0-x,5.0)*UV.y*.78;ALBEDO=vec3(.74,1.0,.49);EMISSION=vec3(.5,.85,.28)*(1.2+.25*sin(TIME*3.0));ALPHA=a;}
"""
 beam_material=ShaderMaterial.new()
 beam_material.shader=shader
 var icon:=TextureRect.new()
 icon.texture=load("res://assets/ui/icons/cash.svg")
 icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 icon.position=Vector2(150,140)
 icon.size=Vector2(34,28)
 icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
 main.get_node("HUD").add_child(icon)
 cash_label=Label.new()
 cash_label.position=Vector2(190,140)
 cash_label.add_theme_font_size_override("font_size",23)
 cash_label.add_theme_color_override("font_color",Color("f5e2a4"))
 cash_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
 main.get_node("HUD").add_child(cash_label)
func spawn_drop(point: Vector3,amount: int=0) -> Dictionary:
 var drop: Dictionary={"position":Vector3(point.x,point.y-.68,point.z),"amount":randi_range(1,5) if amount==0 else clampi(amount,1,5),"expires":GameState.world_seconds+LIFETIME,"uid":str(Time.get_ticks_usec())+str(randi())}
 GameState.cash_drops.append(drop)
 return drop
func reset_visuals() -> void:
 for node in nodes.values():node.queue_free()
 nodes.clear()
 _scan=1.0
func _process(delta: float) -> void:
 if not is_instance_valid(main):return
 cash_label.text="%d"%GameState.cash
 _scan+=delta
 if _scan<.1:return
 _scan=0
 var visible_ids: Dictionary={}
 for i in range(GameState.cash_drops.size()-1,-1,-1):
  var drop: Dictionary=GameState.cash_drops[i]
  if GameState.world_seconds>=float(drop.expires):
   GameState.cash_drops.remove_at(i)
   continue
  var p: Vector3=drop.position
  var same_room: bool=GameState.spatial_room_id(p)==(3 if main.factory.active else (2 if main.inside_store else 0))
  if not main.in_vehicle and not main.inside_rv and main.controls_enabled and main.hotaru.health>0 and same_room and Vector2(p.x,p.z).distance_to(Vector2(main.hotaru.global_position.x,main.hotaru.global_position.z))<=PICKUP_RADIUS:
   GameState.cash+=int(drop.amount)
   GameState.cash_drops.remove_at(i)
   AudioDirector.ui("pickup")
   continue
  var key: String=drop.uid
  visible_ids[key]=true
  if not nodes.has(key):
   var root:=Node3D.new()
   add_child(root)
   root.global_position=p
   var note:=MeshInstance3D.new()
   note.mesh=note_mesh
   note.material_override=note_material
   note.rotation.y=randf()*TAU
   root.add_child(note)
   var beam:=MeshInstance3D.new()
   beam.mesh=beam_mesh
   beam.material_override=beam_material
   beam.position.y=1.35
   beam.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
   root.add_child(beam)
   nodes[key]=root
  nodes[key].visible=same_room and not main.inside_rv and main.phase!=main.Phase.TITLE
 for key in nodes.keys():
  if not visible_ids.has(key):nodes[key].queue_free();nodes.erase(key)
