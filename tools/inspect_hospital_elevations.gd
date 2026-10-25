extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1000,800)
 root.content_scale_size=Vector2i(1000,800)
 var scene=Node3D.new();root.add_child(scene)
 var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("82939f");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.8;scene.add_child(env)
 var sun=DirectionalLight3D.new();scene.add_child(sun);sun.rotation_degrees=Vector3(-55,-30,0)
 var camera=Camera3D.new();scene.add_child(camera);camera.current=true
 var model=load("res://assets/hospital/exterior.glb").instantiate();scene.add_child(model)
 camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=38
 var views={"south":Vector3(0,5,70),"north":Vector3(0,5,-70),"west":Vector3(-70,5,0),"east":Vector3(70,5,0),"court":Vector3(25,17,35)}
 for key in views:
  camera.position=views[key];camera.look_at(Vector3(0,4,0))
  await process_frame;await process_frame;await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://artifacts/hospital_elevation_"+key+".png")
 scene.queue_free();await process_frame;quit()
