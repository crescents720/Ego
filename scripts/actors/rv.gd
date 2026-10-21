extends CharacterBody3D
var touch_move:=Vector2.ZERO
var touch_driving:=false
var touch_steer:=0.0
var touch_throttle:=0.0
var touch_brake:=false
var touch_gear:=1
var _touch_turn:=0.0

signal speed_changed(speed_kph: int)
signal health_changed(current: int,maximum: int)
signal exploded(was_occupied: bool)
signal rammed(speed_before: float)
signal hostile_attack
var last_hostile_attack_ms: int=-100000
const Fire=preload("res://scripts/environment/story_fire.gd")
const BASE_HEALTH:=120
const RAM_SPEED:=4.5
const HULL_HALF:=Vector3(1.0875,0,3.1875)

const MODEL_PATH := "res://assets/vehicles/bounder/bounder_hatches.glb"
const MODEL_SCALE := 0.75
const SIDE_DOOR_Z := -1.05*MODEL_SCALE
const SIDE_DOOR := Vector3(1.49*MODEL_SCALE, 0.0, SIDE_DOOR_Z)

const MAX_FORWARD_SPEED := 14.0
const MAX_REVERSE_SPEED := 5.0
const ACCELERATION := 10.0
const BRAKE_FORCE := 16.0
const COAST_DECELERATION := 5.5
const TURN_SPEED := 1.28

var travel_bounds := Rect2(-165,-165,480,580)
var active: bool = false
var speed: float = 0.0
var upgrade_level: int = 0
var _upgrade_visuals: Node3D
var _door_label: Label3D
var health:=BASE_HEALTH
var max_health:=BASE_HEALTH
var occupied:=false
var wrecked:=false
var _damage_fire: Node3D
var _critical_fire: Node3D
var _blast: Node3D
var _original_materials: Dictionary={}


func _ready() -> void:
	name = "FamilyRV"
	collision_layer = 2
	collision_mask = 7
	add_to_group("rv")
	_build_visual()
	_build_damage_effects()


func _physics_process(delta: float) -> void:
	if not active or wrecked:
		speed = move_toward(speed, 0.0, BRAKE_FORCE * delta)
		velocity = Vector3.ZERO
		return

	var throttle := clampf(Input.get_axis("move_backward", "move_forward")+touch_move.y,-1,1)
	var steering := clampf(Input.get_axis("move_left", "move_right")+touch_move.x,-1,1)
	if touch_driving:
		throttle=touch_throttle*touch_gear
		_touch_turn=move_toward(_touch_turn,touch_steer,delta*(3.8 if not is_zero_approx(touch_steer) else 4.8))
		steering=_touch_turn
	else:_touch_turn=0
	var target_speed := 0.0
	if GameState.fuel_l<=0:throttle=0.0
	if throttle > 0.0:
		target_speed = throttle * MAX_FORWARD_SPEED
	elif throttle < 0.0:
		target_speed = throttle * (2.5 if touch_driving else MAX_REVERSE_SPEED)

	if touch_driving and touch_brake:
		speed=move_toward(speed,0.0,BRAKE_FORCE*delta)
	elif absf(throttle) > 0.05:
		var rate := (6.0 if touch_driving else ACCELERATION) if signf(target_speed) == signf(speed) or absf(speed) < 0.1 else BRAKE_FORCE
		speed = move_toward(speed, target_speed, rate * delta)
	else:
		speed = move_toward(speed, 0.0, COAST_DECELERATION * delta)

	if absf(speed) > 0.25:
		var turn_gain: float=clampf(absf(speed)/4.0,.45,1.0)
		if touch_driving:turn_gain=clampf(absf(speed)/2.0,.12,1.0)*lerpf(1.0,.48,clampf((absf(speed)-4)/10,0,1))
		rotation.y -= steering * TURN_SPEED * delta * signf(speed) * turn_gain

	velocity = -transform.basis.z * speed
	velocity.y = 0.0
	var before:=global_position
	var motion:=velocity*delta
	var available: float=GameState.fuel_l/GameState.FUEL_PER_M
	if motion.length()>available:motion=motion.normalized()*available
	_drive_motion(motion)
	global_position.x = clampf(global_position.x, travel_bounds.position.x, travel_bounds.end.x)
	global_position.z = clampf(global_position.z, travel_bounds.position.y, travel_bounds.end.y)
	global_position.y = 1.02
	GameState.consume_distance(Vector2(global_position.x-before.x,global_position.z-before.z).length())
	if GameState.fuel_l<=0:speed=0.0
	speed_changed.emit(int(round(absf(speed) * 3.6)))


