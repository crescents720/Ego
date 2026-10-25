extends Control

# Flat drawing from the live town layout avoids rendering a second 3D scene.
const SPANS := [80.0,140.0,240.0,420.0,700.0,1200.0]
const MAP_SIZE := 216.0
var main
var zoom_index := 2
var center_world := Vector2.ZERO
var heading := Vector2.UP
var zoom_in_button: Button
var zoom_out_button: Button
var scale_label: Label
var title_label: Label
var map_canvas: Control
var _redraw_elapsed := 0.0

class MapCanvas extends Control:
	var minimap
	func _draw() -> void:
		minimap.draw_map(self)
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:accept_event()

func setup(owner_main: Node3D) -> void:
	main=owner_main
	name="OutdoorMinimap"
	position=Vector2(470,26)
	size=Vector2(232,260)
	mouse_filter=Control.MOUSE_FILTER_STOP
	var panel:=Panel.new()
	panel.size=size
	panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var style:=StyleBoxFlat.new()
	style.bg_color=Color("111d23ed")
	style.border_color=Color("829b96")
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel",style)
	add_child(panel)
	title_label=_label(Vector2(10,5),Vector2(212,26),17)
	map_canvas=MapCanvas.new()
	map_canvas.minimap=self
	map_canvas.position=Vector2(8,36)
	map_canvas.size=Vector2(MAP_SIZE,MAP_SIZE)
	map_canvas.clip_contents=true
	map_canvas.mouse_filter=Control.MOUSE_FILTER_STOP
	add_child(map_canvas)

	sync_state()
	_update_zoom()

func _label(point: Vector2,dimensions: Vector2,font_size: int) -> Label:
	var label:=Label.new()
	label.position=point
	label.size=dimensions
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",Color("e4e8d7"))
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label

func _button(text_value: String,point: Vector2,callback: Callable) -> Button:
	var button:=Button.new()
	button.text=text_value
	button.position=point
	button.size=Vector2(56,44)
	button.focus_mode=Control.FOCUS_NONE
	main._style_button(button,Color("30464a"))
	button.pressed.connect(callback)
	add_child(button)
	return button

func zoom_in() -> void:
	zoom_index=maxi(0,zoom_index-1)
	_update_zoom()

func zoom_out() -> void:
	zoom_index=mini(SPANS.size()-1,zoom_index+1)
	_update_zoom()

func _update_zoom() -> void:

	map_canvas.queue_redraw()

func _process(delta: float) -> void:
	sync_state()
	if not visible:return
	_redraw_elapsed+=delta
	if _redraw_elapsed>=0.08:
		_redraw_elapsed=0
		map_canvas.queue_redraw()

func sync_state() -> void:
	if not is_instance_valid(main):return
	visible=not (is_instance_valid(main.hospital) and main.hospital.active) and not (is_instance_valid(main.factory) and main.factory.active) and not main.inside_rv and not main.inside_store and main.phase not in [main.Phase.TITLE,main.Phase.GAME_OVER] and not main.dialog_panel.visible
	if is_instance_valid(main.opening) and main.opening.is_cinematic():visible=false
	var target: Node3D=main.harbor.crane if is_instance_valid(main.harbor) and main.harbor.active else (main.rv if main.in_vehicle else main.hotaru)
	center_world=Vector2(target.global_position.x,target.global_position.z)
	var forward: Vector3=-target.global_transform.basis.z if main.in_vehicle else target.global_transform.basis.z
	heading=map_direction(Vector2(forward.x,forward.z)).normalized()
	title_label.text=("医院园区 · " if is_instance_valid(main.hospital) and main.hospital.in_campus else "小镇 · ")+("吊装" if is_instance_valid(main.harbor) and main.harbor.active else ("驾驶" if main.in_vehicle else "步行"))

func map_point(world: Vector2) -> Vector2:
	var offset:=world-center_world
	return Vector2(MAP_SIZE/2,MAP_SIZE/2)+map_direction(offset)*(MAP_SIZE/SPANS[zoom_index])

func map_direction(offset: Vector2) -> Vector2:
	if is_instance_valid(main.hospital) and main.hospital.in_campus:return offset
	var direction:=Vector3(offset.x,0,offset.y)
	return Vector2(direction.dot(main.camera.global_basis.x),-direction.dot(main.camera.global_basis.y))

