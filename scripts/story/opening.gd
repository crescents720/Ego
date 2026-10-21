extends Node3D

const Fire = preload("res://scripts/environment/story_fire.gd")
const EscapeTrail = preload("res://scripts/environment/escape_trail.gd")
const ROOM_ORIGIN := Vector3(3000,0,0)
const FRONT_EXIT := Vector3(-6.7,0.95,-43)
const ROUTE := [Vector3(-6.5,0.95,-35.5),Vector3(-24.0,0.95,-35.5),Vector3(-23.28,0.95,-42.21)]
const CROWD := [Vector2(-3.8,-43),Vector2(-3.2,-46.6),Vector2(-2.0,-40.5),Vector2(1.2,-44.1),Vector2(2.4,-47.4),Vector2(4.2,-42.8),Vector2(-1.3,-49.0),Vector2(3.0,-38.4),Vector2(6.1,-46.0),Vector2(6.5,-40.1),Vector2(-4.4,-48.5),Vector2(-0.1,-35.7),Vector2(4.8,-50.2),Vector2(-3.2,-38.9),Vector2(1.7,-52.0),Vector2(7.1,-35.5)]
enum Beat { FILM=-2, BRIDGE=-1, SLEEP, DREAM, BREAK, WAKE, RISING, EXTERIOR, ESCAPE, DONE }
var beat: Beat = Beat.DONE
var elapsed := 0.0
var main
var bedroom: Node3D
var room_fire: Node3D
var ui: CanvasLayer
var background: ColorRect
var photo: TextureRect
var caption: Label
var place: Label
var next_button: Button
var skip_button: Button
var fade: ColorRect
var voice: AudioStreamPlayer
var music: AudioStreamPlayer
var fire_audio: AudioStreamPlayer
var lowpass: AudioEffectLowPassFilter
var reverb: AudioEffectReverb
var _dream_line := -1
var _route_index := 0
var _guides: Array[Node3D] = []
var _trail
var _front_zombies: Array[Node] = []
var _rise_tween: Tween
var movie: VideoStreamPlayer
var _caption_panel: ColorRect
var _using_film := false

func _ready() -> void:
	main = get_parent()
	_build_room()
	_build_ui()
	_build_audio()

func is_cinematic() -> bool:
	return beat < Beat.ESCAPE

func _build_room() -> void:
	bedroom = Node3D.new()
	bedroom.position = ROOM_ORIGIN
	add_child(bedroom)
	var model: Node3D = load("res://assets/story/bedroom/bedroom_mobile.glb").instantiate()
	bedroom.add_child(model)
	main._add_box(bedroom,"RoomFloor",Vector3(6.0,0.12,5.4),Vector3(3.25,-0.06,0),Color("685346"))
	for x in [1.55,4.95]:
		main._add_box(bedroom,"BedsideCabinet",Vector3(0.60,0.54,0.62),Vector3(x,0.27,1.55),Color("524436"))
	main._add_box(bedroom,"RoomBackWall",Vector3(6.0,2.8,0.12),Vector3(3.25,1.4,2.28),Color("aaa394"))
	main._add_box(bedroom,"RoomLeftWall",Vector3(0.12,2.8,5.4),Vector3(0.28,1.4,0),Color("9a978c"))
	main._add_box(bedroom,"WindowFrame",Vector3(0.08,1.65,1.9),Vector3(0.36,1.65,0.6),Color("415562"))
	for i in range(6):
		main._add_box(bedroom,"Curtain",Vector3(0.07,2.0,0.22),Vector3(0.43,1.45,-0.35+i*0.36),Color("c3beb0"))
	room_fire = Node3D.new()
	bedroom.add_child(room_fire)
	for point in [Vector3(0.7,0.05,0.4),Vector3(2.0,0.05,2.0),Vector3(5.1,0.05,1.7),Vector3(5.4,0.05,-0.8)]:
		var fire := Fire.new()
		fire.position = point
		room_fire.add_child(fire)
	room_fire.hide()
	bedroom.hide()
	bedroom.process_mode = Node.PROCESS_MODE_DISABLED

