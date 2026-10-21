extends RefCounted

# A conservative world-space bounds check also works with orthographic
# cameras and decorative buildings that have no matching physics collider.
var _entries: Array[Dictionary] = []


func register_building(building: Node3D) -> void:
	var meshes := building.find_children("*", "MeshInstance3D", true, false)
	if building is MeshInstance3D:
		meshes.append(building)
	var surfaces: Array[Dictionary] = []
	var bounds := AABB()
	var first := true
	var transparent_materials: Dictionary = {}
	for mesh in meshes:
		var world_bounds: AABB = mesh.global_transform * mesh.get_aabb()
		bounds = world_bounds if first else bounds.merge(world_bounds)
		first = false
		for index in range(mesh.mesh.get_surface_count()):
			var material: Material = mesh.get_active_material(index)
			if not material is BaseMaterial3D:
				continue
			if not transparent_materials.has(material):
				var faded: BaseMaterial3D = material.duplicate()
				faded.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				faded.albedo_color.a = 0.16
				faded.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
				transparent_materials[material] = faded
			surfaces.append({"mesh": mesh, "index": index,
				"original": mesh.get_surface_override_material(index),
				"faded": transparent_materials[material]})
	if not surfaces.is_empty():
		_entries.append({"bounds": bounds, "surfaces": surfaces, "occluded": false})


func update(camera: Camera3D, target: Node3D, enabled: bool) -> void:
	var rays: Array[Dictionary]=[]
	if enabled:
		for height in [-0.65,0.0,0.75]:
			var point:=target.global_position+Vector3(0,height,0)
			rays.append({"start":camera.project_ray_origin(camera.unproject_position(point)),"end":point})
	for entry in _entries:
		var blocked := false
		if enabled:
			# Extra margin when already faded prevents flicker at wall edges.
			var bounds: AABB = entry.bounds.grow(0.65 if entry.occluded else 0.25)
			for ray in rays:
				if bounds.intersects_segment(ray.start, ray.end) != null:
					blocked = true
					break
		if blocked == entry.occluded:
			continue
		entry.occluded = blocked
		for surface in entry.surfaces:
			surface.mesh.set_surface_override_material(surface.index, surface.faded if blocked else surface.original)


func get_faded_count() -> int:
	var count := 0
	for entry in _entries:
		if entry.occluded:
			count += 1
	return count

