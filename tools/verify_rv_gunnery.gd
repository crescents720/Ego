extends SceneTree
var errors:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
 if not ok:errors+=1;push_error(message)
func touch(index: int,p: Vector2,pressed: bool) -> void:
 var e:=InputEventScreenTouch.new()
 e.index=index;e.position=p;e.pressed=pressed
 Input.parse_input_event(e);Input.flush_buffered_events()
func run() -> void:
 root.size=Vector2i(720,1280)
 var m=load("res://scenes/main.tscn").instantiate()
 root.add_child(m)
 var s=root.get_node("GameState")
 s.suppress_save=true
 m._start_new_game()
 m.set_process(false)
 m.zombie_population.set_process(false)
 for z in get_nodes_in_group("zombies"):z.queue_free()
 await physics_frame
 m._set_phase(m.Phase.EXPLORE)
 m.rv.position=Vector3(0,1.02,200)
 m.rv.rotation.y=0
 m.hotaru.position=m.rv.get_disembark_position()
 m._enter_rv_interior()
 var g=m.shooting
 g.set_process(false)
 check(m.rv_interior.get_node_or_null("DinetteFront")==null,"Right seat collision still blocks window")
 check(not m.rv_interior._model.find_child("GalleyOverhead_A_Body",true,false).visible,"Left overhead cabinet not removed")
 m.hotaru.position=m.RV_INTERIOR_ORIGIN+Vector3(.87,1.13,.91)
 m._interact()
 check(not g.active,"Missing M60 can be used")
 check(not m.rv_interior._model.find_child("RouteMapBoard",true,false).visible,"Route map board still blocks left window")
 s.cargo={"m60":1,"m60_ammo":500}
 m._interact()
 check(g.active and m.inside_rv and m.rv.occupied and s.m60_window=="right","Window interaction did not mount gun")
 check(g.gun.is_visible_in_tree(),"Active firing proxy gun is hidden")
 for mounted_side in [-1,1]:
  check(not g.mounted[mounted_side].is_visible_in_tree() and not g.exterior_mounted[mounted_side].is_visible_in_tree(),"Mounted M60 has overlapping cabin/exterior duplicate in firing view")
 for angle in [-.7,0.0,.7]:
  g.yaw=angle;g.update_camera(0)
  check(m.camera.unproject_position(g.proxy.global_position+Vector3.UP*1.52).x<300,"Shoulder camera blocks crosshair")
 g.yaw=0;g.update_camera(0)
 check(not m.can_save_safely(),"Can save during firing mode")
 check(not s.move_stack("m60","cargo","trash",1),"Mounted weapon could be discarded")
 var z=m.ZombieController.new()
 m.add_child(z)
 z.position=Vector3(18,.95,201.45)
 z.set_physics_process(false)
 await physics_frame
 m.camera.look_at(z.global_position)
 g.cooldown=0
 check(g.fire_round() and z.health==5 and s.cargo.m60_ammo==499,"First shot did not deal 5 / consume one round")
 check(not g.fire_round() and s.cargo.m60_ammo==499,"Cooldown allowed duplicate shot")
 g.cooldown=0
 check(g.fire_round() and z._dying and s.cargo.m60_ammo==498,"Two shots did not kill")
 check(s.cash_drops.size()==1,"Rifle kill did not drop cash")
 # Hard range boundary: an unobstructed target at 101m remains unharmed.
 var far=m.ZombieController.new()
 m.add_child(far)
 far.position=Vector3(g.muzzle().x+101,.95,g.muzzle().z)
 far.set_physics_process(false)
 await physics_frame
 m.camera.look_at(far.global_position)
 g.cooldown=0;g.fire_round()
 check(far.health==10,"Shot exceeded 100m range")
 far.position.x=g.muzzle().x+95
 await physics_frame
 m.camera.look_at(far.global_position)
 g.cooldown=0;g.fire_round()
 check(far.health==5,"Target inside 100m not hit")
 # Both aiming and muzzle rays obey world cover.
 var wall:=StaticBody3D.new()
 wall.collision_layer=1
 var col:=CollisionShape3D.new()
 var box:=BoxShape3D.new();box.size=Vector3(1,4,4);col.shape=box
 wall.add_child(col);m.add_child(wall)
 wall.position=Vector3(10,1.5,201.45)
 far.position=Vector3(20,.95,201.45)
 await physics_frame
 m.camera.look_at(far.global_position)
 g.cooldown=0;g.fire_round()
 check(far.health==5,"Bullet penetrated solid wall")
 wall.queue_free();far.queue_free()
 # Independent fingers for held fire and aiming; pause clears held input.
 m.mobile_joystick.setup(m,true)
 touch(0,g.fire_button.get_global_rect().get_center(),true)
 touch(1,Vector2(530,600),true)
 var drag:=InputEventScreenDrag.new()
 drag.index=1;drag.position=Vector2(570,620);drag.relative=Vector2(40,20)
 Input.parse_input_event(drag);Input.flush_buffered_events()
 check(g.firing and g.fire_finger==0 and g.aim_finger==1 and absf(g.yaw)>.01,"Touch aim/fire is not independent")
 touch(0,g.fire_button.get_global_rect().get_center(),false)
 check(not g.firing and g.aim_finger==1,"Releasing fire cancels aiming or sticks")
 touch(1,Vector2(570,620),false)
 touch(0,g.fire_button.get_global_rect().get_center(),true)
 m.test_settings.open()
 var ammo: int=s.cargo.m60_ammo
 g._process(.2)
 check(not g.firing and not g.fire_round() and s.cargo.m60_ammo==ammo,"Pause allowed firing/stuck fire")
 m.test_settings.close()
 s.cargo.erase("m60_ammo")
 g.cooldown=0
 check(not g.fire_round(),"Empty gun fired")
 g.stop()
 g._process(0)
 check(g.mounted[1].is_visible_in_tree() and not g.mounted[-1].is_visible_in_tree(),"Cabin gun does not match mounted side")
 check(not g.gun.is_visible_in_tree() and not g.exterior_mounted[1].is_visible_in_tree(),"Cabin view renders a second overlapping M60")
 m.rv_dashboard.open()
 m.rv_dashboard.status.text=s.ITEMS.m60.description
 for i in range(4):await process_frame
 var panel_rect: Rect2=m.rv_dashboard.panel.get_global_rect()
 check(panel_rect.position.x>=0 and panel_rect.end.x<=720 and panel_rect.end.y<=1280,"Long item description overflows dashboard")
 m.rv_dashboard.close()
 check(m.inside_rv and m.hotaru.visible and m.hotaru.active and not m.world_root.visible,"Exit did not restore interior")
 check(is_equal_approx(m.camera.fov,52) and is_equal_approx(m.camera.near,.15),"Camera did not restore lens")
 s.cargo.m60_ammo=25
 m.hotaru.position=m.RV_INTERIOR_ORIGIN+Vector3(-.55,1.13,1.12)
 m._interact()
 check(g.active and g.side==-1 and s.m60_window=="left" and s.cargo.m60==1,"Moving to left window duplicated/lost gun")
 g.stop()
 check(s.save_game("user://gunnery_test/slot.cfg")==OK,"Mount save failed")
 s.m60_window=""
 check(s.load_completed_save("user://gunnery_test/slot.cfg") and s.m60_window=="left" and s.cargo.m60_ammo==25,"Mounted side/ammo save lost")
 # Outside attackers continue damaging the occupied RV in BOTH interior views.
 var biter=m.ZombieController.new()
 m.add_child(biter)
 biter.position=m.rv.to_global(Vector3(-1.9,-.07,0))
 biter.set_target(m.hotaru);biter.set_vehicle_target(m.rv);biter.set_physics_process(false)
 await physics_frame
 check(biter._choose_target()==m.rv,"Indoor heroine does not attract attacks to RV")
 var hp: int=m.rv.health
 biter._last_attack_ms=-10000;biter._bite_elapsed=-1
 biter._physics_process(.01);biter._physics_process(.61)
 check(m.rv.health<hp,"Outside attackers stopped during ordinary interior view")
 g.start(-1)
 hp=m.rv.health
 biter._last_attack_ms=-10000;biter._bite_elapsed=-1
 biter._physics_process(.01);biter._physics_process(.61)
 check(m.rv.health<hp and m.hotaru.health==m.hotaru.max_health,"Firing mode stopped RV damage or exposed heroine")
 var time: float=s.world_seconds
 m._process(.2)
 check(s.world_seconds>time,"Shooting paused survival world time")
 m.rv.take_damage(10000)
 check(not g.active and m.phase==m.Phase.GAME_OVER and m.hotaru.health==0,"Destroyed occupied RV did not stop shooting / kill occupant")
 print("RV_GUNNERY_CHECK errors=",errors)
 root.get_node("AudioDirector").stop_all()
 m.queue_free()
 await create_timer(.15).timeout
 quit(1 if errors else 0)
