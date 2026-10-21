extends SceneTree
const T=preload("res://scripts/save_transfer.gd")
const R=preload("res://scripts/reactor_integer.gd")
var fails:=0
func check(ok:bool,label:String):
 if not ok:fails+=1;printerr("FAIL ",label)
func _initialize():call_deferred("run")
func run():
 var db=ShipDatabase.new();var g=BattleGame.new(db,true);g.profile.cleared=[1];g.profile.reactorLevel=1500
 g.profile.resources["2"]={"m":1.0,"e":400.0}
 check(g.set_reactor_allocation("weapons",R.make("9007199254740993")),"set exact")
 check(g.set_reactor_allocation("defence",7),"set other")
 check(g.upgrade_reactor(1),"large cost purchase")
 check(g.profile.resources["2"] is Dictionary and g.profile.resources["2"].has("m"),"legacy currency type retained")
 var transfer=T.new();check(transfer.export_progress(g,"user://s10-export.json")==OK,"export")
 var prepared=transfer.prepare("user://s10-export.json",db)
 check(prepared.error.is_empty(),"prepare")
 if prepared.error.is_empty():
  check(R.digits(prepared.data.reactorAllocation.weapons)=="9007199254740993","prepared exact")
  var result=transfer.commit_import(g,prepared.data)
  print("COMMIT ",result.get("error"))
  check(result.error==OK,"commit")
  if result.error==OK:
   var restored=BattleGame.new(db,false)
   var raw=JSON.parse_string(FileAccess.get_file_as_string(BattleGame.SAVE_PATH))
   restored.load_progress_data(raw)
   print("RAW ",raw.reactorAllocation," RESTORED ",restored.profile.reactorAllocation," LEVEL ",restored.profile.reactorLevel);check(R.digits(restored.profile.reactorAllocation.weapons)=="9007199254740993" and R.digits(restored.profile.reactorAllocation.defence)=="7","disk load")
   check(restored.profile.resources["2"]==g.profile.resources["2"],"currency retained")
   transfer.finish(result)
 print("PORTABLE PROBE FAILS ",fails)
 quit(1 if fails else 0)
