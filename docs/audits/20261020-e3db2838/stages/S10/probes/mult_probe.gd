extends SceneTree
const R=preload("res://scripts/reactor_integer.gd")
const N=preload("res://scripts/growth_number.gd")
func _initialize():call_deferred("run")
func run():
 var db=ShipDatabase.new();var g=BattleGame.new(db,false);g.profile.cleared=[1]
 g.profile.reactorLevel=2500
 var cap=g.reactor_capacity()
 print("CAPLEN ",R.digits(cap).length())
 var share=R.div_small(cap,4)[0]
 print("SET ",g.set_reactor_allocation("weapons",share))
 var m=g.reactor_multiplier("weapons")
 print("MULT ",N.text(m)," VALID ",N.valid(m))
 var stat=g.stat("laser")
 print("STAT ",N.text(stat)," VALID ",N.valid(stat))
 quit(0 if N.valid(m) and N.valid(stat) else 1)
