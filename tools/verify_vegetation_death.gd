extends SceneTree
var errors:=0
func _initialize() -> void:call_deferred("run")
func check(value: bool,message: String) -> void:
 if not value:
  push_error(message)
  errors+=1
func run() -> void:
 var main=load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 root.get_node("GameState").suppress_save=true
 main._start_new_game()
 var landscape=main.town_layout.vegetation
 var counts: Dictionary={}
 for item in landscape.placements:
  counts[item.id]=counts.get(item.id,0)+1
  var radius: float=1.8 if item.id in ["grass","reeds"] else (7.0 if item.id=="grove" else 2.6)
  check(landscape.clear_grass(item.position) if item.id=="grass" else landscape.clear(item.position,radius),"Vegetation overlaps protected space: "+str(item))
 check(landscape.placements.size()>350,"Landscape too sparse")
 check(counts.get("reeds",0)>20,"Missing lakeshore reeds")
 check(counts.get("leaf1",0)>10 and counts.get("tree1",0)>0,"Missing supplied tree variety")
 check(main.hotaru._animation_names.has("Death"),"No skeletal death clip")
 var source=main.ZombieController.new()
 main.add_child(source)
 source.position=main.hotaru.position+Vector3(0,0,1.2)
 source.set_physics_process(false)
 main.hotaru.take_damage(100,source)
 check(main.hotaru.dead and main.hotaru.get_animation_state()=="Death","Fatal hit did not start death animation")
 check(main.equipment_screen.health_state=="dead","Death avatar did not replace injured portrait")
 check(not main.dialog_panel.visible,"Failure dialog appeared before fall")
 check(not main.controls_enabled and not main.attack_button.visible,"Controls remain enabled during death")
 for button in get_nodes_in_group("movement_controls"):check(not button.visible,"Movement pad still displayed during death")
 for batch in landscape.batches:check(batch.position.length()>1.0,"Batch range center left at world origin")
 var skeleton: Skeleton3D=main.hotaru._character_model.find_children("*","Skeleton3D",true,false)[0]
 await create_timer(0.95).timeout
 check(not main.dialog_panel.visible,"Failure dialog interrupts landing")
 var head: Vector3=skeleton.get_bone_global_pose(skeleton.find_bone("Head")).origin
 check(head.y<0.55,"Head remained upright after fall")
 await create_timer(1.1).timeout
 check(main.dialog_panel.visible,"Missing failure dialog after settling")
 check(main.hotaru.get_animation_state()=="Death","Idle overwrote final death pose")
 main._start_new_game()
 check(not main.hotaru.dead and main.hotaru.health==5 and main.hotaru.active,"New game failed to restore living character")
 check(main.equipment_screen.health_state=="healthy" and not main.equipment_screen.avatar.disabled,"New game failed to restore HUD")
 print("VEGETATION_DEATH_CHECK: ",counts," placements=",landscape.placements.size()," batches=",landscape.batches.size()," errors=",errors)
 main.opening.voice.stop()
 main.opening.music.stop()
 main.opening.fire_audio.stop()
 await create_timer(.15).timeout
 quit(0 if errors==0 else 1)
