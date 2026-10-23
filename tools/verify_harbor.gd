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
	check(harbor.cargoes.size()==8,"eight usable containers were built")
	check(harbor.crane.global_position.is_equal_approx(state.crane_position),"crane restored from state")

	main.hotaru.global_position=harbor.crane.to_global(Vector3(4.1,0.95,-2.3))
	check(harbor.nearby(),"cab entrance can be detected")
	harbor.enter()
	check(harbor.active and not main.hotaru.visible,"entering cab transfers control")

	var cargo: Dictionary=harbor.cargoes[0]
	var hook: Vector3=harbor.crane.to_global(Vector3(0,harbor.SPREADER_BOTTOM+harbor.hoist_offset,harbor.SPREADER_Z))
	cargo.node.global_position=hook-Vector3(0,float(cargo.height),0)
	harbor.toggle_cargo()
	check(not harbor.held.is_empty() and harbor.held.id==cargo.id,"aligned spreader locks a container")

	harbor.hoist_offset=-3.65
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
	check(not harbor.active and main.hotaru.visible,"operator can leave after releasing the load")
	harbor._record_state()
	check(bool(state.harbor_container_states[cargo.id].on_rv),"container state records roof placement")
	var save_path="user://harbor_verify.cfg"
	check(state.save_game(save_path)==OK,"harbor state saves through the normal save system")
	state.roof_container_id=""
	state.harbor_container_states={}
	check(state.load_completed_save(save_path),"harbor test save loads")
	harbor.reset()
	check(state.roof_container_id==cargo.id and bool(cargo.on_rv),"roof container restores from disk")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))

	if failures.is_empty():
		print("HARBOR_VERIFY_PASS: port, cab, pickup, hoist, RV roof placement, and disk persistence")
		quit()
	else:
		quit(1)
