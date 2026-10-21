extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 root.size=Vector2i(900,720)
 root.content_scale_size=root.size
 var stage:=Node3D.new()
 root.add_child(stage)
 var env:=WorldEnvironment.new()
 env.environment=Environment.new()
 env.environment.background_mode=Environment.BG_COLOR
 env.environment.background_color=Color("293c45")
 env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 env.environment.ambient_light_color=Color("dce9f0")
 env.environment.ambient_light_energy=.8
 stage.add_child(env)
 var light:=DirectionalLight3D.new()
 light.rotation_degrees=Vector3(-45,-30,0)
 stage.add_child(light)
 var cam:=Camera3D.new()
 stage.add_child(cam)
 cam.projection=Camera3D.PROJECTION_ORTHOGONAL
 var temple=load("res://assets/temple/temple.glb").instantiate()
 stage.add_child(temple)
 cam.size=29
 for angle in [0,1]:
  cam.position=Vector3(24,16,26) if angle==0 else Vector3(-24,16,-26)
  cam.look_at(Vector3(0,4,0))
  for i in range(5):await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://artifacts/temple_model_%s.png"%angle)
 temple.hide()
 var state=root.get_node("GameState")
 state.suppress_save=true
 state.start_new_run()
 state.try_add_items({"odachi":1})
 state.equip_item("odachi","right_hand")
 var hero=load("res://scripts/actors/hotaru.gd").new()
 stage.add_child(hero)
 hero.position=Vector3(0,.95,0)
 hero.set_active(true)
 hero.set_physics_process(false)
 for label in hero.find_children("*","Label3D",true,false):label.hide()
 cam.size=3.4
 cam.position=Vector3(2.6,1.9,4.5)
 cam.look_at(Vector3(0,1.1,.15))
 for angle in range(3):
  cam.size=2.0
  cam.position=[Vector3(0,1.2,4),Vector3(4,1.2,0),Vector3(-3,1.5,3)][angle]
  cam.look_at(Vector3(0,1.05,.05))
  for clip in ["Idle","SwordIdle","SwordCombo1"]:
   hero._animation_player.play(hero._animation_names[clip],0)
   hero._animation_player.seek(.32 if clip=="SwordCombo1" else 0,true)
   hero._animation_player.pause()
   for i in range(4):await process_frame
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("res://artifacts/sword_audit_%s_%d.png"%[clip,angle])
 quit()
