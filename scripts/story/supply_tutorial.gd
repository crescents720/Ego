extends Node
var main
var card: PanelContainer
var text: Label
var completion_time:=0.0
func build(owner_main) -> void:
 main=owner_main
 card=PanelContainer.new()
 card.position=Vector2(28,240)
 card.size=Vector2(420,115)
 var style:=StyleBoxFlat.new()
 style.bg_color=Color("233c3be6")
 style.border_color=Color("8aada0")
 style.set_border_width_all(1)
 style.set_corner_radius_all(12)
 for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:style.set_content_margin(side,12)
 card.add_theme_stylebox_override("panel",style)
 main.get_node("HUD").add_child(card)
 text=Label.new()
 text.custom_minimum_size=Vector2(390,0)
 text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 text.add_theme_font_size_override("font_size",21)
 text.add_theme_color_override("font_color",Color("f1e7bc"))
 card.add_child(text)
 card.hide()

func begin() -> void:
 if GameState.tutorial_step!=0:return
 GameState.tutorial_step=1
 main.hint_label.text="小萤：要活下去，得先找到食物和水。便利店也许还有补给。"

func on_enter_store() -> void:
 if GameState.tutorial_step in [1,2]:GameState.tutorial_step=2

func on_loot(id: String) -> void:
 if GameState.tutorial_step not in [1,2,3]:return
 if id=="water":GameState.tutorial_water=true
 if id=="food":GameState.tutorial_food=true
 if GameState.tutorial_water and GameState.tutorial_food:
  GameState.tutorial_step=3
  main._set_phase(main.Phase.RETURN_TO_RV)

func check_delivery() -> void:
 if GameState.tutorial_step!=3:return
 if int(GameState.cargo.get("water",0))>=1 and int(GameState.cargo.get("food",0))>=1:
  AudioDirector.ui("complete")
  GameState.tutorial_step=4
  completion_time=0
  if not GameState.clue_found:main._set_phase(main.Phase.EXPLORE)
  if not GameState.suppress_save:GameState.save_game()

func target() -> Vector3:
 return main.rv.global_position if GameState.tutorial_step==3 else main.STORE_DOOR

func route() -> PackedVector2Array:
 var result:=PackedVector2Array()
 if GameState.tutorial_step not in [1,2,3]:return result
 var actor: Node3D=main.rv if main.in_vehicle else main.hotaru
 var p:=Vector2(actor.global_position.x,actor.global_position.z)
 var goal:=Vector2(target().x,target().z)
 result.append(p)
 if GameState.tutorial_step in [1,2] and p.x< -5 and p.y< -20:
  result.append(Vector2(-24,-33))
  result.append(Vector2(0,-33))
 result.append(Vector2(0,p.y if p.x>= -5 else -33))
 result.append(Vector2(0,goal.y))
 result.append(goal)
 return result

func update(delta: float) -> void:
 var step: int=GameState.tutorial_step
 card.visible=not main.factory.active and not (is_instance_valid(main.shooting) and main.shooting.active) and step>0 and main.phase not in [main.Phase.TITLE,main.Phase.GAME_OVER] and not main.dialog_panel.visible and not main.opening.is_cinematic()
 if not card.visible:return
 match step:
  1:
   text.text="初次补给  1 / 3\n先找到食物和水，才能活下去。\n沿小地图金色路线驾车前往便利店。"
   if not main.inside_rv:
    main.hint_label.text="便利店还有食物和水 · 到店停车，起身后从右侧门下车。"
  2:
   text.text="初次补给  2 / 3\n%s 饮水  ·  %s 面包\n可击倒或绕开店内丧尸。"%["✓" if GameState.tutorial_water else "□","✓" if GameState.tutorial_food else "□"]
   if main.inside_store and store_focus_empty():main.hint_label.text="水每桶 5 kg，面包每包 0.5 kg；背包上限 10 kg。\n找到蓝色饮水架和黄色面包架，靠近后交互。"
  3:
   text.text="初次补给  3 / 3\n带回房车，在驾驶座打开「房车管理 → 货物整理」存入补给。"
  4:
   completion_time+=delta
   text.text="补给完成 ✓\n房车有了食物和水。留意消耗，继续探索小镇。"
   if completion_time>8:card.hide()
 if GameState.fuel_l<=0:main.hint_label.text="燃油耗尽：房车无法继续行驶。"

func store_focus_empty() -> bool:
 return main.store_interior.focus(main.hotaru.global_position).is_empty()
