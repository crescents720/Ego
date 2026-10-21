extends SceneTree
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 var main = load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 main._begin_story()
 var name := "dream"
 for arg in OS.get_cmdline_user_args():
  if arg in ["sleep","dream","break","wake","exterior","escape"]: name = arg
 match name:
  "dream":main.opening.set_beat(main.OpeningStory.Beat.DREAM)
  "break":
   main.opening.set_beat(main.OpeningStory.Beat.DREAM)
   main.opening.set_beat(main.OpeningStory.Beat.BREAK)
   main.opening.elapsed = 1.3
  "wake":main.opening.set_beat(main.OpeningStory.Beat.WAKE)
  "exterior":main.opening.set_beat(main.OpeningStory.Beat.EXTERIOR)
  "escape":
   main.opening.set_beat(main.OpeningStory.Beat.EXTERIOR)
   main.opening.set_beat(main.OpeningStory.Beat.ESCAPE)
 main._capture_preview = true
 main._preview_filename = "opening_"+name+".png"
