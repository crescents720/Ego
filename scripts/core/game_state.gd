extends Node
signal inventory_changed
signal survival_changed
signal skills_changed
const CARGO_CAPACITY_G := 1000000
const FUEL_CAPACITY_L := 60.0
const DAY_SECONDS := 360.0
const WATER_INTERVAL := DAY_SECONDS
const FOOD_INTERVAL := DAY_SECONDS/2.0
var store_residents:=2
var store_next_refresh:=180.0
var world_seconds:=0.0
# Compatibility field for old saves; supply no longer consumes stock.
var store_stock: Dictionary={"water":6,"food":12}
const FUEL_PER_M := 0.001
var fuel_l := 6.0
var distance_m := 0.0
var water_clock := 0.0
var food_clock := 0.0
var tutorial_step := 0
var tutorial_water := false
var tutorial_food := false
var vehicle_position:=Vector3(-21.5,1.02,-43.0)
var vehicle_yaw:=PI

const CART_CAPACITY_G := 25000
var cash: int=0
var cash_drops: Array=[]
var cart_owned:=false
var cart_deployed:=false
var cart_use_on_exit:=false
var cart_position:=Vector3.ZERO
var cart_exterior_position:=Vector3.ZERO
var cart_yaw:=0.0
var cart_items: Dictionary={}
var weapon_shop_visited:=false
var weapon_bought:=false
var m60_window:=""
var factory_wire:=0
var factory_refresh_at:=-1.0
var lathe_taken:=false
var lathe_installed:=false
var fence_hp: Dictionary={"front":0,"back":0,"left":0,"right":0}
var fence_job: Dictionary={}
const CAPACITY_G := 10000
const SLOT_NAMES := {"head":"头部","left_hand":"左手","right_hand":"右手","upper":"上身","lower":"下身","feet":"脚部"}
const ITEMS := {
 "wire":{"name":"铁丝","grams":500,"slots":[],"description":"回收铁丝，每份0.5kg。保留用于后续铁丝网加工。"},
 "lathe":{"name":"小型车床","grams":24000,"slots":[],"description":"24kg小型车床，需推车运输。运进房车后在基础维修台交互安装。"},
 "m60":{"name":"M60 机枪","grams":23000,"slots":[],"description":"沉重的 M60，23 kg。只能在房车射击窗架设使用；拆卸后可用推车运输，不能随身携带。"},
 "m60_ammo":{"name":"M60 弹药","grams":4,"slots":[],"description":"M60 配套弹药。500 发合计搬运重量 2 kg。"},
 "odachi":{"name":"寺庙大太刀","grams":2200,"slots":["right_hand"],"description":"双手持握的大太刀，攻击力 4，攻击距离 2.55 米。连击段数随太刀术等级提升。"},
 "bat":{"name":"哥哥的棒球棍","grams":900,"slots":["left_hand","right_hand"],"description":"哥哥一直放在衣柜里的木制棒球棍。攻击力 2；普通丧尸需命中 5 次。"},
 "food":{"name":"面包与口粮","grams":500,"slots":[],"description":"密封面包，每包 0.5 kg。每天需要 1 kg；断粮后约五天从满血降至零。"},
 "water":{"name":"桶装饮水","grams":5000,"slots":[],"description":"5 L 桶装饮水，整桶 5 kg。每天需要 5 L；断水后约三天从满血降至零。"},
 "medicine":{"name":"医疗用品","grams":150,"slots":[],"description":"绷带和消毒用品，一份 0.15 kg。"},
 "scrap":{"name":"维修材料","grams":350,"slots":[],"description":"可用于房车改装的材料，一份 0.35 kg。"},
}
const STORE_LOOT := {"food":{"food":3},"water":{"water":4},"medical":{"medicine":2},"tools":{"scrap":5}}
var items: Dictionary={}
var equipment: Dictionary={"head":"","left_hand":"","right_hand":"","upper":"","lower":"","feet":""}
var cargo: Dictionary={}
var odachi_taken:=false
var odachi_skill_level:=1
var bat_taken := false
var rv_health_ratio:=1.0

