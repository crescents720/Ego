extends Node3D
# Temple forecourt, beyond the factory on the northwest side of town.
const SITE:=Vector3(-94,.08,345)
const RACK:=Vector3(-94,.95,332.5)
var main
var sword: Node3D
var label: Label3D
func build(owner_main) -> void:
 main=owner_main
 name="ShinobiTemple"
 main.town_layout._box("TempleForecourt",Vector3(25,.05,10),SITE+Vector3(0,-.025,-14),"77786a")
 var model=load("res://assets/temple/temple.glb").instantiate()
 model.position=SITE
 model.rotation.y=PI
 add_child(model)
 main.town_occlusion.register_building(model)
 main.town_layout._add_building_collision(model,"ShinobiTemple")
 # A ground-level offering rack at the front hall; no invisible climb/teleport.
 main.town_layout._box("SwordRackTop",Vector3(1.9,.10,.55),RACK+Vector3(0,-.15,0),"51483b",true)
 for x in [-.7,.7]:main.town_layout._box("SwordRackLeg",Vector3(.12,.72,.42),RACK+Vector3(x,-.51,0),"51483b",true)
 sword=load("res://assets/temple/odachi.glb").instantiate()
 sword.position=RACK+Vector3(-.45,-.055,0)
 sword.rotation.z=-PI/2
 add_child(sword)
 label=Label3D.new()
 label.position=RACK+Vector3(0,1.0,0)
 label.font_size=30
 label.outline_size=7
 label.modulate=Color("e9d99d")
 label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
 add_child(label)
 GameState.inventory_changed.connect(refresh)
 refresh()
func refresh() -> void:
 sword.visible=not GameState.odachi_taken
 label.text="寺庙 · 大太刀 E 拾取" if not GameState.odachi_taken else "寺庙 · 空刀架"
func nearby() -> bool:
 return main.controls_enabled and not main.in_vehicle and not main.inside_rv and not main.inside_store and not main.factory.active and not GameState.odachi_taken and main.hotaru.global_position.distance_to(RACK)<2.5
func interact() -> void:
 if not nearby():return
 if not GameState.try_add_items({"odachi":1}):
  main.rest_notice("背包需要 2.2 kg 空间，腾出位置后再来取刀。")
  return
 GameState.odachi_taken=true
 GameState.equip_item("odachi","right_hand")
 refresh()
 main.rest_notice("获得大太刀，已双手持握。当前可使用单段斜斩。")
