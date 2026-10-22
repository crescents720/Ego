extends CharacterBody3D

signal health_changed(current: float, maximum: float)
signal died
signal attacked(hit_something: bool)

const CRITICAL_HEALTH_RATIO := 0.25
var touch_move:=Vector2.ZERO
const MOVE_SPEED := 5.2
const ATTACK_RANGE := 1.60
const ATTACK_COOLDOWN_MS := 650
const PUNCH_CONTACT := 0.24
const PUNCH_LENGTH := 0.62
const SWORD_COMBO_ACTION := "SwordCombo4"
const SWORD_COMBO_CONTACTS := [0.432, 0.945, 1.468, 2.072]
const SWORD_COMBO_SWING_LEAD := 0.072
const SWORD_COMBO_LENGTH := 2.66
const ANIMATED_CHARACTER_MODEL_PATH := "res://assets/characters/anime-girl/hotaru_sword.glb"
const STATIC_CHARACTER_MODEL_PATH := "res://assets/characters/anime-girl/girl.glb"

const DEATH_DURATION := 1.65
var pushing_cart:=false
var sleeping:=false
var servicing:=false
var dead := false
var survival_death:=false
var death_source: Node3D
var active: bool = false
var health: float = 5.0
var max_health: int = 5
var _last_attack_ms: int = -1000
var _movement_camera: Camera3D
var _visual_root: Node3D
var _character_model: Node3D
var _animation_player: AnimationPlayer
var _animation_names: Dictionary = {}
var _current_animation_state: String = ""
var _walk_cycle: float = 0.0
var _ground_height: float = 0.95
var _seated: bool = false
var _combat_action := ""
var _combat_elapsed := 0.0
var _punch_contact_done := false
var _swing_sound_done := false
var _sword_contact_index := 0
var _sword_swing_index := 0
var _step_last_position := Vector3.ZERO
var _punch_target: Node3D
var _hit_tween: Tween
var _hit_material: StandardMaterial3D
var _body_meshes: Array[MeshInstance3D] = []
var _boarding_tween: Tween
var _boarding := false
var _weapon_hand := ""
var _bat_attachments: Dictionary={}
var _bat_models: Dictionary={}
var _sword_model: Node3D
var _attack_damage := 1
var _attack_range := ATTACK_RANGE


func _ready() -> void:
	name = "Hotaru"
	collision_layer = 1
	collision_mask = 3
	add_to_group("hotaru")
	_build_visual()
	_build_held_bats()
	GameState.inventory_changed.connect(sync_equipment)
	sync_equipment()

func _build_held_bats() -> void:
	if not is_instance_valid(_character_model):return
	var skeletons:=_character_model.find_children("*","Skeleton3D",true,false)
	if skeletons.is_empty():return
	var skeleton: Skeleton3D=skeletons[0]
	for side in ["L","R"]:
		var bone:=skeleton.find_bone("Hand."+side)
		var attachment:=BoneAttachment3D.new()
		attachment.bone_name="Hand."+side
		skeleton.add_child(attachment)
		var bat: Node3D=load("res://assets/items/baseball_bat/bat.glb").instantiate()
		attachment.add_child(bat)
		var orientation:=skeleton.get_bone_global_rest(bone).basis.inverse()*Basis(Quaternion(Vector3.UP,Vector3(0,-1,0.25).normalized()))
		bat.basis=orientation
		bat.position=orientation*Vector3(0,-0.10,0)+Vector3(0,-0.015,0)
		_bat_attachments[side]=attachment
		_bat_models[side]=bat
		if side=="R":
			_sword_model=load("res://assets/temple/odachi.glb").instantiate()
			attachment.add_child(_sword_model)
			_sword_model.basis=skeleton.get_bone_global_rest(bone).basis.inverse()*Basis(Vector3.FORWARD,PI/2)
			_sword_model.position=skeleton.get_bone_global_rest(bone).basis.inverse()*Vector3(0,-.035,-.012)
			_sword_model.hide()

