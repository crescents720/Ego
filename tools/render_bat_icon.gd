extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 root.size=Vector2i(256,256)
 root.content_scale_size=Vector2i(256,256)
 root.transparent_bg=true
 var stage:=Node3D.new()
 root.add_child(stage)
 var env:=WorldEnvironment.new()
 env.environment=Environment.new()
 env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 env.environment.ambient_light_color=Color.WHITE
 env.environment.ambient_light_energy=0.8
 stage.add_child(env)
 var light:=DirectionalLight3D.new()
 light.rotation_degrees=Vector3(-35,-30,0)
 light.light_energy=1.5
 stage.add_child(light)
 var bat: Node3D=load("res://assets/items/baseball_bat/bat.glb").instantiate()
 bat.rotation.z=-0.65
 bat.position=Vector3(-0.26,0.08,0)
 stage.add_child(bat)
 var camera:=Camera3D.new()
 camera.projection=Camera3D.PROJECTION_ORTHOGONAL
 camera.size=1.02
 camera.position=Vector3(0,0.425,3)
 stage.add_child(camera)
 camera.look_at(Vector3(0,.425,0))
 for frame in range(5):await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://assets/ui/icons/bat.png")
 quit()
