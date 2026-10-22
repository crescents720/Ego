extends SceneTree

var errors:=0
var state
const TEST_DIR := "user://test_odachi_skill"

func _initialize() -> void:call_deferred("run")

func check(ok: bool,message: String) -> void:
 if not ok:
  errors+=1
  push_error("ODACHI_SKILL_SAVE_FAIL: "+message)

func write_fixture(path: String,schema: int,skill_value: Variant=null) -> void:
 var config:=ConfigFile.new()
 config.set_value("meta","schema",schema)
 config.set_value("progress","demo_completed",false)
 if skill_value!=null:config.set_value("progress","odachi_skill_level",skill_value)
 check(config.save(path)==OK,"could not write fixture "+path)

func run() -> void:
 state=root.get_node("GameState")
 state.suppress_save=true
 var current_path:=TEST_DIR+"/current.cfg"
 var legacy_path:=TEST_DIR+"/schema5.cfg"
 var low_path:=TEST_DIR+"/low.cfg"
 var high_path:=TEST_DIR+"/high.cfg"

 state.start_new_run()
 check(state.odachi_skill_level==1,"new game did not reset odachi skill to level 1")
 var signals: Array[int]=[0]
 state.skills_changed.connect(func():signals[0]+=1)
 state.set_odachi_skill_level(5)
 state.set_odachi_skill_level(5)
 check(state.odachi_skill_level==5 and signals[0]==1,"skill setter failed clamp/change-only signal semantics")
 check(state.save_game(current_path)==OK,"schema 6 skill save failed")
 var saved:=ConfigFile.new()
 check(saved.load(current_path)==OK,"saved skill file could not be reopened")
 check(int(saved.get_value("meta","schema",0))==6,"save schema was not advanced to 6")
 check(int(saved.get_value("progress","odachi_skill_level",0))==5,"level 5 missing from save")
 state.start_new_run()
 check(state.load_completed_save(current_path) and state.odachi_skill_level==5,"level 5 did not round-trip through save/load")

 # Schema-5 saves have no weapon-skill field and must migrate to narrative
 # level 1 without rejecting the otherwise valid old save.
 write_fixture(legacy_path,5)
 state.set_odachi_skill_level(4)
 check(state.load_completed_save(legacy_path),"schema-5 fixture was rejected")
 check(state.odachi_skill_level==1,"schema-5 save without field did not default to level 1")

 # Corrupt/out-of-range values are clamped instead of entering an invalid
 # animation table index.
 write_fixture(low_path,6,0)
 state.set_odachi_skill_level(3)
 check(state.load_completed_save(low_path) and state.odachi_skill_level==1,"low skill value was not clamped to 1")
 write_fixture(high_path,6,99)
 state.set_odachi_skill_level(3)
 check(state.load_completed_save(high_path) and state.odachi_skill_level==5,"high skill value was not clamped to 5")

 for path in [current_path,legacy_path,low_path,high_path]:
  if FileAccess.file_exists(path):DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
 DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_DIR))
 print("ODACHI_SKILL_SAVE_CHECK errors=",errors)
 quit(1 if errors else 0)
