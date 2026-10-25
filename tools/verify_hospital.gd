extends SceneTree
var main
var errors=0
func _initialize():call_deferred("run")
func check(ok,message):
 if not ok:errors+=1;push_error(message)
func run():
 var state=root.get_node("GameState");state.suppress_save=true
 main=load("res://scenes/main.tscn").instantiate();root.add_child(main);main._start_new_game();main._set_phase(main.Phase.EXPLORE)
 main.set_process(false)
 var h=main.hospital
 await physics_frame;await physics_frame
 # Walk from the east road across the courtyard, rather than teleporting to entry.
 main.hotaru.global_position=h.GATE+Vector3(2.4,.87,0)
 check(h.near_gate(),"street gate reachable")
 main._interact();await create_timer(2.0).timeout
 check(h.in_campus and not h.active and main.world_root.visible,"gate enters visible courtyard")
 check(main.camera.projection==Camera3D.PROJECTION_PERSPECTIVE,"campus third person camera")
 for destination in [Vector3(43,.95,260),h.DOOR+Vector3(0,0,1.5)]:
  var start: Vector3=main.hotaru.global_position
  var steps=int(ceil(start.distance_to(destination)/.25))
  for i in range(1,steps+1):
   var next=start.lerp(destination,float(i)/steps)
   check(not main.hotaru.test_move(main.hotaru.global_transform,next-main.hotaru.global_position),"courtyard approach unobstructed")
   main.hotaru.global_position=next
 main.hotaru.global_position=h.DOOR+Vector3(0,0,1)
 check(h.near_entrance(),"hospital front entrance is reachable")
 main._interact()
 check(h.active and not main.world_root.visible,"E enters hospital")
 check(not main.can_save_safely(),"cannot save transient hospital player position")
 var wards=0;var beds=0
 for data in h.rooms:
  if data.kind=="ward":wards+=1;beds+=data.beds
 check(wards==16 and beds==27,"sixteen wards / twenty-seven beds match approved plan")
 check(h.room.scale==Vector3(2,1,2) and h.exterior.scale==Vector3(2,1,2),"hospital interior/exterior horizontal dimensions doubled")
 for bed in get_nodes_in_group("hospital_beds"):
  check(bed.global_basis.get_scale().is_equal_approx(Vector3.ONE),"beds retain normal dimensions")
 var corridor=Transform3D(Basis.IDENTITY,h.to_interior_world(Vector3(0,.95,-10))+Vector3(-2.5,0,0))
 check(not main.hotaru.test_move(corridor,Vector3(5,0,0)),"central corridor provides five metres of clear lateral travel")
 check(get_nodes_in_group("hospital_beds").size()==31,"27 ward beds and 4 treatment beds are modelled")
 check(not main.zombie_population.is_processing(),"outdoor population suspended")
 main._toggle_vehicle();check(h.active and not main.inside_rv,"vehicle action cannot escape interior")
 var door: Dictionary=h.doors[0]
 main.hotaru.global_position=h.to_interior_world(door.point)+Vector3(1,0,0)
 h.interact();await create_timer(.4).timeout
 check(door.open and door.body.collision_layer==0,"opening room door clears passage collision")
 h.interact();await create_timer(.4).timeout
 check(not door.open and door.body.collision_layer==3,"door closes from outside threshold")
 for d in h.doors:d.open=true;d.body.collision_layer=0;d.pivot.position=d.open_position
 await physics_frame;await physics_frame
 for data in h.rooms:
  var normal={"E":Vector3.RIGHT,"W":Vector3.LEFT,"N":Vector3.FORWARD,"S":Vector3.BACK}[data.side]
  var center=h.to_interior_world(Vector3(data.door.x,.95+data.floor*h.STOREY,data.door.y))
  var transform=Transform3D(Basis.IDENTITY,center+normal*.85)
  check(not main.hotaru.test_move(transform,-normal*1.7),"opened doorway can enter and leave: "+data.name)
 # Search walkable capsule positions across the actual collision world, including furniture.
 var capsule=CapsuleShape3D.new();capsule.radius=.36;capsule.height=1.65
 var q=PhysicsShapeQueryParameters3D.new();q.shape=capsule;q.collision_mask=3;q.exclude=[main.hotaru.get_rid()]
 var space=main.hotaru.get_world_3d().direct_space_state
 for level in range(2):
  var free={};var stride=.4
  for x in range(-37,38):
   for z in range(-41,42):
    var p=Vector2(x*stride,z*stride)
    var footprint=h.MAIN_RECTS.duplicate()
    if level==0:footprint.append(h.ANNEX)
    if not h._contains(footprint,p) or h.STAIR.has_point(p):continue
    q.transform=Transform3D(Basis.IDENTITY,h.to_interior_world(Vector3(p.x,.95+level*h.STOREY,p.y)))
    if space.intersect_shape(q,1).is_empty():free[Vector2i(x,z)]=true
  var seed=Vector2i(0,-14) if level==0 else Vector2i(0,-30)
  check(free.has(seed),"floor %d corridor start is free"%level)
  var reached={seed:true};var queue=[seed];var cursor=0
  while cursor<queue.size():
   var p=queue[cursor];cursor+=1
   for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
    var next=p+offset
    if free.has(next) and not reached.has(next):reached[next]=true;queue.append(next)
  for data in h.rooms:
   if data.floor!=level:continue
   var found=false
   for p in reached:
    if data.rect.grow(-.65).has_point(Vector2(p)*stride):found=true;break
   check(found,"connected reachable interior: "+data.name)
  print("FLOOR ",level," free ",free.size()," reachable ",reached.size())
 # Walk both flights and turn on both landings, with actual capsule sweeps.
 h.floor_index=0;main.hotaru.global_position=h.to_interior_world(Vector3(-.65,.95,-12.275))
 var path=[Vector2(-2.65,-12.275),Vector2(-2.65,-16.30),Vector2(-4.65,-16.30),Vector2(-4.65,-12.275),Vector2(-.65,-12.275)]
 for target in path:
  await walk_stair(h,target)
 check(h.floor_index==1,"folded staircase reaches second floor")
 path=[Vector2(-4.65,-12.275),Vector2(-4.65,-16.30),Vector2(-2.65,-16.30),Vector2(-2.65,-12.275),Vector2(-.65,-12.275)]
 for target in path:await walk_stair(h,target)
 check(h.floor_index==0,"folded staircase returns to first floor")
 h.floor_index=0;main.hotaru.global_position=h.to_interior_world(h.ENTRY)
 main._interact();check(not h.active and main.world_root.visible,"E at entrance returns outdoors")
 check(main.camera.environment==null,"outdoor environment restored")
 # A cart left inside must remain in its own spatial room across re-entry.
 h._entry_lock=0;main.hotaru.global_position=h.DOOR+Vector3(0,0,1)
 state.cart_owned=true;state.cart_deployed=true
 state.cart_position=h.DOOR+Vector3(0,-.87,0)
 main.trolley.interact();check(main.trolley.pushing,"push cart at entrance")
 main._interact();check(h.active and state.spatial_room_id(state.cart_position)==5,"cart enters with player")
 main.trolley.release();var parked: Vector3=state.cart_position
 main.hotaru.global_position=h.to_interior_world(h.ENTRY);main._interact()
 check(not h.active and state.cart_position==parked,"left cart remains indoors")
 h._entry_lock=0;main.hotaru.global_position=h.DOOR+Vector3(0,0,1);main._interact()
 main.trolley._physics_process(0)
 check(h.active and main.trolley.visual.visible and state.cart_position==parked,"parked cart reappears on revisit")
 main.hotaru.global_position=state.cart_position+Vector3(0,.87,1)
 main.trolley.interact();main.hotaru.global_position=h.to_interior_world(h.ENTRY);main._interact()
 check(not h.active and state.spatial_room_id(state.cart_position)==0,"push cart back outside")
 h._entry_lock=0;main.hotaru.global_position=h.GATE+Vector3(-2.4,.87,0)
 main.trolley.release();main._interact();await create_timer(2.0).timeout
 check(not h.in_campus and not h.active,"gate exits campus")
 check(main.camera.projection==Camera3D.PROJECTION_ORTHOGONAL,"town camera restored")
 # Bring a loaded cart through both sides of the campus gate.
 h._entry_lock=0
 main.hotaru.global_position=h.GATE+Vector3(2.4,.87,0)
 state.cart_position=h.GATE+Vector3(1.3,0,0)
 main.trolley.interact();check(main.trolley.pushing,"cart attached before campus entry")
 main._interact();await create_timer(2.0).timeout
 check(h.in_campus and main.trolley.pushing and state.cart_position.x<h.GATE.x,"cart accompanies gate entry")
 check(main.hotaru.global_position.distance_to(state.cart_position+Vector3(0,.87,0))<2.3,"cart stays reachable after gate entry")
 h._entry_lock=0;main._interact();await create_timer(2.0).timeout
 check(not h.in_campus and main.trolley.pushing and state.cart_position.x>h.GATE.x,"cart accompanies gate exit")
 # Camera must remain outside walls/ceilings while crossing both stair flights.
 h.in_campus=true;h._entry_lock=0;main.trolley.release()
 main.hotaru.global_position=h.DOOR+Vector3(0,0,1);h.enter()
 for point in [Vector3(-2.65,.95,-13.2),Vector3(-2.65,.95,-15.5),Vector3(-4.65,.95,-16.3),Vector3(-4.65,.95,-14),Vector3(-4.65,.95,-12.5)]:
  main.hotaru.global_position=h.to_interior_world(point);h._physics_process(.02)
  for angle in [0.0,PI/2,PI,-PI/2]:
   h.yaw=angle;h.update_camera(0)
   check(main.hotaru._visual_root.visible,"stair camera never hides protagonist")
   var camera_query=PhysicsShapeQueryParameters3D.new();var sphere=SphereShape3D.new();sphere.radius=.12
   camera_query.shape=sphere;camera_query.collision_mask=11;camera_query.exclude=[main.hotaru.get_rid()]
   camera_query.transform=Transform3D(Basis.IDENTITY,main.camera.global_position)
   check(main.hotaru.get_world_3d().direct_space_state.intersect_shape(camera_query,1).is_empty(),"camera volume stays clear on stairs "+str(point)+" angle "+str(angle))
 # Walk both aisles of room 211 with the real player capsule.
 for x in [6.8,9.95]:
  var start=Transform3D(Basis.IDENTITY,h.to_interior_world(Vector3(x,4.55,-3.6)))
  check(not main.hotaru.test_move(start,Vector3(0,0,5.3)),"211 bedside aisle is traversable")
 # Static corner: tiny contact noise may shorten the arm but must never swap sides.
 main.hotaru.global_position=h.to_interior_world(Vector3(6.65,4.55,-3.90));h.floor_index=1
 main.hotaru.velocity=Vector3.ZERO;h.yaw=PI/2;h.pitch=.05;h.camera_rig.reset();h.update_camera(0)
 var prior: Vector3=main.camera.global_position
 for frame in range(180):
  main.hotaru.global_position.x=h.ORIGIN.x+6.65*2+sin(frame*.1)*.003
  h.update_camera(1.0/60)
  var center: Vector3=main.hotaru.global_position+Vector3(0,.55,0)
  check(main.camera.global_position.x<=center.x+.01,"corner retains same orbit side")
  check(main.camera.global_position.distance_to(prior)<.05,"corner has no camera jump")
  prior=main.camera.global_position
 # Manual input has priority; walking gradually recenters after a deliberate wait.
 main.hotaru.global_position=h.to_interior_world(Vector3(0,.95,-10));h.yaw=0;h.camera_rig.reset();h.update_camera(0)
 h.camera_rig.manual_input();main.hotaru.velocity=Vector3(2,0,0)
 for frame in range(60):h.update_camera(1.0/60)
 check(absf(h.yaw)<.001,"manual look grace period")
 for frame in range(240):h.update_camera(1.0/60)
 check(absf(wrapf(h.yaw-PI/2,-PI,PI))<.12,"walking recenters behind heading")
 main.hotaru.velocity=Vector3.ZERO;var stopped_yaw=h.yaw
 for frame in range(120):h.update_camera(1.0/60)
 check(absf(h.yaw-stopped_yaw)<.001,"idle does not force recenter")
 var bed_triangles=0
 for mesh in h._bed_meshes:
  for surface in range(mesh.get_surface_count()):
   var arrays=mesh.surface_get_arrays(surface)
   bed_triangles+=(arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX]!=null and not arrays[Mesh.ARRAY_INDEX].is_empty() else arrays[Mesh.ARRAY_VERTEX].size())/3
 check(bed_triangles<=300,"light bed geometry budget")
 for bed in get_nodes_in_group("hospital_beds"):
  check(bed.find_children("*","CollisionShape3D",true,false).size()==1,"one simple collider per bed")
 print("LIGHT_BED triangles=",bed_triangles," surfaces=",h._bed_meshes.size()," copies=",get_nodes_in_group("hospital_beds").size())
 print("HOSPITAL_VERIFY errors=",errors)
 root.get_node("AudioDirector").set_process(false);root.get_node("AudioDirector").stop_all()
 await create_timer(.12).timeout
 main.queue_free();await process_frame;await process_frame;quit(errors)

func walk_stair(h,target: Vector2):
 var start: Vector3=h.to_interior_local(main.hotaru.global_position)
 var count=int(ceil(Vector2(start.x,start.z).distance_to(target)/.06))
 for i in range(1,count+1):
  var p=Vector2(start.x,start.z).lerp(target,float(i)/count)
  var old: Transform3D=main.hotaru.global_transform
  main.hotaru.global_position.x=h.ORIGIN.x+p.x*2;main.hotaru.global_position.z=h.ORIGIN.z+p.y*2
  h._physics_process(.02)
  var next: Vector3=main.hotaru.global_position
  check(not main.hotaru.test_move(old,next-old.origin),"folded stair sweep at "+str(p))
