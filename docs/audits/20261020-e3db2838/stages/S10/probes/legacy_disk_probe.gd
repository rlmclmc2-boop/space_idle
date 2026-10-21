extends SceneTree
const R=preload("res://scripts/reactor_integer.gd")
const W=preload("res://scripts/progress_writer.gd")
func _initialize():call_deferred("run")
func run():
 var db=ShipDatabase.new();var g=BattleGame.new(db,false);g.profile.cleared=[1];g.profile.reactorLevel=98
 g.set_reactor_allocation("weapons",R.make("9007199254740993"))
 var source=JSON.stringify(g.portable_save_data()).replace('{"i":"9007199254740993"}',"9007199254740993")
 var f=FileAccess.open("user://s10-old-progress.json",FileAccess.WRITE);f.store_string(source);f.close()
 var checked=W._check_progress_file("user://s10-old-progress.json",db)
 print("DISK ",checked.get("error")," VALUE ",R.digits(checked.data.reactorAllocation.weapons) if checked.get("error","")=="" else "")
 quit(0 if checked.get("error","")=="" and R.digits(checked.data.reactorAllocation.weapons)=="9007199254740993" else 1)
