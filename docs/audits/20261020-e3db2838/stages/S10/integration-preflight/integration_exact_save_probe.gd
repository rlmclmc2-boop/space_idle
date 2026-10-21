extends SceneTree
const R=preload("res://scripts/reactor_integer.gd")
var failures:=0
func check(ok: bool,label: String) -> void:
 if not ok:
  failures+=1
  printerr("FAIL ",label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var db=ShipDatabase.new()
 var game=BattleGame.new(db,true)
 game.profile.cleared=[1]
 game.profile.reactorLevel=1500
 var allocation=R.make("9007199254740993")
 var remainder=R.make("9007199254741003")
 var price=R.from_growth(game.reactor_upgrade_cost())
 game.profile.resources["2"]=R.add(price,remainder)
 check(game.set_reactor_allocation("weapons",allocation),"high exact allocation")
 check(game.upgrade_reactor(1),"purchase exact high wallet")
 check(R.compare(game.profile.resources["2"],remainder)==0,"live exact remainder")
 game.save_progress()
 var raw=JSON.parse_string(FileAccess.get_file_as_string(BattleGame.SAVE_PATH))
 check(raw is Dictionary and raw.reactorAllocation.weapons is Dictionary and raw.reactorAllocation.weapons.get("i","")==R.digits(allocation),"disk encoded allocation")
 check(raw is Dictionary and raw.resources["2"] is Dictionary and raw.resources["2"].get("i","")==R.digits(remainder),"disk encoded remainder")
 var reopened=BattleGame.new(db,false)
 reopened.load_progress_data(raw)
 check(R.compare(reopened.profile.reactorAllocation.weapons,allocation)==0,"reopened allocation")
 check(R.compare(reopened.profile.resources["2"],remainder)==0,"reopened remainder")
 check(reopened.profile.reactorLevel==1501,"reopened level")
 print("INTEGRATION EXACT SAVE failures=",failures," allocation=",R.digits(allocation)," remainder=",R.digits(remainder))
 quit(1 if failures else 0)
