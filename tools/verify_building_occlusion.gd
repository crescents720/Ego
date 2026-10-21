extends SceneTree
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 var main = load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 main._prepare_storefront_preview()
 main.hotaru.set_active(false)
 var found := false
 for lot in main.town_layout.lots:
  var bounds: AABB = lot.bounds
  main.hotaru.global_position = Vector3(bounds.end.x+0.8,0.95,bounds.end.z+0.8)
  main.camera.global_position = main.hotaru.global_position + main.TOWN_CAMERA_OFFSET
  main._update_camera(1.0)
  main.town_occlusion.update(main.camera, main.hotaru, true)
  if main.town_occlusion.get_faded_count() > 0:
   print("OCCLUSION_CASE: new residential lot ",lot.model," faded=",main.town_occlusion.get_faded_count())
   found = true
   break
 if not found:
  push_error("OCCLUSION_FAIL: foreground buildings never fade")
  quit(1)
  return
 for entry in main.town_occlusion._entries:
  if entry.occluded:
   for surface in entry.surfaces:
    if surface.mesh.get_surface_override_material(surface.index).albedo_color.a > 0.2:
     quit(1)
     return
 var blocked_position: Vector3 = main.hotaru.global_position
 main.hotaru.global_position = Vector3(-155, 0.95, -155)
 main.camera.global_position = main.hotaru.global_position + main.TOWN_CAMERA_OFFSET
 main._update_camera(1.0)
 main.town_occlusion.update(main.camera, main.hotaru, true)
 if main.town_occlusion.get_faded_count() != 0:
  quit(1)
  return
 for entry in main.town_occlusion._entries:
  for surface in entry.surfaces:
   if surface.mesh.get_surface_override_material(surface.index) != surface.original:
    push_error("OCCLUSION_FAIL: original material not restored")
    quit(1)
    return
 main.hotaru.global_position = blocked_position
 main.camera.global_position = main.hotaru.global_position + main.TOWN_CAMERA_OFFSET
 main._update_camera(1.0)
 main.town_occlusion.update(main.camera, main.hotaru, true)
 if DisplayServer.get_name() != "headless":
  for i in range(12):
   await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://artifacts/town_occlusion.png")
 print("OCCLUSION_PASS: character behind foreground building remains visible; opaque materials restore")
 quit()
