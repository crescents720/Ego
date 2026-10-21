extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var main=load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var gaps: Array[float]=[]
	var footprints: Array[Rect2]=[]
	for lot in main.town_layout.lots:
		var bb: AABB=lot.bounds
		footprints.append(Rect2(Vector2(bb.position.x,bb.position.z),Vector2(bb.size.x,bb.size.z)))
	for i in range(footprints.size()):
		var nearest:=INF
		for j in range(footprints.size()):
			if i==j:continue
			var a:=footprints[i]
			var b:=footprints[j]
			if a.intersects(b):
				push_error("DENSITY_FAIL: overlapping buildings")
				quit(1)
				return
			var gap:=Vector2(maxf(0,maxf(a.position.x-b.end.x,b.position.x-a.end.x)),maxf(0,maxf(a.position.y-b.end.y,b.position.y-a.end.y))).length()
			nearest=minf(nearest,gap)
		gaps.append(nearest)
	gaps.sort()
	var median: float=gaps[gaps.size()/2]
	if footprints.size()<180 or median>3.5:
		push_error("DENSITY_FAIL: frontage remains sparse")
		quit(1)
		return
	print("DENSITY_PASS: ",footprints.size()," buildings; median nearest wall gap ",median," m; no overlapping footprints")
	quit()
