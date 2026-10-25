extends SceneTree
var failures:=0
func _initialize():call_deferred("run")
func check(ok: bool,message: String):
 if not ok:failures+=1;push_error(message)
func run():
 var state=root.get_node("GameState")
 state.suppress_save=true
 var m=load("res://scenes/main.tscn").instantiate()
 root.add_child(m)
 m._start_new_game()
 m._set_phase(m.Phase.EXPLORE)
 m.set_process(false)
 m.zombie_population.set_process(false)
 for zombie in get_nodes_in_group("zombies"):zombie.queue_free()
 var h=m.harbor
 h.set_physics_process(false)
 m.hotaru.global_position=h.crane.to_global(Vector3(4.1,.95,-2.3))
 h.enter()
 check(h.cab_transitioning and m.hotaru.visible and m.hotaru.get_animation_state()=="Climb","boarding visibly climbs")
 var initial: Vector3=h.crane.global_position
 h._physics_process(.1)
 check(h.crane.global_position==initial,"crane locked while climbing")
 await create_timer(2).timeout
 check(h.active and not h.cab_transitioning and not m.hotaru.visible,"boarding finishes at cab")
 # Desktop holding must survive real process frames, not just one manual tick.
 m.mobile_joystick.mobile=false
 h.raise_button.button_down.emit()
 var mouse_start: float=h.hoist_offset
 for frame in range(12):
  await process_frame
  h._physics_process(1.0/60.0)
 check(h._raise_held and h.hoist_offset>mouse_start+.25,"desktop long hold survives touch-router frames")
 h.raise_button.button_up.emit()
 mouse_start=h.hoist_offset
 await process_frame
 h._physics_process(.1)
 check(is_equal_approx(mouse_start,h.hoist_offset),"desktop release stops hoist")
 m.mobile_joystick.mobile=true
 h.controls.show()
 var e:=InputEventScreenTouch.new()
 e.index=8;e.position=h.raise_button.get_global_rect().get_center();e.pressed=true
 m.mobile_joystick._input(e)
 var before: float=h.hoist_offset
 h._physics_process(.1)
 check(h.hoist_offset>before and h.hoist_offset-before<.2,"touch hold moves continuously at bounded speed")
 e.pressed=false;m.mobile_joystick._input(e)
 before=h.hoist_offset;h._physics_process(.1)
 check(is_equal_approx(before,h.hoist_offset),"release immediately stops without discrete jump")
 e.pressed=true;m.mobile_joystick._input(e);m.mobile_joystick.reset()
 check(not h._raise_held,"pause/focus reset releases held hoist")
 var cargo: Dictionary=h.cargoes[0]
 h.crane.global_position=Vector3(cargo.node.global_position.x,.12,cargo.node.global_position.z-h.SPREADER_Z)
 h.hoist_offset=h.HOIST_MIN;h._update_spreader()
 h.toggle_cargo()
 check(not h.held.is_empty(),"grab aligned initial cargo")
 await physics_frame
 h._move_hoist(6)
 m.rv.global_position=Vector3(h.RV_LIFT_BAY.x,1.02,h.RV_LIFT_BAY.z)
 m.rv.rotation.y=PI/2
 h.crane.global_position=Vector3(h.RV_LIFT_BAY.x,.12,h.RV_LIFT_BAY.z-h.SPREADER_Z)
 h._update_held_cargo()
 await physics_frame
 await physics_frame
 h._move_hoist(-20)
 var roof: float=m.rv.global_position.y+h.ROOF_BOTTOM_LOCAL_Y
 check(cargo.node.global_position.y>=roof-.025 and cargo.node.global_position.y<roof+.12,"swept load stops on roof rather than entering RV")
 var contact: float=h.hoist_offset
 h._move_hoist(-1)
 check(absf(h.hoist_offset-contact)<.03,"continued lowering cannot penetrate roof")
 m.rv.rotation.y=PI/4
 h.toggle_cargo()
 check(not h.held.is_empty() and state.roof_container_id.is_empty(),"bad parking angle rejects placement")
 m.rv.rotation.y=PI/2
 m.rv.position.x+=1
 h.toggle_cargo()
 check(not h.held.is_empty(),"off-centre parking rejects placement")
 m.rv.position.x-=1
 h.crane.position.x+=9;h.hoist_offset=h.HOIST_MIN;h._update_held_cargo()
 await physics_frame
 check(h._load_safe_fraction(Vector3(-12,0,0))<.8,"low horizontal load blocked by RV side")
 h.hoist_offset=0;h.crane.position.x-=9;h._update_held_cargo()
 await physics_frame
 h._move_hoist(-20)
 m.rv.rotation.y=PI/2+deg_to_rad(4)
 h.toggle_cargo()
 check(h.held.is_empty() and cargo.on_rv,"small angular tolerance accepts correctly parked RV")
 h.exit_crane()
 check(h.cab_transitioning and m.hotaru.visible,"exit shows downward climb")
 await create_timer(2).timeout
 check(not h.active and m.hotaru.active,"exit restores walking")
 print("HARBOR_PRECISION errors=",failures)
 m.free()
 quit(failures)
