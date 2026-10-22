extends SceneTree
var errors:=0
func _initialize():call_deferred("run")
func check(ok: bool,message: String):
 if not ok:errors+=1;push_error(message)
func run():
 root.size=Vector2i(720,1280)
 var s=root.get_node("GameState")
 s.suppress_save=true
 var m=load("res://scenes/main.tscn").instantiate()
 root.add_child(m)
 m._start_new_game();m._set_phase(m.Phase.EXPLORE)
 m.zombie_population.set_process(false)
 for z in get_nodes_in_group("zombies"):z.queue_free()
 await physics_frame
 var t=m.temple
 var h=m.hotaru
 h.set_physics_process(false)
 h.position=t.RACK+Vector3(0,0,-2)
 m.rv.position=t.RACK+Vector3(8,0,-3)
 check(t.nearby(),"Temple pickup unreachable")
 m._update_hud()
 check(m.interact_button.visible and m.interact_button.text=="拾取大太刀","Pickup HUD missing")
 s.items={"water":2}
 t.interact()
 check(not s.odachi_taken and t.sword.visible,"Full bag consumed unique sword")
 s.items={"bat":1};s.equipment.left_hand="bat"
 m.interact_button.pressed.emit()
 check(s.odachi_taken and s.items.get("odachi")==1 and s.weapon_id()=="odachi","Sword pickup/equip failed")
 check(s.equipment.left_hand=="" and s.equipment.right_hand=="odachi","Two handed slot conflict")
 check(not t.sword.visible and not t.nearby(),"Sword duplicate pickup possible")
 check(h._sword_model.visible and not h._bat_models.R.visible,"Wrong held weapon")
 for count in range(1,6):
  var key="SwordCombo"+str(count)
  check(h._animation_names.has(key),"Missing "+key)
  check(h._animation_player.get_animation(h._animation_names[key]).loop_mode==Animation.LOOP_NONE,"Combo loops")
 # Sample actual runtime skeleton: both palms remain 11.5cm apart along the grip.
 var sk: Skeleton3D=h._character_model.find_children("*","Skeleton3D",true,false)[0]
 var rb=sk.find_bone("Hand.R");var lb=sk.find_bone("Hand.L")
 for count in range(1,6):
  var clip: String=h._animation_names["SwordCombo"+str(count)]
  var duration: float=h._animation_player.get_animation(clip).length
  for sample in range(15):
   h._animation_player.play(clip,0);h._animation_player.seek(duration*sample/14.0,true);h._animation_player.pause()
   sk.force_update_all_bone_transforms()
   var right: Transform3D=sk.get_bone_global_pose(rb)
   var left: Transform3D=sk.get_bone_global_pose(lb)
   var axis: Vector3=(right.basis*h._sword_model.basis).y.normalized()
   var rp: Vector3=right*(sk.get_bone_global_rest(rb).basis.inverse()*Vector3(0,-.035,-.012))
   var lp: Vector3=left*(sk.get_bone_global_rest(lb).basis.inverse()*Vector3(0,-.035,-.012))
   check((lp-(rp-axis*.115)).length()<.013,"Hands leave grip in %d at %d, error %f"%[count,sample,(lp-(rp-axis*.115)).length()])
 for placement in m.town_layout.vegetation.placements:
  var point: Vector2=placement.position
  check(not Rect2(-97.5,307,7,21).has_point(point),"Tree/grass blocks temple access road")
 h.pushing_cart=true;h._combat_action="";h._last_attack_ms=-10000;h.attack()
 check(h._combat_action.is_empty(),"Sword can attack while pushing cart")
 h.pushing_cart=false
 # Test all four independent damage windows, recovery, and wall occlusion.
 h._combat_action="";h.set_active(true);h._last_attack_ms=-10000
 h.position=t.RACK+Vector3(5,0,-4)
 var z=load("res://scripts/actors/zombie.gd").new();m.world_root.add_child(z)
 z.position=h.position+Vector3(0,0,1.8);z.set_physics_process(false)
 z.health=30
 await physics_frame
 h.attack()
 check(h._combat_action=="SwordCombo4","Temple sword did not start four-hit combo")
 var expected_health:=30
 for index in range(h.SWORD_COMBO_CONTACTS.size()):
  var contact: float=float(h.SWORD_COMBO_CONTACTS[index])
  var before_contact: float=contact-h._combat_elapsed-.001
  if before_contact>0:h._tick_combat(before_contact)
  check(z.health==expected_health,"Sword hit early at window %d"%(index+1))
  h._tick_combat(.002);expected_health-=4
  check(z.health==expected_health,"Sword contact %d damage failed"%(index+1))
  h._tick_combat(.05)
  check(z.health==expected_health,"Sword contact %d repeated damage"%(index+1))
 check(h._sword_contact_index==4,"Four-hit combo skipped a contact window")
 h._tick_combat(h.SWORD_COMBO_LENGTH-h._combat_elapsed+.01)
 check(h._combat_action.is_empty(),"Sword recovery stuck")
 var wall:=StaticBody3D.new();var col:=CollisionShape3D.new();var box:=BoxShape3D.new()
 box.size=Vector3(2,3,.1);col.shape=box;wall.add_child(col);wall.position=h.position+Vector3(0,0,.9);m.world_root.add_child(wall)
 await physics_frame
 h._last_attack_ms=-10000;h.attack();h._tick_combat(h.SWORD_COMBO_LENGTH+.01)
 check(z.health==14,"Sword hits through walls")
 wall.queue_free();z.queue_free()
 await physics_frame
 # A single low-FPS tick must catch every contact and retarget after the first zombie falls.
 var lead=load("res://scripts/actors/zombie.gd").new();m.world_root.add_child(lead)
 var reserve=load("res://scripts/actors/zombie.gd").new();m.world_root.add_child(reserve)
 lead.position=h.position+Vector3(0,0,1.7);lead.health=10;lead.set_physics_process(false)
 reserve.position=h.position+Vector3(0,0,2.2);reserve.health=10;reserve.set_physics_process(false)
 await physics_frame
 h._last_attack_ms=-10000;h.attack();h._tick_combat(h.SWORD_COMBO_LENGTH+.01)
 check(lead._dying,"Four-hit combo did not defeat the first zombie in three hits")
 check(reserve.health==6,"Fourth contact did not retarget the next zombie")
 lead.queue_free();reserve.queue_free()
 # Crossing the recovery timestamp must remain movement-locked for that whole physics frame.
 h._combat_action=h.SWORD_COMBO_ACTION;h._combat_elapsed=h.SWORD_COMBO_LENGTH-.01
 h.touch_move=Vector2(1,0)
 var locked_position:=Vector2(h.global_position.x,h.global_position.z)
 h._physics_process(.05)
 check(Vector2(h.global_position.x,h.global_position.z).distance_to(locked_position)<.001,"Sword recovery frame allowed movement")
 h.touch_move=Vector2.ZERO
 check(s.equip_item("bat","left_hand") and s.weapon_id()=="bat" and s.equipment.right_hand=="","Bat swap leaves two-handed weapon")
 check(not h._sword_model.visible and h._bat_models.L.visible,"Sword remains visible after swapping")
 s.equip_item("odachi","right_hand")
 h.set_seated(true);h._update_visual_motion(Vector3.ZERO,0)
 check(not h._bat_attachments.R.visible,"Sword displayed when seated")
 h.set_seated(false)
 var path="user://sword_test/slot.cfg"
 check(s.save_game(path)==OK,"Isolated save failed")
 s.start_new_run();check(not s.odachi_taken and t.sword.visible,"New game failed to restore unique pickup")
 check(s.load_completed_save(path) and s.odachi_taken and s.weapon_id()=="odachi","Sword save/load failed")
 check(not t.sword.visible,"Loaded sword respawned")
 m.hotaru.position=t.RACK+Vector3(0,0,-3)
 m._update_camera(100)
 m._update_hud()
 if DisplayServer.get_name()!="headless":
  for frame in range(6):await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://artifacts/temple_in_game.png")
 print("SWORD_VERIFY errors=",errors)
 quit(1 if errors else 0)

