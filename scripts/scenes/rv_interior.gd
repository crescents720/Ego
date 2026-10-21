extends Node3D
# 房车内部造型预览场景
# 目的：把小萤的灰盒造型 + 房车内部空间布局先"嘬"出来，供走查和迭代。
# 操作：WASD 移动小萤，鼠标拖拽视角，滚轮缩放；按 1/2/3/4 切换机位。
# 这个场景刻意不接主循环，确认布局后再把构件搬进主游戏。

# ---- 房车内部尺寸（外部尺寸：宽 2.3 / 高 2.4 / 长 6.0，车头朝 -Z）----
const RV_W := 2.3          # 外部宽
const RV_H := 2.4          # 外部高
const RV_L := 6.0          # 外部长
const WALL_T := 0.10
const FLOOR_T := 0.10
const CEIL_T := 0.10
const INTERIOR_W := RV_W - WALL_T * 2.0   # 约 2.1
const INTERIOR_H := RV_H - FLOOR_T - CEIL_T  # 约 2.2
const Z_FRONT := -RV_L * 0.5             # 车头端 -3.0
const Z_REAR := RV_L * 0.5                # 车尾端 +3.0

# ---- 配色 ----
const COL_FLOOR := Color("c9a87a")        # 浅木地板
const COL_WALL := Color("efe6d6")         # 米白墙
const COL_CEIL := Color("f6f1e7")
const COL_KITCHEN := Color("d9d2c2")     # 厨房台面
const COL_CABINET := Color("b98d5f")      # 木柜
const COL_SOFA := Color("c8a9a0")         # 豆沙粉沙发
const COL_BED := Color("e8d9c5")          # 床品米白
const COL_WORKTOP := Color("5a6068")      # 钢灰工作台
const COL_METAL := Color("8a9098")
const COL_DARK := Color("2c2f34")

const COL_HAIR := Color("dfe6ef")         # 银白发
const COL_SKIN := Color("f6d2b8")
const COL_SHIRT := Color("f5f2ec")        # 白T
const COL_SKIRT := Color("1d1d22")       # 黑裙
const COL_RIBBON := Color("0d0d10")      # 黑丝带
const COL_SHOE := Color("f4f1ec")
const COL_SHOE_ACCENT := Color("e88a93")  # 粉鞋带装饰

var player: CharacterBody3D
var camera_pivot: Node3D
var camera: Camera3D
var cam_distance := 4.2
var cam_height := 2.2
var cam_angle_y := 0.6
var cam_angle_x := -0.35
var _mouse_down := false
var _walk_model: Node3D = null
var _walk_time := 0.0


func _ready() -> void:
	_ensure_input_actions()
	_build_environment()
	_build_rv_shell()
	_build_cabin()
	_build_living_room()
	_build_workshop()
	_build_door_and_exit()
	_build_player()
	_build_lighting()
	# 地面网格辅助
	var grid := GridMap.new()
	# 简单起见，用一个静态地板标记外面
	var ground := MeshInstance3D.new()
	var gm := PlaneMesh.new()
	gm.size = Vector2(20, 20)
	ground.mesh = gm
	ground.position = Vector3(0, -FLOOR_T - 0.01, 0)
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color("3a3f45")
	gmat.roughness = 1.0
	ground.material_override = gmat
	add_child(ground)


# ---------- 环境 ----------
func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("11161d")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("404856")
	env.ambient_light_energy = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


# ---------- 房车外壳（地板/墙/天花板）--------
func _build_rv_shell() -> void:
	# 地板（内部 Y=0）
	_box(Vector3(RV_W, FLOOR_T, RV_L), Vector3(0, -FLOOR_T * 0.5, 0), COL_FLOOR)
	# 天花板
	_box(Vector3(RV_W, CEIL_T, RV_L), Vector3(0, INTERIOR_H + CEIL_T * 0.5, 0), COL_CEIL)
	# 左右墙（半透明，方便外部看内部）
	var left_wall := _box(Vector3(WALL_T, RV_H, RV_L), Vector3(-RV_W * 0.5 + WALL_T * 0.5, RV_H * 0.5, 0), COL_WALL)
	_make_transparent(left_wall, 0.12)
	var right_wall := _box(Vector3(WALL_T, RV_H, RV_L), Vector3(RV_W * 0.5 - WALL_T * 0.5, RV_H * 0.5, 0), COL_WALL)
	_make_transparent(right_wall, 0.12)
	# 车尾墙（+Z，半透明）
	var rear_wall := _box(Vector3(RV_W, RV_H, WALL_T), Vector3(0, RV_H * 0.5, RV_L * 0.5 - WALL_T * 0.5), COL_WALL)
	_make_transparent(rear_wall, 0.12)
	# 车头端：驾驶室与起居舱之间的"隔断墙"——但留贯通口
	# 不封死，只做矮隔断
	_box(Vector3(INTERIOR_W, 0.7, WALL_T), Vector3(0, 0.35, -1.0), COL_CABINET)