func sync_equipment() -> void:
	if dead:return
	_weapon_hand=GameState.weapon_hand()
	for side in _bat_models:_bat_models[side].visible=GameState.weapon_id()=="bat"
	if is_instance_valid(_sword_model):_sword_model.visible=GameState.weapon_id()=="odachi"
	_combat_action=""
	_punch_target=null
	for side in _bat_attachments:_bat_attachments[side].visible=side==_weapon_hand and not _seated and not servicing and not pushing_cart
	_update_visual_motion(Vector3.ZERO,0)


func _physics_process(delta: float) -> void:
	if sleeping:return
	if dead:
		velocity=Vector3.ZERO
		return
	if servicing:
		velocity=Vector3.ZERO
		return
	if _boarding:
		velocity=Vector3.ZERO
		_play_character_animation(_armed_motion("Walk"))
		return
	if not active:
		cancel_boarding_step()
		velocity = Vector3.ZERO
		_update_visual_motion(Vector3.ZERO, delta)
		return

	var sword_combo_active := _combat_action.begins_with("SwordCombo")
	_tick_combat(delta)
	var input_vector := (Input.get_vector("move_left", "move_right", "move_backward", "move_forward")+touch_move).limit_length(1)
	var direction := Vector3(input_vector.x, 0.0, input_vector.y)
	if is_instance_valid(_movement_camera):
		var camera_forward: Vector3 = -_movement_camera.global_transform.basis.z
		var camera_right: Vector3 = _movement_camera.global_transform.basis.x
		camera_forward.y = 0.0
		camera_right.y = 0.0
		camera_forward = camera_forward.normalized()
		camera_right = camera_right.normalized()
		direction = camera_right * input_vector.x + camera_forward * input_vector.y
	if direction.length_squared() > 1.0:
		direction = direction.normalized()

	var action_speed := .48 if pushing_cart else (0.0 if sword_combo_active else (0.25 if not _combat_action.is_empty() else 1.0))
	velocity.x = direction.x * MOVE_SPEED * action_speed
	velocity.z = direction.z * MOVE_SPEED * action_speed
	velocity.y = 0.0
	if direction.length_squared() > 0.01 and _combat_action.is_empty() and not sword_combo_active:
		rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), minf(1.0, delta * 12.0))
	_step_last_position=global_position
	move_and_slide()
	global_position.y = _ground_height
	_update_visual_motion(direction, delta)


func set_active(value: bool) -> void:
	if dead and value:return
	active = value
	if not active:
		velocity = Vector3.ZERO
		_combat_action=""
		_punch_target=null
	_update_visual_motion(Vector3.ZERO, 0.0)


func set_movement_camera(value: Camera3D) -> void:
	_movement_camera = value


func set_ground_height(value: float) -> void:
	_ground_height = value
	global_position.y = value


func set_seated(value: bool) -> void:
	cancel_boarding_step()
	_seated = value
	if value:
		set_active(false)
	else:
		_update_visual_motion(Vector3.ZERO, 0.0)


func get_animation_state() -> String:
	return _current_animation_state

func play_boarding_step() -> void:
	cancel_boarding_step()
	_boarding=true
	_visual_root.position=global_basis.inverse()*Vector3(0.40,0,0)
	_play_character_animation(_armed_motion("Walk"),true)
	_boarding_tween=create_tween()
	_boarding_tween.tween_property(_visual_root,"position",Vector3.ZERO,0.48).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_boarding_tween.tween_callback(func():
		_boarding=false
		_play_character_animation(_armed_motion("Idle"))
	)

func cancel_boarding_step() -> void:
	if is_instance_valid(_boarding_tween):_boarding_tween.kill()
	_boarding=false
	if is_instance_valid(_visual_root):_visual_root.position=Vector3.ZERO


