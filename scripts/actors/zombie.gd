extends CharacterBody3D

signal defeated
const MODEL_PATH := "res://assets/characters/zombie/zombie_combat.glb"
const MOVE_SPEED := 0.85
const AGGRO_RANGE := 17.0
const ATTACK_RANGE := 1.0
const ATTACK_COOLDOWN_MS := 1200
const BITE_CONTACT := 0.44
const VEHICLE_CONTACT := 0.60
const VEHICLE_ATTACK_LENGTH := 1.15
const MAX_HEALTH := 10

var move_speed:=MOVE_SPEED
var ground_height:=0.9
var target: Node3D
var vehicle_target: Node3D
var _bite_victim: Node3D
var aggro_range: float=AGGRO_RANGE
var pursuit_detour:=PackedVector3Array()
var _detour_index:=0
var health: int = MAX_HEALTH
var _last_attack_ms: int = -1000
var _visual: Node3D
var _meshes: Array[MeshInstance3D] = []
var _hit_material: StandardMaterial3D
var _hit_tween: Tween
var _walk_time := 0.0
var _dying := false
var _animation_player: AnimationPlayer
var _animations: Dictionary = {}
var _animation_state := ""
var _bite_elapsed := -1.0
var _bite_contact_done := false
var _recoil_elapsed := 0.0
var _wander_rng := RandomNumberGenerator.new()
var _wander_origin := Vector3.ZERO
var _wander_goal := Vector3.ZERO
var _wander_ready := false
var _wander_wait := 0.0
var _wander_stuck := 0.0

func _ready() -> void:
 collision_layer = 4
 collision_mask = 3
 add_to_group("zombies")
 var collision := CollisionShape3D.new()
 var capsule := CapsuleShape3D.new()
 capsule.radius = 0.33
 capsule.height = 1.7
 collision.shape = capsule
 add_child(collision)
 _visual = load(MODEL_PATH).instantiate()
 _visual.name = "ZombieVisual"
 _visual.position.y = -0.89
 _visual.scale = Vector3.ONE * 1.08
 add_child(_visual)
 for node in _visual.find_children("*", "MeshInstance3D", true, false):
  _meshes.append(node)
 for node in _visual.find_children("*","AnimationPlayer",true,false):
  _animation_player=node
  for animation in node.get_animation_list():
   var state:=str(animation).get_file()
   _animations[state]=animation
   node.get_animation(animation).loop_mode=Animation.LOOP_LINEAR if state in ["Idle","Walk"] else Animation.LOOP_NONE
 _build_vehicle_attack()
 _play_animation("Idle")
 _wander_rng.randomize()
 _hit_material = StandardMaterial3D.new()
 _hit_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
 _hit_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
 _hit_material.albedo_color = Color(1, 0.35, 0.25, 0.0)

func _physics_process(delta: float) -> void:
 if _dying:
  return
 var victim:=_choose_target()
 if not is_instance_valid(victim):
  _bite_elapsed=-1
  _wander(delta)
  return
 var offset := _target_point(victim) - global_position
 offset.y = 0
 var distance := offset.length()
 if distance > aggro_range:
  _bite_elapsed=-1
  _wander(delta)
  return
 _wander_ready=false
 var direction := offset.normalized()
 # Opening pursuers go around the south side of the burning house rather
 # than pressing into its front wall after Hotaru reaches the backyard.
 if not pursuit_detour.is_empty() and victim.global_position.x < -8.5:
  while _detour_index<pursuit_detour.size() and global_position.distance_to(pursuit_detour[_detour_index])<1.0:
   _detour_index+=1
  if _detour_index<pursuit_detour.size():
   var detour:=pursuit_detour[_detour_index]-global_position
   detour.y=0
   direction=detour.normalized()
 rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), minf(1.0, delta * 7.0))
 if _bite_elapsed>=0:
  if _bite_victim!=victim:
   _bite_elapsed=-1
   _bite_victim=null
   return
  velocity=Vector3.ZERO
  _tick_bite(delta)
  return
 if distance > ATTACK_RANGE:
  velocity = direction * move_speed
  move_and_slide()
 else:
  velocity = Vector3.ZERO
  var now := Time.get_ticks_msec()
  if now - _last_attack_ms >= ATTACK_COOLDOWN_MS:
   _last_attack_ms = now
   AudioDirector.sound("bite",global_position,-17)
   _bite_elapsed=0
   _bite_victim=victim
   if victim.is_in_group("rv"):victim.mark_hostile_attack()
   _bite_contact_done=false
   _play_animation("VehicleAttack" if victim.is_in_group("rv") else "Bite",true)
 global_position.y = ground_height
 var actual_speed:=Vector2(get_real_velocity().x,get_real_velocity().z).length()
 _update_motion(delta, distance > ATTACK_RANGE and actual_speed>0.05)

