extends SceneTree
const R=preload("res://scripts/reactor_integer.gd")
var fails:=0
func check(ok:bool,label:String):
 if not ok:fails+=1;printerr("FAIL ",label)
func _initialize():call_deferred("run")
func run():
 var db=ShipDatabase.new()
 var g=BattleGame.new(db,false)
 g.profile.cleared=[1]
 check(R.digits(R.subtract(R.make("100000000000000000000"),5))=="99999999999999999995","sub")
 check(R.div_small(R.make("100000000000000000000"),3)[1]==1,"remainder")
 g.profile.reactorLevel=97
 print("CAP97 ",R.digits(g.reactor_capacity()))
 g.profile.reactorLevel=98
 print("CAP98 ",R.digits(g.reactor_capacity()))
 check(R.compare(g.reactor_capacity(),R.make("9223372036854775807"))>0,"98 above int")
 check(g.set_reactor_allocation("weapons",5),"set5")
 check(g.set_reactor_allocation("defence",7),"set7")
 check(R.digits(g.reactor_allocated())=="12","total12")
 check(R.digits(R.subtract(g.reactor_capacity(),g.reactor_allocated()))=="12046257112154525540","remaining")
 var saved=JSON.stringify(g.portable_save_data())
 var parsed=JSON.parse_string(saved)
 var other=BattleGame.new(db,false)
 other.load_progress_data(parsed)
 check(R.digits(other.profile.reactorAllocation.weapons)=="5" and R.digits(other.profile.reactorAllocation.defence)=="7","roundtrip")
 check(g.equalize_reactor_allocation(),"equalize")
 check(R.compare(g.reactor_allocated(),g.reactor_capacity())==0,"equalized total")
 print("S10 PROBE FAILS ",fails)
 quit(1 if fails else 0)
