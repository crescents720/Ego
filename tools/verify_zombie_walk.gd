extends SceneTree
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> bool:
	if ok:return true
	push_error("ZOMBIE_WALK_FAIL: "+message)
	quit(1)
	return false
func run() -> void:
	var stage:=Node3D.new()
	root.add_child(stage)
	var hero=load("res://scripts/actors/hotaru.gd").new()
	stage.add_child(hero)
	hero.position=Vector3(0,0.95,12)
	hero.set_active(true)
	hero.set_physics_process(false)
	var actor=load("res://scripts/actors/zombie.gd").new()
	stage.add_child(actor)
	actor.position=Vector3(0,0.9,0)
	actor.set_target(hero)
	for frame in range(70):await physics_frame
	if not check(actor.position.z>0.8 and actor._animation_state=="Walk","pursuit must play walk while moving"):return
	actor.set_physics_process(false)
	var skeleton: Skeleton3D=actor.find_children("*","Skeleton3D",true,false)[0]
	var samples: Dictionary={"Foot.L":[],"Foot.R":[]}
	for frame in range(24):
		actor._animation_player.play(actor._animations["Walk"],0)
		actor._animation_player.seek(float(frame)*.95/24,true)
		actor._animation_player.pause()
		skeleton.force_update_all_bone_transforms()
		await process_frame
		for name in samples:
			samples[name].append(skeleton.get_bone_global_pose(skeleton.find_bone(name)).origin)
	for name in samples:
		var z_min:=100.0
		var z_max:=-100.0
		var y_min:=100.0
		var y_max:=-100.0
		for p in samples[name]:
			z_min=minf(z_min,p.z);z_max=maxf(z_max,p.z)
			y_min=minf(y_min,p.y);y_max=maxf(y_max,p.y)
		if not check(z_max-z_min>.43 and y_max-y_min>.10,"insufficient stride/foot lift for "+name):return
		print("FOOT_TRAVEL: ",name," stride=",z_max-z_min," lift=",y_max-y_min)
	if not check(samples["Foot.L"][0].z<samples["Foot.R"][0].z and samples["Foot.L"][12].z>samples["Foot.R"][12].z,"legs must alternate"):return
	print("ZOMBIE_WALK_PASS: real pursuit uses Walk; both feet alternate ~48cm with visible lift")
	quit()