const SAVE_PATH := "user://saves/slot_1.cfg"
const LEGACY_SAVE_PATH := "user://firefly_road_save.cfg"
var hero_health_ratio:=1.0
var slot_directory: String="user://saves"

var scrap: int = 0
var food: int = 0
var water: int = 0
var medicine: int = 0
var store_looted: Dictionary = {}
var clue_found: bool = false
var rv_upgrade_level: int = 0
var demo_completed: bool = false
var suppress_save: bool = false


func start_new_run() -> void:
 cash=0
 cash_drops=[]
 cart_owned=false
 cart_deployed=false
 cart_use_on_exit=false
 cart_position=Vector3.ZERO
 cart_exterior_position=Vector3.ZERO
 cart_yaw=0.0
 cart_items={}
 weapon_shop_visited=false
 weapon_bought=false
 m60_window=""
 factory_wire=0
 factory_refresh_at=-1.0
 lathe_taken=false
 lathe_installed=false
 fence_hp={"front":0,"back":0,"left":0,"right":0}
 fence_job={}
 items={}
 equipment={"head":"","left_hand":"","right_hand":"","upper":"","lower":"","feet":""}
 cargo={}
 vehicle_position=Vector3(-21.5,1.02,-43.0)
 vehicle_yaw=PI
 fuel_l=6.0
 distance_m=0.0
 world_seconds=0.0
 store_residents=2
 store_next_refresh=180.0
 store_stock={"water":6,"food":12}
 water_clock=0.0
 food_clock=0.0
 tutorial_step=0
 tutorial_water=false
 tutorial_food=false
 bat_taken=false
 odachi_taken=false
 odachi_skill_level=1
 rv_health_ratio=1.0
 scrap = 0
 food = 0
 water = 0
 medicine = 0
 store_looted = {}
 clue_found = false
 rv_upgrade_level = 0
 demo_completed = false
 _sync_resources()
 inventory_changed.emit()
 survival_changed.emit()
 skills_changed.emit()

func set_odachi_skill_level(value: int) -> void:
 var level:=clampi(value,1,5)
 if odachi_skill_level==level:return
 odachi_skill_level=level
 skills_changed.emit()

func carried_grams() -> int:
 var result:=0
 for id in items:result+=int(ITEMS[id].grams)*int(items[id])
 return result

func equipped_count(id: String) -> int:
 var result:=0
 for slot in equipment:
  if equipment[slot]==id:result+=1
 return result

func can_add(batch: Dictionary) -> bool:
 var total:=carried_grams()
 for id in batch:
  if not ITEMS.has(id) or int(batch[id])<0:return false
  total+=int(ITEMS[id].grams)*int(batch[id])
 return total<=CAPACITY_G

func try_add_items(batch: Dictionary) -> bool:
 if not can_add(batch):
  AudioDirector.ui("reject")
  return false
 for id in batch:items[id]=int(items.get(id,0))+int(batch[id])
 _sync_resources()
 inventory_changed.emit()
 AudioDirector.ui("pickup")
 return true

func equip_item(id: String,slot: String,source_slot: String="") -> bool:
 if not ITEMS.has(id) or not SLOT_NAMES.has(slot) or not slot in ITEMS[id].slots:return false
 if not source_slot.is_empty():
  if equipment.get(source_slot,"")!=id:return false
  equipment[source_slot]=""
 elif int(items.get(id,0))-equipped_count(id)<=0 or cargo_grams()+int(ITEMS[id].grams)>CARGO_CAPACITY_G:return false
 if id=="odachi":equipment["left_hand"]=""
 elif slot=="left_hand" and equipment.get("right_hand","")=="odachi":equipment["right_hand"]=""
 equipment[slot]=id
 inventory_changed.emit()
 AudioDirector.ui("equip")
 return true

func unequip_item(slot: String) -> void:
 if not SLOT_NAMES.has(slot):return
 equipment[slot]=""
 AudioDirector.ui("equip")
 inventory_changed.emit()

