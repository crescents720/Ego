extends Node
const RESPAWN_DELAY:=9.0
const WAKE_RANGE:=105.0
const SLEEP_RANGE:=150.0
var main
var night:=false
var districts: Array[Dictionary]=[]
var indoor: Array[Node3D]=[]
var indoor_created:=false
var _registered_authored:=false
var _clock:=0.0
var rng:=RandomNumberGenerator.new()

func build(owner_main) -> void:
 main=owner_main
 rng.seed=170017
 for road in main.town_layout.roads:
  var length: float=road.a.distance_to(road.b)
  for i in range(maxi(1,int(length/55))):
   var t: float=(i+0.5)/maxi(1,int(length/55))
   var p: Vector2=road.a.lerp(road.b,t)
   # Existing prologue/store guards remain independently authored.
   if p.distance_to(Vector2(-11,-43))<30 or p.distance_to(Vector2(0,51))<16:continue
   var district: Dictionary={"center":p,"road":road,"members":[],"delay":-1.0,"visited":false,"spawn_points":[]}
   for lot in main.town_layout.lots:
    var b: AABB=lot.bounds
    var base: Vector2=lot.position
    var front: Vector2=Geometry2D.get_closest_point_to_segment(base,road.a,road.b)
    if base.distance_to(p)>45 or base.distance_to(front)>23:continue
    var direction: Vector2=(front-base).normalized()
    var extent: float=maxf(b.size.x,b.size.z)*0.5+1.2
    var exit: Vector2=base+direction*extent
    if _free(exit):district.spawn_points.append(exit)
   districts.append(district)

func reset(origin: Vector2=Vector2(-21,-43)) -> void:
 _registered_authored=false
 night=GameState.is_night()
 for d in districts:
  for actor in d.members:
   if is_instance_valid(actor):actor.queue_free()
  d.members=[]
  d.delay=-1.0
  d.visited=false
 for actor in indoor:
  if is_instance_valid(actor):actor.queue_free()
 indoor=[]
 indoor_created=false
 _clock=0
 # Initial residents exist before the opening camera is shown, not spawned in view.
 for d in districts:
  if d.center.distance_to(origin)<WAKE_RANGE:_spawn(d,true)

func _process(delta: float) -> void:
 if not is_instance_valid(main) or main.phase in [main.Phase.TITLE,main.Phase.GAME_OVER] or main.opening.is_cinematic():return
 _refresh_store()
 if is_instance_valid(main.factory) and main.factory.active:return
 if main.inside_store:
  _sync_indoor()
  return
 _clock+=delta
 if _clock<0.5:return
 var elapsed:=_clock
 _clock=0
 var outdoor: bool=not main.inside_store and (not main.inside_rv or (is_instance_valid(main.shooting) and main.shooting.active))
 var origin: Vector3=main.rv.global_position if main.in_vehicle or main.inside_rv else main.hotaru.global_position
 var p:=Vector2(origin.x,origin.z)
 for d in districts:
  var members: Array=[]
  for actor in d.members:
   if is_instance_valid(actor) and not actor._dying:members.append(actor)
  d.members=members
  var distance: float=d.center.distance_to(p)
  for actor in members:
   actor.visible=outdoor and distance<SLEEP_RANGE
   actor.process_mode=Node.PROCESS_MODE_INHERIT if distance<SLEEP_RANGE else Node.PROCESS_MODE_DISABLED
   actor.set_physics_process(not main.inside_store and distance<SLEEP_RANGE)
  if distance>SLEEP_RANGE:continue
  if night and members.size()>0 and members.size()<9 and distance<WAKE_RANGE:_spawn(d,false,9-members.size())
  if not night and members.size()>3:
   for actor in members:
    if actor.get_meta("nocturnal",false) and _safe(Vector2(actor.position.x,actor.position.z)):actor.queue_free()
  if members.is_empty():
   if not d.visited:
    if distance<WAKE_RANGE:_spawn(d,false,9 if night else 3)
   elif d.delay<0:d.delay=RESPAWN_DELAY
   else:
    d.delay-=elapsed
    if d.delay<=0 and distance<WAKE_RANGE:_spawn(d,false,9 if night else 3)

func _free(p: Vector2) -> bool:
 var query:=PhysicsShapeQueryParameters3D.new()
 var capsule:=CapsuleShape3D.new()
 capsule.radius=.38
 capsule.height=1.7
 query.shape=capsule
 query.transform=Transform3D(Basis.IDENTITY,Vector3(p.x,.95,p.y))
 query.collision_mask=7
 return main.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()

