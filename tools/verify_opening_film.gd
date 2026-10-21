extends SceneTree
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> bool:
 if ok:return true
 push_error("FILM_FAIL: "+message)
 quit(1)
 return false
func run() -> void:
 var main=load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 root.get_node("GameState").suppress_save=true
 main._begin_story()
 var opening=main.opening
 if not check(opening.beat==opening.Beat.FILM and opening.movie.is_playing() and not main.controls_enabled,"new game plays film with controls locked"):return
 if not check(not opening.voice.playing and not opening.music.playing and not opening._caption_panel.visible,"film owns audio and full frame"):return
 opening.advance()
 if not check(opening.beat==opening.Beat.BRIDGE and not opening.movie.is_playing() and opening.movie.stream==null,"skip stops video and releases stream"):return
 opening.advance()
 if not check(opening.beat==opening.Beat.EXTERIOR,"bridge leads outside without repeat wake scene"):return
 opening.start()
 await create_timer(4.0).timeout
 if not check(opening.movie.get_stream_position()>3.0,"video decoder advances"):return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://artifacts/opening_film.png")
 await create_timer(14.0).timeout
 if not check(opening.beat==opening.Beat.EXTERIOR and not opening.movie.is_playing() and not main.controls_enabled,"natural ending reaches protected exterior"):return
 opening.advance()
 if not check(opening.beat==opening.Beat.ESCAPE and main.controls_enabled and main.hotaru.active,"handoff restores gameplay"):return
 opening.voice.stop()
 opening.fire_audio.stop()
 await create_timer(0.1).timeout
 print("FILM_PASS: startup, audio ownership, unobstructed layout, skip, replay, real decoding, natural finish and gameplay handoff")
 quit()
