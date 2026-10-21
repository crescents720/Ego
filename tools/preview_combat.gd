extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	root.size=Vector2i(1200,800)
	root.content_scale_size=Vector2i(1200,800)
	var stage:=Node3D.new()
	root.add_child(stage)
	var env:=WorldEnvironment.new()
	env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR
	env.environment.background_color=Color("35434c")
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color("d4e5ec")
	env.environment.ambient_light_energy=0.65
	stage.add_child(env)
	var light:=DirectionalLight3D.new()
	light.rotation_degrees=Vector3(-45,-30,0)
	stage.add_child(light)
	var hero=load("res://scripts/actors/hotaru.gd").new()
	stage.add_child(hero)
	hero.position=Vector3(-0.6,0.95,0)
	hero.rotation.y=PI/2
	hero.set_physics_process(false)
	for label in hero.find_children("*","Label3D",true,false):label.hide()
	var zombie=load("res://scripts/actors/zombie.gd").new()
	stage.add_child(zombie)
	zombie.position=Vector3(0.25,0.9,0)
	zombie.rotation.y=-PI/2
	zombie.set_physics_process(false)
	var bite:=OS.get_cmdline_user_args().has("bite")
	var walking:=OS.get_cmdline_user_args().has("walk")
	if walking:
		hero.hide()
		zombie.position.x=0
	var player: AnimationPlayer=hero._animation_player
	player.play("Hit" if bite else "Punch",0)
	player.seek(0.10 if bite else 0.24,true)
	player.pause()
	zombie._animation_player.play("Bite" if bite else "Idle",0)
	zombie._animation_player.seek(0.44 if bite else 0,true)
	zombie._animation_player.pause()
	var camera:=Camera3D.new()
	stage.add_child(camera)
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect=Camera3D.KEEP_HEIGHT
	camera.size=2.2
	camera.position=Vector3(0,1.7,-4)
	camera.look_at(Vector3(0,0.86,0))
	if OS.get_cmdline_user_args().has("sequence"):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/combat_frames"))
		for frame in range(30):
			var time:=float(frame)/30
			var hero_clip: String="Punch" if not bite and time<=0.62 else "Idle"
			var hero_time: float=time
			if bite:
				hero_clip="Hit" if time>=0.44 and time<0.88 else "Idle"
				hero_time=maxf(0,time-0.44)
			player.play(hero_clip,0)
			player.seek(hero_time,true)
			player.pause()
			zombie._animation_player.play("Bite" if bite and time<0.84 else "Idle",0)
			zombie._animation_player.seek(time,true)
			zombie._animation_player.pause()
			if walking:
				zombie._animation_player.play("Walk",0)
				zombie._animation_player.seek(float(frame)*.95/30,true)
				zombie._animation_player.pause()
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://artifacts/combat_frames/"+("walk" if walking else ("bite" if bite else "punch"))+"_%02d.png"%frame)
		quit()
		return
	for frame in range(5):await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/combat_"+("bite_hit" if bite else "punch")+".png")
	quit()