func set_active(value: bool) -> void:
	active = value and not wrecked
	if is_instance_valid(_door_label):
		_door_label.visible = not value
	if not active:
		velocity = Vector3.ZERO


func apply_first_upgrade() -> void:
	if upgrade_level==1:return
	var ratio:=float(health)/max_health
	upgrade_level = 1
	max_health=160
	health=roundi(ratio*max_health)
	if _upgrade_visuals:
		_upgrade_visuals.visible = true
	health_changed.emit(health,max_health)
	_update_damage_effects()

func _drive_motion(motion: Vector3) -> void:
	# Sweep the solid hull. Dead zombies release their collider immediately,
	# allowing the remaining movement to continue at the reduced speed.
	for impact in range(12):
		if motion.length_squared()<0.000001 or wrecked:break
		var hit:=move_and_collide(motion)
		if hit==null:break
		var actor:=hit.get_collider()
		var closing_speed:=absf(speed)*maxf(0.0,-motion.normalized().dot(hit.get_normal()))
		if actor!=null and actor.is_in_group("zombies") and not actor._dying and closing_speed>=RAM_SPEED:
			var before:=absf(speed)
			actor.take_damage(100)
			var retention:=0.90 if upgrade_level>0 else 0.82
			speed*=retention
			motion=hit.get_remainder()*retention
			take_damage(2)
			AudioDirector.sound("ram_flesh",actor.global_position,-8)
			rammed.emit(before)
		else:
			if absf(speed)>1.0:AudioDirector.sound("crash",global_position,-8)
			# Throttle cannot build invisible speed against a solid crowd/wall.
			speed=0
			velocity=Vector3.ZERO
			break

func closest_hull_point(world_point: Vector3) -> Vector3:
	var local:=to_local(world_point)
	local.x=clampf(local.x,-HULL_HALF.x,HULL_HALF.x)
	local.z=clampf(local.z,-HULL_HALF.z,HULL_HALF.z)
	return to_global(local)

func mark_hostile_attack() -> void:
	last_hostile_attack_ms=Time.get_ticks_msec()
	hostile_attack.emit()

func repair_full() -> void:
	if wrecked:return
	GameState.repair_fences()
	health=max_health
	_update_damage_effects()
	health_changed.emit(health,max_health)

func take_damage(amount: int) -> void:
	if wrecked or amount<=0:return
	var damage:=maxi(1,ceili(float(amount)*(0.5 if upgrade_level>0 else 1.0)))
	health=maxi(0,health-damage)
	health_changed.emit(health,max_health)
	_update_damage_effects()
	if health==0:_explode()

func reset_condition() -> void:
	clear_touch_drive()
	last_hostile_attack_ms=-100000
	wrecked=false
	occupied=false
	active=false
	speed=0
	velocity=Vector3.ZERO
	upgrade_level=0
	max_health=BASE_HEALTH
	health=max_health
	_upgrade_visuals.hide()
	for mesh in _original_materials:
		if is_instance_valid(mesh):mesh.material_override=_original_materials[mesh]
	_original_materials.clear()
	if is_instance_valid(_blast):_blast.queue_free()
	_update_damage_effects()
	health_changed.emit(health,max_health)

func restore_health_ratio(ratio: float) -> void:
	health=clampi(roundi(max_health*ratio),1,max_health)
	_update_damage_effects()
	health_changed.emit(health,max_health)

