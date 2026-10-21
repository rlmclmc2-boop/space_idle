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
 var wallet={"m":8.584232684623766,"e":310.0}
 var one=BattleGame.new(db,true)
 one.profile.cleared=[1]
 one.profile.reactorLevel=2379
 one.profile.resources["2"]=wallet.duplicate(true)
 var quote=one.reactor_upgrade_cost()
 var expanded=R.nearby_legacy_integer(wallet,quote)
 check(expanded!=null and R.compare(expanded,quote)>0,"near wallet materialized above quote")
 var expected=R.subtract(expanded,quote) if expanded!=null else 0
 var max_count=one.reactor_max_upgrades()
 check(max_count>=1,"MAX sees affordable first quote")
 var max_game=BattleGame.new(db,false)
 max_game.profile.cleared=[1]
 max_game.profile.reactorLevel=2379
 max_game.profile.resources["2"]=wallet.duplicate(true)
 for index in max_count:check(max_game.upgrade_reactor(1),"MAX amount each "+str(index))
 check(not max_game.upgrade_reactor(1),"MAX next unaffordable")
 var short=BattleGame.new(db,false)
 short.profile.cleared=[1]
 short.profile.reactorLevel=2379
 short.profile.resources["2"]={"m":8.584232684623760,"e":310.0}
 check(not short.reactor_affordable(quote,short.profile.resources["2"]) and short.reactor_max_upgrades()==0 and not short.upgrade_reactor(1),"legacy below quote")
 short.profile.resources["2"]=R.subtract(quote,1)
 check(short.reactor_max_upgrades()==0 and not short.upgrade_reactor(1),"exact quote minus one")
 short.profile.resources["2"]=quote
 check(short.reactor_max_upgrades()>=1 and short.upgrade_reactor(1) and R.compare(short.profile.resources["2"],0)==0,"exact quote")
 check(one.upgrade_reactor(1),"single purchase")
 check(R.compare(one.profile.resources["2"],expected)==0 and R.compare(expected,0)>0,"single exact positive remainder")
 var ten_total: Variant=0
 for offset in 10:ten_total=R.add(ten_total,R.from_growth(one.reactor_upgrade_cost(2379+offset)))
 var batch_wallet={"m":1.234567890123456,"e":float(R.digits(ten_total).length())}
 var batch_exact=R.nearby_legacy_integer(batch_wallet,quote)
 check(batch_exact!=null and R.compare(batch_exact,ten_total)>=0,"legacy x10 affordable")
 var batch=BattleGame.new(db,false)
 var singles=BattleGame.new(db,false)
 for game in [batch,singles]:
  game.profile.cleared=[1]
  game.profile.reactorLevel=2379
  game.profile.resources["2"]=batch_wallet.duplicate(true)
 check(batch.upgrade_reactor(10),"legacy x10")
 for index in 10:check(singles.upgrade_reactor(1),"legacy ten singles "+str(index))
 if R.compare(batch_exact,ten_total)>=0 and R.valid(batch.profile.resources["2"]) and R.valid(singles.profile.resources["2"]):
  check(R.compare(batch.profile.resources["2"],R.subtract(batch_exact,ten_total))==0 and R.compare(batch.profile.resources["2"],singles.profile.resources["2"])==0,"legacy x10 exact sum equals singles")
 var parsed=JSON.parse_string(JSON.stringify(one.portable_save_data()))
 check(parsed.resources["2"] is Dictionary and parsed.resources["2"].get("i","")==R.digits(expected),"portable JSON remainder")
 one.save_progress()
 var disk=JSON.parse_string(FileAccess.get_file_as_string(BattleGame.SAVE_PATH))
 check(disk.resources["2"] is Dictionary and disk.resources["2"].get("i","")==R.digits(expected),"disk remainder")
 var transfer=T.new()
 check(transfer.export_progress(one,"user://s10-round4-export.json")==OK,"export")
 var prepared=transfer.prepare("user://s10-round4-export.json",db)
 check(prepared.error.is_empty() and R.compare(prepared.data.resources["2"],expected)==0,"prepare")
 if prepared.error.is_empty():
  var result=transfer.commit_import(one,prepared.data)
  check(result.error==OK,"commit")
  if result.error==OK:
   var reopened=BattleGame.new(db,false)
   reopened.load_progress_data(JSON.parse_string(FileAccess.get_file_as_string(BattleGame.SAVE_PATH)))
   check(R.compare(reopened.profile.resources["2"],expected)==0,"disk reopen")
   transfer.finish(result)
 var huge={"m":1.0,"e":1000000000.0}
 check(R.nearby_legacy_integer(huge,quote)==null,"distant exponent not expanded")
 print("ROUND4 quote=",R.digits(quote)," wallet=",R.digits(expanded)," remainder=",R.digits(expected)," failures=",failures)
 quit(1 if failures else 0)
