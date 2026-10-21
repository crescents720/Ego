extends Node
# Sound decisions use real time, independent of sleep's 30x world simulation.
const MUSIC = {"title":"title", "explore":"explore", "shelter":"shelter", "danger":"danger"}
const VARIANTS = ["step_hard","step_grass","step_inside","swing","bat_swing","punch","bat_hit","hurt","zombie","zombie_hurt","zombie_die","ram_flesh","hero_hurt","bite","body","door","metal","crash","pickup","equip","transfer","trash","repair"]
var main
var context := ""
var requested := ""
var stable := 0.0
var danger_hold := 0.0
var explore_clock := 0.0
var music_players: Array[AudioStreamPlayer] = []
var gains: Array[float] = [0.0,0.0]
var active_music := 0
var streams: Dictionary = {}
var loops: Dictionary = {}
var cooldowns: Dictionary = {}
var last_variants: Dictionary = {}
var volumes := {"Music":0.65,"Effects":0.8,"Ambience":0.55,"UI":0.7,"Film":0.85}
var played_events: Dictionary = {}
var voices: Array[AudioStreamPlayer3D] = []
var listener: AudioListener3D
var previous_position := Vector3.ZERO
var hero_speaker: AudioStreamPlayer
var breath_player: AudioStreamPlayer
var breath_state := ""
var breath_wait := 0.0
var breath_bags: Dictionary = {}
var engine_ready_ms := 0
var scan_clock := 0.0
var near_zombies: Array[Node3D] = []
var was_driving := false
var last_speed := 0.0
var warning_states: Dictionary = {}
var settings
var rng := RandomNumberGenerator.new()
var _wall_ms := 0

func _ready() -> void:
 process_mode=Node.PROCESS_MODE_ALWAYS
 rng.randomize()
 for bus in ["Music","Effects","Ambience","UI","Film"]:
  if AudioServer.get_bus_index(bus)<0:
   AudioServer.add_bus()
   AudioServer.set_bus_name(AudioServer.bus_count-1,bus)
 var limiter:=AudioEffectHardLimiter.new()
 AudioServer.add_bus_effect(0,limiter)
 var config:=ConfigFile.new()
 if config.load("user://audio_settings.cfg")==OK:
  for bus in volumes:volumes[bus]=clampf(float(config.get_value("volume",bus,volumes[bus])),0,1)
 for bus in volumes:apply_volume(bus,volumes[bus],false)
 for i in range(2):
  var player:=AudioStreamPlayer.new()
  player.bus="Music"
  player.volume_db=-80
  add_child(player)
  music_players.append(player)
 for id in ["engine","wind","night","lake","fire"]:
  var player:=AudioStreamPlayer.new()
  player.bus="Effects" if id in ["engine","fire"] else "Ambience"
  player.stream=_stream(id,true)
  player.volume_db=-80
  add_child(player)
  loops[id]=player
 hero_speaker=AudioStreamPlayer.new()
 hero_speaker.bus="Effects"
 add_child(hero_speaker)
 breath_player=AudioStreamPlayer.new()
 breath_player.bus="Effects"
 add_child(breath_player)
 _wall_ms=Time.get_ticks_msec()

func attach(owner_main) -> void:
 main=owner_main
 context=""
 requested=""
 near_zombies.clear()
 warning_states.clear()
 danger_hold=0
 explore_clock=0
 was_driving=false
 listener=AudioListener3D.new()
 main.add_child(listener)
 listener.make_current()
 previous_position=main.hotaru.global_position
 settings=load("res://scripts/ui/audio_settings.gd").new()
 main.add_child(settings)
 settings.build(main)

func _stream(id: String, loop: bool=false) -> AudioStream:
 var key:=id+str(loop)
 if streams.has(key):return streams[key]
 var path: String="res://assets/audio/music/"+MUSIC[id]+".ogg" if MUSIC.has(id) else "res://assets/audio/sfx/"+id+".wav"
 if not ResourceLoader.exists(path):return null
 var stream: AudioStream=load(path).duplicate()
 if stream is AudioStreamWAV and loop:
  stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
  stream.loop_end=int(stream.get_length()*stream.mix_rate)
 # Music tails finish naturally; the director spaces exploration cues apart.
 if stream is AudioStreamOggVorbis:stream.loop=false
 streams[key]=stream
 return stream