func _build_ui() -> void:
	ui = CanvasLayer.new()
	ui.layer = 90
	add_child(ui)
	background = ColorRect.new()
	background.size = Vector2(720,1280)
	background.color = Color("e4d5b5")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(background)
	movie=VideoStreamPlayer.new()
	movie.bus="Film"
	movie.name="OpeningFilm"
	movie.position=Vector2.ZERO
	movie.size=Vector2(720,1280)
	movie.expand=true
	movie.mouse_filter=Control.MOUSE_FILTER_IGNORE
	movie.volume_db=-3
	movie.finished.connect(_finish_film)
	movie.hide()
	ui.add_child(movie)
	photo = TextureRect.new()
	photo.position = Vector2(0,100)
	photo.size = Vector2(720,960)
	photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	photo.texture = load("res://assets/story/graduation.png")
	photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
uniform float broken = 0.0;
void fragment() {
 vec2 cell = floor(UV*vec2(7.0,10.0));
 float h = fract(sin(dot(cell,vec2(12.9898,78.233)))*43758.5453);
 vec2 uv = UV + (cell/vec2(7.0,10.0)-0.5)*broken*0.65 + vec2(sin(TIME*35.0+h*8.0),0.0)*broken*0.018;
 vec4 c = texture(TEXTURE,uv);
 vec2 edge = min(fract(UV*vec2(7,10)),1.0-fract(UV*vec2(7,10)));
 float cracks = 1.0-smoothstep(0.0,0.035,min(edge.x,edge.y));
 c.rgb = mix(c.rgb,vec3(0.95,0.98,1.0),cracks*broken);
 c.a *= (1.0-broken*0.7)*step(0.0,uv.x)*step(uv.x,1.0)*step(0.0,uv.y)*step(uv.y,1.0);
 COLOR = c;
}"""
	var material := ShaderMaterial.new()
	material.shader = shader
	photo.material = material
	ui.add_child(photo)
	place = Label.new()
	place.position = Vector2(34,35)
	place.size = Vector2(500,60)
	place.add_theme_font_size_override("font_size",26)
	ui.add_child(place)
	var panel := ColorRect.new()
	_caption_panel=panel
	panel.position = Vector2(26,1000)
	panel.size = Vector2(668,170)
	panel.color = Color(0.025,0.025,0.03,0.86)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(panel)
	caption = Label.new()
	caption.position = Vector2(46,1015)
	caption.size = Vector2(628,145)
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.add_theme_font_size_override("font_size",27)
	caption.add_theme_color_override("font_color",Color("fff0d6"))
	ui.add_child(caption)
	next_button = Button.new()
	next_button.position = Vector2(448,1190)
	next_button.size = Vector2(240,64)
	next_button.text = "继续 E"
	next_button.focus_mode = Control.FOCUS_NONE
	main._style_button(next_button,Color("725138"))
	next_button.pressed.connect(advance)
	ui.add_child(next_button)
	skip_button = Button.new()
	skip_button.position = Vector2(540,30)
	skip_button.size = Vector2(150,55)
	skip_button.text = "跳过过场"
	skip_button.focus_mode = Control.FOCUS_NONE
	skip_button.pressed.connect(func(): set_beat(Beat.EXTERIOR))
	ui.add_child(skip_button)
	fade = ColorRect.new()
	fade.size = Vector2(720,1280)
	fade.color = Color(0,0,0,0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(fade)
	ui.hide()

func _build_audio() -> void:
	var index := AudioServer.get_bus_index("OpeningDream")
	if index < 0:
		AudioServer.add_bus()
		index = AudioServer.bus_count-1
		AudioServer.set_bus_name(index,"OpeningDream")
		lowpass = AudioEffectLowPassFilter.new()
		reverb = AudioEffectReverb.new()
		AudioServer.add_bus_effect(index,lowpass)
		AudioServer.add_bus_effect(index,reverb)
	else:
		lowpass = AudioServer.get_bus_effect(index,0)
		reverb = AudioServer.get_bus_effect(index,1)
	voice = AudioStreamPlayer.new()
	voice.volume_db = -3
	add_child(voice)
	music = AudioStreamPlayer.new()
	music.stream = load("res://assets/story/audio/dream.wav")
	music.bus = "OpeningDream"
	music.volume_db = -19
	add_child(music)
	fire_audio = AudioStreamPlayer.new()
	var stream: AudioStreamWAV = load("res://assets/story/audio/fire.wav").duplicate()
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = int(stream.get_length()*stream.mix_rate)
	fire_audio.stream = stream
	fire_audio.volume_db = -14
	add_child(fire_audio)

func _speak(file: String, dream: bool = false) -> void:
	voice.stop()
	# Keep captions; synthesized narration is disabled pending new recordings.

func start(use_film: bool=true) -> void:
	_route_index = 0
	lowpass.cutoff_hz = 20000
	reverb.wet = 0.18
	reverb.dry = 0.9
	photo.material.set_shader_parameter("broken",0.0)
	background.color = Color("e4d5b5")
	next_button.show()
	next_button.text = "继续 E"
	skip_button.show()
	_using_film=use_film and ResourceLoader.exists("res://assets/story/video/opening_v2.ogv")
	set_beat(Beat.FILM if _using_film else Beat.SLEEP)

func _finish_film() -> void:
	if beat==Beat.FILM:set_beat(Beat.BRIDGE)

func set_beat(value: Beat) -> void:
	if is_instance_valid(movie) and value!=Beat.FILM:
		movie.stop()
		movie.stream=null
		movie.hide()
	beat = value
	elapsed = 0
	main.controls_enabled = not is_cinematic()
	main.hotaru.set_active(not is_cinematic())
	main.get_node("HUD").visible = not is_cinematic()
	ui.visible = is_cinematic()
	background.visible = beat in [Beat.DREAM,Beat.BREAK]
	photo.visible = background.visible
	fade.color.a = 0
	_caption_panel.visible=beat!=Beat.FILM
	caption.visible=beat!=Beat.FILM
	match beat:
		Beat.FILM:
			main.world_root.hide()
			main.rv.hide()
			bedroom.hide()
			bedroom.process_mode=Node.PROCESS_MODE_DISABLED
			voice.stop()
			music.stop()
			fire_audio.stop()
			background.show()
			background.color=Color.BLACK
			photo.hide()
			place.text=""
			next_button.text="跳过影片 E"
			skip_button.hide()
			movie.stream=load("res://assets/story/video/opening_v2.ogv")
			movie.show()
			movie.play()
		Beat.BRIDGE:
			background.show()
			background.color=Color.BLACK
			photo.hide()
			place.text="现实 · 火中的家"
			caption.text="房车钥匙……还在！\n小萤抓起钥匙，冲出了房间。"
			next_button.text="冲出房间 E"
			skip_button.hide()
			fire_audio.play()
		Beat.SLEEP:
			main.world_root.hide()
			main.rv.hide()
			bedroom.show()
			bedroom.process_mode = Node.PROCESS_MODE_INHERIT
			main.hotaru.set_ground_height(0.95)
			main.hotaru._visual_root.rotation.x = -PI/2
			main.hotaru.global_position = ROOM_ORIGIN+Vector3(3.25,0.60,1.08)
			main.hotaru.rotation.y = PI
			place.text = ""
			caption.text = "小萤睡着了。\n梦里，是一个再普通不过的春天。"
			_set_room_camera()
		Beat.DREAM:
			place.text = "梦里 · 高中毕业那天"
			_dream_line = 0
			caption.text = "哥哥：哈哈，小萤，看镜头。\n三、二、一——毕业快乐！"
			_speak("brother_graduation",true)
			music.play()
		Beat.BREAK:
			place.text = "……哥哥？"
			caption.text = "哥哥：我们就开着房车……一起去……\n他的声音越来越远，像隔着一层水。"
		Beat.WAKE:
			music.stop()
			voice.stop()
			room_fire.show()
			main.home_fire.show()
			main.home_fire.process_mode = Node.PROCESS_MODE_INHERIT
			place.text = "现实 · 卧室"
			caption.text = "小萤：哥……？好烫！失火了！\n烟正从门缝涌进来。必须马上离开！"
			next_button.text = "起身逃离 E"
			skip_button.hide()
			_speak("hotaru_wake")
			fire_audio.play()
			_set_room_camera()
		Beat.RISING:
			next_button.hide()
			caption.text = "小萤抓起床边的房车钥匙，冲向门口。"
			_rise_tween = create_tween().set_parallel()
			_rise_tween.tween_property(main.hotaru._visual_root,"rotation:x",0.0,0.7)
			_rise_tween.tween_property(main.hotaru,"global_position",ROOM_ORIGIN+Vector3(1.75,0.95,0.55),0.85)
		Beat.EXTERIOR:
			music.stop()
			if is_instance_valid(_rise_tween):
				_rise_tween.kill()
			bedroom.hide()
			bedroom.process_mode = Node.PROCESS_MODE_DISABLED
			main.world_root.show()
			main.rv.show()
			main.home_fire.show()
			main.home_fire.process_mode = Node.PROCESS_MODE_INHERIT
			main.hotaru._visual_root.rotation.x = 0
			main.hotaru.set_ground_height(0.95)
			main.hotaru.global_position = FRONT_EXIT
			main.hotaru.rotation.y = PI/2
			_spawn_front_crowd()
			place.text = "家门外 · 前门被围住了"
			caption.text = "小萤：前门……全是那些东西。\n哥哥，你去哪儿了？后院的房车——钥匙还在！"
			next_button.show()
			next_button.text = "从后院逃走 E"
			skip_button.hide()
			_speak("hotaru_outside")
			if not fire_audio.playing:
				fire_audio.play()
			main._set_town_projection()
			main.camera.global_position = FRONT_EXIT+main.TOWN_CAMERA_OFFSET
			main.camera.look_at(FRONT_EXIT+Vector3(0,0.6,0))
		Beat.ESCAPE:
			voice.stop()
			main.hotaru.set_active(true)
			_build_guides()
		Beat.DONE:
			for guide in _guides:
				if is_instance_valid(guide): guide.hide()
			for zombie in _front_zombies:
				if is_instance_valid(zombie): zombie.set_target(main.hotaru)

func _set_room_camera() -> void:
	main.camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	main.camera.keep_aspect = Camera3D.KEEP_WIDTH
	main.camera.size = 5.7
	main.camera.global_position = ROOM_ORIGIN+Vector3(8,6,-6)
	main.camera.look_at(ROOM_ORIGIN+Vector3(3.2,0.65,0.85))

func advance() -> void:
	match beat:
		Beat.FILM: _finish_film()
		Beat.BRIDGE: set_beat(Beat.EXTERIOR)
		Beat.SLEEP: set_beat(Beat.DREAM)
		Beat.DREAM: set_beat(Beat.BREAK)
		Beat.BREAK: set_beat(Beat.WAKE)
		Beat.WAKE: set_beat(Beat.RISING)
		Beat.EXTERIOR: set_beat(Beat.ESCAPE)

func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") or event.is_action_pressed("toggle_vehicle"):
		advance()

func _process(delta: float) -> void:
	elapsed += delta
	match beat:
		Beat.BRIDGE:
			if elapsed>1.8:set_beat(Beat.EXTERIOR)
		Beat.SLEEP:
			if elapsed>2.6: set_beat(Beat.DREAM)
		Beat.DREAM:
			if elapsed>float(_dream_line+1)*3.2:
				_dream_line += 1
				if _dream_line == 1:
					caption.text = "小萤：哈哈哈，你刚才又没看镜头！再拍一张。"
					_speak("hotaru_laugh",true)
				elif _dream_line == 2:
					caption.text = "哥哥：好，再拍一张。等你收拾好行李，我们就开着房车……"
					_speak("brother_promise",true)
				else:
					set_beat(Beat.BREAK)
			if not music.playing: music.play()
		Beat.BREAK:
			var progress := clampf(elapsed/2.6,0,1)
			photo.material.set_shader_parameter("broken",progress)
			background.color = Color("e4d5b5").lerp(Color("171b22"),progress)
			lowpass.cutoff_hz = lerpf(18000,350,progress)
			reverb.wet = lerpf(0.18,0.85,progress)
			voice.pitch_scale = lerpf(1.0,0.6,progress)
			if elapsed>2.6: set_beat(Beat.WAKE)
		Beat.RISING:
			fade.color.a = clampf((elapsed-0.9)/0.6,0,1)
			if elapsed>1.6: set_beat(Beat.EXTERIOR)
		Beat.EXTERIOR:
			if elapsed>(5.0 if _using_film else 11.0): set_beat(Beat.ESCAPE)
		Beat.ESCAPE:
			if main.inside_rv:
				set_beat(Beat.DONE)
			elif _route_index < ROUTE.size() and main.hotaru.global_position.distance_to(ROUTE[_route_index])<1.7:
				_route_index += 1
			if is_instance_valid(_trail):_trail.update_progress(main.hotaru.global_position,_route_index)
	if beat >= Beat.EXTERIOR:
		var fire_visible: bool = not main.inside_rv and not main.inside_store and main.hotaru.global_position.distance_to(Vector3(-11,0,-43))<45
		main.home_fire.visible = fire_visible
		main.home_fire.process_mode = Node.PROCESS_MODE_INHERIT if fire_visible else Node.PROCESS_MODE_DISABLED
	if beat >= Beat.EXTERIOR and fire_audio.playing:
		var distance: float = main.hotaru.global_position.distance_to(Vector3(-11,0,-43))
		fire_audio.volume_db = -14-clampf(distance,0,50)*0.7

func _spawn_front_crowd() -> void:
	if not _front_zombies.is_empty(): return
	for i in range(CROWD.size()):
		var zombie = main.ZombieController.new()
		zombie.position = Vector3(CROWD[i].x,0.9,CROWD[i].y)
		zombie.rotation.y = -PI/2+sin(float(i))*0.5
		main.add_child(zombie)
		zombie.collision_layer = 5
		zombie.add_to_group("opening_zombies")
		zombie.set_target(main.hotaru)
		zombie.set_vehicle_target(main.rv)
		zombie.aggro_range=36.0
		zombie.pursuit_detour=PackedVector3Array([Vector3(-5.8,0.9,-35.3),Vector3(-17.5,0.9,-35.3)])
		zombie._animation_player.seek(float(i)*0.13,true)
		_front_zombies.append(zombie)

func _build_guides() -> void:
	if is_instance_valid(_trail):
		_trail.show()
		return
	_trail=EscapeTrail.new()
	main.world_root.add_child(_trail)
	var points: Array[Vector3]=[FRONT_EXIT]
	points.append_array(ROUTE)
	points[-1]=main.rv.get_disembark_position()
	_trail.build(points)
	_guides.append(_trail)

func apply_escape_hud() -> void:
	if beat != Beat.ESCAPE or main.phase==main.Phase.GAME_OVER: return
	main.objective_label.text = "前门被围住了 · 绕到后院的房车"
	main.attack_button.visible=not main.inside_rv and not main.in_vehicle and main.phase!=main.Phase.GAME_OVER
	main.hint_label.text = "沿地面金色虚线绕到后院 · 房车右侧门 E 上车"

func _exit_tree() -> void:
	if is_instance_valid(voice): voice.stop()
	if is_instance_valid(music): music.stop()
	if is_instance_valid(fire_audio): fire_audio.stop()
	var index := AudioServer.get_bus_index("OpeningDream")
	if index > 0: AudioServer.remove_bus(index)
