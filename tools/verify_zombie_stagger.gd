extends SceneTree

class DummyTarget extends Node3D:
 var active:=true
 var health:=5.0
 func take_damage(amount: int,_source: Node3D=null) -> void:health=maxf(0,health-amount)

var errors:=0
var arena: Node3D

func _initialize() -> void:call_deferred("run")

func check(ok: bool,message: String) -> void:
 if not ok:
  errors+=1
  push_error("ZOMBIE_STAGGER_FAIL: "+message)

func make_pair():
 var target:=DummyTarget.new()
 arena.add_child(target)
 target.global_position=Vector3(0,.9,0)
 var zombie=load("res://scripts/actors/zombie.gd").new()
 arena.add_child(zombie)
 zombie.global_position=Vector3(0,.9,.8)
 zombie.set_target(target)
 zombie.set_vehicle_target(null)
 zombie.health=100
 zombie._last_attack_ms=-10000
 zombie.set_physics_process(false)
 return [zombie,target]

func run() -> void:
 arena=Node3D.new()
 root.add_child(arena)
 var pair=make_pair()
 var zombie=pair[0]
 var target: DummyTarget=pair[1]
 await physics_frame

 # Ordinary damage retains only the visual reaction. Explicit melee stagger is
 # a separate timer, uses max rather than addition, and is capped at .95 s.
 zombie.take_damage(1)
 check(is_zero_approx(zombie._stagger_elapsed),"ordinary damage unexpectedly movement-staggers")
 zombie.take_damage(1,.38)
 zombie.take_damage(1,.18)
 check(absf(zombie._stagger_elapsed-.38)<.0001,"shorter hit added to or replaced active stagger")
 zombie.take_damage(1,2.0)
 check(absf(zombie._stagger_elapsed-.95)<.0001,"stagger cap is not .95 seconds")

 # A real stagger cancels an in-progress bite, freezes translation, then lets
 # the basic zombie immediately resume pursuit/windup when the timer expires.
 zombie._stagger_elapsed=0
 zombie._bite_elapsed=.2
 zombie._bite_victim=target
 zombie._bite_contact_done=false
 zombie.take_damage(1,.18)
 check(zombie._bite_elapsed<0 and zombie._bite_victim==null,"melee stagger did not cancel bite windup")
 var frozen: Vector3=zombie.global_position
 zombie._physics_process(.17)
 check(zombie.global_position.distance_to(frozen)<.0001 and zombie._stagger_elapsed>0,"zombie moved during stagger")
 zombie._physics_process(.02)
 check(is_zero_approx(zombie._stagger_elapsed) and zombie.global_position.distance_to(frozen)<.0001,"stagger expiry frame moved zombie")
 zombie._physics_process(.01)
 check(zombie._bite_elapsed>=0,"recovered zombie could not immediately start a new bite")

 # Level-one's .18 s stop is deliberately unsafe: after it expires, the .44 s
 # bite reaches Hotaru well before the next one-hit combo can connect.
 zombie._bite_elapsed=-1
 zombie._bite_victim=null
 zombie._last_attack_ms=-10000
 target.health=5
 zombie.take_damage(1,.18)
 zombie._physics_process(.18)
 zombie._physics_process(.001)
 zombie._physics_process(.43)
 check(target.health==5,"level-one scenario damaged before bite contact")
 zombie._physics_process(.02)
 check(target.health==4,"level-one short stagger incorrectly prevented the next bite")

 # At level two, the .38 s first hit and .70 s finisher repeatedly interrupt
 # bite windups. Across the real contact/recovery gaps, the basic zombie cannot
 # finish a bite before the next combo begins.
 zombie._bite_elapsed=-1
 zombie._bite_victim=null
 zombie._last_attack_ms=-10000
 target.health=5
 zombie.take_damage(1,.38)
 zombie._physics_process(.38)
 zombie._physics_process(.001)
 zombie._physics_process(.225) # gap from stagger end to second contact
 check(target.health==5 and zombie._bite_elapsed>=0,"level-two first interval behaved incorrectly")
 zombie.take_damage(1,.70)
 check(zombie._bite_elapsed<0,"level-two finisher did not interrupt bite")
 zombie._physics_process(.70)
 zombie._physics_process(.001)
 zombie._physics_process(.383) # remainder before the next combo's first contact
 check(target.health==5,"level-two sequence allowed a bite before the next first hit")
 zombie.take_damage(1,.38)
 check(zombie._bite_elapsed<0 and target.health==5,"next level-two opener failed to maintain pressure")

 arena.queue_free()
 print("ZOMBIE_STAGGER_CHECK errors=",errors)
 quit(1 if errors else 0)