func _map_polygon(world_rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([map_point(world_rect.position),map_point(Vector2(world_rect.end.x,world_rect.position.y)),map_point(world_rect.end),map_point(Vector2(world_rect.position.x,world_rect.end.y))])

func _inside(point: Vector2,margin: float=8) -> bool:
	return Rect2(Vector2.ONE*margin,Vector2.ONE*(MAP_SIZE-2*margin)).has_point(point)

func _poi(canvas: Control,world: Vector2,text_value: String,color: Color,filled: bool=true) -> void:
	var point:=map_point(world)
	if not _inside(point):return
	canvas.draw_circle(point,4.5,color,filled,-1.0 if filled else 1.5,true)
	if SPANS[zoom_index]<=420 or text_value in ["家","店"]:
		var font:=ThemeDB.fallback_font
		var label_width:=font.get_string_size(text_value,HORIZONTAL_ALIGNMENT_LEFT,-1,13).x
		var origin:=Vector2(clampf(point.x-label_width/2,2,MAP_SIZE-label_width-2),clampf(point.y+18,14,MAP_SIZE-3))
		canvas.draw_string(font,origin,text_value,HORIZONTAL_ALIGNMENT_LEFT,-1,13,color)

func draw_map(canvas: Control) -> void:
	canvas.draw_rect(Rect2(Vector2.ZERO,Vector2.ONE*MAP_SIZE),Color("384a3d"))
	var scale_value: float=MAP_SIZE/SPANS[zoom_index]
	var lake:=PackedVector2Array()
	for point in main.TownLayout.LAKE:lake.append(map_point(point))
	canvas.draw_colored_polygon(lake,Color("397c8a"))
	for site in main.TownLayout.SITES:
		canvas.draw_colored_polygon(_map_polygon(site.rect),Color("617166"))
	for lot in main.town_layout.lots:
		var bounds: AABB=lot.bounds
		canvas.draw_colored_polygon(_map_polygon(Rect2(Vector2(bounds.position.x,bounds.position.z),Vector2(bounds.size.x,bounds.size.z))),Color("929182"))
	for road in main.town_layout.roads:
		canvas.draw_line(map_point(road.a),map_point(road.b),Color("b5b9a7"),maxf(1.6,road.width*scale_value),true)
	canvas.draw_colored_polygon(_map_polygon(Rect2(-14.3,-47.6,6.6,9.2)),Color("d3b783"))
	canvas.draw_colored_polygon(_map_polygon(Rect2(7.9,46.9,7.4,8.1)),Color("91c4ba"))
	var names: Array[String]=["五金","工厂","医院","警局","武器","油站","取水","钓点","营地","修车","港口","寺庙"]
	for i in range(main.TownLayout.SITES.size()):
		_poi(canvas,main.TownLayout.SITES[i].rect.get_center(),names[i],Color("b5c6b0"),false)
	_poi(canvas,Vector2(-11,-43),"家",Color("f1ce8a"))
	_poi(canvas,Vector2(11.6,51),"店",Color("8ee4d0"))
	if not main.in_vehicle:
		var rv_point:=map_point(Vector2(main.rv.global_position.x,main.rv.global_position.z))
		if _inside(rv_point):
			canvas.draw_rect(Rect2(rv_point-Vector2(3,5),Vector2(6,10)),Color("8fcbe9"))
	if is_instance_valid(main.supply_quest) and GameState.tutorial_step in [1,2,3]:
		var path: PackedVector2Array=main.supply_quest.route()
		for i in range(1,path.size()):
			var a:=map_point(path[i-1])
			var b:=map_point(path[i])
			var length:=a.distance_to(b)
			var direction: Vector2=(b-a).normalized()
			for d in range(0,int(length),7):canvas.draw_line(a+direction*d,a+direction*minf(d+4,length),Color("f4cd72"),2,true)
		var destination: Vector3=main.supply_quest.target()
		var mark:=map_point(Vector2(destination.x,destination.z))
		mark=mark.clamp(Vector2(12,12),Vector2(MAP_SIZE-12,MAP_SIZE-12))
		canvas.draw_arc(mark,8+sin(Time.get_ticks_msec()*0.004)*1.5,0,TAU,24,Color("ffe5a0"),2,true)
		canvas.draw_string(ThemeDB.fallback_font,mark+Vector2(10,-8),"返回" if GameState.tutorial_step==3 else "补给",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("ffe5a0"))
	var middle:=Vector2.ONE*MAP_SIZE/2
	canvas.draw_circle(middle,9,Color("142b2ce0"))
	var right:=Vector2(-heading.y,heading.x)
	canvas.draw_colored_polygon(PackedVector2Array([middle+heading*9,middle-heading*6+right*5,middle-heading*3,middle-heading*6-right*5]),Color("ffe39a"))
	var north:=map_direction(Vector2(0,1)).normalized()
	canvas.draw_line(Vector2(20,27),Vector2(20,27)+north*12,Color("f1efda"),2,true)
	canvas.draw_string(ThemeDB.fallback_font,Vector2(8,16),"N",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("f1efda"))
	canvas.draw_rect(Rect2(Vector2.ONE,Vector2.ONE*(MAP_SIZE-2)),Color("78958b"),false,1)
