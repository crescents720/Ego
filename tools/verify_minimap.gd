extends SceneTree
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> bool:
 if ok:return true
 push_error("MINIMAP_FAIL: "+message)
 quit(1)
 return false
func run() -> void:
 var main=load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 root.get_node("GameState").suppress_save=true
 var map=main.minimap
 if not check(not map.visible,"title hidden"):return
 main._start_new_game()
 main._update_camera(100)
 map.sync_state()
 if not check(map.visible and map.zoom_in_button==null and map.zoom_out_button==null,"compact fixed map, no zoom controls"):return
 if not check(not main.outdoor_zoom.visible,"world zoom buttons hidden"):return
 var origin: Vector3=main.hotaru.global_position
 for direction in [Vector3.RIGHT,Vector3.LEFT,Vector3.BACK,Vector3.FORWARD,main.camera.global_basis.x]:
  var a: Vector2=main.camera.unproject_position(origin)
  var b: Vector2=main.camera.unproject_position(origin+direction)
  var map_delta: Vector2=map.map_direction(Vector2(direction.x,direction.z))
  if not check(map_delta.normalized().dot((b-a).normalized())>.999,"map must match actual camera projection for "+str(direction)):return
 main.set_process(false)
 main.hotaru.global_position=Vector3(0,.95,30)
 main._update_camera(100)
 var before: Vector3=main.hotaru.global_position
 Input.action_press("move_right")
 for frame in range(10):await physics_frame
 Input.action_release("move_right")
 var delta: Vector3=main.hotaru.global_position-before
 var map_delta: Vector2=map.map_direction(Vector2(delta.x,delta.z))
 if not check(map_delta.x>0.1 and absf(map_delta.y)<0.01,"walking screen-right moves map-right"):return
 main.in_vehicle=true
 main.rv.rotation.y=atan2(-main.camera.global_basis.x.x,-main.camera.global_basis.x.z)
 main._update_camera(100)
 map.sync_state()
 if not check(map.heading.x>.99 and absf(map.heading.y)<.01,"driving arrow matches screen-right"):return
 if not check(map.map_point(map.center_world).is_equal_approx(Vector2(108,108)),"marker centered"):return
 main.in_vehicle=false
 main.inside_rv=true
 map.sync_state()
 if not check(not map.visible,"interior map hidden"):return
 print("MINIMAP_PASS: camera projection in all directions, actual rightward walk, driving heading, centered marker, no zoom UI, indoor hiding")
 quit()
