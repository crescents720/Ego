extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1000,800)
 root.content_scale_size=Vector2i(1000,800)
 var scene=Node3D.new();root.add_child(scene)
 var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("82939f");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.8;scene.add_child(env)
 var sun=DirectionalLight3D.new();scene.add_child(sun);sun.rotation_degrees=Vector3(-55,-30,0)
 var camera=Camera3D.new();scene.add_child(camera);camera.current=true
 for key in ["exterior","operating"]:
  var model: Node3D
  if key=="exterior":model=load("res://assets/hospital/exterior.glb").instantiate()
  else:
   var document=GLTFDocument.new();var state=GLTFState.new();document.append_from_file("res://artifacts/hospital_reference_models/"+key+".glb",state);model=document.generate_scene(state)
  scene.add_child(model)
  if key=="exterior":
   camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=43
   camera.position=Vector3(30,28,40);camera.look_at(Vector3(0,3,0))
  else:
   camera.projection=Camera3D.PROJECTION_PERSPECTIVE;camera.fov=80
   camera.position=Vector3(0,1.7,2.4);camera.look_at(Vector3(0,1.2,-1))
  await process_frame;await process_frame;await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://artifacts/hospital_source_"+key+".png")
  if key=="exterior":
   camera.position=Vector3(0,70,.01);camera.look_at(Vector3.ZERO,Vector3.FORWARD)
   await process_frame;await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("res://artifacts/hospital_source_exterior_reverse.png")
  model.free()
 quit()
