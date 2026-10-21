extends SceneTree
func _initialize() -> void:call_deferred("run")
func sample(hero,clip: String,time: float) -> Dictionary:
 hero._animation_player.play(clip,0)
 hero._animation_player.seek(time,true)
 hero._animation_player.pause()
 var skeleton: Skeleton3D=hero.find_children("*","Skeleton3D",true,false)[0]
 skeleton.force_update_all_bone_transforms()
 await process_frame
 await RenderingServer.frame_post_draw
 var result:={}
 for bone in ["Hand.R","Hand.L","Foot.L","Foot.R"]:
  result[bone]=skeleton.get_bone_global_pose(skeleton.find_bone(bone)).origin
 return result
func run() -> void:
 var state=root.get_node("GameState")
 state.start_new_run()
 state.try_add_items({"bat":1})
 var hero=load("res://scripts/actors/hotaru.gd").new()
 root.add_child(hero)
 hero.set_physics_process(false)
 for side in ["R","L"]:
  state.unequip_item("right_hand")
  state.unequip_item("left_hand")
  state.equip_item("bat","right_hand" if side=="R" else "left_hand")
  var idle: Dictionary=await sample(hero,"BatIdle"+side,0)
  var wind: Dictionary=await sample(hero,"BatAttack"+side,.25)
  var hit: Dictionary=await sample(hero,"BatAttack"+side,.42)
  if wind["Hand."+side].distance_to(hit["Hand."+side])<.30:
   push_error("BAT_ANIMATION_FAIL: insufficient swing");quit(1);return
  var step1: Dictionary=await sample(hero,"BatWalk"+side,0)
  var step2: Dictionary=await sample(hero,"BatWalk"+side,.25)
  if step1["Foot.L"].distance_to(step2["Foot.L"])<.08:
   push_error("BAT_ANIMATION_FAIL: lost walk leg motion");quit(1);return
  var attachment: BoneAttachment3D=hero._bat_attachments[side]
  if not attachment.visible or attachment.get_child_count()!=1:
   push_error("BAT_ANIMATION_FAIL: weapon missing from hand bone");quit(1);return
  print("BAT_HAND: ",side," swing=",wind["Hand."+side].distance_to(hit["Hand."+side]))
 print("BAT_ANIMATION_PASS: both hands have held Idle/Walk/Attack, preserved foot motion, moving hand bones and attached source bat")
 quit()
