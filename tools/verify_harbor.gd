extends SceneTree

var failures: Array[String]=[]


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool,message: String) -> void:
	if not condition:
		failures.append(message)
		push_error("HARBOR_VERIFY: "+message)


func run() -> void:
	var main=load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var state=root.get_node("GameState")
	state.suppress_save=true
	await process_frame
	await process_frame
	main._start_new_game()
	main._set_phase(main.Phase.EXPLORE)
	var harbor=main.harbor
	check(is_instance_valid(harbor),"harbor controller exists")
	check(is_instance_valid(main.world_root.get_node_or_null("SouthernContainerHarbor")),"harbor scene exists")
	check(harbor.cargoes.size()==26,"26 usable containers were built")
	check(harbor.crane.global_position.is_equal_approx(state.crane_position),"crane restored from state")

	main.hotaru.global_position=harbor.crane.to_global(Vector3(4.1,0.95,-2.3))
	check(harbor.nearby(),"cab entrance can be detected")
	harbor.enter()
	await create_timer(2.0).timeout
	check(harbor.active and not main.hotaru.visible,"entering cab transfers control")
	check(harbor.crane.get_collision_exceptions().has(main.hotaru),"hidden operator cannot block crane")

	var cargo: Dictionary=harbor.cargoes[0]
	harbor.crane.global_position=Vector3(cargo.node.global_position.x,.12,cargo.node.global_position.z-harbor.SPREADER_Z)
	harbor.hoist_offset=harbor.HOIST_MIN
	harbor._update_spreader()
	harbor.toggle_cargo()
	check(not harbor.held.is_empty() and harbor.held.id==cargo.id,"aligned spreader locks a container")

	harbor.hoist_offset=0.0
	harbor._update_held_cargo()
	harbor.crane.global_position=Vector3(harbor.RV_LIFT_BAY.x,.12,harbor.RV_LIFT_BAY.z-harbor.SPREADER_Z)
	harbor.hoist_offset=-3.26
	harbor._update_spreader()
	harbor._update_held_cargo()
	var bottom: Vector3=cargo.node.global_position
	main.rv.global_position=Vector3(bottom.x,1.02,bottom.z)
	main.rv.rotation.y=PI/2
	harbor.toggle_cargo()
	check(harbor.held.is_empty(),"lowered 20-foot container releases on RV")
	check(bool(cargo.on_rv),"container is marked as roof cargo")
	check(cargo.node.get_parent()==main.rv,"roof cargo follows the RV")
	check(state.roof_container_id==cargo.id,"roof placement is persisted in state")

	harbor.exit_crane()
	await create_timer(2.0).timeout
	check(not harbor.active and main.hotaru.visible,"operator can leave after releasing the load")
	harbor._record_state()
	check(bool(state.harbor_container_states[cargo.id].on_rv),"container state records roof placement")
	# Every initial row must be reachable without the crane base hitting the quay.
	for item in harbor.cargoes:
		var point: Vector3=item.position-Vector3(0,0,harbor.SPREADER_Z)
		check(harbor.CRANE_TRAVEL.has_point(Vector2(point.x,point.z)),"reachable cargo "+item.id)
	main.hotaru.global_position=Vector3(0,.95,-160)
	var start: Vector3=harbor.crane.global_position
	harbor.crane.global_position=Vector3(-140,.12,-223.23)
	await physics_frame
	await physics_frame
	var obstacle:=KinematicCollision3D.new()
	var blocked: bool=harbor.crane.test_move(harbor.crane.global_transform,Vector3(265,0,0),obstacle)
	if blocked:print("LANE_OBSTACLE ",obstacle.get_collider().get_path()," ",obstacle.get_position())
	check(not blocked,"full rear travel lane unobstructed")
	harbor.crane.global_position=start
	for offset in [harbor.HOIST_MIN,harbor.HOIST_MAX]:
		harbor.hoist_offset=offset
		harbor._update_spreader()
		var ropes:=0
		for rope in harbor.cable_root.get_children():
			if not rope.has_meta("hoist_rope"):continue
			ropes+=1
			check(is_equal_approx(rope.position.y+rope.scale.y*.5,25.0),"rope meets upper beam")
			check(is_equal_approx(rope.position.y-rope.scale.y*.5,8.95+offset),"rope meets moving spreader")
		check(ropes==4,"all four ropes follow hoist")
	main.hotaru.global_position=main.rv.global_position+Vector3(4,0,0)
	harbor.apply_hud()
	check(harbor.fix_button.visible,"fix action available near RV")
	main.mobile_joystick.mobile=true
	check(main.mobile_joystick._buttons().has(harbor.fix_button),"mobile touch router includes fix button")
	var touch:=InputEventScreenTouch.new()
	touch.index=7
	touch.position=harbor.fix_button.get_global_rect().get_center()
	touch.pressed=true
	main.mobile_joystick._input(touch)
	touch.pressed=false
	main.mobile_joystick._input(touch)
	check(state.roof_container_fixed and harbor.roof_support.visible and harbor.rv_ladder.visible,"touch fixes structure and unlocks ladder")
	main._enter_rv_interior(true)
	# Sweep the full route from the aisle, not just the final ladder landing.
	main.hotaru.global_position=main.rv_interior.to_global(Vector3(0,1.13,-3.35))
	await physics_frame
	for waypoint in [Vector3(-.30,1.13,-3.35),Vector3(-.30,1.13,-4.57)]:
		var destination: Vector3=main.rv_interior.to_global(waypoint)
		var step: Vector3=(destination-main.hotaru.global_position)/20.0
		for i in range(20):
			check(not main.hotaru.test_move(main.hotaru.global_transform,step),"aisle-to-ladder route remains unobstructed")
			main.hotaru.global_position+=step
	check(harbor.near_interior_ladder(),"walked route reaches ladder interaction")
	main.hotaru.global_position=main.rv_interior.to_global(Vector3(-.30,1.13,-4.57))
	await physics_frame
	await physics_frame
	check(not main.hotaru.test_move(main.hotaru.global_transform,Vector3(0,0,.05)),"ladder return point clear of seat")
	main.hotaru.global_position=main.rv_interior.get_driver_stand_position()
	check(not harbor.near_interior_ladder(),"ladder never steals driver stand interaction")
	main._interact()
	check(main.seated_at_driver,"driver E still seats Hotaru after upgrade")
	main._interact()
	main.hotaru.global_position=main.rv_interior.to_global(Vector3(-.30,1.13,-4.57))
	check(harbor.near_interior_ladder(),"ladder reachable from left window zone")
	main._update_camera(100)
	var lower_camera: Vector3=main.camera.global_position
	var lower_basis: Basis=main.camera.global_basis
	main._interact()
	check(harbor.roof_interior_active,"actual E interaction enters upper floor")
	check(harbor.roof_transitioning and not main.hotaru.active,"floor transition blocks movement")
	await create_timer(.8).timeout
	harbor.update_roof_camera(100)
	check(main.camera.global_position.is_equal_approx(lower_camera+Vector3.UP*harbor.ROOF_INTERIOR_ORIGIN.y),"floor camera translates vertically only")
	check(main.camera.global_basis.is_equal_approx(lower_basis),"floor camera retains orbit orientation")
	check(harbor.ROOF_HALF_LENGTH*2>8.7 and harbor.ROOF_HALF_WIDTH*2>2.6,"upper floor follows interior/exterior scale")
	check(not harbor._roof_ceiling.visible,"roof ceiling cut away")
	var old_yaw: float=main._interior_camera_yaw
	main._orbit_interior_camera(Vector2(400,0))
	harbor.update_roof_camera(100)
	var side_hidden: bool=not harbor._roof_walls.left.visible if main.camera.global_position.x<1000 else not harbor._roof_walls.right.visible
	check(side_hidden,"rotating upper floor hides camera-facing wall")
	main._interior_camera_yaw=old_yaw
	check(not main.can_save_safely(),"upper-floor transient player position cannot corrupt save")
	check(harbor.near_roof_hatch(),"arrival can return through hatch")
	await physics_frame
	var space=main.hotaru.get_world_3d().direct_space_state
	var hole: Vector3=harbor.ROOF_INTERIOR_ORIGIN+Vector3(harbor.ROOF_HATCH_ANCHOR.x,0,harbor.ROOF_HATCH_ANCHOR.z)
	var floor_point: Vector3=harbor.ROOF_INTERIOR_ORIGIN+Vector3(.5,0,harbor.ROOF_HATCH_ANCHOR.z)
	check(space.intersect_ray(PhysicsRayQueryParameters3D.create(hole+Vector3.UP*.3,hole-Vector3.UP*.3,3)).is_empty(),"hatch is a real floor opening")
	check(not space.intersect_ray(PhysicsRayQueryParameters3D.create(floor_point+Vector3.UP*.3,floor_point-Vector3.UP*.3,3)).is_empty(),"floor beside hatch remains solid")
	main._interact()
	await create_timer(.8).timeout
	check(not harbor.roof_interior_active and main.rv_interior.visible,"actual E interaction returns to cabin")
	check(main.camera.global_position.distance_to(main.rv_interior.global_position)<30,"return camera restored immediately")
	main._exit_rv_interior()
	var save_path="user://harbor_verify.cfg"
	check(state.save_game(save_path)==OK,"harbor state saves through the normal save system")
	state.roof_container_id=""
	state.roof_container_fixed=false
	state.harbor_container_states={}
	check(state.load_completed_save(save_path),"harbor test save loads")
	harbor.reset()
	check(state.roof_container_id==cargo.id and bool(cargo.on_rv) and state.roof_container_fixed and harbor.rv_ladder.visible,"fixed roof container and ladder restore from disk")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	check(harbor._has_cargo_above(harbor.cargoes[11]),"stacked lower container cannot be pulled out")
	check(not harbor._has_cargo_above(harbor.cargoes[14]),"top container remains available")
	main._start_new_game()
	harbor.reset()
	check(not harbor.rv_ladder.visible and not harbor.roof_support.visible,"new game removes upgrade visuals")

	main.free()
	await process_frame
	if failures.is_empty():
		print("HARBOR_VERIFY_PASS: port, cab, pickup, hoist, RV roof placement, and disk persistence")
		quit()
	else:
		quit(1)
