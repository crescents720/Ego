extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(900,700)
 var n=Node3D.new();root.add_child(n)
 n.add_child(load("res://assets/factory/factory.glb").instantiate())
 var light=DirectionalLight3D.new();light.rotation_degrees=Vector3(-55,-35,0);n.add_child(light)
 var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.8;n.add_child(env)
 var c=Camera3D.new();n.add_child(c)
 for i in range(4):
  c.position=Vector3(sin(i*PI/2+.3)*35,17,cos(i*PI/2+.3)*35);c.look_at(Vector3(0,3,0))
  for j in range(4):await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://artifacts/factory_model_%d.png"%i)
 quit()
