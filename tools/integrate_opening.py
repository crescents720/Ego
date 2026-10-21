from pathlib import Path
p=Path('scripts/main.gd');s=p.read_text(encoding='utf-8-sig')
s=s.replace('const BuildingOcclusion', 'const OpeningStory = preload("res://scripts/story/opening.gd")\nconst StoryFire = preload("res://scripts/environment/story_fire.gd")\n\nconst BuildingOcclusion',1)
s=s.replace('var world_root: Node3D','var opening\nvar home_fire: Node3D\nvar world_root: Node3D',1)
s=s.replace('var home_parking_position := Vector3(0.0, 1.02, -43.0)','var home_parking_position := Vector3(-21.5, 1.02, -43.0)',1)
s=s.replace('\t_create_hud()\n\t_show_title()', '\t_create_hud()\n\topening = OpeningStory.new()\n\tadd_child(opening)\n\t_show_title()',1)
s=s.replace('func _unhandled_input(event: InputEvent) -> void:\n', 'func _unhandled_input(event: InputEvent) -> void:\n\tif is_instance_valid(opening) and opening.is_cinematic():\n\t\topening.handle_input(event)\n\t\treturn\n',1)
s=s.replace('func _update_camera(delta: float) -> void:\n', 'func _update_camera(delta: float) -> void:\n\tif is_instance_valid(opening) and opening.is_cinematic():\n\t\treturn\n',1)
s=s.replace('func _attack() -> void:\n','func _attack() -> void:\n\tif is_instance_valid(opening) and opening.beat == OpeningStory.Beat.ESCAPE:\n\t\treturn\n',1)
s=s.replace('"开始新游戏", _start_new_game','"开始新游戏", _begin_story',1)
s=s.replace('var body_text := "小萤一觉醒来，镇上的人都变成了丧尸。\\n哥哥不见了，只留下停在家门口的房车。\\n\\n走出家门，沿街寻找物资和哥哥的线索。"','var body_text := "梦里，哥哥正笑着祝小萤毕业快乐。\\n醒来时，卧室已是一片火海。\\n\\n前门被围住，哥哥不见了。\\n后院的房车，是她唯一的退路。"',1)
s=s.replace('func _start_new_game() -> void:', 'func _begin_story() -> void:\n\t_start_new_game()\n\topening.start()\n\n\nfunc _start_new_game() -> void:',1)
s=s.replace('Vector3(-10.0, 0.95, -43.0)','Vector3(-6.7, 0.95, -43.0)')
s=s.replace('\tvar zombie = ZombieController.new()\n\t\tzombie.position', '\tvar zombie = ZombieController.new()\n\t\tzombie.position')
s=s.replace('\t\tadd_child(zombie)\n\n\tcamera =', '\t\tadd_child(zombie)\n\t\tzombie.add_to_group("store_zombies")\n\n\tcamera =',1)
s=s.replace('func _alive_zombie_count() -> int:\n\tvar count := 0\n\tfor zombie in get_tree().get_nodes_in_group("zombies"):', 'func _alive_zombie_count() -> int:\n\tvar count := 0\n\tfor zombie in get_tree().get_nodes_in_group("store_zombies"):',1)
s=s.replace('\t_update_hud()\n\tif _capture_preview:', '\t_update_hud()\n\tif is_instance_valid(opening):\n\t\topening.apply_escape_hud()\n\tif _capture_preview:',1)
a=s.index('func _create_home()');b=s.index('\n\nfunc _create_storefront_and_cache()',a)
s=s[:a]+'''func _create_home() -> void:
	var home: Node3D = load("res://assets/story/house/house.glb").instantiate()
	home.name = "HotaruAmericanHouse"
	home.position = Vector3(-11,0.08,-43)
	home.scale = Vector3.ONE*1.6
	home.rotation.y = PI/2
	world_root.add_child(home)
	town_occlusion.register_building(home)
	_add_static_collision(Vector3(6.6,4.2,9.2),Vector3(-11,2.1,-43),3)
	_add_box(world_root,"BackParking",Vector3(9,0.10,15),Vector3(-22,0,-43),Color("5c6060"))
	_add_box(world_root,"SideDriveway",Vector3(25,0.10,5),Vector3(-12,0,-33),Color("5c6060"))
	_add_label("后院停车场",Vector3(-23,2.0,-48.5),Color("ffdfa3"),28)
	home_fire = Node3D.new()
	home_fire.name = "HouseFire"
	world_root.add_child(home_fire)
	for point in [Vector3(-8.0,0.3,-45),Vector3(-8,2.5,-41),Vector3(-11,4.0,-43),Vector3(-13.5,0.2,-40.5)]:
		var fire := StoryFire.new()
		fire.position = point
		home_fire.add_child(fire)
	home_fire.hide()
	home_fire.process_mode = Node.PROCESS_MODE_DISABLED
'''+s[b:]
p.write_text(s,encoding='utf-8')
p=Path('scripts/actors/rv.gd');s=p.read_text(encoding='utf-8-sig').replace('clampf(global_position.x, -3.15, 3.15)','clampf(global_position.x, -28.0, 3.15)');p.write_text(s,encoding='utf-8')
p=Path('scripts/story/opening.gd');s=p.read_text(encoding='utf-8-sig').replace('Vector3(-20.5,0.95,-35.5)','Vector3(-24.0,0.95,-35.5)')
s=s.replace('\t\t\tmain.home_fire.show()', '\t\t\tmain.home_fire.show()\n\t\t\tmain.home_fire.process_mode = Node.PROCESS_MODE_INHERIT')
s=s.replace('main.camera.global_position = FRONT_EXIT+main.TOWN_CAMERA_OFFSET','main.camera.global_position = FRONT_EXIT+Vector3(16,14,16)')
s=s.replace('\t\tbackground.color =', '\t\tbackground.color =')
s=s.replace('\tphoto.material.set_shader_parameter("broken",0.0)','\tphoto.material.set_shader_parameter("broken",0.0)\n\tbackground.color = Color("e4d5b5")\n\tnext_button.show()\n\tnext_button.text = "继续 E"\n\tskip_button.show()',1)
s=s.replace('\tif beat >= Beat.EXTERIOR and fire_audio.playing:', '\tif beat >= Beat.EXTERIOR:\n\t\tvar fire_visible: bool = not main.inside_rv and not main.inside_store and main.hotaru.global_position.distance_to(Vector3(-11,0,-43))<45\n\t\tmain.home_fire.visible = fire_visible\n\t\tmain.home_fire.process_mode = Node.PROCESS_MODE_INHERIT if fire_visible else Node.PROCESS_MODE_DISABLED\n\tif beat >= Beat.EXTERIOR and fire_audio.playing:',1)
p.write_text(s,encoding='utf-8')