func _wander(delta: float) -> void:
 if not _wander_ready:
  _wander_ready=true
  _wander_origin=global_position
  _wander_goal=global_position
  _wander_wait=_wander_rng.randf_range(0.15,1.1)
 if _wander_wait>0:
  _wander_wait-=delta
  velocity=Vector3.ZERO
  _update_motion(delta,false)
  return
 var offset:=_wander_goal-global_position
 offset.y=0
 if offset.length()<0.20 or _wander_stuck>0.65:
  _wander_stuck=0
  _wander_goal=global_position
  for attempt in range(8):
   var angle:=_wander_rng.randf_range(-PI,PI)
   var candidate:=_wander_origin+Vector3(sin(angle),0,cos(angle))*_wander_rng.randf_range(0.8,2.8)
   candidate.y=ground_height
   var query:=PhysicsRayQueryParameters3D.create(global_position,candidate,3,[get_rid()])
   if get_world_3d().direct_space_state.intersect_ray(query).is_empty():
    _wander_goal=candidate
    break
  _wander_wait=_wander_rng.randf_range(0.6,1.8)
  velocity=Vector3.ZERO
  _update_motion(delta,false)
  return
 var direction:=offset.normalized()
 rotation.y=lerp_angle(rotation.y,atan2(direction.x,direction.z),minf(1,delta*2.2))
 velocity=direction*(2.6 if move_speed>1.0 else 0.43)
 var before:=global_position
 move_and_slide()
 global_position.y=ground_height
 var moved:=global_position.distance_to(before)>delta*0.1
 _wander_stuck=0.0 if moved else _wander_stuck+delta
 _update_motion(delta,moved)

func _update_motion(delta: float, walking: bool) -> void:
 if _bite_elapsed>=0:return
 _recoil_elapsed=maxf(0,_recoil_elapsed-delta)
 _play_animation("Hit" if _recoil_elapsed>0 else ("Walk" if walking else "Idle"))
 var actual_speed:=Vector2(get_real_velocity().x,get_real_velocity().z).length()
 _animation_player.speed_scale=clampf(actual_speed/MOVE_SPEED,0.45,3.0) if walking and _recoil_elapsed<=0 else 1.0
 _walk_time += delta * (5.0 if walking else 1.5)
 _visual.rotation.z = sin(_walk_time) * (0.035 if walking else 0.01)
 _visual.position.y = -0.89

func _tick_bite(delta: float) -> void:
 _bite_elapsed+=delta
 var attacking_vehicle: bool=is_instance_valid(_bite_victim) and _bite_victim.is_in_group("rv")
 var contact_time: float=VEHICLE_CONTACT if attacking_vehicle else BITE_CONTACT
 if not _bite_contact_done and _bite_elapsed>=contact_time:
  _bite_contact_done=true
  var victim:=_bite_victim
  if is_instance_valid(victim) and _choose_target()==victim and global_position.distance_to(_target_point(victim))<=ATTACK_RANGE+0.15:
   var query:=PhysicsRayQueryParameters3D.create(global_position+Vector3(0,0.2,0),_target_point(victim)+Vector3(0,0.2,0),3,[get_rid()])
   var hit:=get_world_3d().direct_space_state.intersect_ray(query)
   if hit.is_empty() or hit.collider==victim:
    if victim.is_in_group("rv"):
     victim.mark_hostile_attack()
     AudioDirector.sound("metal",global_position)
     victim.take_zombie_hit(global_position)
    else:victim.take_damage(1,self)
 if _bite_elapsed>=(VEHICLE_ATTACK_LENGTH if attacking_vehicle else 0.84):
  _bite_elapsed=-1
  _play_animation("Idle")

