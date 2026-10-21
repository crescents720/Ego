extends SceneTree
func _initialize() -> void:call_deferred("run")
func baked(actor: Node3D,player: AnimationPlayer,clip: String,time: float) -> Array:
	player.play(clip,0)
	player.seek(time,true)
	player.pause()
	for skeleton in actor.find_children("*","Skeleton3D",true,false):skeleton.force_update_all_bone_transforms()
	await process_frame
	await RenderingServer.frame_post_draw
	var vertices: Array=[]
	for mesh in actor.find_children("*","MeshInstance3D",true,false):
		if mesh.skin==null:continue
		var baked_mesh: ArrayMesh=mesh.bake_mesh_from_current_skeleton_pose()
		for surface in range(baked_mesh.get_surface_count()):
			vertices.append_array(baked_mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX])
	return vertices
func run() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("Combat skin check needs graphical renderer")
		quit(1)
		return
	var hero=load("res://scripts/actors/hotaru.gd").new()
	root.add_child(hero)
	hero.set_physics_process(false)
	var zombie=load("res://scripts/actors/zombie.gd").new()
	root.add_child(zombie)
	zombie.set_physics_process(false)
	for test in [[hero,hero._animation_player,"Punch",0.24],[hero,hero._animation_player,"Hit",0.10],[zombie,zombie._animation_player,"Bite",0.44]]:
		var rest: Array=await baked(test[0],test[1],"Idle",0)
		var action: Array=await baked(test[0],test[1],test[2],test[3])
		var count:=0
		for i in range(rest.size()):
			if not action[i].is_finite():
				push_error("COMBAT_SKIN_FAIL: nonfinite vertex")
				quit(1)
				return
			if rest[i].distance_to(action[i])>0.02:count+=1
		if count<100:
			push_error("COMBAT_SKIN_FAIL: "+test[2]+" does not deform skin")
			quit(1)
			return
		print("SKIN_DEFORMATION: ",test[2]," moved ",count," vertices over 2cm")
	print("COMBAT_SKIN_PASS: actual skinned mesh deforms for Punch/Hit/Bite")
	quit()
