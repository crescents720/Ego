extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 root.size=Vector2i(1100,800)
 root.content_scale_size=root.size
 var stage:=Node3D.new()
 root.add_child(stage)
 var env:=WorldEnvironment.new()
 env.environment=Environment.new()
 env.environment.background_mode=Environment.BG_COLOR
 env.environment.background_color=Color("a6b6aa")
 env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 env.environment.ambient_light_color=Color.WHITE
 env.environment.ambient_light_energy=0.8
 stage.add_child(env)
 var sun:=DirectionalLight3D.new()
 sun.rotation_degrees=Vector3(-40,-20,0)
 stage.add_child(sun)
 for i in range(3):
  var id: String=["leaf1","grass","reeds"][i]
  var plant: Node3D=load("res://assets/environment/vegetation/"+id+".glb").instantiate()
  stage.add_child(plant)
  for part in plant.find_children("*","MeshInstance3D",true,false):
   for j in range(part.mesh.get_surface_count()):
    var mat: StandardMaterial3D=part.mesh.surface_get_material(j)
    print(id," ",mat.resource_name," color=",mat.albedo_color," alpha=",mat.transparency," texture=",mat.albedo_texture)
    var custom:=ShaderMaterial.new()
    var template=load("res://scripts/environment/town_vegetation.gd").new()
    # Assign the exact town shader to compare source and instanced appearance.
    custom.shader=Shader.new()
    custom.shader.code="""shader_type spatial;render_mode cull_disabled;
uniform sampler2D albedo_tex:source_color,filter_linear_mipmap,repeat_enable;
void fragment(){vec4 c=texture(albedo_tex,UV);ALBEDO=c.rgb;ALPHA=c.a;ALPHA_SCISSOR_THRESHOLD=0.4;ROUGHNESS=0.95;}"""
    custom.set_shader_parameter("albedo_tex",mat.albedo_texture)
    part.set_surface_override_material(j,custom)
    template.free()
  plant.position.x=(i-1)*5
 var camera:=Camera3D.new()
 stage.add_child(camera)
 camera.position=Vector3(9,8,16)
 camera.look_at(Vector3(0,2,0))
 camera.projection=Camera3D.PROJECTION_ORTHOGONAL
 camera.size=15
 for frame in range(15):await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://artifacts/vegetation_shader_gallery.png")
 quit()