func store_item(id: String) -> bool:
 if int(items.get(id,0))-equipped_count(id)<=0 or cargo_grams()+int(ITEMS[id].grams)>CARGO_CAPACITY_G:return false
 items[id]-=1
 if items[id]==0:items.erase(id)
 cargo[id]=int(cargo.get(id,0))+1
 _sync_resources()
 inventory_changed.emit()
 AudioDirector.ui("transfer")
 return true

func retrieve_item(id: String) -> bool:
 if int(cargo.get(id,0))<=0 or not can_add({id:1}):return false
 cargo[id]-=1
 if cargo[id]==0:cargo.erase(id)
 return try_add_items({id:1})

func _sync_resources() -> void:
 for id in ["scrap","food","water","medicine"]:set(id,int(items.get(id,0))+int(cargo.get(id,0)))

func weapon_id() -> String:
 if equipment.get("right_hand","") in ["odachi","bat"]:return equipment.right_hand
 if equipment.get("left_hand","")=="bat":return "bat"
 return ""

func weapon_hand() -> String:
 if equipment.get("right_hand","") in ["bat","odachi"]:return "R"
 if equipment.get("left_hand","")=="bat":return "L"
 return ""


func add_loot(scrap_amount: int, food_amount: int) -> bool:
 if not try_add_items({"scrap":scrap_amount,"food":food_amount}):return false
 clue_found = true
 return true


func can_buy_first_upgrade() -> bool:
 return scrap >= 4 and rv_upgrade_level == 0


func buy_first_upgrade() -> bool:
 if not can_buy_first_upgrade():
  return false
 scrap -= 4
 var remaining:=4
 for container in [items,cargo]:
  var count:=mini(remaining,int(container.get("scrap",0)))
  if count>0:
   container["scrap"]-=count
   if container["scrap"]==0:container.erase("scrap")
   remaining-=count
 inventory_changed.emit()
 rv_upgrade_level = 1
 demo_completed = true
 if not suppress_save:
  save_game()
 return true


func save_game(path: String=SAVE_PATH) -> Error:
 var sessions:=get_tree().get_nodes_in_group("game_session")
 if not sessions.is_empty():
  var session=sessions[0]
  if not session.can_save_safely():return ERR_BUSY
  hero_health_ratio=float(session.hotaru.health)/session.hotaru.max_health
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
 var config := ConfigFile.new()
 config.set_value("meta","schema",6)
 for key in economy_defaults():config.set_value("economy",key,get(key))
 config.set_value("meta","saved_unix",Time.get_unix_time_from_system())
 config.set_value("survivor","health_ratio",hero_health_ratio)
 config.set_value("progress", "scrap", scrap)
 config.set_value("progress", "food", food)
 config.set_value("progress", "water", water)
 config.set_value("progress", "medicine", medicine)
 config.set_value("progress", "store_looted", store_looted)
 config.set_value("progress", "clue_found", clue_found)
 config.set_value("progress", "rv_upgrade_level", rv_upgrade_level)
 config.set_value("progress", "demo_completed", demo_completed)
 config.set_value("progress","rv_health_ratio",rv_health_ratio)
 config.set_value("progress","odachi_skill_level",odachi_skill_level)
 config.set_value("inventory","items",items)
 config.set_value("inventory","equipment",equipment)
 config.set_value("inventory","cargo",cargo)
 config.set_value("inventory","bat_taken",bat_taken)

 for key in ["fuel_l","distance_m","water_clock","food_clock","tutorial_step","tutorial_water","tutorial_food","vehicle_position","vehicle_yaw","world_seconds","store_stock","store_residents","store_next_refresh"]:
  config.set_value("survival",key,get(key))
 return config.save(path)


func _ready() -> void:
 if FileAccess.file_exists(LEGACY_SAVE_PATH) and not FileAccess.file_exists(SAVE_PATH):
  DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://saves"))
  DirAccess.copy_absolute(ProjectSettings.globalize_path(LEGACY_SAVE_PATH),ProjectSettings.globalize_path(SAVE_PATH))