func apply_volume(bus: String, value: float, save: bool=true) -> void:
 volumes[bus]=clampf(value,0,1)
 var index:=AudioServer.get_bus_index(bus)
 AudioServer.set_bus_mute(index,value<=0)
 AudioServer.set_bus_volume_db(index,linear_to_db(maxf(value,.0001)))
 if save:
  var config:=ConfigFile.new()
  for key in volumes:config.set_value("volume",key,volumes[key])
  config.save("user://audio_settings.cfg")

func ui(id: String="ui") -> void:
 if not _allow("ui_"+id,.075):return
 var player:=AudioStreamPlayer.new()
 player.stream=_stream(id+"_"+str(rng.randi_range(0,2)) if id in VARIANTS else id)
 player.bus="UI"
 player.volume_db=-16
 add_child(player)
 player.finished.connect(player.queue_free)
 player.play()
 played_events[id]=int(played_events.get(id,0))+1

func _allow(key: String, seconds: float) -> bool:
 var now:=Time.get_ticks_msec()
 if now<int(cooldowns.get(key,0)):return false
 cooldowns[key]=now+int(seconds*1000)
 return true

func sound(id: String, at: Vector3, db: float=-10.0) -> void:
 if not is_instance_valid(main) or get_tree().paused:return
 if is_instance_valid(main.opening) and main.opening.is_cinematic():return
 var focus: Vector3=main.rv.global_position if main.inside_rv or main.in_vehicle else main.hotaru.global_position
 # Outdoor attackers remain audible from the separate RV interior scene.
 var mapped:=at
 if main.inside_rv and at.x<500:mapped=main.hotaru.global_position+(at-main.rv.global_position)
 elif main.inside_rv and at.x>500:focus=main.hotaru.global_position
 if at.x<500 and main.inside_rv:focus=main.hotaru.global_position
 if mapped.distance_to(focus)>40:return
 voices=voices.filter(func(p):return is_instance_valid(p) and p.playing)
 if voices.size()>=20:return
 if id=="zombie" and not _allow("zombie",1.4):return
 if id=="metal" and not _allow("metal",.16):return
 if id=="crash" and not _allow("crash",.35):return
 if id=="ram_flesh" and not _allow("ram_flesh",.12):return
 var file_id:=id
 if id in VARIANTS:
  var variant:=rng.randi_range(0,2)
  if variant==int(last_variants.get(id,-1)):variant=(variant+1)%3
  last_variants[id]=variant
  file_id+="_"+str(variant)
 var player:=AudioStreamPlayer3D.new()
 player.stream=_stream(file_id)
 player.bus="Effects"
 player.volume_db=db- (5 if main.inside_rv and at.x<500 else 0)
 player.unit_size=5
 player.max_distance=40
 player.pitch_scale=rng.randf_range(.98,1.02)
 add_child(player)
 player.global_position=mapped
 player.finished.connect(player.queue_free)
 player.play()
 voices.append(player)
 played_events[id]=int(played_events.get(id,0))+1

func _switch_music(id: String) -> void:
 context=id
 if id.is_empty():return
 active_music=1-active_music
 var player:=music_players[active_music]
 player.stop()
 gains[active_music]=0
 player.volume_db=-80
 player.stream=_stream(id)
 player.play()

