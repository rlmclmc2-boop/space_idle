extends SceneTree
const R=preload("res://scripts/reactor_integer.gd")
const T=preload("res://scripts/save_transfer.gd")
var failures:=0
func check(ok: bool,label: String) -> void:
 if not ok:
  failures+=1
  printerr("FAIL ",label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var db=ShipDatabase.new()
 var original=R.make("10000000000000000000000000")
 var bulk=BattleGame.new(db,false)
 var singles=BattleGame.new(db,false)
 for game in [bulk,singles]:
  game.profile.cleared=[1]
  game.profile.reactorLevel=140
  game.profile.resources["2"]=original.duplicate(true)
 var quoted: Variant=0
 for offset in 10:
  quoted=R.add(quoted,R.from_growth(bulk.reactor_upgrade_cost(140+offset)))
 check(bulk.upgrade_reactor(10),"exact x10")
 var each:=true
 for index in 10:each=singles.upgrade_reactor(1) and each
 check(each,"ten exact singles")
 var expected=R.subtract(original,quoted)
 check(R.compare(bulk.profile.resources["2"],singles.profile.resources["2"])==0,"x10 equals singles")
 check(R.compare(bulk.profile.resources["2"],expected)==0,"exact quote sum debit")
 print("EXACT X10 ",R.digits(bulk.profile.resources["2"])," SINGLES ",R.digits(singles.profile.resources["2"])," QUOTED ",R.digits(quoted))
 var escaped='{"reactor\\u0041llocation":{"weapons":0}}'
 var raw=JSON.parse_string(escaped)
 check(raw is Dictionary and raw.has("reactorAllocation"),"escaped JSON parses to semantic key")
 check(T.restore_legacy_reactor_integers(escaped,raw),"escaped top-level key accepted")
 check(T.shape(raw.reactorAllocation,T.schema().reactorAllocation),"escaped allocation shape")
 var duplicate='{"reactorAllocation":{"weapons":0},"reactor\\u0041llocation":{"weapons":1}}'
 check(not T.restore_legacy_reactor_integers(duplicate,JSON.parse_string(duplicate)),"semantic duplicate rejected")
 print("REVIEW ROUND3 FAILURES ",failures)
 quit(1 if failures else 0)