func _play_animation(state: String,restart: bool=false) -> void:
 if not is_instance_valid(_animation_player) or not _animations.has(state):return
 if _animation_state==state and not restart:return
 if state!="Walk":_animation_player.speed_scale=1.0
 _animation_player.play(_animations[state],0.05)
 _animation_player.advance(0)
 _animation_state=state

func set_target(value: Node3D) -> void:
 target = value

func set_vehicle_target(value: Node3D) -> void:
 vehicle_target=value

func _choose_target() -> Node3D:
 if is_instance_valid(vehicle_target) and vehicle_target.occupied and not vehicle_target.wrecked:return vehicle_target
 if is_instance_valid(target) and bool(target.active) and target.health>0:return target
 return null

func _target_point(victim: Node3D) -> Vector3:
 if victim.is_in_group("rv"):return victim.closest_hull_point(global_position)
 return victim.global_position

func take_damage(amount: int) -> void:
 if _dying:
  return
 AudioDirector.sound("zombie_die" if health<=amount else "zombie_hurt",global_position,-12)
 health -= amount
 if _bite_elapsed<0:
  _recoil_elapsed=0.30
  _play_animation("Hit",true)
 if is_instance_valid(_hit_tween):
  _hit_tween.kill()
 for mesh in _meshes:
  mesh.material_overlay = _hit_material
 _hit_tween = create_tween()
 _hit_tween.tween_method(_set_hit_alpha, 0.65, 0.0, 0.18)
 _hit_tween.tween_callback(func():
  for mesh in _meshes:
   mesh.material_overlay = null
 )
 if health <= 0:
  _dying = true
  collision_layer = 0
  collision_mask = 0
  set_physics_process(false)
  var session=get_tree().get_first_node_in_group("game_session")
  if is_instance_valid(session) and is_instance_valid(session.cash_drops):session.cash_drops.spawn_drop(global_position)
  defeated.emit()
  var tween := create_tween().set_parallel()
  tween.tween_property(_visual, "rotation:z", -1.45, 0.35)
  tween.tween_property(_visual, "position:y", -0.86, 0.35)
  tween.chain().tween_interval(0.25)
  tween.chain().tween_callback(queue_free)

func _set_hit_alpha(alpha: float) -> void:
 _hit_material.albedo_color.a = alpha

func _build_vehicle_attack() -> void:
 if not _animations.has("Bite"):return
 var attack: Animation=_animation_player.get_animation(_animations.Bite).duplicate(true)
 var stretch:=VEHICLE_CONTACT/BITE_CONTACT
 for track in range(attack.get_track_count()):
  # Reverse order avoids time collisions while extending the same windup/contact poses.
  for key in range(attack.track_get_key_count(track)-1,-1,-1):
   attack.track_set_key_time(track,key,attack.track_get_key_time(track,key)*stretch)
 # Raise both arms during anticipation, then strike the hull at the contact key.
 for track in range(attack.get_track_count()):
  var bone:=str(attack.track_get_path(track))
  if attack.track_get_type(track)!=Animation.TYPE_ROTATION_3D:continue
  var angles: Array=[]
  if "UpperArm" in bone:angles=[0,-65,-55,-10,-25,0]
  elif "Forearm" in bone:angles=[0,55,45,8,25,0]
  elif "Jaw" in bone:angles=[0,0,0,0,0,0]
  if not angles.is_empty():
   for key in range(mini(angles.size(),attack.track_get_key_count(track))):
    attack.track_set_key_value(track,key,Quaternion(Vector3.RIGHT,deg_to_rad(float(angles[key]))))
 attack.length=VEHICLE_ATTACK_LENGTH
 attack.loop_mode=Animation.LOOP_NONE
 var library:=AnimationLibrary.new()
 library.add_animation("VehicleAttack",attack)
 _animation_player.add_animation_library("vehicle",library)
 _animations["VehicleAttack"]="vehicle/VehicleAttack"
