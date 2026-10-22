extends SceneTree


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	root.size=Vector2i(1000,720)
	root.content_scale_size=root.size
	var stage:=Node3D.new()
	root.add_child(stage)
	var environment:=WorldEnvironment.new()
	environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color("182830")
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color("d9ecf2")
	environment.environment.ambient_light_energy=.55
	stage.add_child(environment)
	var light:=DirectionalLight3D.new()
	light.rotation_degrees=Vector3(-48,-28,0)
	light.light_energy=1.05
	light.shadow_enabled=true
	stage.add_child(light)
	var floor:=MeshInstance3D.new()
	var plane:=PlaneMesh.new()
	plane.size=Vector2(12,12)
	floor.mesh=plane
	var floor_material:=StandardMaterial3D.new()
	floor_material.albedo_color=Color("38484e")
	floor_material.roughness=.9
	floor.material_override=floor_material
	stage.add_child(floor)
	var camera:=Camera3D.new()
	camera.fov=48
	camera.position=Vector3(2.55,1.62,3.25)
	stage.add_child(camera)
	camera.look_at(Vector3(0,1.02,.10))

	var state=root.get_node("GameState")
	state.suppress_save=true
	state.start_new_run()
	state.items={"odachi":1}
	state.equipment.right_hand="odachi"
	state.odachi_skill_level=5
	var hero=load("res://scripts/actors/hotaru.gd").new()
	stage.add_child(hero)
	hero.position=Vector3(0,.95,0)
	hero.rotation.y=0
	hero.set_active(true)
	hero.set_physics_process(false)
	for label in hero.find_children("*","Label3D",true,false):
		label.hide()
	for frame in range(6):
		await process_frame
	await RenderingServer.frame_post_draw

	var clip: String=hero._animation_names.SwordCombo5
	var contacts: Array[float]=[.432,1.038,1.668,2.272,3.052]
	for index in range(contacts.size()):
		for old_effect in stage.get_children():
			if old_effect.name.begins_with("SwordSlashFX"):
				old_effect.free()
		hero._animation_player.play(clip,0)
		hero._animation_player.seek(contacts[index],true)
		hero._animation_player.pause()
		hero._spawn_sword_effect(index,index==contacts.size()-1)
		var effect: Node3D=stage.get_node("SwordSlashFX%d"%(index+1))
		for frame in range(2):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/sword_vfx_contact_%d.png"%(index+1))

	for old_effect in stage.get_children():
		if old_effect.name.begins_with("SwordSlashFX"):
			old_effect.free()
	hero._combat_action=""
	hero._animation_player.play(hero._animation_names.SwordIdle,0)
	hero._animation_player.seek(.22,true)
	hero._animation_player.pause()
	hero._set_sword_sheathed(true)
	for frame in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/sword_sheathed_close.png")
	print("SWORD_GAMEPLAY_VFX_PREVIEW_OK")
	quit()