func _armed_motion(state: String) -> String:
	if GameState.weapon_id()=="odachi":return "Sword"+state
	return state if _weapon_hand.is_empty() else "Bat"+state+_weapon_hand

func attack() -> void:
	if pushing_cart or not active or _seated or not _combat_action.is_empty():
		return
	var now := Time.get_ticks_msec()
	if now - _last_attack_ms < ATTACK_COOLDOWN_MS:
		return
	_last_attack_ms = now
	_attack_damage=4 if GameState.weapon_id()=="odachi" else (2 if not _weapon_hand.is_empty() else 1)
	_attack_range=2.4 if _attack_damage==4 else (2.05 if _attack_damage==2 else ATTACK_RANGE)
	_punch_target=null
	var nearest:=_attack_range
	for zombie in get_tree().get_nodes_in_group("zombies"):
		if not is_instance_valid(zombie) or zombie._dying:
			continue
		var distance: float=global_position.distance_to(zombie.global_position)
		if distance<=nearest and _can_reach(zombie):
			nearest=distance
			_punch_target=zombie
	if is_instance_valid(_punch_target):
		var offset:=_punch_target.global_position-global_position
		rotation.y=atan2(offset.x,offset.z)
	_combat_action=SWORD_COMBO_ACTION if _attack_damage==4 else ("BatAttack"+_weapon_hand if _attack_damage==2 else "Punch")
	_combat_elapsed=0
	_punch_contact_done=false
	_swing_sound_done=false
	_sword_contact_index=0
	_sword_swing_index=0
	_play_character_animation(_combat_action,true)


func _can_reach(victim: Node3D) -> bool:
	var ray:=PhysicsRayQueryParameters3D.create(global_position+Vector3(0,0.2,0),victim.global_position+Vector3(0,0.2,0),3,[get_rid()])
	var result:=get_world_3d().direct_space_state.intersect_ray(ray)
	return result.is_empty() or result.collider==victim


func _tick_combat(delta: float) -> void:
	if _combat_action.is_empty():return
	_combat_elapsed+=delta
	if _combat_action==SWORD_COMBO_ACTION:
		# Resolve each cut in timeline order, even when one slow frame crosses
		# several swing and contact timestamps.
		while _sword_contact_index<SWORD_COMBO_CONTACTS.size():
			var contact_time: float=float(SWORD_COMBO_CONTACTS[_sword_contact_index])
			if _sword_swing_index==_sword_contact_index and _combat_elapsed>=contact_time-SWORD_COMBO_SWING_LEAD:
				AudioDirector.sound("swing",global_position,-16)
				_sword_swing_index+=1
			if _combat_elapsed<contact_time:
				break
			_resolve_sword_contact()
			_sword_contact_index+=1
		if _combat_elapsed>=SWORD_COMBO_LENGTH:
			_combat_action=""
			_punch_target=null
	elif _combat_action=="Punch" or _combat_action.begins_with("BatAttack"):
		var bat_attack:=_combat_action.begins_with("BatAttack")
		if not _swing_sound_done and _combat_elapsed>=(0.30 if bat_attack else 0.12):
			_swing_sound_done=true
			AudioDirector.sound("bat_swing" if bat_attack else "swing",global_position,-16)
		if not _punch_contact_done and _combat_elapsed>=(0.40 if bat_attack else PUNCH_CONTACT):
			_punch_contact_done=true
			var hit:=false
			if is_instance_valid(_punch_target) and not _punch_target._dying:
				var offset: Vector3=_punch_target.global_position-global_position
				offset.y=0
				if offset.length()<=_attack_range and transform.basis.z.dot(offset.normalized())>0.45 and _can_reach(_punch_target):
					_punch_target.take_damage(_attack_damage)
					AudioDirector.sound("bat_hit" if bat_attack else "punch",_punch_target.global_position)
					hit=true
			attacked.emit(hit)
		if _combat_elapsed>=(0.86 if bat_attack else PUNCH_LENGTH):
			_combat_action=""
			_punch_target=null
	elif _combat_elapsed>=0.44:
		_combat_action=""


