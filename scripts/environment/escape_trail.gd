extends Node3D

var _points: Array[Vector3]=[]
var _section_starts: Array[float]=[]
var _dashes: Array[Dictionary]=[]

func build(points: Array[Vector3]) -> void:
	name="EscapeGoldenTrail"
	_points=points
	var shader:=Shader.new()
	shader.code="""shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
instance uniform float arc = 0.0;
void fragment() {
 float edge=abs(UV.x-0.5)*2.0;
 float core=1.0-smoothstep(0.12,0.40,edge);
 float halo=exp(-edge*edge*3.5);
 float pulse=0.64+0.36*pow(0.5+0.5*sin(TIME*4.0-arc*1.7),3.0);
 vec3 gold=vec3(1.0,0.69,0.21);
 ALBEDO=gold; EMISSION=gold*(1.3+core);
 ALPHA=(core*0.82+halo*0.18)*pulse;
}"""
	var material:=ShaderMaterial.new()
	material.shader=shader
	var dash:=PlaneMesh.new()
	dash.size=Vector2(0.24,0.54)
	var arc:=0.0
	for section in range(points.size()-1):
		_section_starts.append(arc)
		var start:=points[section]
		var finish:=points[section+1]
		var direction: Vector3=(finish-start).normalized()
		var length:=start.distance_to(finish)
		var distance:=0.25
		while distance<length-0.1:
			var mesh:=MeshInstance3D.new()
			mesh.name="FlowingDash"
			mesh.mesh=dash
			mesh.material_override=material
			mesh.position=start+direction*distance
			mesh.position.y=0.12
			mesh.rotation.y=atan2(direction.x,direction.z)
			mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mesh)
			mesh.set_instance_shader_parameter("arc",arc+distance)
			_dashes.append({"mesh":mesh,"arc":arc+distance})
			distance+=0.88
		arc+=length
	_section_starts.append(arc)

func update_progress(player: Vector3,section: int) -> void:
	var progress: float=_section_starts[-1]
	if section<_points.size()-1:
		var start:=_points[section]
		var finish:=_points[section+1]
		player.y=start.y
		var closest:=Geometry3D.get_closest_point_to_segment(player,start,finish)
		progress=_section_starts[section]+start.distance_to(closest)
	for dash in _dashes:dash.mesh.visible=dash.arc>=progress-0.4