func _process(_delta: float) -> void:
 var now:=Time.get_ticks_msec()
 var dt:=minf(.1,(now-_wall_ms)/1000.0)
 _wall_ms=now
 # Scene reload removes children before the autoload receives its new owner.
 if not is_instance_valid(main) or not main.is_inside_tree() or main.is_queued_for_deletion():return
 if not is_instance_valid(main.hotaru) or not main.hotaru.is_inside_tree():return
 if not is_instance_valid(main.rv) or not main.rv.is_inside_tree():return
 var cinematic: bool=is_instance_valid(main.opening) and main.opening.is_cinematic()
 var title: bool=main.phase==main.Phase.TITLE
 var dead: bool=main.phase==main.Phase.GAME_OVER or main.hotaru.dead
 var paused: bool=get_tree().paused or (not main.controls_enabled and not title and not main.sleep_controller.sleeping and not main.service.active)
 var world_active: bool=not title and not dead and not cinematic and not paused
 var focus: Vector3=main.rv.global_position if main.in_vehicle else main.hotaru.global_position
 if is_instance_valid(listener):
  listener.global_position=focus
  listener.global_basis=main.camera.global_basis
 AudioServer.set_bus_mute(AudioServer.get_bus_index("Effects"),get_tree().paused or cinematic or float(volumes.Effects)<=0)
 settings.launch.visible=title and not cinematic
 hero_speaker.stream_paused=get_tree().paused or cinematic
 if get_tree().paused or cinematic:
  for voice in voices:
   if is_instance_valid(voice):voice.stream_paused=true
 else:
  for voice in voices:
   if is_instance_valid(voice):voice.stream_paused=false
 var threat:=false
 if world_active:
  scan_clock-=dt
  if scan_clock<=0:
   scan_clock=.3
   near_zombies.clear()
   var target_position: Vector3=main.rv.global_position if main.inside_rv or main.in_vehicle else focus
   for z in get_tree().get_nodes_in_group("zombies"):
    if not z._dying and z.is_physics_processing() and z.global_position.distance_to(target_position)<14:near_zombies.append(z)
  threat=main.is_under_attack()
  for z in near_zombies:
   if is_instance_valid(z) and not z._dying and is_instance_valid(z._choose_target()):threat=true
  if threat:danger_hold=6
  else:danger_hold=maxf(0,danger_hold-dt)
 var wanted: String="title" if title else ("" if cinematic or dead else ("danger" if danger_hold>0 else ("shelter" if main.inside_rv else "explore")))
 if wanted!=requested:requested=wanted;stable=0
 else:stable+=dt
 if wanted!=context and (wanted.is_empty() or wanted=="danger" or title or stable>=2.5):_switch_music(wanted)
 if context=="explore" and world_active:explore_clock+=dt
 var gap: bool=context=="explore" and fmod(explore_clock,150)>80
 for i in range(2):
  var target_gain:=1.0 if i==active_music and not context.is_empty() and not gap and not cinematic else 0.0
  gains[i]=move_toward(gains[i],target_gain,dt*.45)
  var level: float=0.0 if cinematic else gains[i]*(.35 if paused else 1.0)
  music_players[i].volume_db=linear_to_db(maxf(.0001,level))-10
  if i!=active_music and gains[i]<=0:music_players[i].stop()
 if not context.is_empty() and not cinematic and not music_players[active_music].playing and not gap:
  music_players[active_music].play()
 if world_active and main.in_vehicle!=was_driving:
  if main.in_vehicle and GameState.fuel_l>0:
   sound("start",focus,-8)
   engine_ready_ms=now+1100
  elif was_driving:sound("stop",focus,-21)
  was_driving=main.in_vehicle
 _loop("engine",-23+clampf(absf(main.rv.speed)/14,0,1)*7 if world_active and main.in_vehicle and now>=engine_ready_ms and GameState.fuel_l>0 and not main.rv.wrecked else -80,dt)
 loops.engine.pitch_scale=lerpf(loops.engine.pitch_scale,.7+absf(main.rv.speed)/14*.65,dt*3)
 var outdoors: bool=world_active and not main.factory.active and not main.inside_rv and not main.inside_store
 _loop("wind",-32 if outdoors else -80,dt)
 _loop("night",-32 if outdoors and GameState.is_night() else -80,dt)
 _loop("lake",-26 if outdoors and focus.x>240 else -80,dt)
 var rv_distance: float=0 if main.inside_rv or main.in_vehicle else focus.distance_to(main.rv.global_position)
 _loop("fire",-20-rv_distance if world_active and main.rv.health<=main.rv.max_health*.5 and rv_distance<25 and not main.inside_store else -80,dt)
 if world_active:
  last_speed=absf(main.rv.speed)
  if not main.sleep_controller.sleeping:
   if _allow("groan_scan",2.7) and not near_zombies.is_empty():
    var zombie: Node3D=near_zombies[rng.randi_range(0,near_zombies.size()-1)]
    if is_instance_valid(zombie):sound("zombie",zombie.global_position,-15)
   _warning("water",GameState.water<=0)
   _warning("food",GameState.food<=0)
   _warning("fuel",GameState.fuel_l<1)
   # Vehicle crisis is conveyed by fire/impacts, never a score-like tone.
 _update_breathing(dt,world_active)
 previous_position=focus

