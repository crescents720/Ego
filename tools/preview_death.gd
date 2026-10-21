extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 root.size=Vector2i(1000,900)
 root.content_scale_size=Vector2i(1000,900)
 var stage:=Node3D.new()
 root.add_child(stage)
 var env:=WorldEnvironment.new()
 env.environment=Environment.new()
 env.environment.background_mode=Environment.BG_COLOR
 env.environment.background_color=Color("293c45")
 env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 env.environment.ambient_light_color=Color("dce9f0")
 env.environment.ambient_light_energy=0.8
 stage.add_child(env)
 var light:=DirectionalLight3D.new()
 light.rotation_degrees=Vector3(-45,-30,0)
 stage.add_child(light)
 var state=root.get_node("GameState")
 state.start_new_run()
 state.try_add_items({"bat":1})
 state.equip_item("bat","right_hand")
 var hero=load("res://scripts/actors/hotaru.gd").new()
 stage.add_child(hero)
 hero.position=Vector3(0,0.95,0)
 hero.set_active(true)
 hero.set_physics_process(false)
 for label in hero.find_children("*","Label3D",true,false):label.hide()
 var camera:=Camera3D.new()
 stage.add_child(camera)
 camera.projection=Camera3D.PROJECTION_ORTHOGONAL
 camera.size=2.6
 camera.position=Vector3(2.5,1.6,3.6)
 camera.look_at(Vector3(0,0.45,-0.6))
 for pose in [["death_recoil","Death",0.14],["death_fall","Death",0.54],["death_rest","Death",1.65]]:
  hero._animation_player.play(pose[1],0)
  hero._animation_player.seek(pose[2],true)
  hero._animation_player.pause()
  for frame in range(4):await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://artifacts/"+pose[0]+".png")
 quit()
