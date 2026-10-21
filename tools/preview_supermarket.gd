extends SceneTree
func _initialize():
 call_deferred("run")
func run():
 var model = load("res://assets/third_party/supermarket/supermarket.glb").instantiate()
 root.add_child(model)
 if OS.get_cmdline_user_args().has("--cutaway"):
  for node in model.get_children():
   if str(node.name).begins_with("Roof") or str(node.name).begins_with("WallZP") or str(node.name).begins_with("WallXP"):
    node.hide()
 var camera = Camera3D.new()
 root.add_child(camera)
 camera.position = Vector3(11,10,13)
 camera.projection = Camera3D.PROJECTION_ORTHOGONAL
 camera.size = 13
 camera.look_at(Vector3(0,0.8,0))
 var sun = DirectionalLight3D.new()
 sun.rotation_degrees = Vector3(-55,-30,0)
 root.add_child(sun)
 var world = WorldEnvironment.new()
 world.environment = Environment.new()
 world.environment.background_mode = Environment.BG_COLOR
 world.environment.background_color = Color("84999a")
 world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 world.environment.ambient_light_color = Color.WHITE
 world.environment.ambient_light_energy = 0.7
 root.add_child(world)
 for i in range(12):
  await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://artifacts/store_audit.png")
 quit()
