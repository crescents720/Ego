extends RefCounted
# Single continuous orbit. Obstruction changes arm length, never selects another side.
# References: Godot spring-arm shape sweeps and Cinemachine hold/damping/recentering.
var view_yaw=0.0
var view_pitch=.05
var arm_length=1.8
var release_hold=0.0
var manual_wait=0.0
var moving_time=0.0
var initialized=false
var last_target=Vector3.ZERO
var query=PhysicsShapeQueryParameters3D.new()
var character_materials=[]
func _init():
 var sphere=SphereShape3D.new();sphere.radius=.16
 query.shape=sphere;query.collision_mask=11
func reset():
 restore_character()
 initialized=false;manual_wait=0;moving_time=0;release_hold=0
func manual_input():
 manual_wait=1.6;moving_time=0
func update(h,delta: float):
 var main=h.main
 _prepare_character(main.hotaru)
 var target: Vector3=main.hotaru.global_position
 var snap=not initialized or delta<=0 or delta>1 or target.distance_to(last_target)>5
 var dt=clampf(delta,0,.05)
 if not main.controls_enabled or main.get_tree().paused:dt=0
 var manual=h.dragging or h.aim_finger>=0
 if manual:manual_wait=1.6;moving_time=0
 else:manual_wait=maxf(0,manual_wait-dt)
 var velocity: Vector3=main.hotaru.velocity;velocity.y=0
 if velocity.length_squared()>.16 and not manual:moving_time+=dt
 else:moving_time=0
 if manual_wait<=0 and moving_time>.35 and not snap:
  var heading=atan2(velocity.x,velocity.z)
  # Slow return behind the walking direction; never recenter while standing still.
  var difference=wrapf(heading-h.yaw,-PI,PI)
  h.yaw+=clampf(difference*(1-exp(-1.8*dt)),-dt*.9,dt*.9)
  h.pitch=lerpf(h.pitch,.05,1-exp(-1.2*dt))
 if snap:view_yaw=h.yaw;view_pitch=h.pitch
 else:
  view_yaw=lerp_angle(view_yaw,h.yaw,1-exp(-14*dt))
  view_pitch=lerpf(view_pitch,h.pitch,1-exp(-12*dt))
 var center=target+Vector3(0,.80,0)
 var forward=Vector3(sin(view_yaw),0,cos(view_yaw))
 var local=h.to_interior_local(target)
 var on_stairs=h.active and h.STAIR.grow(.15).has_point(Vector2(local.x,local.z))
 var length=1.8 if h.active else 2.45
 if on_stairs:length=1.25
 var offset=-forward*length+Vector3(0,.28+view_pitch*.5,0)
 var ideal=offset.length()
 var direction=offset/ideal
 query.exclude=[main.hotaru.get_rid()]
 query.transform=Transform3D(Basis.IDENTITY,center);query.motion=offset
 var result=main.get_world_3d().direct_space_state.cast_motion(query)
 var safe=maxf(.01,ideal*result[0]-.045)
 if snap:arm_length=safe;release_hold=0
 elif safe<arm_length:
  # Collision safety is immediate; outward recovery waits so doorway edges don't pump.
  arm_length=safe;release_hold=.18
 else:
  release_hold=maxf(0,release_hold-dt)
  if release_hold<=0:arm_length=lerpf(arm_length,safe,1-exp(-3.2*dt))
 arm_length=minf(arm_length,safe)
 main.camera.environment=h.interior_environment if h.active else null
 main.camera.projection=Camera3D.PROJECTION_PERSPECTIVE
 main.camera.keep_aspect=Camera3D.KEEP_HEIGHT;main.camera.fov=78;main.camera.near=.04
 main.camera.global_position=center+direction*arm_length
 main.camera.look_at(center+forward*.45)
 for mesh in main.hotaru._body_meshes:mesh.transparency=0
 main.hotaru._visual_root.show()
 initialized=true;last_target=target

func _prepare_character(character):
 if not character_materials.is_empty():return
 for mesh in character._body_meshes:
  for surface in range(mesh.mesh.get_surface_count()):
   var source=mesh.get_active_material(surface)
   if not source is BaseMaterial3D:continue
   var material=source.duplicate()
   # Screen-door fade only for geometry very near the lens, without hiding the actor node.
   material.distance_fade_mode=BaseMaterial3D.DISTANCE_FADE_OBJECT_DITHER
   material.distance_fade_min_distance=1.0;material.distance_fade_max_distance=1.5
   character_materials.append([mesh,surface,mesh.get_surface_override_material(surface)])
   mesh.set_surface_override_material(surface,material)
func restore_character():
 for entry in character_materials:
  if is_instance_valid(entry[0]):entry[0].set_surface_override_material(entry[1],entry[2])
 character_materials.clear()

