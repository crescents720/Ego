extends SceneTree
var errors:=0
var main
var audio
func _initialize() -> void:call_deferred("run")
func check(ok: bool, message: String) -> void:
 if not ok:push_error(message);errors+=1
func wait_seconds(seconds: float) -> void:
 await create_timer(seconds).timeout
func clear_enemies() -> void:
 for zombie in get_nodes_in_group("zombies"):zombie.queue_free()
 await physics_frame
func run() -> void:
 main=load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 audio=root.get_node("AudioDirector")
 var state=root.get_node("GameState")
 state.suppress_save=true
 main._start_new_game()
 main.zombie_population.set_process(false)
 await clear_enemies()
 state.cargo={"water":20,"food":20}
 state._sync_resources()
 main._set_phase(main.Phase.EXPLORE)
 main.hotaru.global_position=Vector3(0,.95,200)
 await physics_frame
 audio.played_events.clear()
 Input.action_press("move_forward")
 await wait_seconds(2.1)
 Input.action_release("move_forward")
 var steps:=0
 for key in ["step_hard","step_grass","step_inside"]:steps+=int(audio.played_events.get(key,0))
 print("FOOT_CONTACTS in 2.1s: ",steps)
 check(steps>=3 and steps<=5,"Foot sounds must match 2 planted feet per 1-second animation, rather than distance cadence")
 await wait_seconds(.2)
 var stopped:=0
 for key in ["step_hard","step_grass","step_inside"]:stopped+=int(audio.played_events.get(key,0))
 await wait_seconds(.7)
 var after:=0
 for key in ["step_hard","step_grass","step_inside"]:after+=int(audio.played_events.get(key,0))
 check(stopped==after,"Standing still must be silent")
 # Check bare-handed and armed walk clips all carry the same foot-contact markers.
 for name in ["Walk","BatWalkR","BatWalkL"]:
  var animation: Animation=main.hotaru._animation_player.get_animation(main.hotaru._animation_names[name])
  var keys:=0
  for track in range(animation.get_track_count()):
   if animation.track_get_type(track)==Animation.TYPE_METHOD:keys+=animation.track_get_key_count(track)
  check(keys==2,"Missing foot markers on "+name)
 main.hotaru.health=2.4
 audio._update_breathing(.6,true)
 check(audio.breath_state=="pain_medium" and audio.breath_player.playing,"Yellow health breathing missing")
 main.hotaru.health=.74
 audio._update_breathing(.6,true)
 check(audio.breath_state=="pain_heavy" and audio.breath_player.playing,"Red health breathing missing")
 main.hotaru.health=1.251
 audio._update_breathing(.6,true)
 check(audio.breath_state=="pain_medium","Above 25 percent belongs to yellow state")
 main.hotaru.health=1.25
 audio._update_breathing(.6,true)
 check(audio.breath_state=="pain_heavy","Exactly 25 percent must enter red breathing")
 for tier in ["pain_medium","pain_heavy"]:
  var previous: AudioStream
  var seen: Dictionary={}
  for i in range(12):
   main.hotaru.health=2.0 if tier=="pain_medium" else 1.0
   audio.breath_player.stop()
   audio.breath_wait=0
   audio._update_breathing(.6,true)
   var playing: AudioStream=audio.breath_player.stream
   check(playing!=null and playing!=previous,"Breathing repeated adjacent take: "+tier)
   seen[playing]=true
   previous=playing
  check(seen.size()==3,"Breathing must use three distinct streams: "+tier)
 check(not audio.settings.launch.visible,"In-game sound shortcut must be hidden")
 audio.hero_voice("hero_hurt")
 check(audio.hero_speaker.playing and not audio.breath_player.playing,"Hurt voice must interrupt breathing without layering")
 audio._update_breathing(.1,false)
 check(not audio.breath_player.playing,"Pain breathing must stop in paused/blocked scenes")
 main.hotaru.health=5
 audio.hero_speaker.stop()
 # Vehicle anticipation: not a point of damage until the arms actually reach the hull.
 main.rv.global_position=Vector3(0,1.02,200)
 main.hotaru.global_position=main.rv.get_disembark_position()
 main._enter_rv_interior()
 main.rv.occupied=true
 var zombie=main.ZombieController.new()
 main.add_child(zombie)
 zombie.global_position=main.rv.to_global(Vector3(1.85,-.12,0))
 zombie.set_target(main.hotaru)
 zombie.set_vehicle_target(main.rv)
 zombie._physics_process(0)
 zombie.set_physics_process(false)
 var hp: int=main.rv.health
 check(zombie._animation_state=="VehicleAttack","Hull attack must visibly anticipate with raised arms")
 zombie._tick_bite(.59)
 check(main.rv.health==hp,"Vehicle attack damages before 0.60 second contact")
 zombie._tick_bite(.02)
 check(main.rv.health==hp-4,"Vehicle contact does not apply exactly one hit")
 zombie._tick_bite(.1)
 check(main.rv.health==hp-4,"Vehicle attack applied contact twice")
 zombie._bite_elapsed=0
 zombie._bite_contact_done=false
 zombie._bite_victim=main.rv
 main.rv.occupied=false
 zombie._tick_bite(.7)
 check(main.rv.health==hp-4,"Disembarking must cancel the previous vehicle hit")
 zombie.queue_free()
 await physics_frame
 main.rv.last_hostile_attack_ms=-100000
 # No repair loot is needed, no stock is consumed.
 state.items={}
 state.cargo={}
 state._sync_resources()
 main.rv.global_position=main.repair_shop.BAY
 main.rv.speed=0
 main.in_vehicle=false
 main.inside_rv=false
 main.hotaru.position=main.rv.get_disembark_position()
 check(main.repair_shop.repair(),"Garage refused repair with zero materials")
 main.service.walking=false
 main.service._process(12.1)
 check(main.rv.health==main.rv.max_health and state.scrap==0,"Free repair must restore condition without item changes")
 main.rv.take_damage(20)
 main.rv.speed=2
 check(not main.repair_shop.repair(),"Moving vehicle must not repair")
 main.rv.speed=0
 main.rv.mark_hostile_attack()
 check(not main.repair_shop.repair(),"Active attack must prevent on-site repair")
 audio.played_events.clear()
 audio.hero_voice("hero_death")
 check(audio.hero_speaker.playing and int(audio.played_events.get("death",0))==0,"Defeat must use a human voice, not a UI tone")
 print("AUDIO_REVISION2_CHECK errors=",errors)
 audio.stop_all()
 main.queue_free()
 await create_timer(.15).timeout
 quit(1 if errors else 0)
