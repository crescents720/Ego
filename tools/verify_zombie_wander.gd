extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var stage:=Node3D.new()
 root.add_child(stage)
 var zombie=load("res://scripts/actors/zombie.gd").new()
 stage.add_child(zombie)
 zombie.position=Vector3(0,0.9,0)
 var start: Vector3=zombie.position
 var max_distance:=0.0
 var saw_walk:=false
 var saw_idle:=false
 for frame in range(480):
  await physics_frame
  max_distance=maxf(max_distance,zombie.position.distance_to(start))
  saw_walk=saw_walk or zombie._animation_state=="Walk"
  saw_idle=saw_idle or zombie._animation_state=="Idle"
 if max_distance<0.4 or max_distance>3.0 or not saw_walk or not saw_idle:
  push_error("WANDER_FAIL: no target must wander locally with walking and pauses");quit(1);return
 var hero=load("res://scripts/actors/hotaru.gd").new()
 stage.add_child(hero)
 hero.set_physics_process(false)
 hero.position=zombie.position+Vector3(0,0,4)
 hero.set_active(true)
 zombie.set_target(hero)
 var before: float=zombie.position.distance_to(hero.position)
 for frame in range(70):await physics_frame
 if zombie.position.distance_to(hero.position)>before-0.7 or zombie._animation_state!="Walk":
  push_error("WANDER_FAIL: failed to resume pursuit");quit(1);return
 hero.set_active(false)
 var lost: Vector3=zombie.position
 var moved:=false
 for frame in range(300):
  await physics_frame
  moved=moved or zombie.position.distance_to(lost)>0.3
 if not moved:
  push_error("WANDER_FAIL: inactive target freezes zombie");quit(1);return
 hero.set_active(true)
 hero.position=Vector3(100,0.95,100)
 var far: Vector3=zombie.position
 moved=false
 for frame in range(300):
  await physics_frame
  moved=moved or zombie.position.distance_to(far)>0.3
 if not moved:
  push_error("WANDER_FAIL: distant target freezes zombie");quit(1);return
 print("WANDER_PASS: no target, inactive target, distant target, local bounds, Walk/Idle and immediate chase reacquisition")
 quit()
