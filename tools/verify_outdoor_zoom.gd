extends SceneTree
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> bool:
	if ok:return true
	push_error("OUTDOOR_ZOOM_FAIL: "+message)
	quit(1)
	return false
func run() -> void:
	var main=load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	root.get_node("GameState").suppress_save=true
	main._start_new_game()
	var zoom=main.outdoor_zoom
	zoom._process(1)
	var map_index: int=main.minimap.zoom_index
	var wheel:=InputEventMouseButton.new()
	wheel.button_index=MOUSE_BUTTON_WHEEL_UP
	wheel.pressed=true
	main._unhandled_input(wheel)
	zoom._process(1)
	main._update_camera(1)
	if not check(main.camera.size<15 and main.minimap.zoom_index==map_index,"world wheel zooms main camera only"):return
	var factor: float=zoom.target_factor
	main.minimap.map_canvas._gui_input(wheel)
	if not check(is_equal_approx(factor,zoom.target_factor),"minimap wheel must not change main camera"):return
	zoom.farther_button.pressed.emit()
	if not check(zoom.target_factor>factor,"screen farther button"):return
	zoom.closer_button.pressed.emit()
	if not check(is_equal_approx(factor,zoom.target_factor),"screen closer button"):return
	zoom.target_factor=1
	for i in [0,1]:
		var touch:=InputEventScreenTouch.new()
		touch.index=i
		touch.pressed=true
		touch.position=Vector2(100+i*100,500)
		main._unhandled_input(touch)
	var drag:=InputEventScreenDrag.new()
	drag.index=1
	drag.position=Vector2(250,500)
	main._unhandled_input(drag)
	if not check(is_equal_approx(zoom.target_factor,2.0/3.0),"two-finger spread zooms in"):return
	var release:=InputEventScreenTouch.new()
	release.index=1
	release.pressed=false
	zoom._input(release)
	if not check(zoom._touches.size()==1,"release over HUD clears gesture"):return
	for i in range(30):zoom.change_zoom(0.5)
	if not check(is_equal_approx(zoom.target_factor,zoom.MIN_FACTOR) and zoom.closer_button.disabled,"near clamp"):return
	for i in range(30):zoom.change_zoom(2)
	if not check(is_equal_approx(zoom.target_factor,zoom.MAX_FACTOR) and zoom.farther_button.disabled,"far clamp"):return
	zoom.target_factor=1.5
	zoom._process(2)
	main.in_vehicle=true
	main._update_camera(1)
	if not check(absf(main.camera.size-30.0)<0.01,"zoom persists when driving"):return
	main.in_vehicle=false
	main.inside_store=true
	main._update_camera(1)
	zoom.change_zoom(0.5)
	zoom._process(1)
	if not check(not zoom.visible and is_equal_approx(zoom.target_factor,1.5) and is_equal_approx(main.camera.size,10.8),"store remains fixed"):return
	main.inside_store=false
	main.inside_rv=true
	var before: float=main._interior_camera_distance
	main._unhandled_input(wheel)
	if not check(main._interior_camera_distance<before and is_equal_approx(zoom.target_factor,1.5),"RV keeps existing orbit zoom"):return
	main.inside_rv=false
	main.controls_enabled=false
	if not check(not zoom.can_zoom(),"cinematic/dialog controls lock"):return
	print("OUTDOOR_ZOOM_PASS: world wheel/buttons/pinch; zoom limits; walking/driving; minimap independent; store/RV preserved")
	quit()