func slot_path(index: int) -> String:
 return "%s/slot_%d.cfg"%[slot_directory,clampi(index,1,6)]

func slot_info(index: int) -> Dictionary:
 var config:=ConfigFile.new()
 if config.load(slot_path(index))!=OK:return {}
 return {"day":int(float(config.get_value("survival","world_seconds",0))/360)+1,"health":float(config.get_value("survivor","health_ratio",1.0)),"saved":int(config.get_value("meta","saved_unix",0)),"fuel":float(config.get_value("survival","fuel_l",6))}

func has_completed_save() -> bool:
 for index in range(1,7):
  if not slot_info(index).is_empty():return true
 return false


func load_completed_save(path: String=SAVE_PATH) -> bool:
 var config := ConfigFile.new()
 if config.load(path) != OK:
  return false
 for key in economy_defaults():set(key,config.get_value("economy",key,economy_defaults()[key]))
 cash=maxi(0,cash)
 hero_health_ratio=clampf(float(config.get_value("survivor","health_ratio",1.0)),0.001,1.0)
 scrap = int(config.get_value("progress", "scrap", 0))
 food = int(config.get_value("progress", "food", 0))
 water = int(config.get_value("progress", "water", 0))
 medicine = int(config.get_value("progress", "medicine", 0))
 store_looted = config.get_value("progress", "store_looted", {})
 clue_found = bool(config.get_value("progress", "clue_found", false))
 rv_upgrade_level = int(config.get_value("progress", "rv_upgrade_level", 0))
 demo_completed = bool(config.get_value("progress", "demo_completed", false))
 rv_health_ratio=clampf(float(config.get_value("progress","rv_health_ratio",1.0)),0.0,1.0)
 odachi_skill_level=clampi(int(config.get_value("progress","odachi_skill_level",1)),1,5)
 items=config.get_value("inventory","items",{"scrap":scrap,"food":food,"water":water,"medicine":medicine})
 equipment=config.get_value("inventory","equipment",{"head":"","left_hand":"","right_hand":"","upper":"","lower":"","feet":""})
 cargo=config.get_value("inventory","cargo",{})
 bat_taken=bool(config.get_value("inventory","bat_taken",false))
 # Old prototype clothes were never separate equipment.
 for container in [items,cargo,cart_items]:
  for id in container.keys():
   if not ITEMS.has(id):container.erase(id)
 for slot in SLOT_NAMES:
  if not ITEMS.has(equipment.get(slot,"")):equipment[slot]=""
 for key in ["fuel_l","distance_m","water_clock","food_clock","tutorial_step","tutorial_water","tutorial_food","vehicle_position","vehicle_yaw","world_seconds","store_stock","store_residents","store_next_refresh"]:
  set(key,config.get_value("survival",key,{"fuel_l":6.0,"distance_m":0.0,"water_clock":0.0,"food_clock":0.0,"tutorial_step":0,"tutorial_water":false,"tutorial_food":false,"vehicle_position":Vector3(-21.5,1.02,-43.0),"vehicle_yaw":PI,"world_seconds":0.0,"store_stock":{"water":6,"food":12},"store_residents":2,"store_next_refresh":180.0}[key]))
 fuel_l=clampf(fuel_l,0,FUEL_CAPACITY_L)
 water_clock=fposmod(water_clock,WATER_INTERVAL)
 food_clock=fposmod(food_clock,FOOD_INTERVAL)
 # Existing saves adopt the new package weights without silently breaking the 10 kg limit.
 for id in items.keys():
  while carried_grams()>CAPACITY_G and int(items.get(id,0))-equipped_count(id)>0:
   if not store_item(id):break
 if int(config.get_value("meta","schema",0))<3:
  for id in ["water","food"]:
   if store_looted.has(id):store_stock[id]=0
 normalize_fence_job()
 _sync_resources()
 inventory_changed.emit()
 survival_changed.emit()
 skills_changed.emit()
 return demo_completed or int(config.get_value("meta","schema",0))>=2


