extends SceneTree
var main
var state
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> bool:
 if ok:return true
 push_error("EQUIPMENT_FAIL: "+message)
 quit(1)
 return false
func walk_to(goal: Vector3) -> bool:
 for frame in range(240):
  await physics_frame
  var offset: Vector3=goal-main.hotaru.global_position
  offset.y=0
  if offset.length()<0.10:return true
  main.hotaru.velocity=offset.normalized()*2.4
  main.hotaru.move_and_slide()
 return false
func run() -> void:
 state=root.get_node("GameState")
 state.suppress_save=true
 main=load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 main._start_new_game()
 if not check(state.carried_grams()==0,"casual outfit is not equipment"):return
 if not check(state.try_add_items({"food":18,"medicine":4}) and state.carried_grams()==9600,"weight before starter pickup"):return
 main.hotaru.global_position=main.rv.get_disembark_position()
 main._enter_rv_interior()
 await create_timer(0.55).timeout
 main.hotaru.set_physics_process(false)
 for point in [Vector3(0.45,1.13,-3.13),Vector3(-0.1,1.13,-3.13)]:
  if not check(await walk_to(main.RV_INTERIOR_ORIGIN+point),"physical route from door to wardrobe"):return
 main._interact()
 if not check(main.rv_interior.wardrobe_open and main.dialog_panel.visible,"reachable wardrobe opens with story"):return
 main._take_starter_bat()
 if not check(not state.bat_taken and not state.items.has("bat") and main.rv_interior.wardrobe_bat.visible,"full bag leaves bat in cabinet"):return
 main._close_dialog_and_resume()
 if not check(state.store_item("food"),"store one item in RV"):return
 main._take_starter_bat()
 if not check(state.weapon_hand().is_empty(),"starter pickup must remain in backpack"):return
 main.equipment_screen.equip_drop("right_hand",{"kind":"personal_item","id":"bat","source_slot":""})
 if not check(state.bat_taken and state.items.bat==1 and state.carried_grams()==10000 and state.equipment.right_hand=="bat","exactly 10kg accepts and equips starter"):return
 main._take_starter_bat()
 if not check(state.items.bat==1 and not main.rv_interior.wardrobe_bat.visible,"no duplicate starter or leftover prop"):return
 if not check(not state.retrieve_item("food") and state.cargo.food==1 and not state.try_add_items({"food":1}),"overweight takeback and pickups atomic"):return
 state.unequip_item("right_hand")
 if not check(state.carried_grams()==10000 and state.equip_item("bat","left_hand") and main.hotaru._weapon_hand=="L","unequip/equip do not bypass weight; left hand works"):return
 if not check(not state.equip_item("bat","right_hand") and not state.equip_item("water","head"),"cannot duplicate held item or equip wrong slot"):return
 state.unequip_item("left_hand")
 if not check(state.store_item("bat") and main.hotaru._weapon_hand.is_empty() and state.retrieve_item("bat"),"cargo round trip"):return
 state.equip_item("bat","right_hand")
 main.equipment_screen.avatar.pressed.emit()
 if not check(main.equipment_screen.panel.visible and paused,"avatar opens modal and pauses danger"):return
 main.equipment_screen.close()
 if not check(not paused,"close restores game"):return
 # Real combat must deal one damage unarmed and two with the bat, at contact.
 main._exit_rv_interior()
 main.hotaru.cancel_boarding_step()
 main.hotaru.set_physics_process(false)
 main.hotaru.position=Vector3(0,0.95,-10)
 main.hotaru.set_active(true)
 var zombie=main.get_tree().get_nodes_in_group("store_zombies")[0]
 zombie.set_physics_process(false)
 zombie.position=Vector3(0,0.9,-8.9)
 state.unequip_item("right_hand")
 main.hotaru._last_attack_ms=-10000
 main.hotaru.attack()
 main.hotaru._tick_combat(0.23)
 if not check(zombie.health==10,"no early punch damage"):return
 main.hotaru._tick_combat(0.02)
 if not check(zombie.health==9,"unarmed damage one"):return
 zombie.health=10
 state.equip_item("bat","right_hand")
 for hit in range(5):
  main.hotaru._last_attack_ms=-10000
  main.hotaru.attack()
  main.hotaru._tick_combat(0.39)
  if not check(zombie.health==10-hit*2,"no early bat damage"):return
  main.hotaru._tick_combat(0.02)
  main.hotaru._tick_combat(0.01)
  if not check(zombie.health==8-hit*2,"bat does two damage exactly once"):return
  main.hotaru._tick_combat(0.50)
 if not check(zombie._dying,"five bat hits defeat zombie"):return
 state.demo_completed=true
 var expected_weight: int=state.carried_grams()
 var path:="user://equipment_regression.cfg"
 state.save_game(path)
 state.start_new_run()
 if not check(state.load_completed_save(path) and state.bat_taken and state.equipment.right_hand=="bat" and state.carried_grams()==expected_weight and state.cargo.food==1,"save round trip with equipment cargo and unique bat"):return
 DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
 var legacy:=ConfigFile.new()
 legacy.set_value("progress","demo_completed",true)
 legacy.set_value("progress","food",3)
 legacy.set_value("progress","water",4)
 legacy.set_value("progress","medicine",2)
 legacy.set_value("progress","scrap",5)
 legacy.save(path)
 if not check(state.load_completed_save(path) and state.carried_grams()+state.cargo_grams()==23550 and state.food==3 and not state.bat_taken,"legacy save migrates resources and basic clothes"):return
 DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
 # Store shelves retain all stock when overweight.
 main._start_new_game()
 state.try_add_items({"food":18,"medicine":4})
 main.hotaru.position=main.STORE_DOOR
 main._enter_store()
 main.hotaru.global_position=main.STORE_ORIGIN+main.StoreController.STATIONS.water.anchor
 main._interact_store()
 main.quantity_picker.amount.value=1
 main.quantity_picker.refresh()
 if not check(main.quantity_picker.confirm.disabled and not state.store_looted.has("water") and state.items.food==18,"overweight shelf remains untouched"):return
 main.quantity_picker.close()
 print("EQUIPMENT_PASS: 10kg boundary, atomic rejection, starter story and wardrobe, unique pickup, both hands, cargo, modal pause, contact timing, five-hit combat, persistence, overweight shelves")
 quit()