func _safe(p: Vector2) -> bool:
 var observer: Vector3=main.rv.global_position if main.in_vehicle or main.inside_rv else main.hotaru.global_position
 if p.distance_to(Vector2(observer.x,observer.z))<18:return false
 return not main.camera.is_position_in_frustum(Vector3(p.x,1,p.y))

func _spawn(d: Dictionary,initial: bool,limit: int=3) -> void:
 if limit<=0:return
 var candidates: Array=[]
 if d.visited:
  candidates=d.spawn_points.duplicate()
 else:
  for i in range(12):candidates.append(d.center+Vector2(rng.randf_range(-12,12),rng.randf_range(-2,2)))
 var created:=0
 for p in candidates:
  if not _free(p) or (not initial and not _safe(p)):continue
  if p.distance_to(Vector2(-11,-43))<23:continue
  if initial and p.distance_to(Vector2(main.rv.global_position.x,main.rv.global_position.z))<18:continue
  var actor=main.ZombieController.new()
  main.add_child(actor)
  actor.global_position=Vector3(p.x,.9,p.y)
  actor.set_target(main.hotaru)
  actor.set_vehicle_target(main.rv)
  actor.aggro_range=13
  actor.move_speed=5.2 if night else actor.MOVE_SPEED
  actor.set_meta("nocturnal",night)
  actor.add_to_group("town_wanderers")
  actor.visible=not main.inside_store and (not main.inside_rv or (is_instance_valid(main.shooting) and main.shooting.active))
  actor.set_physics_process(actor.visible)
  d.members.append(actor)
  created+=1
  if created>=limit:break
 if created>0:
  d.visited=true
  d.delay=-1.0
 elif d.visited:d.delay=1.0

func _refresh_store() -> void:
 # Half-day boundaries use world time, so sleep fast-forward also replenishes.
 GameState.store_residents=clampi(GameState.store_residents,0,6)
 if GameState.store_next_refresh>GameState.world_seconds:return
 var periods:=int(floor((GameState.world_seconds-GameState.store_next_refresh)/180.0))+1
 for i in range(mini(periods,6)):
  GameState.store_residents=mini(6,GameState.store_residents+rng.randi_range(1,2))
 GameState.store_next_refresh+=periods*180.0

func _sync_indoor() -> void:
 var alive: Array[Node3D]=[]
 for actor in indoor:
  if is_instance_valid(actor) and not actor._dying:alive.append(actor)
 indoor=alive
 var points: Array[Vector3]=[]
 for x in [-3.4,-1.75,0.0,1.75,3.4]:
  for z in [-1.9,-.9,.1,1.1]:points.append(main.STORE_ORIGIN+Vector3(x,1.08,z))
 while not points.is_empty() and indoor.size()<mini(6,GameState.store_residents):
  var index:=rng.randi_range(0,points.size()-1)
  var p: Vector3=points.pop_at(index)
  if p.distance_to(main.hotaru.global_position)<2.5 or not _free(Vector2(p.x,p.z)):continue
  var actor=main.ZombieController.new()
  main.add_child(actor)
  actor.ground_height=1.08
  actor.global_position=p
  actor.set_target(main.hotaru)
  actor.aggro_range=4.0
  actor.add_to_group("store_indoor_zombies")
  actor.defeated.connect(func():GameState.store_residents=maxi(0,GameState.store_residents-1))
  indoor.append(actor)

func enter_store() -> void:
 _refresh_store()
 indoor_created=true
 _sync_indoor()
 for actor in get_tree().get_nodes_in_group("zombies"):
  var inside: bool=actor.is_in_group("store_indoor_zombies")
  actor.visible=inside
  if not actor._dying:actor.set_physics_process(inside)

func exit_store() -> void:
 for actor in get_tree().get_nodes_in_group("zombies"):
  var inside: bool=actor.is_in_group("store_indoor_zombies")
  actor.visible=not inside
  if not actor._dying:actor.set_physics_process(not inside)

func register_authored() -> void:
 if _registered_authored:return
 _registered_authored=true
 for actor in get_tree().get_nodes_in_group("zombies"):
  if actor.is_in_group("town_wanderers") or actor.is_in_group("store_indoor_zombies") or actor._dying:continue
  var closest: Dictionary={}
  var distance:=INF
  var p:=Vector2(actor.global_position.x,actor.global_position.z)
  for d in districts:
   var test: float=d.center.distance_to(p)
   if test<distance:distance=test;closest=d
  if not closest.is_empty():
   closest.members.append(actor)
   closest.visited=true

func set_night(value: bool) -> void:
 night=value
 for actor in get_tree().get_nodes_in_group("zombies"):
  actor.move_speed=5.2 if night and not actor.is_in_group("store_indoor_zombies") else actor.MOVE_SPEED