func _build_damage_effects() -> void:
	_damage_fire=Fire.new()
	_damage_fire.name="EngineDamageFire"
	_damage_fire.position=Vector3(0,0.9,-2.35)
	_damage_fire.scale=Vector3.ONE*0.85
	add_child(_damage_fire)
	_critical_fire=Fire.new()
	_critical_fire.name="CriticalRoofFire"
	_critical_fire.position=Vector3(0,1.35,0.35)
	_critical_fire.scale=Vector3.ONE*1.3
	add_child(_critical_fire)
	_update_damage_effects()

func _update_damage_effects() -> void:
	if not is_instance_valid(_damage_fire):return
	var ratio:=float(health)/max_health
	_damage_fire.visible=ratio<=0.5
	_critical_fire.visible=ratio<=0.25
	_damage_fire.process_mode=Node.PROCESS_MODE_INHERIT if _damage_fire.visible else Node.PROCESS_MODE_DISABLED
	_critical_fire.process_mode=Node.PROCESS_MODE_INHERIT if _critical_fire.visible else Node.PROCESS_MODE_DISABLED

func _explode() -> void:
	if wrecked:return
	wrecked=true
	active=false
	speed=0
	velocity=Vector3.ZERO
	var scorched:=_material(Color("282b2b"),1.0)
	for mesh in get_node("FleetwoodBounder").find_children("*","MeshInstance3D",true,false):
		_original_materials[mesh]=mesh.material_override
		mesh.material_override=scorched
	_blast=Node3D.new()
	_blast.name="RVExplosion"
	_blast.position.y=1.1
	add_child(_blast)
	var flash:=MeshInstance3D.new()
	var sphere:=QuadMesh.new()
	sphere.size=Vector2(1.2,1.2)
	flash.mesh=sphere
	flash.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material:=StandardMaterial3D.new()
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED
	material.billboard_keep_scale=true
	material.cull_mode=BaseMaterial3D.CULL_DISABLED
	material.no_depth_test=true
	material.blend_mode=BaseMaterial3D.BLEND_MODE_ADD
	var gradient:=Gradient.new()
	gradient.set_color(0,Color(1,1,0.8,1))
	gradient.set_color(1,Color(1,0.15,0.01,0))
	gradient.add_point(0.48,Color(1,0.60,0.10,0.85))
	var glow:=GradientTexture2D.new()
	glow.gradient=gradient
	glow.fill=GradientTexture2D.FILL_RADIAL
	glow.fill_from=Vector2(0.5,0.5)
	glow.fill_to=Vector2(1,0.5)
	material.albedo_texture=glow
	material.albedo_color=Color(1,0.45,0.06,0.85)
	material.emission_enabled=true
	material.emission=Color(1,0.30,0.02)
	material.emission_energy_multiplier=3
	flash.material_override=material
	_blast.add_child(flash)
	var light:=OmniLight3D.new()
	light.light_color=Color("ffbe73")
	light.light_energy=12
	light.omni_range=14
	_blast.add_child(light)
	var sound:=AudioStreamPlayer.new()
	sound.stream=load("res://assets/audio/rv_explosion.wav")
	sound.bus="Effects"
	var listener_distance: float=0.0
	if is_instance_valid(AudioDirector.main) and not occupied:
		listener_distance=global_position.distance_to(AudioDirector.main.hotaru.global_position)
	sound.volume_db=-5-20*log(maxf(1.0,listener_distance/8.0))/log(10.0)
	_blast.add_child(sound)
	sound.play()
	var sparks:=CPUParticles3D.new()
	sparks.amount=52
	sparks.one_shot=true
	sparks.explosiveness=1
	sparks.lifetime=1.3
	sparks.direction=Vector3.UP
	sparks.spread=180
	sparks.initial_velocity_min=3
	sparks.initial_velocity_max=7
	sparks.gravity=Vector3(0,-5,0)
	var particle:=SphereMesh.new()
	particle.radius=0.07
	particle.height=0.14
	var spark_material:=_material(Color("ff8c26"),1)
	spark_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	particle.material=spark_material
	sparks.mesh=particle
	_blast.add_child(sparks)
	sparks.emitting=true
	var tween:=create_tween().set_parallel()
	tween.tween_property(flash,"scale",Vector3.ONE*6,0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(material,"albedo_color:a",0.0,0.7)
	tween.tween_property(light,"light_energy",0.0,0.8)
	var had_occupants:=occupied
	occupied=false
	exploded.emit(had_occupants)


func get_side_door_position() -> Vector3:
	return to_global(SIDE_DOOR)


func is_near_side_door(player_position: Vector3) -> bool:
	if wrecked:return false
	var local_player := to_local(player_position)
	return local_player.x >= SIDE_DOOR.x-0.10 and Vector2(local_player.x - SIDE_DOOR.x, local_player.z - SIDE_DOOR.z).length() <= 1.35


func get_disembark_position(outward: float = 0.0) -> Vector3:
	return to_global(Vector3(SIDE_DOOR.x+0.66+outward, -0.07, SIDE_DOOR_Z))


func _build_visual() -> void:
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.90, 2.45, 8.50)*MODEL_SCALE
	collision.position.y = -0.93+(0.42+0.93)*MODEL_SCALE
	collision.shape = shape
	add_child(collision)
	var model: Node3D = load(MODEL_PATH).instantiate()
	model.name = "FleetwoodBounder"
	model.position.y = -0.93
	add_child(model)
	# The supplied exterior is open on top; add an opaque roof below its vents.
	_add_box("OpaqueRoof",Vector3(2.84,0.12,7.05),Vector3(0,2.20,0.64),Color("c7c3ad"))
	_build_cab_roof_seam()
	_extend_windshield()
	_add_box("RoofVentRear",Vector3(0.72,0.12,0.82),Vector3(0,2.29,2.65),Color("e0dcc5"))
	_add_box("RoofVentFront",Vector3(0.76,0.12,0.90),Vector3(0,2.29,-1.9),Color("dcd7bf"))

	_upgrade_visuals = Node3D.new()
	_upgrade_visuals.name = "Level1Armor"
	_upgrade_visuals.visible = false
	add_child(_upgrade_visuals)
	_add_box_to(_upgrade_visuals, "FrontBumper", Vector3(3.0, 0.28, 0.25), Vector3(0, -0.35, -4.35), Color("d79a2d"))
	_add_box_to(_upgrade_visuals, "RoofRack", Vector3(2.55, 0.13, 3.2), Vector3(0, 2.57, 1.15), Color("30363a"))
	_add_box_to(_upgrade_visuals, "LeftArmor", Vector3(0.10, 0.65, 5.4), Vector3(-1.49, 0.05, 0.0), Color("687277"))
	# Leave a gap around the passenger-side entrance and its step.
	_add_box_to(_upgrade_visuals, "RightRearArmor", Vector3(0.10, 0.65, 3.7), Vector3(1.49, 0.05, 1.5), Color("687277"))
	_add_box_to(_upgrade_visuals, "RightFrontArmor", Vector3(0.10, 0.65, 1.6), Vector3(1.49, 0.05, -2.8), Color("687277"))

	_door_label = Label3D.new()
	_door_label.text = "右侧车门 · E"
	_door_label.position = Vector3(1.60, 1.15, -1.05)
	_door_label.font_size = 24
	_door_label.outline_size = 7
	_door_label.modulate = Color("ffdfa1")
	_door_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_door_label.no_depth_test = true
	add_child(_door_label)
	# Scale about wheel/ground level, not the actor root. Keep people and
	# disembark clearance at their original size; scale the door anchor separately.
	for node in get_children():
		if not node is Node3D or node==collision:continue
		node.position=Vector3(node.position.x*MODEL_SCALE,-0.93+(node.position.y+0.93)*MODEL_SCALE,node.position.z*MODEL_SCALE)
		if not node is Label3D:node.scale*=MODEL_SCALE


