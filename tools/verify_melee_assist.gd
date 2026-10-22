extends SceneTree

var errors:=0
var state
var arena: Node3D
var hero

func _initialize() -> void:call_deferred("run")

func check(ok: bool,message: String) -> void:
 if not ok:
  errors+=1
  push_error("MELEE_ASSIST_FAIL: "+message)

func point_at(angle_degrees: float,distance: float,height: float=.9) -> Vector3:
 var angle:=deg_to_rad(angle_degrees)
 return Vector3(sin(angle)*distance,height,cos(angle)*distance)

func spawn_zombie(angle_degrees: float,distance: float):
 var zombie=load("res://scripts/actors/zombie.gd").new()
 arena.add_child(zombie)
 zombie.global_position=point_at(angle_degrees,distance)
 zombie.health=100
 zombie.set_physics_process(false)
 return zombie

func reset_hero() -> void:
 hero._combat_action=""
 hero._combat_elapsed=0
 hero._punch_target=null
 hero._last_attack_ms=-10000
 hero.rotation.y=0

func discard(node: Node) -> void:
 if is_instance_valid(node):node.free()

func run() -> void:
 state=root.get_node("GameState")
 state.suppress_save=true
 state.start_new_run()
 arena=Node3D.new()
 root.add_child(arena)
 hero=load("res://scripts/actors/hotaru.gd").new()
 arena.add_child(hero)
 hero.global_position=Vector3(0,.95,0)
 hero.set_active(true)
 hero.set_physics_process(false)
 state.items={"bat":1}
 check(state.equip_item("bat","right_hand"),"could not equip bat")
 await physics_frame

 # A target near the widened fan edge is acquired, but each correction remains
 # visibly limited: 25 degrees at windup and another 10 at contact.
 var zombie=spawn_zombie(70,2.0)
 await physics_frame
 hero.attack()
 check(hero._punch_target==zombie,"70-degree target inside fan was not acquired")
 check(absf(rad_to_deg(hero.rotation.y)-25.0)<.05,"initial aim assist exceeded or missed 25-degree cap")
 hero._tick_combat(.39)
 check(zombie.health==100,"bat damaged before contact")
 hero._tick_combat(.02)
 check(zombie.health==98,"bat did not hit target inside widened fan")
 check(absf(rad_to_deg(hero.rotation.y)-35.0)<.06,"contact correction exceeded or missed 10-degree cap")
 discard(zombie)

 # Targets outside the 75-degree half-angle and directly behind must never
 # rotate Hotaru or receive the hit.
 reset_hero()
 zombie=spawn_zombie(80,2.0)
 await physics_frame
 hero.attack();hero._tick_combat(.41)
 check(hero._punch_target==null and zombie.health==100,"80-degree target leaked into melee fan")
 check(absf(hero.rotation.y)<.0001,"out-of-fan target rotated Hotaru")
 discard(zombie)
 reset_hero()
 zombie=spawn_zombie(180,1.0)
 await physics_frame
 hero.attack();hero._tick_combat(.41)
 check(hero._punch_target==null and zombie.health==100,"rear target was auto-aimed or hit")
 discard(zombie)

 # Bat and odachi range boundaries remain slightly forgiving but finite.
 reset_hero()
 zombie=spawn_zombie(0,2.19)
 await physics_frame
 hero.attack();hero._tick_combat(.41)
 check(zombie.health==98,"bat failed just inside 2.20m range")
 discard(zombie)
 reset_hero()
 zombie=spawn_zombie(0,2.21)
 await physics_frame
 hero.attack();hero._tick_combat(.41)
 check(zombie.health==100,"bat hit beyond 2.20m range")
 discard(zombie)

 state.items={"odachi":1}
 check(state.equip_item("odachi","right_hand"),"could not equip odachi")
 state.set_odachi_skill_level(1)
 reset_hero()
 zombie=spawn_zombie(0,2.54)
 await physics_frame
 hero.attack();hero._tick_combat(.45)
 check(hero._combat_action=="SwordCombo1" and zombie.health==96,"odachi failed just inside 2.55m range")
 discard(zombie)
 reset_hero()
 zombie=spawn_zombie(0,2.56)
 await physics_frame
 hero.attack();hero._tick_combat(.45)
 check(zombie.health==100,"odachi hit beyond 2.55m range")
 discard(zombie)

 # Aim assistance must retain the existing wall/occluder check.
 reset_hero()
 zombie=spawn_zombie(0,2.0)
 var wall:=StaticBody3D.new()
 wall.collision_layer=2
 wall.collision_mask=0
 var shape:=CollisionShape3D.new()
 var box:=BoxShape3D.new()
 box.size=Vector3(1.5,2.0,.12)
 shape.shape=box
 wall.add_child(shape)
 arena.add_child(wall)
 wall.global_position=Vector3(0,1.0,1.0)
 await physics_frame
 hero.attack();hero._tick_combat(.45)
 check(hero._punch_target==null and zombie.health==100,"aim assist selected or hit through wall")

 arena.queue_free()
 print("MELEE_ASSIST_CHECK errors=",errors)
 quit(1 if errors else 0)
