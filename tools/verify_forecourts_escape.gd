extends SceneTree
func _initialize() -> void:call_deferred("run")
func fail(message: String) -> void:
 push_error(message)
 quit(1)
func run() -> void:
 var main=load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 root.get_node("GameState").suppress_save=true
 main._start_new_game()
 main.rv.set_physics_process(false)
 await physics_frame
 await physics_frame
 var tested:=0
 for index in range(main.town_layout.lots.size()):
  var lot: Dictionary=main.town_layout.lots[index]
  var building=main.town_layout.get_node("StreetBuilding_%03d"%index)
  var shape=building.get_node("BuildingWalls").get_child(0).shape
  if not shape is ConcavePolygonShape3D or shape.get_faces().size()<30:
   fail("Missing wall collision");return
  if lot.model!="LM_Laundrette" or tested>=3:continue
  var bounds: AABB=lot.bounds
  var found:=false
  # Scan entry lanes from all four apron edges using the actual moving RV.
  for side in range(4):
   if found:break
   var direction:=Vector3.RIGHT if side<2 else Vector3.BACK
   if side%2==1:direction=-direction
   var tangent:=Vector3(-direction.z,0,direction.x)
   for lane in range(-7,8):
    var center: Vector3=bounds.get_center()+tangent*lane*0.45
    center.y=1.02
    var start: Vector3=center-direction*9
    main.rv.global_position=start
    main.rv.rotation.y=atan2(-direction.x,-direction.z)
    var entered:=false
    for step in range(80):
     main.rv.velocity=direction*6
     main.rv.move_and_collide(direction*0.10)
     var p: Vector3=main.rv.global_position
     if p.distance_to(start)<step*0.08:break
     var margin:=Vector3(3.2,0,1.1) if side<2 else Vector3(1.1,0,3.2)
     if p.x>bounds.position.x+margin.x and p.x<bounds.end.x-margin.x and p.z>bounds.position.z+margin.z and p.z<bounds.end.z-margin.z:
      entered=true;break
    if entered:
     found=true
     print("FORECOURT_ACCESS: ",index," ",main.rv.global_position)
     break
  if not found:fail("No RV apron entry at laundrette "+str(index));return
  tested+=1
 if tested!=3:fail("Insufficient parking samples");return
 main._begin_story()
 main.opening.set_beat(main.OpeningStory.Beat.EXTERIOR)
 var view: Basis=main.camera.global_basis
 var hp: int=main.hotaru.health
 for frame in range(15):await physics_frame
 if hp!=main.hotaru.health:fail("Cinematic damage");return
 main.opening.set_beat(main.OpeningStory.Beat.ESCAPE)
 main._update_camera(1)
 if view.z.dot(main.camera.global_basis.z)<0.999:fail("Exterior camera flipped");return
 if main.opening._trail._dashes.size()<25:fail("Missing dashed trail");return
 main.hotaru.set_physics_process(false)
 for frame in range(240):await physics_frame
 if main.hotaru.health>=hp:fail("Horde failed to pursue and bite");return
 print("FORECOURT_ESCAPE_PASS: three parking entries; wall geometry; camera continuity; cinematic protection; active horde attack; dashed trail")
 main.opening.voice.stop()
 main.opening.music.stop()
 main.opening.fire_audio.stop()
 await create_timer(0.1).timeout
 quit()