func _warning(id: String, active: bool) -> void:
 if active and not bool(warning_states.get(id,false)):ui("warning")
 warning_states[id]=active

func _loop(id: String, target_db: float, dt: float) -> void:
 var player: AudioStreamPlayer=loops[id]
 player.volume_db=move_toward(player.volume_db,target_db,dt*40)
 if target_db>-79 and not player.playing:player.play()
 if player.volume_db<=-79:player.stop()

func _footstep(at: Vector3) -> String:
 if main.inside_rv or main.inside_store or main.factory.active:return "step_inside"
 var point:=Vector2(at.x,at.z)
 for road in main.town_layout.roads:
  var closest:=Geometry2D.get_closest_point_to_segment(point,road.a,road.b)
  if closest.distance_to(point)<float(road.width)*.5+1.8:return "step_hard"
 if Rect2(-30,-55,32,30).has_point(point) or Rect2(-5,35,32,35).has_point(point):return "step_hard"
 return "step_grass"

func reset_run() -> void:
 danger_hold=0
 near_zombies.clear()
 warning_states.clear()
 explore_clock=0
 breath_state=""
 breath_bags.clear()
 breath_wait=0
 if is_instance_valid(breath_player):breath_player.stop()
 if is_instance_valid(hero_speaker):hero_speaker.stop()
 was_driving=false
 for voice in voices:
  if is_instance_valid(voice):voice.queue_free()
 voices.clear()

func hero_voice(id: String) -> void:
 if not is_instance_valid(main) or get_tree().paused:return
 if is_instance_valid(main.opening) and main.opening.is_cinematic():return
 if id=="hero_hurt" and not _allow("hero_hurt",.35):return
 breath_player.stop()
 breath_wait=2.8
 var file:=id
 if id=="hero_hurt":
  var variant:=rng.randi_range(0,2)
  if variant==int(last_variants.get(id,-1)):variant=(variant+1)%3
  last_variants[id]=variant
  file+="_"+str(variant)
 hero_speaker.stop()
 hero_speaker.stream=_stream(file)
 hero_speaker.volume_db=-9 if id=="hero_death" else -12
 hero_speaker.pitch_scale=1.0
 hero_speaker.play()
 played_events[id]=int(played_events.get(id,0))+1

func _update_breathing(dt: float, world_active: bool) -> void:
 var ratio: float=main.hotaru.health/main.hotaru.max_health
 var desired: String="" if not world_active or main.hotaru.dead or main.hotaru.sleeping or ratio<=0 or ratio>.5 else ("pain_heavy" if ratio<=main.hotaru.CRITICAL_HEALTH_RATIO else "pain_medium")
 if desired!=breath_state:
  breath_state=desired
  breath_player.stop()
  breath_wait=0.5 if not desired.is_empty() else 0.0
 if desired.is_empty():return
 if hero_speaker.playing:return
 breath_wait=maxf(0,breath_wait-dt)
 if not breath_player.playing and breath_wait<=0:
  var variant:=_next_breath_variant(desired)
  breath_player.stream=_stream(desired+"_"+str(variant))
  breath_player.volume_db=-18 if desired=="pain_heavy" else -24
  breath_player.play()
  breath_wait=breath_player.stream.get_length()+(rng.randf_range(1.2,2.4) if desired=="pain_heavy" else rng.randf_range(3.4,5.2))
  played_events[desired]=int(played_events.get(desired,0))+1

func _next_breath_variant(id: String) -> int:
 if not breath_bags.has(id) or breath_bags[id].is_empty():
  var bag: Array[int]=[0,1,2]
  for i in range(2,0,-1):
   var j:=rng.randi_range(0,i)
   var swap:=bag[i]
   bag[i]=bag[j]
   bag[j]=swap
  if bag[0]==int(last_variants.get(id,-1)):
   var swap:=bag[0]
   bag[0]=bag[1]
   bag[1]=swap
  breath_bags[id]=bag
 var result: int=breath_bags[id].pop_front()
 last_variants[id]=result
 return result

func stop_all() -> void:
 for player in find_children("*","AudioStreamPlayer",true,false):
  player.stop()
  player.stream=null
 for player in find_children("*","AudioStreamPlayer3D",true,false):
  player.stop()
  player.stream=null
 streams.clear()

func _exit_tree() -> void:
 stop_all()
