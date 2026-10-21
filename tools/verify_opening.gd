extends SceneTree
var main
func _initialize() -> void:
 call_deferred("run")
func check(ok: bool, text: String) -> bool:
 if ok: return true
 push_error("OPENING_FAIL: "+text)
 quit(1)
 return false
func walk_to(goal: Vector3) -> bool:
 for frame in range(700):
  await physics_frame
  var offset: Vector3 = goal-main.hotaru.global_position
  offset.y=0
  if offset.length()<0.20:return true
  main.hotaru.velocity=offset.normalized()*5.2
  main.hotaru.move_and_slide()
 return false
func run() -> void:
 main=load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 root.get_node("GameState").suppress_save=true
 main._begin_story()
 main.opening.start(false)
 if not check(main.opening.beat==main.OpeningStory.Beat.SLEEP and not main.controls_enabled,"new game must start asleep in bedroom"):return
 main.opening.advance()
 if not check(main.opening.photo.visible and not main.opening.voice.playing,"dream photo with synthesized speech disabled"):return
 main.opening.advance()
 main.opening.elapsed=1.5
 main.opening._process(0.1)
 if not check(main.opening.lowpass.cutoff_hz<12000,"dream audio distortion"):return
 main.opening.advance()
 if not check(main.opening.room_fire.visible and main.opening.fire_audio.playing,"wake fire and sound"):return
 main.opening.advance()
 main.opening.elapsed=2
 main.opening._process(0.1)
 if not check(main.opening.beat==main.OpeningStory.Beat.EXTERIOR and main.get_tree().get_nodes_in_group("opening_zombies").size()==16,"exterior cut and front crowd"):return
 if not check(main._alive_zombie_count()==3,"opening crowd must not lock store quest"):return
 main.opening.advance()
 main.hotaru.set_physics_process(false)
 for point in main.opening.ROUTE:
  if not check(await walk_to(point),"escape route obstructed at "+str(point)):return
 main._interact()
 if not check(main.inside_rv,"rear parking side-door boarding"):return
 await process_frame
 await process_frame
 if not check(main.opening.beat==main.OpeningStory.Beat.DONE,"opening completes upon reaching RV"):return
 main.hotaru.global_position=main.rv_interior.get_driver_stand_position()
 main._interact()
 main._toggle_vehicle()
 if not check(main.in_vehicle and main.phase==main.Phase.DRIVE_TO_STORE,"opening must join first-day driving quest"):return
 var previous_x: float=main.rv.global_position.x
 await physics_frame
 await physics_frame
 if not check(absf(main.rv.global_position.x-previous_x)<0.2,"backyard RV must not snap to street clamp"):return
 main.rv.set_physics_process(false)
 for goal in [Vector3(-21.5,1.02,-33),Vector3(0,1.02,-33)]:
  main.rv.rotation.y=PI if goal.x < -10 else -PI/2
  var reached := false
  for frame in range(700):
   await physics_frame
   var offset: Vector3=goal-main.rv.global_position
   offset.y=0
   if offset.length()<0.25:
    reached=true
    break
   main.rv.velocity=offset.normalized()*7
   main.rv.move_and_slide()
  if not check(reached,"RV driveway blocked toward "+str(goal)):return
 print("OPENING_PASS: sleep/dream/distortion/fire/rise/cut/front crowd; physical escape to rear RV; main quest handoff")
 main.opening.voice.stop()
 main.opening.music.stop()
 main.opening.fire_audio.stop()
 await create_timer(0.1).timeout
 quit()