# ---------- 驾驶室 ----------
func _build_cabin() -> void:
	# 仪表盘
	_box(Vector3(INTERIOR_W - 0.2, 0.25, 0.4), Vector3(0, 1.05, -2.55), COL_DARK)
	# 两个座椅（驾驶/副驾）
	for x in [-0.45, 0.45]:
		_box(Vector3(0.5, 0.15, 0.5), Vector3(x, 0.45, -1.9), COL_SOFA)        # 座垫
		_box(Vector3(0.5, 0.6, 0.12), Vector3(x, 0.8, -2.15), COL_SOFA)        # 靠背
	# 前挡风玻璃示意（半透明蓝）
	var glass := _box(Vector3(INTERIOR_W - 0.1, 0.5, 0.05), Vector3(0, 1.35, Z_FRONT + 0.05), Color("5a7a90"))
	var gm: StandardMaterial3D = glass.material_override
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.albedo_color.a = 0.4


# ---------- 日式起居区 ----------
func _build_living_room() -> void:
	# === 左侧厨房（-X 墙，Z -0.8 ~ +0.3）===
	# 地柜
	_box(Vector3(0.55, 0.8, 1.1), Vector3(-RV_W * 0.5 + WALL_T + 0.275, 0.4, -0.25), COL_CABINET)
	# 台面
	_box(Vector3(0.6, 0.05, 1.15), Vector3(-RV_W * 0.5 + WALL_T + 0.3, 0.825, -0.25), COL_KITCHEN)
	# 灶台（两个圆盘示意）
	_cylinder(0.11, 0.02, Vector3(-0.85, 0.86, -0.55), COL_DARK)
	_cylinder(0.09, 0.02, Vector3(-0.85, 0.86, -0.25), COL_DARK)
	# 水槽（凹陷示意）
	_box(Vector3(0.3, 0.02, 0.35), Vector3(-0.85, 0.86, 0.15), Color("9aa3ab"))
	# 小冰箱（立柜，Z=+0.4 处）
	_box(Vector3(0.55, 1.2, 0.5), Vector3(-RV_W * 0.5 + WALL_T + 0.275, 0.6, 0.55), Color("d8dde2"))

	# === 右侧卡座沙发（+X 墙，Z -0.6 ~ +0.8）===
	# 长凳
	_box(Vector3(0.55, 0.4, 1.4), Vector3(RV_W * 0.5 - WALL_T - 0.275, 0.2, 0.1), COL_SOFA)
	# 靠背
	_box(Vector3(0.15, 0.6, 1.4), Vector3(RV_W * 0.5 - WALL_T - 0.075, 0.55, 0.1), COL_SOFA)
	# 矮桌（中间）
	_box(Vector3(0.55, 0.06, 0.55), Vector3(0.35, 0.4, 0.1), Color("a87848"))

	# === 后段双人床（沿 -X 墙，Z +1.0 ~ +2.4）===
	_box(Vector3(1.0, 0.25, 1.4), Vector3(-0.5, 0.25, 1.7), COL_BED)
	# 枕头
	_box(Vector3(0.35, 0.12, 0.25), Vector3(-0.75, 0.45, 1.1), Color("ffffff"))
	# 薄被
	_box(Vector3(0.9, 0.06, 0.8), Vector3(-0.5, 0.42, 1.95), Color("b8c4d4"))

	# === 衣柜（后段 +X 墙）===
	_box(Vector3(0.5, 1.8, 0.6), Vector3(RV_W * 0.5 - WALL_T - 0.25, 0.9, 1.6), COL_CABINET)

	# === 顶柜（沿两侧墙上方）===
	_box(Vector3(0.4, 0.5, 1.6), Vector3(-RV_W * 0.5 + WALL_T + 0.2, 1.75, -0.25), COL_CABINET)
	_box(Vector3(0.4, 0.5, 1.2), Vector3(RV_W * 0.5 - WALL_T - 0.2, 1.75, 1.6), COL_CABINET)

	# === 暖黄顶灯 ===
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, 1.9, 0.2)
	lamp.light_color = Color("ffd9a0")
	lamp.light_energy = 1.2
	lamp.omni_range = 5.0
	add_child(lamp)
	# 灯罩
	_cylinder(0.12, 0.05, Vector3(0, INTERIOR_H - 0.03, 0.2), Color("fff3d0"))


