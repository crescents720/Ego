extends Node
var main
var label: Label
var notice: Label
var _last_night:=false
var _notice_time:=0.0
func build(owner_main) -> void:
 main=owner_main
 label=Label.new()
 label.position=Vector2(228,174)
 label.size=Vector2(225,50)
 label.add_theme_font_size_override("font_size",20)
 label.add_theme_color_override("font_color",Color("e8dec0"))
 main.get_node("HUD").add_child(label)
 notice=Label.new()
 notice.position=Vector2(75,370)
 notice.size=Vector2(570,110)
 notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 notice.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 notice.add_theme_font_size_override("font_size",26)
 notice.add_theme_color_override("font_color",Color("f4dfae"))
 notice.add_theme_color_override("font_outline_color",Color("17272d"))
 notice.add_theme_constant_override("outline_size",6)
 main.get_node("HUD").add_child(notice)
 notice.hide()
func _process(delta: float) -> void:
 if not is_instance_valid(main):return
 var playing: bool=main.phase not in [main.Phase.TITLE,main.Phase.GAME_OVER] and not main.opening.is_cinematic()
 label.visible=playing
 if not playing:notice.hide();return
 var night: bool=GameState.is_night()
 if night!=_last_night:
  _last_night=night
  _notice_time=4.0
  notice.text="夜幕降临\n尸群增多，追逐速度提高。" if night else "黎明到来\n尸群逐渐恢复白天的活动。"
  main.zombie_population.set_night(night)
 _notice_time=maxf(0,_notice_time-delta)
 notice.visible=_notice_time>0
 notice.modulate.a=minf(1,_notice_time)
 var phase: float=fposmod(GameState.world_seconds,GameState.DAY_SECONDS)/GameState.DAY_SECONDS
 var minutes:=int(fposmod(6+phase*24,24)*60)
 label.text="%s · 第 %d 天\n%02d:%02d"%["夜晚" if night else "白昼",int(GameState.world_seconds/GameState.DAY_SECONDS)+1,minutes/60,minutes%60]
 var daylight:=smoothstep(-.14,.14,sin(phase*TAU))
 var indoor: bool=main.inside_rv or main.inside_store or (is_instance_valid(main.factory) and main.factory.active) or (is_instance_valid(main.hospital) and main.hospital.active)
 for child in main.get_children():
  if child is DirectionalLight3D:
   child.light_energy=0.0 if is_instance_valid(main.hospital) and main.hospital.active else (1.05 if indoor else lerpf(.16,1.15,daylight))
   child.light_color=Color("95b1ed").lerp(Color("ffe2b5"),daylight) if not indoor else Color("ffe6c8")
   child.rotation_degrees.x=-32.0-35.0*sin(phase*PI) if not indoor else -52.0
  elif child is WorldEnvironment:
   child.environment.ambient_light_energy=.72 if indoor else lerpf(.32,.72,daylight)
   child.environment.fog_light_color=Color("25364e").lerp(Color("aab9c3"),daylight)
   child.environment.background_color=Color("101d32").lerp(Color("6986a2"),daylight)
 for actor in get_tree().get_nodes_in_group("zombies"):
  actor.move_speed=5.2 if night and not actor.is_in_group("store_indoor_zombies") else actor.MOVE_SPEED

func reset() -> void:
 _last_night=GameState.is_night()
 _notice_time=0
 notice.hide()
