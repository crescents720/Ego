extends Control

const MIN_FACTOR := 0.60
const MAX_FACTOR := 2.40
const STEP := 1.16
var main
var target_factor := 1.0
var current_factor := 1.0
var closer_button: Button
var farther_button: Button
var _touches: Dictionary = {}

func setup(owner_main: Node3D) -> void:
	main=owner_main
	hide()
	name="OutdoorCameraZoom"
	position=Vector2(470,482)
	size=Vector2(232,80)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	var title:=Label.new()
	title.text="画面缩放"
	title.size=Vector2(232,26)
	title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size",18)
	title.add_theme_color_override("font_color",Color("fff1c5"))
	title.add_theme_color_override("font_outline_color",Color("172124"))
	title.add_theme_constant_override("outline_size",5)
	title.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(title)
	closer_button=_button("拉近 +",Vector2(0,30),func(): change_zoom(1.0/STEP))
	farther_button=_button("拉远 −",Vector2(120,30),func(): change_zoom(STEP))
	_update_buttons()

func _button(text_value: String,point: Vector2,callback: Callable) -> Button:
	var button:=Button.new()
	button.text=text_value
	button.position=point
	button.size=Vector2(112,46)
	button.focus_mode=Control.FOCUS_NONE
	main._style_button(button,Color("30464ae8"))
	button.add_theme_font_size_override("font_size",20)
	button.pressed.connect(callback)
	add_child(button)
	return button

func can_zoom() -> bool:
	if is_instance_valid(main) and is_instance_valid(main.factory) and main.factory.active:return false
	return is_instance_valid(main) and main.controls_enabled and not main.inside_rv and not main.inside_store and not main.dialog_panel.visible and (not is_instance_valid(main.opening) or not main.opening.is_cinematic())

func _process(delta: float) -> void:
	visible=false
	if not can_zoom():_touches.clear()
	current_factor=lerpf(current_factor,target_factor,1.0-exp(-delta*14.0))
	_update_buttons()

func _update_buttons() -> void:
	closer_button.disabled=target_factor<=MIN_FACTOR+0.001
	farther_button.disabled=target_factor>=MAX_FACTOR-0.001

func change_zoom(multiplier: float) -> void:
	if not can_zoom():return
	target_factor=clampf(target_factor*multiplier,MIN_FACTOR,MAX_FACTOR)
	_update_buttons()

func _input(event: InputEvent) -> void:
	# Releases can land on a HUD button; clear them before GUI consumption.
	if event is InputEventScreenTouch and not event.pressed:
		_touches.erase(event.index)

func handle_world_input(event: InputEvent) -> bool:
	if not can_zoom():return false
	if event is InputEventMouseButton and event.pressed:
		if event.button_index==MOUSE_BUTTON_WHEEL_UP:
			change_zoom(1.0/STEP)
			return true
		if event.button_index==MOUSE_BUTTON_WHEEL_DOWN:
			change_zoom(STEP)
			return true
	elif event is InputEventMagnifyGesture:
		if event.factor>0:change_zoom(1.0/event.factor)
		return true
	elif event is InputEventScreenTouch:
		if event.pressed:_touches[event.index]=event.position
		else:_touches.erase(event.index)
	elif event is InputEventScreenDrag and _touches.has(event.index):
		var previous: Vector2=_touches[event.index]
		_touches[event.index]=event.position
		if _touches.size()==2:
			for index in _touches:
				if index==event.index:continue
				var other: Vector2=_touches[index]
				var before:=previous.distance_to(other)
				var after: float=event.position.distance_to(other)
				if before>12 and after>12:change_zoom(before/after)
				return true
	return false
