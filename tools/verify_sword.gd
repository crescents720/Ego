extends SceneTree

var errors:=0
const EXPECTED_DURATIONS := [1.00,1.69,2.23,2.86,4.06]
const EXPECTED_CONTACTS := [
	[0.432],
	[0.432,1.038],
	[0.432,1.038,1.668],
	[0.432,1.038,1.668,2.272],
	[0.432,1.038,1.668,2.272,3.052],
]


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool,message: String) -> void:
	if not ok:
		errors+=1
		push_error(message)


func spawn_zombie(parent: Node,point: Vector3,hp: int=100):
	var zombie=load("res://scripts/actors/zombie.gd").new()
	parent.add_child(zombie)
	zombie.global_position=point
	zombie.health=hp
	zombie.set_physics_process(false)
	return zombie


func run() -> void:
	root.size=Vector2i(720,1280)
	var state=root.get_node("GameState")
	state.suppress_save=true
	var main=load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main._start_new_game()
	main._set_phase(main.Phase.EXPLORE)
	main.zombie_population.set_process(false)
	for existing in get_nodes_in_group("zombies"):
		existing.queue_free()
	await physics_frame

	var temple=main.temple
	var hero=main.hotaru
	hero.set_physics_process(false)
	hero.global_position=temple.SITE+Vector3(0,temple.OUTDOOR_GROUND_Y-temple.SITE.y,-temple.ENTER_HALF.y+.1)
	temple.enter(Vector2(0,-temple.ENTER_HALF.y+.1))
	check(temple.active,"Temple did not enter before sword pickup")
	hero.global_position=temple.RACK+Vector3(0,temple.TEMPLE_GROUND_Y-temple.RACK.y,-1.2)
	check(temple.nearby(),"Temple offering sword is unreachable")
	main._update_hud()
	check(main.interact_button.visible and main.interact_button.text=="拾取大太刀","Pickup HUD missing")
	state.items={"water":2}
	temple.interact()
	check(not state.odachi_taken and temple.sword.visible,"Full bag consumed unique sword")
	state.items={"bat":1}
	state.equipment.left_hand="bat"
	state.inventory_changed.emit()
	main.interact_button.pressed.emit()
	check(state.odachi_taken and state.items.get("odachi")==1 and state.weapon_id()=="odachi","Sword pickup/equip failed")
	check(state.equipment.left_hand=="" and state.equipment.right_hand=="odachi","Two-handed slot conflict")
	check(not temple.sword.visible and not temple.nearby(),"Sword duplicate pickup possible")
	check(hero._sword_model.visible and not hero._bat_models.R.visible,"Wrong held weapon")

	for count in range(1,6):
		var key="SwordCombo"+str(count)
		check(hero._animation_names.has(key),"Missing "+key)
		if not hero._animation_names.has(key):
			continue
		var animation: Animation=hero._animation_player.get_animation(hero._animation_names[key])
		check(animation.loop_mode==Animation.LOOP_NONE,key+" loops")
		check(absf(animation.length-EXPECTED_DURATIONS[count-1])<.02,key+" duration does not match metadata")

	# Sample the imported skeleton rather than trusting the generator alone:
	# both palms must remain 11.5 cm apart along the grip in every level.
	var skeletons: Array[Node]=hero._character_model.find_children("*","Skeleton3D",true,false)
	check(not skeletons.is_empty(),"Sword character skeleton missing")
	if not skeletons.is_empty():
		var skeleton: Skeleton3D=skeletons[0]
		var right_bone:=skeleton.find_bone("Hand.R")
		var left_bone:=skeleton.find_bone("Hand.L")
		for count in range(1,6):
			var clip: String=hero._animation_names["SwordCombo"+str(count)]
			var duration: float=hero._animation_player.get_animation(clip).length
			for sample in range(15):
				hero._animation_player.play(clip,0)
				hero._animation_player.seek(duration*sample/14.0,true)
				hero._animation_player.pause()
				skeleton.force_update_all_bone_transforms()
				var right: Transform3D=skeleton.get_bone_global_pose(right_bone)
				var left: Transform3D=skeleton.get_bone_global_pose(left_bone)
				var axis: Vector3=(right.basis*hero._sword_model.basis).y.normalized()
				var right_palm: Vector3=right*(skeleton.get_bone_global_rest(right_bone).basis.inverse()*Vector3(0,-.035,-.012))
				var left_palm: Vector3=left*(skeleton.get_bone_global_rest(left_bone).basis.inverse()*Vector3(0,-.035,-.012))
				var grip_error:=(left_palm-(right_palm-axis*.115)).length()
				check(grip_error<.013,"Hands leave grip in %d at %d, error %f"%[count,sample,grip_error])

	for placement in main.town_layout.vegetation.placements:
		var point: Vector2=placement.position
		check(not Rect2(-97.5,307,7,21).has_point(point),"Tree/grass blocks temple access road")

	hero.pushing_cart=true
	hero._combat_action=""
	hero._last_attack_ms=-10000
	hero.attack()
	check(hero._combat_action.is_empty(),"Sword can attack while pushing cart")
	hero.pushing_cart=false
	temple.leave(true)
	temple.set_process(false)
	hero.set_active(true)
	hero.set_ground_height(temple.OUTDOOR_GROUND_Y)
	hero.global_position=Vector3(200,temple.OUTDOOR_GROUND_Y,200)
	hero.rotation.y=0

	# Every skill level must select its own clip and resolve exactly that many
	# independent damage windows. Changing the menu during a swing must not
	# mutate the combo already in progress.
	for level in range(1,6):
		state.set_odachi_skill_level(level)
		hero.rotation.y=0
		hero._combat_action=""
		hero._last_attack_ms=-10000
		var zombie=spawn_zombie(main.world_root,hero.global_position+Vector3(0,0,1.8),100)
		await physics_frame
		hero.attack()
		check(hero._combat_action=="SwordCombo%d"%level,"Skill level %d selected wrong animation"%level)
		check(hero._sword_level==level and hero._sword_contacts.size()==level and hero._sword_requested_stage==1,"Skill level %d runtime snapshot is wrong"%level)
		check(absf(hero._sword_combo_length-EXPECTED_DURATIONS[level-1])<.001,"Skill level %d duration mismatch"%level)
		for index in range(level):
			check(absf(hero._sword_contacts[index]-EXPECTED_CONTACTS[level-1][index])<.001,"Skill level %d contact %d metadata mismatch"%[level,index+1])
		var snapshotted_contacts: Array[float]=hero._sword_contacts.duplicate()
		state.set_odachi_skill_level(1 if level==5 else 5)
		check(hero._sword_level==level and hero._sword_contacts==snapshotted_contacts,"Open combo changed when skill menu value changed")
		var expected_health:=100
		for index in range(level):
			var contact: float=hero._sword_contacts[index]
			var before_contact: float=contact-hero._combat_elapsed-.001
			if before_contact>0:
				hero._tick_combat(before_contact)
			check(zombie.health==expected_health,"Sword level %d hit early at contact %d"%[level,index+1])
			hero._tick_combat(.002)
			expected_health-=4
			check(zombie.health==expected_health,"Sword level %d contact %d damage failed"%[level,index+1])
			check(zombie._stagger_elapsed>0,"Sword level %d contact %d applied no stagger"%[level,index+1])
			hero._tick_combat(.03)
			check(zombie.health==expected_health,"Sword level %d contact %d repeated damage"%[level,index+1])
			if index+1<level:
				hero.attack()
				check(hero._sword_requested_stage==index+2,"Separate press did not queue sword stage %d"%(index+2))
		check(hero._sword_contact_index==level,"Sword level %d skipped a contact window"%level)
		if level==5:
			check(is_instance_valid(hero.get_parent().get_node_or_null("SwordSlashFX5")),"Level-five finisher VFX missing")
		hero._tick_combat(hero._sword_combo_length-hero._combat_elapsed+.01)
		check(hero._combat_action.is_empty(),"Sword level %d recovery stuck"%level)
		zombie.queue_free()
		await physics_frame

	# Even at level five, one press performs exactly one cut and then takes the
	# natural SwordCombo1 recovery branch instead of forcing the remaining four.
	state.set_odachi_skill_level(5)
	hero.rotation.y=0
	var single=spawn_zombie(main.world_root,hero.global_position+Vector3(0,0,1.8),100)
	await physics_frame
	hero._combat_action=""
	hero._last_attack_ms=-10000
	hero.attack()
	hero._tick_combat(EXPECTED_DURATIONS[4]+.01)
	check(single.health==96 and hero._sword_contact_index==1,"One attack press forced more than one sword hit")
	check(hero._combat_action.is_empty() and hero._sword_chain_closed,"One-cut recovery did not finish")
	single.queue_free()
	await physics_frame

	# A wall still blocks the wider cone and bounded aim assist.
	state.set_odachi_skill_level(1)
	hero.rotation.y=0
	var blocked=spawn_zombie(main.world_root,hero.global_position+Vector3(0,0,1.8),20)
	var wall:=StaticBody3D.new()
	wall.collision_layer=3
	var collision:=CollisionShape3D.new()
	var box:=BoxShape3D.new()
	box.size=Vector3(2,3,.1)
	collision.shape=box
	wall.add_child(collision)
	main.world_root.add_child(wall)
	wall.global_position=hero.global_position+Vector3(0,0,.9)
	await physics_frame
	hero._combat_action=""
	hero._last_attack_ms=-10000
	hero.attack()
	hero._sword_requested_stage=5 # Represents five accepted presses before this simulated slow frame.
	hero._tick_combat(hero._sword_combo_length+.01)
	check(blocked.health==20,"Sword hits through walls")
	wall.queue_free()
	blocked.queue_free()
	await physics_frame

	# A single low-FPS frame must catch all five contacts and retarget after
	# the first ordinary zombie falls on hit three.
	state.set_odachi_skill_level(5)
	hero.rotation.y=0
	var lead=spawn_zombie(main.world_root,hero.global_position+Vector3(0,0,1.7),10)
	var reserve=spawn_zombie(main.world_root,hero.global_position+Vector3(0,0,2.2),20)
	await physics_frame
	hero._combat_action=""
	hero._last_attack_ms=-10000
	hero.attack()
	hero._sword_requested_stage=5 # Represents five separately accepted presses before this simulated slow frame.
	hero._tick_combat(hero._sword_combo_length+.01)
	check(lead._dying,"Five-hit combo did not defeat the first zombie in three hits")
	check(reserve.health==12,"Fourth and fifth contacts did not retarget the next zombie")
	lead.queue_free()
	reserve.queue_free()
	await physics_frame

	# Crossing recovery remains movement-locked for that whole physics frame.
	hero._prepare_sword_combo(5)
	hero._combat_action="SwordCombo5"
	hero._sword_requested_stage=5
	hero._sword_chain_closed=true
	hero._combat_elapsed=hero._sword_combo_length-.01
	hero._sword_contact_index=hero._sword_contacts.size()
	hero.touch_move=Vector2(1,0)
	var locked_position:=Vector2(hero.global_position.x,hero.global_position.z)
	var old_collision_mask: int=hero.collision_mask
	hero.collision_mask=0 # Isolate input locking from any town/world depenetration.
	hero._physics_process(.05)
	hero.collision_mask=old_collision_mask
	var recovery_distance:=Vector2(hero.global_position.x,hero.global_position.z).distance_to(locked_position)
	check(recovery_distance<.001,"Sword recovery frame allowed movement: %.6f m"%recovery_distance)
	hero.touch_move=Vector2.ZERO
	await physics_frame

	# After a few safe walking steps the carried blade moves to its scabbard;
	# a nearby enemy or the next attack draws it again immediately.
	hero._combat_action=""
	hero._set_sword_sheathed(false)
	hero._update_sword_carry_state(hero.SWORD_SHEATHE_DISTANCE+.1,true)
	check(hero._sword_sheathed and not hero._sword_model.visible and hero._sword_sheath_root.visible,"Safe walking did not sheath the odachi")
	check(hero._armed_motion("Walk")=="Walk","Sheathed odachi still uses drawn-sword locomotion")
	var alert=spawn_zombie(main.world_root,hero.global_position+Vector3(0,0,4.0),20)
	await physics_frame
	hero._update_sword_carry_state(0,false)
	check(not hero._sword_sheathed and hero._sword_model.visible and not hero._sword_sheath_root.visible,"Nearby enemy did not draw the odachi")
	alert.queue_free()
	await physics_frame
	hero._set_sword_sheathed(true)
	hero._last_attack_ms=-10000
	hero.attack()
	check(not hero._sword_sheathed and hero._combat_action.begins_with("SwordCombo"),"Attacking did not draw a sheathed odachi")
	hero._combat_action=""

	check(state.equip_item("bat","left_hand") and state.weapon_id()=="bat" and state.equipment.right_hand=="","Bat swap leaves two-handed weapon")
	check(not hero._sword_model.visible and hero._bat_models.L.visible,"Sword remains visible after swapping")
	state.equip_item("odachi","right_hand")
	hero.set_seated(true)
	hero._update_visual_motion(Vector3.ZERO,0)
	check(not hero._bat_attachments.R.visible,"Sword displayed when seated")
	hero.set_seated(false)
	var save_path="user://sword_test/slot.cfg"
	check(state.save_game(save_path)==OK,"Isolated save failed")
	state.start_new_run()
	check(not state.odachi_taken and temple.sword.visible,"New game failed to restore unique pickup")
	check(state.load_completed_save(save_path) and state.odachi_taken and state.weapon_id()=="odachi","Sword save/load failed")
	check(not temple.sword.visible,"Loaded sword respawned")

	print("SWORD_VERIFY errors=",errors)
	root.get_node("AudioDirector").stop_all()
	quit(1 if errors else 0)
