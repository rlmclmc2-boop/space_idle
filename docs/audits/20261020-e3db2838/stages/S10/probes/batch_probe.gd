extends SceneTree
const R=preload("res://scripts/reactor_integer.gd")
func _initialize():call_deferred("run")
func run():
 var db=ShipDatabase.new();var a=BattleGame.new(db,false);var b=BattleGame.new(db,false)
 for g in [a,b]:g.profile.cleared=[1];g.profile.reactorLevel=1500;g.profile.resources["2"]={"m":1.0,"e":400.0}
 var batch=a.upgrade_reactor(10)
 var singles=true
 for i in 10:singles=singles and b.upgrade_reactor(1)
 var equal=a.profile.reactorLevel==b.profile.reactorLevel and a.profile.resources["2"]==b.profile.resources["2"]
 print("BATCH ",batch," SINGLES ",singles," EQUAL ",equal," LEFTLEN ",R.digits(a.profile.resources["2"]).length())
 quit(0 if batch and singles and equal else 1)