func _resolve_sword_contact() -> void:
	if not _can_hit_current_target():
		_punch_target=_find_sword_target()
	var hit:=false
	if _can_hit_current_target():
		var victim:=_punch_target
		victim.take_damage(_attack_damage)
		AudioDirector.sound("bat_hit",victim.global_position)
		hit=true
		if victim._dying:_punch_target=null
	attacked.emit(hit)


func _find_sword_target() -> Node3D:
	var nearest: Node3D
	var nearest_distance:=_attack_range
	for zombie in get_tree().get_nodes_in_group("zombies"):
		if not is_instance_valid(zombie) or zombie._dying:
			continue
		var offset: Vector3=zombie.global_position-global_position
		offset.y=0
		var distance:=offset.length()
		if distance<=nearest_distance and distance>0.001 and transform.basis.z.dot(offset/distance)>0.45 and _can_reach(zombie):
			nearest=zombie
			nearest_distance=distance
	return nearest


func _can_hit_current_target() -> bool:
	if not is_instance_valid(_punch_target) or _punch_target._dying:
		return false
	var offset: Vector3=_punch_target.global_position-global_position
	offset.y=0
	var distance:=offset.length()
	return distance>0.001 and distance<=_attack_range and transform.basis.z.dot(offset/distance)>0.45 and _can_reach(_punch_target)


func take_damage(amount: int, source: Node3D = null) -> void:
	if not active or health <= 0:
		return
	health = maxf(0, health - amount)
	if health>0:AudioDirector.hero_voice("hero_hurt")
	_combat_action="Hit"
	_combat_elapsed=0
	_punch_target=null
	_play_character_animation("Hit",true)
	if is_instance_valid(_hit_tween):_hit_tween.kill()
	for mesh in _body_meshes:mesh.material_overlay=_hit_material
	_hit_tween=create_tween()
	_hit_tween.tween_method(func(alpha: float): _hit_material.albedo_color.a=alpha,0.30,0.0,0.22)
	_hit_tween.tween_callback(func():
		for mesh in _body_meshes:mesh.material_overlay=null
	)
	health_changed.emit(health, max_health)
	if health <= 0:
		death_source=source
		play_death()
		died.emit()


func take_survival_damage(amount: float) -> void:
	if dead or health<=0 or amount<=0:return
	health=maxf(0,health-maxf(0,amount))
	if health<0.00001:health=0.0
	health_changed.emit(health,max_health)
	if health<=0:
		survival_death=true
		play_death()
		died.emit()

func play_death() -> void:
	if dead:return
	cancel_boarding_step()
	dead=true
	AudioDirector.hero_voice("hero_death")
	_death_landing_sound()
	for label in find_children("*","Label3D",true,false):label.hide()
	active=false
	velocity=Vector3.ZERO
	_combat_action=""
	_punch_target=null
	collision_layer=0
	for side in _bat_attachments:_bat_attachments[side].hide()
	if is_instance_valid(death_source):
		var direction: Vector3=death_source.global_position-global_position
		direction.y=0
		if direction.length_squared()>0.001:rotation.y=atan2(direction.x,direction.z)
	_play_character_animation("Death",true)

func reset_death() -> void:
	sleeping=false
	dead=false
	survival_death=false
	for label in find_children("*","Label3D",true,false):label.show()
	death_source=null
	collision_layer=1
	_current_animation_state=""
	sync_equipment()