func _build_cab_roof_seam() -> void:
	# Follow the windshield's sloping upper frame; overlap the main roof instead of leaving a slit.
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cross_sections: Array[Vector2]=[Vector2(-3.46,2.10),Vector2(-3.15,2.19),Vector2(-2.78,2.40),Vector2(-2.64,2.23)]
	for i in range(cross_sections.size()-1):
		var a:=Vector3(-1.46,cross_sections[i].y,cross_sections[i].x)
		var b:=Vector3(1.46,cross_sections[i].y,cross_sections[i].x)
		var c:=Vector3(-1.46,cross_sections[i+1].y,cross_sections[i+1].x)
		var d:=Vector3(1.46,cross_sections[i+1].y,cross_sections[i+1].x)
		for vertex in [a,c,b,b,c,d]:surface.add_vertex(vertex)
		# Short side skirts seal the header edges without covering the glass.
		for x in [-1.46,1.46]:
			var u:=Vector3(x,cross_sections[i].y-.14,cross_sections[i].x)
			var v:=Vector3(x,cross_sections[i+1].y-.14,cross_sections[i+1].x)
			var top_a:=Vector3(x,cross_sections[i].y,cross_sections[i].x)
			var top_b:=Vector3(x,cross_sections[i+1].y,cross_sections[i+1].x)
			for vertex in [u,v,top_a,top_a,v,top_b]:surface.add_vertex(vertex)
	surface.generate_normals()
	var seam:=MeshInstance3D.new()
	seam.name="CabRoofSealedHeader"
	seam.mesh=surface.commit()
	var material:=_material(Color("c7c3ad"),.82)
	material.cull_mode=BaseMaterial3D.CULL_DISABLED
	seam.material_override=material
	add_child(seam)

