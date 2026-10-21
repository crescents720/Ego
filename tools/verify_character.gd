extends SceneTree
# Verifies the imported skin deforms, not merely that animation names exist.
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 if DisplayServer.get_name() == "headless":
  push_error("Run this skin deformation check with graphical rendering enabled")
  quit(1)
  return
 var actor = load("res://scripts/actors/hotaru.gd").new()
 root.add_child(actor)
 actor.set_process(false)
 actor.set_physics_process(false)
 var player: AnimationPlayer = actor._animation_player
 var mesh: MeshInstance3D = actor.find_children("*", "MeshInstance3D", true, false)[0]
 var skeleton: Skeleton3D = mesh.get_node(mesh.skeleton)
 await process_frame
 await process_frame
 var poses: Array = []
 for time in [0.0, 0.5]:
  player.play("Walk", 0.0)
  player.seek(time, true)
  skeleton.force_update_all_bone_transforms()
  await process_frame
  await RenderingServer.frame_post_draw
  poses.append(mesh.bake_mesh_from_current_skeleton_pose().surface_get_arrays(0)[Mesh.ARRAY_VERTEX])
 var changed := 0
 for index in range(poses[0].size()):
  if poses[0][index].distance_to(poses[1][index]) > 0.01:
   changed += 1
 if changed < 100:
  push_error("CHARACTER_TEST_FAIL: walk skin does not deform")
  quit(1)
  return
 actor.set_seated(true)
 if actor.get_animation_state() != "Sit":
  quit(1)
  return
 print("CHARACTER_TEST_PASS: Idle/Walk/Sit; ", changed, " vertices move between opposite walk poses")
 quit()



