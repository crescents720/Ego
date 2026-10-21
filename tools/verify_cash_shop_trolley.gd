extends SceneTree
var errors:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,message: String) -> void:
 if not ok:errors+=1;push_error(message)
func run() -> void:
 var main=load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 var state=root.get_node("GameState")
 state.suppress_save=true
 main._start_new_game()
 main.set_process(false)
 main.zombie_population.set_process(false)
 main.cash_drops.set_process(false)
 main.trolley.set_physics_process(false)
 for z in get_nodes_in_group("zombies"):z.queue_free()
 await physics_frame
 main._set_phase(main.Phase.EXPLORE)
 main.rv.position=Vector3(75,1.02,145)
 main.rv.rotation.y=0
 main.hotaru.position=Vector3(68,.95,145)
 var z=load("res://scripts/actors/zombie.gd").new()
 main.add_child(z)
 z.position=Vector3(69,.95,145)
 z.set_physics_process(false)
 z.take_damage(100)
 z.take_damage(100)
 check(state.cash_drops.size()==1,"Death must drop once")
 check(state.cash_drops[0].amount>=1 and state.cash_drops[0].amount<=5,"Invalid cash amount")
 var value: int=state.cash_drops[0].amount
 main.in_vehicle=true
 main.cash_drops._process(.2)
 check(state.cash==0 and state.cash_drops.size()==1,"Driving picked up cash")
 main.in_vehicle=false
 main.inside_rv=true
 main.cash_drops._process(.2)
 check(state.cash==0,"Interior picked up outside cash")
 main.inside_rv=false
 main.cash_drops._process(.2)
 check(state.cash==value and state.cash_drops.is_empty(),"Walking pickup failed")
 main.cash_drops.spawn_drop(Vector3(62,.95,145),5)
 state.tick_survival(179.9)
 main.cash_drops._process(.2)
 check(state.cash_drops.size()==1,"Drop expired too early")
 state.tick_survival(.1)
 main.cash_drops._process(.2)
 check(state.cash_drops.is_empty(),"Drop did not expire after half day")
 # UI branch: not enough cash, exits without granting a cart.
 main.hotaru.position=main.weapon_shop.door
 state.cash=999
 main.weapon_shop.enter()
 check(main.weapon_shop.active and paused,"Shop dialogue does not pause")
 for i in range(6):main.weapon_shop.advance()
 check(main.weapon_shop.words.text.contains("一千块"),"Poor customer was not dismissed")
 main.weapon_shop.advance()
 main.weapon_shop.advance()
 check(not main.weapon_shop.active and not state.cart_owned and state.cash==999,"Failed purchase mutated state")
 state.cash=1234
 main.weapon_shop.enter()
 main.weapon_shop.advance()
 check(main.weapon_shop.accept.visible,"Returning customer cannot buy")
 main.weapon_shop.purchase()
 check(state.cash==234 and state.cart_owned and state.weapon_bought,"Purchase failed")
 check(state.cart_items.get("m60",0)==1 and state.cart_items.get("m60_ammo",0)==500,"Bundle is wrong")
 check(state.cart_grams()==25000,"Bundle does not fit cart exactly")
 check(not state.buy_m60(),"Duplicate purchase allowed")
 main.weapon_shop.leave()
 check(not state.move_stack("m60","cart","bag",1),"23kg weapon fit in backpack")
 main.hotaru.position=state.cart_position+Vector3(0,.87,-1)
 check(main.trolley.interact(),"Cannot start pushing")
 check(main.hotaru.pushing_cart,"Push state not passed to hero")
 var last: int=main.hotaru._last_attack_ms
 main.hotaru.attack()
 check(main.hotaru._last_attack_ms==last,"Pushing permits attack")
 main.trolley.release()
 main.hotaru.attack()
 check(main.hotaru._last_attack_ms!=last,"Release does not restore attack")
 main.hotaru._combat_action=""
 # Save with remote cart/drop, then reload isolated file. Never touch a player slot.
 main.cash_drops.spawn_drop(Vector3(60,.95,145),4)
 var cart_pos: Vector3=state.cart_position
 check(state.save_game("user://economy_test/slot.cfg")==OK,"Save failed")
 state.cash=0
 state.cart_items={}
 state.cash_drops=[]
 check(state.load_completed_save("user://economy_test/slot.cfg"),"Reload failed")
 check(state.cash==234 and state.cart_position==cart_pos and state.cart_grams()==25000 and state.cash_drops.size()==1,"Economy save roundtrip lost data")
 # Remote boarding must not teleport the cart.
 main.hotaru.position=main.rv.get_disembark_position()
 check(not main.trolley.prepare_boarding() and state.cart_deployed,"Remote cart was teleported")
 state.cart_position=main.hotaru.position+Vector3(0,-.87,1.5)
 main.trolley.visual.position=state.cart_position
 check(main.trolley.prepare_boarding(),"Nearby cart failed to unload")
 check(not main.can_save_safely(),"Mid-animation save is allowed")
 await create_timer(2.3).timeout
 check(main.inside_rv and not state.cart_deployed and state.cart_items.is_empty(),"Cart not stowed")
 check(state.cargo.get("m60",0)==1 and state.cargo.get("m60_ammo",0)==500,"Unloading lost contents")
 state.cart_use_on_exit=true
 main.hotaru.position=main.rv_interior.get_entry_position()
 main._exit_rv_interior()
 await physics_frame
 check(state.cart_deployed,"Automatic deployment failed")
 check(state.cart_position.distance_to(main.rv.get_disembark_position())>1.2,"Deployed cart blocks doorway")
 check(state.move_stack("m60","cargo","cart",1),"Cannot reload cart from cargo")
 check(state.move_stack("m60_ammo","cargo","cart",500),"Ammo reload failed")
 check(not state.move_stack("food","bag","cart",1),"Nonexistent goods transferred")
 state.items={"food":1}
 check(not state.move_stack("food","bag","cart",1),"Cart exceeded 25kg")
 # Partial stack transfer remains independent of the 10kg backpack limit.
 check(state.move_stack("m60_ammo","cart","bag",100),"Ammo split failed")
 check(state.carried_grams()==900 and state.cart_grams()==24600,"Separate weights are wrong")
 print("CASH_SHOP_TROLLEY_CHECK errors=",errors)
 root.get_node("AudioDirector").stop_all()
 main.queue_free()
 await create_timer(.2).timeout
 quit(1 if errors else 0)
