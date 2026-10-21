extends Node3D

const MODEL_PATH := "res://assets/third_party/supermarket/supermarket_mobile.glb"
const ENTRY := Vector3(0.0, 1.08, 2.68)
const EXIT_AISLE:=Rect2(-3.5,2.15,7.0,1.45)
const STATIONS := {
	"food": {"name": "密封面包 · 0.5 kg/包", "anchor": Vector3(-2.625, 0.95, 0.3), "color": Color("e8bb69")},
	"water": {"name": "桶装饮水 · 5 L/桶", "anchor": Vector3(-0.875, 0.95, 0.3), "color": Color("6acbd5")},
	"medical": {"name": "应急医疗用品", "anchor": Vector3(0.875, 0.95, -0.8), "color": Color("a6cf9a")},
	"tools": {"name": "维修材料与留言", "anchor": Vector3(2.625, 0.95, 0.8), "color": Color("df946e")},
}

var looted: Dictionary = {}
var _model: Node3D
var _markers: Dictionary = {}
var _labels: Dictionary = {}
var _focused := ""
var _collider: StaticBody3D


func _ready() -> void:
	_model = load(MODEL_PATH).instantiate()
	add_child(_model)
	_build_collision()
	for id in STATIONS:
		var data: Dictionary = STATIONS[id]
		var marker := MeshInstance3D.new()
		var ring := TorusMesh.new()
		ring.inner_radius = 0.19
		ring.outer_radius = 0.25
		ring.rings = 12
		ring.ring_segments = 8
		marker.mesh = ring
		marker.position = data.anchor + Vector3(0, 0.85, 0)
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = data.color
		marker.material_override = material
		add_child(marker)
		_markers[id] = marker
		var label := Label3D.new()
		label.text = data.name
		label.position = marker.position + Vector3(0, 0.45, 0)
		label.font_size = 25
		label.outline_size = 7
		label.modulate = data.color
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.visible = false
		add_child(label)
		_labels[id] = label
	set_active(false)


func _build_collision() -> void:
	# Navigation uses a handful of boxes, never individual product triangles.
	_collider = StaticBody3D.new()
	_collider.collision_layer = 0
	_collider.collision_mask = 0
	add_child(_collider)
	_add_collision_box(Vector3(8.0, 0.12, 7.4), Vector3(0, -0.02, 0))
	for x in [-3.96, 3.96]:
		_add_collision_box(Vector3(0.12, 2.8, 7.4), Vector3(x, 1.4, 0))
	for z in [-3.68, 3.55]:
		_add_collision_box(Vector3(7.8, 2.8, 0.12), Vector3(0, 1.4, z))
	for x in [-2.625, -0.875, 0.875, 2.625]:
		_add_collision_box(Vector3(0.85, 1.45, 3.4), Vector3(x, 0.725, 0))
	_add_collision_box(Vector3(6.5, 1.9, 0.6), Vector3(0, 0.95, -2.75))
	_add_collision_box(Vector3(0.9, 1.1, 0.55), Vector3(-3.32, 0.55, 2.9))


func _add_collision_box(size_value: Vector3, position_value: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size_value
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = position_value
	_collider.add_child(collision)


func set_active(value: bool) -> void:
	visible = value
	_collider.collision_layer = 1 if value else 0
	if not value:
		_focused = ""


func reset_loot(taken: Dictionary = {}) -> void:
	looted = taken
	for id in _markers:
		_markers[id].visible = true
		_labels[id].hide()


func get_entry_position() -> Vector3:
	return to_global(ENTRY)


func is_near_exit(player_position: Vector3) -> bool:
	# The whole walkable front-door aisle is an exit interaction zone. A
	# one-metre sphere around the spawn point missed the visible door edges.
	var local:=to_local(player_position)
	return visible and EXIT_AISLE.has_point(Vector2(local.x,local.z))


func get_camera_pivot() -> Vector3:
	return global_position + Vector3(0, 0.8, 0)


func update_cutaway(camera_position: Vector3) -> void:
	var local_camera := to_local(camera_position)
	for node in _model.get_children():
		var n := str(node.name)
		if n.begins_with("Roof"):
			node.visible = false
		elif n.begins_with("WallXP"):
			node.visible = local_camera.x < 0
		elif n.begins_with("WallXN"):
			node.visible = local_camera.x >= 0
		elif n.begins_with("WallZP"):
			node.visible = local_camera.z < 0
		elif n.begins_with("WallZN"):
			node.visible = local_camera.z >= 0


func focus(player_position: Vector3) -> String:
	var player := to_local(player_position)
	_focused = ""
	var nearest := 1.3
	for id in STATIONS:
		_labels[id].hide()
		var anchor: Vector3 = STATIONS[id].anchor
		var distance := Vector2(player.x, player.z).distance_to(Vector2(anchor.x, anchor.z))
		if distance < nearest:
			nearest = distance
			_focused = id
	if not _focused.is_empty():
		_labels[_focused].show()
	return _focused


func take_focused() -> String:
	var id := _focused
	if id.is_empty():
		return ""
	looted[id] = true
	_markers[id].show()
	_labels[id].hide()
	_focused = ""
	return id