func cargo_grams() -> int:
 var result:=0
 for id in cargo:result+=int(ITEMS[id].grams)*int(cargo[id])
 return result

func tick_survival(delta: float) -> float:
 var elapsed:=maxf(0,delta)
 world_seconds+=elapsed
 var water_missing:=_drain("water",elapsed,WATER_INTERVAL,"water_clock")
 var food_missing:=_drain("food",elapsed,FOOD_INTERVAL,"food_clock")
 _sync_resources()
 survival_changed.emit()
 return maxf(water_missing/(DAY_SECONDS*3.0),food_missing/(DAY_SECONDS*5.0))

func _drain(id: String,seconds: float,interval: float,clock_key: String) -> float:
 var count: int=int(items.get(id,0))+int(cargo.get(id,0))
 var clock: float=get(clock_key)
 if count==0:
  set(clock_key,0.0)
  return seconds
 var fed:=minf(seconds,count*interval-clock)
 clock+=fed
 var consumed:=false
 while clock>=interval-0.00001:
  clock=maxf(0,clock-interval)
  if not _consume_one(id):break
  consumed=true
 set(clock_key,clock)
 if consumed:inventory_changed.emit()
 return maxf(0,seconds-fed)

func is_night() -> bool:
 return fposmod(world_seconds,DAY_SECONDS)>=DAY_SECONDS/2

func water_liters(container: Dictionary={}) -> float:
 if not container.is_empty():return int(container.get("water",0))*5.0
 return maxf(0,(int(items.get("water",0))+int(cargo.get("water",0)))*5.0-water_clock/WATER_INTERVAL*5.0)

func container_for(source: String) -> Dictionary:
 match source:
  "bag":return items
  "cargo":return cargo
  "cart":return cart_items
 return {}

func container_grams(container: Dictionary) -> int:
 var total:=0
 for id in container:
  if ITEMS.has(id):total+=int(ITEMS[id].grams)*int(container[id])
 return total

func cart_grams() -> int:
 return container_grams(cart_items)

func move_stack(id: String,source: String,destination: String,count: int) -> bool:
 if not ITEMS.has(id) or count<=0 or source==destination:return false
 if id=="m60" and source=="cargo" and not m60_window.is_empty():return false
 if not source in ["bag","cargo","cart"] or not destination in ["bag","cargo","cart","trash"]:return false
 if (source=="cart" or destination=="cart") and not cart_owned:return false
 var from:=container_for(source)
 if int(from.get(id,0))-(equipped_count(id) if source=="bag" else 0)<count:return false
 var limits: Dictionary={"bag":CAPACITY_G,"cargo":CARGO_CAPACITY_G,"cart":CART_CAPACITY_G}
 if destination!="trash" and container_grams(container_for(destination))+int(ITEMS[id].grams)*count>int(limits[destination]):return false
 from[id]-=count
 if from[id]==0:from.erase(id)
 if destination!="trash":
  var to:=container_for(destination)
  to[id]=int(to.get(id,0))+count
 _sync_resources()
 inventory_changed.emit()
 AudioDirector.ui("trash" if destination=="trash" else "transfer")
 return true

func economy_defaults() -> Dictionary:
 return {"odachi_taken":false,"fence_hp":{"front":0,"back":0,"left":0,"right":0},"fence_job":{},"factory_wire":0,"factory_refresh_at":-1.0,"lathe_taken":false,"lathe_installed":false,"cash":0,"cash_drops":[],"cart_owned":false,"cart_deployed":false,"cart_use_on_exit":false,"cart_position":Vector3.ZERO,"cart_exterior_position":Vector3.ZERO,"cart_yaw":0.0,"cart_items":{},"weapon_shop_visited":false,"weapon_bought":false,"m60_window":""}

func buy_m60() -> bool:
 if cash<1000 or weapon_bought or cart_owned:return false
 cash-=1000
 weapon_bought=true
 cart_owned=true
 cart_items={"m60":1,"m60_ammo":500}
 cart_deployed=true
 inventory_changed.emit()
 return true