func _build_visual() -> void:
	var collision := CollisionShape3D.new()
	var capsule_shape := CapsuleShape3D.new()
	capsule_shape.radius = 0.36
	capsule_shape.height = 1.65
	collision.shape = capsule_shape
	add_child(collision)

	_visual_root = Node3D.new()
	_visual_root.name = "HotaruVisual"
	add_child(_visual_root)

	var character_path := ANIMATED_CHARACTER_MODEL_PATH
	if not ResourceLoader.exists(character_path):
		character_path = STATIC_CHARACTER_MODEL_PATH
	if ResourceLoader.exists(character_path):
		var model_resource := load(character_path)
		if model_resource is PackedScene:
			var model: Node3D = model_resource.instantiate()
			model.name = "HotaruAnimatedPrototype" if character_path == ANIMATED_CHARACTER_MODEL_PATH else "AnimeGirlPrototype"
			# CharacterBody roots sit near capsule center.  The visual origin is
			# feet-level, so this offset places shoes just above both world and RV floors.
			model.position = Vector3(0.0, -0.93, 0.0)
			# Both converted assets face local +Z, matching atan2(x, z) below.
			model.rotation.y = 0.0
			_visual_root.add_child(model)
			_character_model = model
			for mesh in model.find_children("*","MeshInstance3D",true,false):_body_meshes.append(mesh)
			_hit_material=StandardMaterial3D.new()
			_hit_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
			_hit_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
			_hit_material.albedo_color=Color(1,0.25,0.18,0)
			_animation_player = _find_animation_player(model)
			if is_instance_valid(_animation_player):
				_cache_character_animations()
				_play_character_animation("Idle", true)
		else:
			_build_fallback_visual()
	else:
		_build_fallback_visual()

	var label := Label3D.new()
	label.text = "蛍"
	label.position.y = 1.45
	label.font_size = 32
	label.outline_size = 8
	label.modulate = Color("ffe4a8")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	add_child(label)


func _build_fallback_visual() -> void:
	var body_mesh := MeshInstance3D.new()
	var body := CapsuleMesh.new()
	body.radius = 0.32
	body.height = 1.12
	body_mesh.mesh = body
	body_mesh.position.y = -0.08
	body_mesh.material_override = _material(Color("d96a4e"))
	_visual_root.add_child(body_mesh)

	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.29
	head_mesh.height = 0.58
	head.mesh = head_mesh
	head.position = Vector3(0.0, 0.72, 0.0)
	head.material_override = _material(Color("f3c6aa"))
	_visual_root.add_child(head)

	var hair := MeshInstance3D.new()
	var hair_mesh := SphereMesh.new()
	hair_mesh.radius = 0.315
	hair_mesh.height = 0.54
	hair.mesh = hair_mesh
	hair.position = Vector3(0.0, 0.82, -0.045)
	hair.scale = Vector3(1.03, 0.72, 1.03)
	hair.material_override = _material(Color("27202b"))
	_visual_root.add_child(hair)

	var pack := MeshInstance3D.new()
	var pack_mesh := BoxMesh.new()
	pack_mesh.size = Vector3(0.48, 0.62, 0.2)
	pack.mesh = pack_mesh
	pack.position = Vector3(0.0, 0.02, -0.31)
	pack.material_override = _material(Color("3c5152"))
	_visual_root.add_child(pack)