# ---------- 工作生产区（沿后墙 +Z 一字排开）----------
func _build_workshop() -> void:
	# 主工作台（沿后墙）
	_box(Vector3(1.8, 0.08, 0.6), Vector3(0, 0.85, 2.65), COL_WORKTOP)
	# 桌腿
	for x in [-0.8, 0.8]:
		_box(Vector3(0.06, 0.85, 0.5), Vector3(x, 0.425, 2.65), COL_METAL)
	# 工具挂板（后墙上）
	_box(Vector3(1.9, 0.7, 0.04), Vector3(0, 1.35, 2.95), Color("6b5842"))
	# 几个工具示意
	for i in range(5):
		_box(Vector3(0.04, 0.25, 0.03), Vector3(-0.7 + i * 0.35, 1.35, 2.92), COL_DARK)

	# 武器改装台（左侧，单独小台）
	_box(Vector3(0.5, 0.08, 0.5), Vector3(-0.7, 0.85, 2.1), COL_WORKTOP)
	_box(Vector3(0.05, 0.85, 0.05), Vector3(-0.9, 0.425, 2.0), COL_METAL)
	_box(Vector3(0.05, 0.85, 0.05), Vector3(-0.5, 0.425, 2.0), COL_METAL)

	# 材料货架（右侧，三层）
	_box(Vector3(0.5, 1.6, 0.4), Vector3(0.85, 0.8, 2.1), COL_METAL)
	for y in [0.4, 0.85, 1.3]:
		_box(Vector3(0.55, 0.04, 0.42), Vector3(0.85, y, 2.1), COL_DARK)

	# 暖光灯
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, 1.9, 2.3)
	lamp.light_color = Color("ffe6b8")
	lamp.light_energy = 1.0
	lamp.omni_range = 4.0
	add_child(lamp)


# ---------- 侧门（右侧 +X，中间 Z=0 处开个口）----------
func _build_door_and_exit() -> void:
	# 右墙在 Z -0.4 ~ +0.4 处留门洞——上面 _build_rv_shell 是整面墙，这里"补"出门框
	# 用门框木色标记位置
	_box(Vector3(0.06, 1.9, 0.06), Vector3(RV_W * 0.5 - WALL_T - 0.02, 0.95, -0.45), COL_CABINET)
	_box(Vector3(0.06, 1.9, 0.06), Vector3(RV_W * 0.5 - WALL_T - 0.02, 0.95, 0.45), COL_CABINET)
	# 台阶
	_box(Vector3(0.5, 0.08, 0.9), Vector3(RV_W * 0.5 + 0.2, -0.04, 0.0), Color("9aa0a6"))


# ---------- 灯光 ----------
func _build_lighting() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_energy = 0.4
	sun.shadow_enabled = true
	add_child(sun)


# ---------- 小萤（角色灰盒）----------
func _build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Hotaru"
	player.position = Vector3(0, 0, 0.0)
	add_child(player)

	# 碰撞胶囊
	var col := CollisionShape3D.new()
	var cs := CapsuleShape3D.new()
	cs.radius = 0.28
	cs.height = 1.45
	col.shape = cs
	col.position.y = 0.78
	player.add_child(col)

	# === 视觉：加载站着的模型 ===
	var root := Node3D.new()
	root.name = "Visual"
	player.add_child(root)

	var hotaru_scene := load("res://assets/characters/anime-girl/girl.glb") as PackedScene
	if hotaru_scene:
		_walk_model = hotaru_scene.instantiate()
		_walk_model.position = Vector3(0, 0, 0)
		root.add_child(_walk_model)
	else:
		push_error("无法加载 girl.glb")

	# 名字标签
	var label := Label3D.new()
	label.text = "小萤 Hotaru"
	label.position = Vector3(0, 1.95, 0)
	label.font_size = 36
	label.outline_size = 8
	label.modulate = Color("ffe4a8")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	root.add_child(label)

	# === 相机 ===
	camera_pivot = Node3D.new()
	camera_pivot.position = Vector3(0, 1.0, 0)
	player.add_child(camera_pivot)

	camera = Camera3D.new()
	camera.fov = 60
	camera_pivot.add_child(camera)
	_update_camera()


