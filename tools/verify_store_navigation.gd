extends SceneTree

const Store = preload("res://scripts/environment/convenience_store.gd")
const STEP := 0.25
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 var main = load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 main._start_new_game()
 main._set_phase(main.Phase.SCAVENGE)
 main.hotaru.global_position = main.STORE_DOOR
 main._enter_store()
 main.hotaru.set_active(false)
 await physics_frame
 await physics_frame
 var space = main.get_world_3d().direct_space_state
 var query = PhysicsShapeQueryParameters3D.new()
 query.shape = main.hotaru.get_child(0).shape
 query.collision_mask = 1
 query.exclude = [main.hotaru.get_rid()]
 var free: Dictionary = {}
 for x in range(-14, 15):
  for z in range(-13, 13):
   var cell := Vector2i(x, z)
   query.transform = Transform3D(Basis.IDENTITY, main.STORE_ORIGIN + Vector3(x * STEP, 1.08, z * STEP))
   if space.intersect_shape(query, 1).is_empty():
    free[cell] = true
 var start := Vector2i(0, 11)
 if not free.has(start):
  push_error("STORE_NAV_FAIL: entrance overlaps model collision")
  quit(1)
  return
 var visited := {start: true}
 var queue: Array[Vector2i] = [start]
 var cursor := 0
 while cursor < queue.size():
  var cell := queue[cursor]
  cursor += 1
  for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
   var next: Vector2i = cell + step
   if free.has(next) and not visited.has(next):
    visited[next] = true
    queue.append(next)
 for id in Store.STATIONS:
  var reachable := false
  for cell in visited:
   if main.store_interior.focus(main.STORE_ORIGIN + Vector3(cell.x * STEP, 1.08, cell.y * STEP)) == id:
    reachable = true
    break
  if not reachable:
   push_error("STORE_NAV_FAIL: no walkable route to " + id)
   quit(1)
   return
 main.hotaru.global_position = main.store_interior.get_entry_position()
 main.hotaru.set_active(true)
 main._update_camera(1.0)
 var before: Vector2 = main.camera.unproject_position(main.hotaru.global_position)
 Input.action_press("move_forward")
 for frame in range(6):
  await physics_frame
 Input.action_release("move_forward")
 var after: Vector2 = main.camera.unproject_position(main.hotaru.global_position)
 if after.y >= before.y - 1.0:
  push_error("STORE_NAV_FAIL: W does not move toward screen top")
  quit(1)
  return
 print("STORE_NAV_PASS: capsule clearance from entrance to all four loot stations; ", visited.size(), " connected cells")
 quit()