func _update_visual_motion(direction: Vector3, delta: float) -> void:
	if sleeping or servicing:return
	if dead:return
	if not is_instance_valid(_visual_root):
		return
	if is_instance_valid(_animation_player):
		var desired_animation := "Sit" if _seated else ("Walk" if direction.length_squared() > 0.01 and active else "Idle")
		if pushing_cart:desired_animation="PushWalk" if direction.length_squared()>.01 and active else "PushIdle"
		if not pushing_cart and not _weapon_hand.is_empty() and not _seated:desired_animation=_armed_motion(desired_animation)
		for side in _bat_attachments:_bat_attachments[side].visible=side==_weapon_hand and not _seated and not servicing and not pushing_cart
		if not _combat_action.is_empty() and not _seated:desired_animation=_combat_action
		_play_character_animation(desired_animation)
		_visual_root.position.y = 0.0
		_visual_root.rotation.z = 0.0
		return
	if _seated:
		_visual_root.position.y = lerpf(_visual_root.position.y, 0.0, minf(1.0, delta * 12.0))
		_visual_root.rotation.z = lerpf(_visual_root.rotation.z, 0.0, minf(1.0, delta * 12.0))
		return
	if direction.length_squared() > 0.01 and active:
		_walk_cycle += delta * 10.0
		_visual_root.position.y = lerpf(_visual_root.position.y, absf(sin(_walk_cycle)) * 0.035, minf(1.0, delta * 14.0))
		_visual_root.rotation.z = lerpf(_visual_root.rotation.z, sin(_walk_cycle) * 0.025, minf(1.0, delta * 12.0))
	else:
		_walk_cycle += delta * 2.0
		_visual_root.position.y = lerpf(_visual_root.position.y, sin(_walk_cycle) * 0.006, minf(1.0, delta * 8.0))
		_visual_root.rotation.z = lerpf(_visual_root.rotation.z, 0.0, minf(1.0, delta * 8.0))


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var result := _find_animation_player(child)
		if is_instance_valid(result):
			return result
	return null


func _cache_character_animations() -> void:
	_animation_names.clear()
	for animation_name in _animation_player.get_animation_list():
		var normalized := str(animation_name).to_lower()
		for state_name in ["Idle", "Walk", "Sit", "Punch", "Hit","BatIdleR","BatWalkR","BatAttackR","BatIdleL","BatWalkL","BatAttackL","Death","Sleep","RepairKneel","FuelHold","PushIdle","PushWalk","LatheWork","SwordIdle","SwordWalk","SwordCombo1","SwordCombo2","SwordCombo3","SwordCombo4","SwordCombo5"]:
			var target: String = str(state_name).to_lower()
			if normalized == target or normalized.ends_with("/" + target) or normalized.ends_with("|" + target):
				_animation_names[state_name] = animation_name
				var animation := _animation_player.get_animation(animation_name)
				if animation:
					if state_name in ["Walk","BatWalkL","BatWalkR","PushWalk","SwordWalk"]:
						_install_foot_contacts(animation)
					animation.loop_mode = Animation.LOOP_NONE if state_name in ["Punch","Hit","Death"] or state_name.begins_with("BatAttack") or state_name.begins_with("SwordCombo") else Animation.LOOP_LINEAR


func _play_character_animation(state_name: String, restart: bool = false) -> void:
	if not is_instance_valid(_animation_player) or not _animation_names.has(state_name):
		return
	if not restart and _current_animation_state == state_name:
		return
	var animation_name: StringName = _animation_names[state_name]
	var blend_time := 0.0 if _current_animation_state.is_empty() else (0.035 if state_name in ["Punch","Hit","Death"] else 0.10)
	_animation_player.play(animation_name, blend_time)
	_animation_player.advance(0.0)
	_current_animation_state = state_name


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.86
	return material


func _death_landing_sound() -> void:
	await get_tree().create_timer(1.1,false).timeout
	if dead:AudioDirector.sound("body",global_position,-17)

func _foot_plant() -> void:
	# Animation calls at left/right contact. Actual motion suppresses wall shuffling.
	if not active or sleeping or dead or _seated or _boarding or not _combat_action.is_empty():return
	if global_position.distance_to(_step_last_position)<0.002:return
	AudioDirector.sound(AudioDirector._footstep(global_position),global_position,-26)

func _install_foot_contacts(animation: Animation) -> void:
	if animation.has_meta("foot_contacts"):return
	var track:=animation.add_track(Animation.TYPE_METHOD)
	var animation_root: Node=_animation_player.get_node(_animation_player.root_node)
	animation.track_set_path(track,animation_root.get_path_to(self))
	# The authored 30 fps cycle has left contact at frame 1, right at frame 16.
	for time in [0.0,animation.length*0.5]:
		animation.track_insert_key(track,time,{"method":&"_foot_plant","args":[]})
	animation.set_meta("foot_contacts",true)
