extends SceneTree
func _initialize():
 call_deferred("run")
func run():
 var zombie := OS.get_cmdline_user_args().has("--zombie")
 var model = load("res://assets/characters/zombie/zombie.glb" if zombie else "res://assets/vehicles/bounder/bounder.glb").instantiate()
 root.add_child(model)
 var camera = Camera3D.new()
 root.add_child(camera)
 camera.position = Vector3(3,2.2,4) if zombie else Vector3(10,7,-10)
 if OS.get_cmdline_user_args().has("--side"):
  camera.position = Vector3(10,1.5,0)
 camera.projection = Camera3D.PROJECTION_ORTHOGONAL
 camera.keep_aspect = Camera3D.KEEP_WIDTH
 camera.size = 2.6 if zombie else 10.8
 camera.look_at(Vector3(0,0.8,0) if zombie else Vector3(0,1.1,0))
 if OS.get_cmdline_user_args().has("--door"):
  camera.position = Vector3(10,1.5,0)
  camera.size = 3.6
  camera.look_at(Vector3(0,1.4,0))
 var sun = DirectionalLight3D.new()
 sun.rotation_degrees = Vector3(-55,-30,0)
 root.add_child(sun)
 var world = WorldEnvironment.new()
 world.environment = Environment.new()
 world.environment.background_mode = Environment.BG_COLOR
 world.environment.background_color = Color("728787")
 world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 world.environment.ambient_light_color = Color.WHITE
 world.environment.ambient_light_energy = 0.65
 root.add_child(world)
 for i in range(20):
  await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://artifacts/" + ("bounder_door_detail.png" if OS.get_cmdline_user_args().has("--door") else "bounder_side.png" if OS.get_cmdline_user_args().has("--side") else ("zombie_model.png" if zombie else "bounder_model.png")))
 quit()


