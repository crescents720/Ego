extends SceneTree
var main
var failed := false
func _initialize() -> void:
 call_deferred("run")
func check(ok: bool, message: String) -> bool:
 if ok:
  return true
 failed = true
 push_error("ACTOR_MODELS_FAIL: " + message)
 quit(1)
 return false
func walk_to(goal: Vector3) -> bool:
 for frame in range(180):
  await physics_frame
  var offset: Vector3 = goal - main.hotaru.global_position
  offset.y = 0
  if offset.length() < 0.14:
   return true
  main.hotaru.velocity = offset.normalized() * 2.4
  main.hotaru.move_and_slide()
 return false
func run() -> void:
 main = load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 root.get_node("GameState").suppress_save = true
 main._start_new_game()
 main.hotaru.set_physics_process(false)
 for angle in [0.0, PI / 2, PI, -PI / 2]:
  main.rv.rotation.y = angle
  main.hotaru.global_position = main.rv.to_global(Vector3(-2.15,-0.07,main.rv.SIDE_DOOR_Z))
  main._interact()
  if not check(not main.inside_rv, "boarding accepted on wrong side"):
   return
  main.hotaru.global_position = main.rv.get_disembark_position()
  main._interact()
  if not check(main.inside_rv and not main.in_vehicle, "right door must enter cabin first"):
   return
  if not check(main.hotaru.global_position.distance_to(main.rv_interior.get_entry_position()) < 0.01, "interior side entry mismatch"):
   return
  if not check(await walk_to(main.rv_interior.get_driver_stand_position()), "furniture blocks route from side door to cockpit"):
   return
  main._interact()
  if not check(main.seated_at_driver, "driver seat unreachable by walking"):
   return
  main._toggle_vehicle()
  if not check(main.in_vehicle and not main.inside_rv, "start driving at cockpit"):
   return
  main._toggle_vehicle()
  if not check(main.inside_rv and not main.in_vehicle, "stopping must return to cabin"):
   return
  if not check(await walk_to(main.rv_interior.get_entry_position()), "route from cockpit to side door blocked"):
   return
  main._interact()
  if not check(not main.inside_rv, "side door exit blocked in open street"):
   return
  var local_exit: Vector3 = main.rv.to_local(main.hotaru.global_position)
  if not check(local_exit.x > main.rv.SIDE_DOOR.x + 0.5 and absf(local_exit.z - main.rv.SIDE_DOOR_Z) < 0.02, "rotation changed side or longitudinal exit position"):
   return
 # An obstructed side door must not teleport the character through a wall.
 main._enter_rv_interior()
 var obstacle := StaticBody3D.new()
 obstacle.position = main.rv.get_disembark_position()
 var collision := CollisionShape3D.new()
 var box := BoxShape3D.new()
 box.size = Vector3(1.2,2.0,1.2)
 collision.shape = box
 obstacle.add_child(collision)
 root.add_child(obstacle)
 await physics_frame
 await physics_frame
 main._interact()
 if not check(main.inside_rv, "blocked door teleported through obstruction"):
  return
 obstacle.queue_free()
 await physics_frame
 await physics_frame
 main._interact()
 if not check(not main.inside_rv, "door did not recover after obstruction cleared"):
  return
 # Exercise chase, real attack, hit flash and death with the new mesh.
 main.hotaru.global_position = Vector3(0,0.95,-7)
 main.hotaru.health = 5
 main.hotaru.set_active(true)
 var zombie = main.get_tree().get_nodes_in_group("zombies")[0]
 zombie.global_position = Vector3(0,0.9,-10)
 var start: Vector3 = zombie.global_position
 for frame in range(185):
  await physics_frame
 if not check(zombie.global_position.distance_to(start) > 0.5 and main.hotaru.health < 5, "new zombie chase or attack failed"):
  return
 main.hotaru.set_active(false)
 var defeated := [0]
 zombie.defeated.connect(func(): defeated[0] += 1)
 zombie.take_damage(9)
 for frame in range(16):
  await physics_frame
 zombie.take_damage(1)
 for frame in range(45):
  await physics_frame
 if not check(defeated[0] == 1 and not is_instance_valid(zombie), "new zombie damage/death failed"):
  return
 print("ACTOR_MODELS_PASS: four vehicle orientations; physical side door/cockpit routes; obstructed exit; zombie chase/attack/hit/death")
 quit()

