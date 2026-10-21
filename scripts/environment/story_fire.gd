extends Node3D

var _light: OmniLight3D
var _time := 0.0

func _ready() -> void:
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
void vertex() {
 MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
 float sway = sin(UV.y*8.0 - TIME*8.0 + MODEL_MATRIX[3].x)*0.07;
 float width = 0.06 + UV.y*0.40;
 float body = 1.0-smoothstep(width*0.45,width,abs(UV.x-0.5+sway));
 float edge = smoothstep(0.0,0.16,UV.y)*(1.0-smoothstep(0.90,1.0,UV.y));
 float flicker = 0.8+0.2*sin(TIME*15.0+UV.y*13.0);
 ALBEDO = mix(vec3(1.0,0.08,0.005),vec3(1.0,0.85,0.25),UV.y);
 EMISSION = ALBEDO*1.4;
 ALPHA = body*edge*flicker*COLOR.a*0.80;
}"""
	var material := ShaderMaterial.new()
	material.shader = shader
	var flames := CPUParticles3D.new()
	flames.amount = 28
	flames.lifetime = 1.25
	flames.preprocess = 1.25
	flames.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	flames.emission_box_extents = Vector3(0.50,0.08,0.30)
	flames.direction = Vector3.UP
	flames.spread = 14
	flames.gravity = Vector3(0,0.35,0)
	flames.initial_velocity_min = 0.55
	flames.initial_velocity_max = 1.0
	flames.position.y = 0.40
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.65,1.05)
	mesh.material = material
	flames.mesh = mesh
	var gradient := Gradient.new()
	gradient.set_color(0,Color(1,1,1,0.9))
	gradient.set_color(1,Color(1,1,1,0))
	flames.color_ramp = gradient
	add_child(flames)
	var smoke := CPUParticles3D.new()
	smoke.amount = 10
	smoke.lifetime = 2.4
	smoke.preprocess = 2.4
	smoke.direction = Vector3.UP
	smoke.initial_velocity_min = 0.3
	smoke.initial_velocity_max = 0.6
	smoke.gravity = Vector3(0,0.10,0)
	smoke.position.y = 1.15
	smoke.spread = 24
	var smoke_mesh := QuadMesh.new()
	smoke_mesh.size = Vector2(1.5,1.5)
	var smoke_material := StandardMaterial3D.new()
	smoke_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smoke_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	smoke_material.vertex_color_use_as_albedo = true
	var smoke_gradient := Gradient.new()
	smoke_gradient.set_color(0,Color(0.08,0.06,0.04,0.35))
	smoke_gradient.set_color(1,Color(0.08,0.06,0.04,0))
	var texture := GradientTexture2D.new()
	texture.gradient = smoke_gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5,0.5)
	texture.fill_to = Vector2(1,0.5)
	smoke_material.albedo_texture = texture
	smoke_mesh.material = smoke_material
	smoke.mesh = smoke_mesh
	smoke.color_ramp = gradient
	add_child(smoke)
	_light = OmniLight3D.new()
	_light.light_color = Color("ff7a25")
	_light.light_energy = 1.3
	_light.omni_range = 4.0
	_light.shadow_enabled = false
	add_child(_light)

func _process(delta: float) -> void:
	_time += delta
	_light.light_energy = 1.15 + sin(_time*11)*0.18 + sin(_time*19)*0.1