# ---------- 玩家控制 ----------
func _physics_process(delta: float) -> void:
	var input_vec := Input.get_vector("move_left", "move_right", "move_backward", "move_forward")
	var dir := Vector3(input_vec.x, 0, input_vec.y)
	if dir.length_squared() > 1.0:
		dir = dir.normalized()
	# 镜头相对方向
	var cam_dir := Vector3(cos(cam_angle_y), 0, -sin(cam_angle_y))
	var right := Vector3(cam_dir.z, 0, -cam_dir.x)
	var move := (cam_dir * dir.z + right * dir.x) * 2.8
	player.velocity.x = move.x
	player.velocity.z = move.z
	player.velocity.y = 0
	player.move_and_slide()
	# 边界
	player.position.x = clampf(player.position.x, -RV_W * 0.5 + 0.3, RV_W * 0.5 - 0.3)
	player.position.z = clampf(player.position.z, Z_FRONT + 0.4, Z_REAR - 0.3)
	# 朝向
	if move.length_squared() > 0.05:
		player.rotation.y = lerp_angle(player.rotation.y, atan2(move.x, move.z), delta * 10.0)
	# 走路动画：整体上下晃 + 微倾
	var moving := move.length_squared() > 0.05
	if moving:
		_walk_time += delta * 8.0
	else:
		_walk_time += delta * 2.0
	if _walk_model:
		if moving:
			_walk_model.position.y = abs(sin(_walk_time)) * 0.04
			_walk_model.rotation.z = sin(_walk_time) * 0.03
		else:
			_walk_model.position.y = lerp(_walk_model.position.y, 0.0, delta * 5.0)
			_walk_model.rotation.z = lerp(_walk_model.rotation.z, 0.0, delta * 5.0)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _mouse_down:
		cam_angle_y -= event.relative.x * 0.005
		cam_angle_x = clampf(cam_angle_x - event.relative.y * 0.005, -1.2, 0.3)
		_update_camera()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_mouse_down = event.pressed
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam_distance = maxf(1.8, cam_distance - 0.3)
			_update_camera()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam_distance = minf(8.0, cam_distance + 0.3)
			_update_camera()
	elif event is InputEventKey:
		if event.pressed:
			match event.keycode:
				KEY_1:
					cam_distance = 3.5; cam_angle_x = -0.3; _update_camera()
				KEY_2:
					cam_distance = 6.0; cam_angle_x = -0.9; _update_camera()  # 上帝视角
				KEY_3:
					# 近看小萤
					cam_distance = 1.5; cam_angle_x = -0.1; _update_camera()
				KEY_4:
					# 车尾工作台视角
					cam_angle_y = 0.0; cam_angle_x = -0.2; cam_distance = 3.0; _update_camera()


func _update_camera() -> void:
	camera_pivot.position.y = 1.0
	camera.position = Vector3(0, cam_height, cam_distance)
	camera.rotation_degrees = Vector3(rad_to_deg(cam_angle_x), 0, 0)


# ---------- 工具函数 ----------
func _ensure_input_actions() -> void:
	var bindings := {
		"move_forward": [KEY_W, KEY_UP],
		"move_backward": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
	}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			for keycode in bindings[action]:
				var ev := InputEventKey.new()
				ev.physical_keycode = keycode
				InputMap.action_add_event(action, ev)


func _mat(color: Color, roughness: float = 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	return m


func _make_transparent(mesh: MeshInstance3D, alpha: float) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(mesh.material_override.albedo_color, alpha)
	m.roughness = 0.85
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material_override = m


func _box(size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = _mat(color)
	add_child(mi)
	return mi


func _cylinder(radius: float, height: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	mi.mesh = cm
	mi.position = pos
	mi.material_override = _mat(color)
	add_child(mi)
	return mi