func _add_box(node_name: String, size: Vector3, position_value: Vector3, color: Color) -> void:
	_add_box_to(self, node_name, size, position_value, color)


func _add_box_to(parent: Node, node_name: String, size: Vector3, position_value: Vector3, color: Color) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = position_value
	instance.material_override = _material(color, 0.82)
	parent.add_child(instance)


func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = 0.12
	return material


func _extend_windshield() -> void:
	# Source glass ends around local y=1.56 after the model's -0.93 offset.
	# Extend the same sloping plane to overlap the roof header, not just its sides.
	var surface:=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var a:=Vector3(-1.42,1.49,-3.745)
	var b:=Vector3(1.37,1.49,-3.745)
	var c:=Vector3(-1.46,2.16,-3.43)
	var d:=Vector3(1.46,2.16,-3.43)
	for vertex in [a,c,b,b,c,d]:surface.add_vertex(vertex)
	surface.generate_normals()
	var glass:=MeshInstance3D.new()
	glass.name="WindshieldUpperExtension"
	glass.mesh=surface.commit()
	var material:=_material(Color(.24,.36,.49),.85)
	material.cull_mode=BaseMaterial3D.CULL_DISABLED
	material.metallic=0.0
	glass.material_override=material
	add_child(glass)


func take_zombie_hit(attacker_point: Vector3) -> void:
	var local:=to_local(attacker_point)
	var side: String
	if absf(local.x)/HULL_HALF.x>absf(local.z)/HULL_HALF.z:side="right" if local.x>0 else "left"
	else:side="front" if local.z<0 else "back"
	var hp:=int(GameState.fence_hp.get(side,0))
	if hp>0:
		GameState.fence_hp[side]=hp-1
		GameState.inventory_changed.emit()
		return
	take_damage(4)


func set_touch_drive(steer: float,throttle: float,brake: bool,gear: int) -> void:
	touch_driving=true
	touch_steer=clampf(steer,-1,1)
	touch_throttle=clampf(throttle,0,1)
	touch_brake=brake
	touch_gear=1 if gear>=0 else -1
func clear_touch_drive() -> void:
	touch_driving=false
	touch_steer=0
	touch_throttle=0
	touch_brake=false
	touch_move=Vector2.ZERO
	_touch_turn=0
