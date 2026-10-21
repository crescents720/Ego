extends SceneTree
var errors:=0
var main
var audio
func _initialize() -> void:call_deferred("run")
func check(ok: bool, message: String) -> void:
 if not ok:push_error(message);errors+=1
func settle(seconds: float) -> void:
 var deadline:=Time.get_ticks_msec()+int(seconds*1000)
 while Time.get_ticks_msec()<deadline:await process_frame
func run() -> void:
 main=load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 root.get_node("GameState").suppress_save=true
 audio=root.get_node("AudioDirector")
 await settle(.3)
 check(audio.context=="title","Title music context")
 for key in ["title","explore","shelter","danger"]:
  check(audio._stream(key)!=null,"Missing music: "+key)
 check(audio.music_players[audio.active_music].playing,"Title music must play")
 if DisplayServer.get_name()!="headless":
  var recorder:=AudioEffectRecord.new()
  AudioServer.add_bus_effect(0,recorder)
  recorder.set_recording_active(true)
  await settle(1.0)
  recorder.set_recording_active(false)
  var recording:=recorder.get_recording()
  check(recording!=null and recording.data.size()>1000,"Actual audio output is empty")
  if recording!=null:
   var audible:=false
   for byte in recording.data:
    if byte>2 and byte<254:audible=true;break
   check(audible,"Audio output is silent")
   recording.save_to_wav("res://artifacts/audio_title_sample.wav")
  AudioServer.remove_bus_effect(0,AudioServer.get_bus_effect_count(0)-1)
 main._start_new_game()
 main.zombie_population.set_process(false)
 for z in get_nodes_in_group("zombies"):z.queue_free()
 await physics_frame
 await settle(3)
 check(audio.context=="explore","Exploration context")
 audio.played_events.clear()
 main.hotaru.attack()
 await settle(.15)
 check(int(audio.played_events.get("swing",0))==1,"Swing event missing")
 await settle(.7)
 check(int(audio.played_events.get("punch",0))==0,"Miss must not sound like a hit")
 var zombie=main.ZombieController.new()
 main.add_child(zombie)
 zombie.global_position=main.hotaru.global_position+main.hotaru.transform.basis.z*.9
 zombie.set_target(main.hotaru)
 zombie.set_vehicle_target(main.rv)
 main.hotaru._last_attack_ms=-1000
 main.hotaru.attack()
 await settle(.5)
 check(int(audio.played_events.get("punch",0))>=1,"Confirmed punch has no sound")
 check(audio.context=="danger","Threat must select danger music")
 zombie.queue_free()
 await physics_frame
 audio.danger_hold=0
 main.hotaru.global_position=main.rv.get_disembark_position()
 main._enter_rv_interior()
 await settle(3)
 check(audio.context=="shelter","Safe RV music context")
 audio.sound("metal",main.rv.global_position)
 var voice=audio.voices.back()
 check(voice.global_position.distance_to(main.hotaru.global_position)<1,"Exterior vehicle impact not remapped inside RV")
 audio.settings.open()
 await settle(.15)
 check(paused,"Settings should pause world")
 check(not audio.loops.engine.playing,"Engine loop must stop in paused menu")
 audio.ui("pickup")
 check(int(audio.played_events.get("pickup",0))>=1,"Paused inventory feedback missing")
 audio.settings.close()
 main.opening.beat=main.opening.Beat.FILM
 await settle(.2)
 check(audio.context=="","Film must suppress global music")
 check(audio.music_players[0].volume_db<=-80 and audio.music_players[1].volume_db<=-80,"Film soundtrack overlap")
 main.opening.beat=main.opening.Beat.DONE
 await settle(.15)
 if DisplayServer.get_name()!="headless":
  audio.settings.open()
  await process_frame
  await process_frame
  get_root().get_texture().get_image().save_png("res://artifacts/audio_settings.png")
  audio.settings.close()
 print("AUDIO_CHECK errors=",errors)
 main.queue_free()
 await process_frame
 quit(1 if errors else 0)
