extends SceneTree
func _initialize():
 call_deferred("run")
func run():
 var bedroom := not OS.get_cmdline_user_args().has("--house")
 var model = load("res://assets/story/bedroom/bedroom.glb" if bedroom else "res://assets/story/house/house.glb").instantiate()
 root.add_child(model)
 for node in model.get_children():
  if str(node.name).begins_with("Shell"):
   node.hide()
 var cam := Camera3D.new()
 root.add_child(cam)
 cam.projection = Camera3D.PROJECTION_ORTHOGONAL
 cam.keep_aspect = Camera3D.KEEP_WIDTH
 cam.size = 7 if bedroom else 9
 cam.position = Vector3(9,7,9) if bedroom else Vector3(8,6,10)
 cam.look_at(Vector3(3.1,0.7,0.8) if bedroom else Vector3(0,1,0))
 var sun := DirectionalLight3D.new()
 sun.rotation_degrees = Vector3(-50,-30,0)
 root.add_child(sun)
 var env := WorldEnvironment.new()
 env.environment = Environment.new()
 env.environment.background_mode = Environment.BG_COLOR
 env.environment.background_color = Color("7e8b91")
 env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 env.environment.ambient_light_color = Color.WHITE
 env.environment.ambient_light_energy = 0.6
 root.add_child(env)
 for i in range(20):
  await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://artifacts/" + ("bedroom_model.png" if bedroom else "house_model.png"))
 quit()
