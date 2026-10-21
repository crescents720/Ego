extends SceneTree
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> bool:
	if ok:return true
	push_error("COMBAT_FAIL: "+message)
	quit(1)
	return false
func run() -> void:
	var main=load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	root.get_node("GameState").suppress_save=true
	main._start_new_game()
	var hero=main.hotaru
	hero.set_physics_process(false)
	hero.global_position=Vector3(0,0.95,-7)
	for actor in get_nodes_in_group("zombies"):actor.queue_free()
	await physics_frame
	await physics_frame
	var zombie=main.ZombieController.new()
	main.add_child(zombie)
	zombie.set_physics_process(false)
	zombie.global_position=Vector3(0,0.9,-6.1)
	if not check(zombie._animations.has("Bite") and hero._animation_names.has("Punch") and hero._animation_names.has("Hit"),"combat clips imported"):return
	var defeats: Array[int]=[0]
	zombie.defeated.connect(func():defeats[0]+=1)
	hero.attack()
	if not check(zombie.health==10 and hero.get_animation_state()=="Punch","punch must wind up without instant damage"):return
	hero._tick_combat(0.23)
	if not check(zombie.health==10,"contact not reached"):return
	hero._tick_combat(0.02)
	if not check(zombie.health==9,"one hit at contact"):return
	hero._tick_combat(0.1)
	if not check(zombie.health==9,"contact cannot hit twice"):return
	hero._tick_combat(1)
	for i in range(8):
		hero._last_attack_ms=-10000
		hero.attack()
		hero._tick_combat(0.7)
	if not check(zombie.health==1 and not zombie._dying and defeats[0]==0,"nine punches must not kill"):return
	hero._last_attack_ms=-10000
	hero.attack()
	hero._tick_combat(0.7)
	if not check(zombie._dying and defeats[0]==1,"tenth punch kills exactly once"):return
	zombie=main.ZombieController.new()
	main.add_child(zombie)
	zombie.set_physics_process(false)
	zombie.global_position=Vector3(0,0.9,-6.1)
	zombie.set_target(hero)
	hero._last_attack_ms=-10000
	hero.attack()
	zombie.global_position.z=-3
	hero._tick_combat(0.7)
	if not check(zombie.health==10,"evading a punch must avoid damage"):return
	zombie.global_position.z=-6.1
	zombie._physics_process(0.01)
	if not check(zombie._animation_state=="Bite" and hero.health==5,"bite windup without immediate damage"):return
	zombie._tick_bite(0.43)
	if not check(hero.health==5,"bite before contact"):return
	zombie._tick_bite(0.02)
	if not check(hero.health==4 and hero.get_animation_state()=="Hit","bite contact triggers skeletal hit reaction"):return
	zombie._tick_bite(0.2)
	if not check(hero.health==4,"bite damage once per cycle"):return
	zombie._bite_elapsed=0
	zombie._bite_contact_done=false
	hero.global_position.z=-10
	zombie._tick_bite(0.45)
	if not check(hero.health==4,"evade bite during windup"):return
	for mesh in main.rv_interior._model.find_children("SOCKET_*_Plate","MeshInstance3D",true,false):
		if not check(not mesh.visible,"interior socket plates hidden"):return
	if not check(main.rv.get_node("OpaqueRoof").material_override.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED,"opaque RV roof"):return
	print("COMBAT_PASS: 10 connected punches; no early/double damage; misses evade; bite contact/Hit; socket plates hidden; opaque roof")
	await create_timer(0.7).timeout
	quit()
