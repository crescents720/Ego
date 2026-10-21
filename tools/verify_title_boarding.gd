extends SceneTree
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> bool:
 if ok:return true
 push_error("TITLE_BOARDING_FAIL: "+message)
 quit(1)
 return false
func run() -> void:
 var main=load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 root.get_node("GameState").suppress_save=true
 if not check(main.title_screen.visible and not main.get_node("HUD").visible,"title is separate from game HUD"):return
 var title=main.title_screen
 if not check(title.new_button.text=="新游戏" and title.load_button.text=="加载存档" and title.quit_button.text=="退出游戏","three requested menu entries"):return
 if not check(title.load_button.disabled==not root.get_node("GameState").has_completed_save(),"load availability follows actual save"):return
 title.new_button.pressed.emit()
 if not check(not title.visible and main.opening.beat==main.opening.Beat.FILM and main.opening.movie.is_playing(),"new game starts film"):return
 await create_timer(0.6).timeout
 var texture: Texture2D=main.opening.movie.get_video_texture()
 if not check(texture.get_width()==720 and texture.get_height()==1280,"video has same 9:16 portrait aspect as game"):return
 main.opening.advance()
 main.opening.advance()
 if not check(not main.opening.voice.playing,"exterior has no synthesized narration"):return
 main.opening.advance()
 main.hotaru.global_position=main.rv.get_disembark_position()
 var rotation_before: Vector3=main.rv.rotation
 main._interact()
 if not check(main.inside_rv and main.hotaru._boarding,"boarding starts one step"):return
 var entry: Vector3=main.rv_interior.get_entry_position()
 var visual_offset: Vector3=main.hotaru.global_basis*main.hotaru._visual_root.position
 if not check(visual_offset.x>0.35 and absf(visual_offset.z)<0.02,"step starts toward exterior side of door"):return
 var camera_before: Transform3D=main.camera.global_transform
 main._update_camera(0.016)
 if not check(camera_before.origin.distance_to(main.camera.global_position)<0.001 and rotation_before==main.rv.rotation,"entry camera already at stable final position; RV does not rotate"):return
 await create_timer(0.65).timeout
 if not check(not main.hotaru._boarding and main.hotaru._visual_root.position.length()<0.01 and main.hotaru.global_position.distance_to(entry)<0.01,"one step stops exactly inside doorway"):return
 main._capture_preview=true
 main._preview_filename="boarding_stable.png"
 # The normal preview capture quits after rendering its frame.
 print("TITLE_BOARDING_PASS: menu, save availability, new game film, portrait format, no synthesized speech, stable camera and door step")