func unload_cart() -> bool:
 if cargo_grams()+cart_grams()>CARGO_CAPACITY_G:return false
 for id in cart_items:cargo[id]=int(cargo.get(id,0))+int(cart_items[id])
 cart_items.clear()
 cart_deployed=false
 _sync_resources()
 inventory_changed.emit()
 return true

func take_stock(id: String,count: int,destination: String="bag") -> bool:
 if count<=0 or not id in ["water","food"]:return false
 if destination=="cart":
  if not cart_owned or not cart_deployed or cart_grams()+int(ITEMS[id].grams)*count>CART_CAPACITY_G:return false
  cart_items[id]=int(cart_items.get(id,0))+count
  inventory_changed.emit()
 elif destination=="bag":
  if not try_add_items({id:count}):return false
 else:return false
 store_looted[id]=true
 return true

func _consume_one(id: String) -> bool:
 # Prefer the carried ration while on foot; both stores belong to this survivor.
 for container in [items,cargo]:
  if int(container.get(id,0))>0:
   container[id]-=1
   if container[id]==0:container.erase(id)
   return true
 return false

func consume_distance(meters: float) -> void:
 var travelled:=maxf(0,meters)
 distance_m+=travelled
 fuel_l=maxf(0,fuel_l-travelled*FUEL_PER_M)
 survival_changed.emit()

func deposit_all() -> int:
 var moved:=0
 for id in items.keys():
  while int(items.get(id,0))-equipped_count(id)>0:
   if not store_item(id):break
   moved+=1
 return moved

func apply_cheat(code: String) -> bool:
 if code.strip_edges().to_lower()!="showmethemoney":return false
 cash+=10000
 inventory_changed.emit()
 return true


func fence_recipe(side: String) -> Dictionary:
 return {"wire":4 if side in ["front","back"] else 6,"seconds":DAY_SECONDS/24.0}
func normalize_fence_job() -> void:
 if fence_job.is_empty() or fence_job.has("stage"):return
 var old_seconds:=20.0 if str(fence_job.get("side","front")) in ["front","back"] else 30.0
 var remaining:=maxf(0,float(fence_job.get("finish",world_seconds+old_seconds))-world_seconds)
 var done:=clampf(1.0-remaining/old_seconds,0,1)*15.0
 fence_job={"side":str(fence_job.get("side","front")),"stage":"install" if done>=15 else "craft","work":done,"install_work":0.0}
func start_fence_job(side: String) -> bool:
 normalize_fence_job()
 if not side in ["front","back","left","right"] or not lathe_installed or not fence_job.is_empty() or int(fence_hp.get(side,0))>0:return false
 var recipe:=fence_recipe(side)
 if int(cargo.get("wire",0))<int(recipe.wire):return false
 cargo.wire-=int(recipe.wire)
 if cargo.wire<=0:cargo.erase("wire")
 fence_job={"side":side,"stage":"craft","work":0.0,"install_work":0.0}
 inventory_changed.emit()
 return true
func advance_fence_work(delta: float,stage: String) -> bool:
 normalize_fence_job()
 if fence_job.is_empty() or str(fence_job.stage)!=stage:return false
 var key: String="work" if stage=="craft" else "install_work"
 var duration:=DAY_SECONDS/24.0 if stage=="craft" else 8.0
 fence_job[key]=minf(duration,float(fence_job.get(key,0))+maxf(0,delta))
 if float(fence_job[key])<duration:return false
 if stage=="craft":fence_job.stage="install"
 else:
  fence_hp[str(fence_job.side)]=500
  fence_job={}
 inventory_changed.emit()
 return true
func fences_need_repair() -> bool:
 for hp in fence_hp.values():
  if int(hp)>0 and int(hp)<500:return true
 return false
func repair_fences() -> void:
 for side in fence_hp:
  if int(fence_hp[side])>0:fence_hp[side]=500
 inventory_changed.emit()


func spatial_room_id(point: Vector3) -> int:
 # Rooms are centred on x=0/1000/2000/3000; use nearest centre, not truncation.
 return roundi(point.x/1000.0)
