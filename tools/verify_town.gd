extends SceneTree
var main
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool,message: String) -> bool:
	if ok:return true
	push_error("TOWN_FAIL: "+message)
	quit(1)
	return false
func run() -> void:
	main=load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	root.get_node("GameState").suppress_save=true
	main._start_new_game()
	main.hotaru.set_active(false)
	# Asset-heavy scenes can give the population controller enough startup time
	# to place a zombie on the test route; this test is strictly about roads.
	main.zombie_population.set_process(false)
	for zombie in get_nodes_in_group("zombies"):zombie.queue_free()
	await physics_frame
	if not check(main.town_layout.lots.size()>=50,"too few ordinary buildings"):return
	for lot in main.town_layout.lots:
		if not check(lot.bounds.size.y<8,"building exceeds low-rise selection"):return
		for site in main.TownLayout.SITES:
			var footprint:=Rect2(Vector2(lot.bounds.position.x,lot.bounds.position.z),Vector2(lot.bounds.size.x,lot.bounds.size.z))
			if not check(not footprint.intersects(site.rect),"building occupies reserved site"):return
	# Drive the actual vehicle collider over every major street and the outer loop.
	main.rv.set_physics_process(false)
	main.rv.global_position=Vector3(-120,1.02,-100)
	var route: Array[Vector2]=[Vector2(-120,300),Vector2(150,300),Vector2(150,-100),Vector2(-120,-100),Vector2(0,-100),Vector2(0,300),Vector2(75,300),Vector2(75,-100),Vector2(75,0),Vector2(-120,0),Vector2(-120,100),Vector2(150,100),Vector2(150,200),Vector2(-120,200),Vector2(-60,200),Vector2(-60,-100)]
	for target in route:
		var start:=Vector2(main.rv.global_position.x,main.rv.global_position.z)
		var direction:=start.direction_to(target)
		main.rv.rotation.y=atan2(-direction.x,-direction.y)
		var steps:=int(ceil(start.distance_to(target)/0.8))
		for step in range(steps):
			await physics_frame
			var expected: Vector2=start.move_toward(target,(step+1)*0.8)
			main.rv.velocity=Vector3(direction.x,0,direction.y)*48
			main.rv.move_and_slide()
			if not check(Vector2(main.rv.global_position.x,main.rv.global_position.z).distance_to(expected)<1.0,"road collision approaching "+str(target)):return
			if not check(main.town_layout.is_road(expected),"disconnected road"):return
		main.rv.global_position=Vector3(target.x,1.02,target.y)
	# Boundary collider must keep the player and vehicle out of the lake.
	main.rv.global_position=Vector3(170,1.02,132)
	main.rv.rotation.y=-PI/2
	for frame in range(70):
		await physics_frame
		main.rv.velocity=Vector3(48,0,0)
		main.rv.move_and_slide()
	if not check(main.rv.global_position.x<185,"vehicle enters lake"):return
	# Parking elsewhere north of the old street must not mean reaching the store.
	main.controls_enabled=true
	main.phase=main.Phase.DRIVE_TO_STORE
	main.in_vehicle=true
	main.rv.global_position=Vector3(-120,1.02,150)
	main._toggle_vehicle()
	if not check(main.phase==main.Phase.DRIVE_TO_STORE,"remote parking triggers store arrival"):return
	print("TOWN_PASS: ",main.town_layout.lots.size()," low-rise buildings; reserved sites clear; vehicle collider traversed loop/all main streets; shore blocks water; arrival remains local")
	quit()
