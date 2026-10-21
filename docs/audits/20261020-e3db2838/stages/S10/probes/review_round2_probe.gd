extends SceneTree
const R=preload("res://scripts/reactor_integer.gd")
const N=preload("res://scripts/growth_number.gd")
const T=preload("res://scripts/save_transfer.gd")
var failures:=0
func check(ok: bool,label: String) -> void:
 if not ok:
  failures+=1
  printerr("FAIL ",label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var legacy=N.multiply({"m":1.0,"e":20.0},2)
 check(not (legacy is Dictionary and legacy.has("i")),"legacy multiply type")
 var legacy_damage=N.multiply({"m":1.0,"e":400.0},2)
 var main=preload("res://scripts/main.gd").new()
 main.show_damage_numbers=false
 main.queue_damage_number({"player":true,"uid":1,"type":1,"critical":false,"amount":legacy_damage,"absorbed":0})
 check(main.damage_history_records.size()==1 and main.damage_history_records[0][4].has("m"),"real damage history")
 main.free()
 var enormous={"m":1.0,"e":1000000000.0}
 check(R.from_growth(enormous)==null and N.valid(enormous),"large exponent stays legacy")
 var db=ShipDatabase.new()
 var legacy_game=BattleGame.new(db,false)
 legacy_game.profile.cleared=[1]
 check(not legacy_game.reactor_affordable(R.make("100000000000000000005"),{"m":1.0,"e":20.0}),"legacy near-cost compare")
 check(legacy_game.reactor_affordable(10,enormous),"large legacy exponent compare")
 legacy_game.profile.resources["2"]=enormous
 check(legacy_game.upgrade_reactor(1) and N.valid(legacy_game.profile.resources["2"]),"large legacy wallet purchase without expansion")
 var g=BattleGame.new(db,true)
 g.profile.cleared=[1]
 g.profile.resources["2"]={"v":1,"i":"9007199254741003"}
 check(g.upgrade_reactor(1),"buy with exact tagged budget")
 check(R.digits(g.profile.resources["2"])=="9007199254740993","live balance")
 var transfer=T.new()
 var serialized=JSON.stringify(g.portable_save_data())
 var parsed=JSON.parse_string(serialized)
 check(parsed.resources["2"] is Dictionary and parsed.resources["2"].get("i","")=="9007199254740993","JSON balance")
 g.save_progress()
 var durable=JSON.parse_string(FileAccess.get_file_as_string(BattleGame.SAVE_PATH))
 check(durable.resources["2"] is Dictionary and durable.resources["2"].get("i","")=="9007199254740993","direct disk save")
 check(transfer.export_progress(g,"user://s10-round2-export.json")==OK,"export")
 var prepared=transfer.prepare("user://s10-round2-export.json",db)
 check(prepared.error.is_empty() and R.digits(prepared.data.resources["2"])=="9007199254740993","prepare")
 if prepared.error.is_empty():
  var result=transfer.commit_import(g,prepared.data)
  check(result.error==OK,"commit")
  if result.error==OK:
   var reread=BattleGame.new(db,false)
   reread.load_progress_data(JSON.parse_string(FileAccess.get_file_as_string(BattleGame.SAVE_PATH)))
   check(R.digits(reread.profile.resources["2"])=="9007199254740993","disk reopen")
   transfer.finish(result)
 for body in [
  '"defence":0.0,"weapons":9007199254740993',
  '"weapons":9007199254740993,"defence":0.0',
  '"defence":0e0,"weapons":9007199254740993.0',
  '"defence":-0.0,"weapons":9007199254740993',
  '"defence":0.0,"weapons":9.007199254740993e15',
  '"defence":{"v":1,"i":"9007199254740993"},"weapons":9007199254740995',
 ]:
  var source='{"reactorAllocation":{'+body+'}}'
  var raw=JSON.parse_string(source)
  var restored=T.restore_legacy_reactor_integers(source,raw)
  check(restored and R.digits(raw.reactorAllocation.weapons)==("9007199254740995" if body.contains("9007199254740995") else "9007199254740993"),"legacy body "+body)
  check(restored and T.shape(raw.reactorAllocation,T.schema().reactorAllocation),"legacy schema "+body)
 var duplicate='{"reactorAllocation":{"weapons":0,"weapons":9007199254740993}}'
 check(not T.restore_legacy_reactor_integers(duplicate,JSON.parse_string(duplicate)),"duplicate reject")
 var invalid='{"reactorAllocation":{"defence":0.0,"weapons":1.5}}'
 check(not T.restore_legacy_reactor_integers(invalid,JSON.parse_string(invalid)),"fraction reject")
 for level in [140,150,1000]:
  g.profile.reactorLevel=level
  var original=ceilf(float(db.config.reactorUpgradeBase)*pow(float(db.config.reactorUpgradeGrowth),level-1))
  check(g.reactor_upgrade_cost()==original,"finite old cost "+str(level))
 var ordinary_batch=BattleGame.new(db,false)
 ordinary_batch.profile.cleared=[1]
 ordinary_batch.profile.reactorLevel=140
 ordinary_batch.profile.resources["2"]=1e25
 var old_total:=0.0
 for offset in 10:old_total+=ceilf(float(db.config.reactorUpgradeBase)*pow(float(db.config.reactorUpgradeGrowth),139+offset))
 check(ordinary_batch.upgrade_reactor(10),"finite batch buy")
 check(ordinary_batch.profile.resources["2"]==N.subtract(1e25,old_total),"finite batch old float sum")
 print("REVIEW ROUND2 FAILURES ",failures)
 quit(1 if failures else 0)
