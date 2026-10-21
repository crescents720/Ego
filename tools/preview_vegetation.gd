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
  plant.position.x=(i-1)*5
 var camera:=Camera3D.new()
 stage.add_child(camera)
 camera.position=Vector3(9,8,16)
 camera.look_at(Vector3(0,2,0))
 camera.projection=Camera3D.PROJECTION_ORTHOGONAL
 camera.size=15
 for frame in range(15):await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://artifacts/vegetation_gallery.png")
 quit()
