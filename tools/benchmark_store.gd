extends SceneTree
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 Engine.max_fps = 0
 var main = load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 main._prepare_store_preview()
 for i in range(40):
  await process_frame
 var begin := Time.get_ticks_usec()
 var draws := 0.0
 var primitives := 0.0
 for i in range(120):
  await process_frame
  draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
  primitives += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
 var elapsed := (Time.get_ticks_usec() - begin) / 1000000.0
 print("STORE_BENCHMARK: ", JSON.stringify({"fps": 120.0 / elapsed, "frame_ms": elapsed * 1000 / 120, "draw_calls": draws / 120, "primitives": primitives / 120}))
 quit()
