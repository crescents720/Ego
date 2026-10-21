extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1000,750)
 var n=Node3D.new();root.add_child(n)
 n.add_child(load("res://assets/factory/factory.glb").instantiate())
 var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.9;n.add_child(env)
 var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-55,-35,0);n.add_child(light)
 var c:=Camera3D.new();c.fov=75;c.near=.04;n.add_child(c)
 var points: Array=[ [Vector3(-2,1.8,5),Vector3(-2,1.8,-6)], [Vector3(-2,1.8,-7),Vector3(-2,1.8,5)], [Vector3(-2,5,4),Vector3(-2,5,-6)], [Vector3(-5,2,0),Vector3(2,2,0)], [Vector3(-2,6.2,0),Vector3(-2,2,0)]]
 for i in range(points.size()):
  c.position=points[i][0];c.look_at(points[i][1])
  for j in range(6):await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://artifacts/factory_original_inside_%d.png"%i)
 quit()
