extends SceneTree
const R=preload("res://scripts/reactor_integer.gd")
const N=preload("res://scripts/growth_number.gd")
func _initialize():call_deferred("run")
func run():
 var db=ShipDatabase.new();var g=BattleGame.new(db,false);g.profile.cleared=[1,15];g.rebuild_unlocks()
 g.profile.reactorLevel=2500
 var share=R.div_small(g.reactor_capacity(),4)[0]
 print("AVAILABLE ",g.reactor_available_modules())
 print("SET ",g.set_reactor_allocation("condensation",share))
 var m=g.reactor_multiplier("condensation")
 print("MULT ",N.text(m))
 var income=g.settle_jewel_fragments(1.0,"drop",1.0)
 print("INCOME ",N.text(income)," VALID ",N.valid(income))
 quit(0 if N.valid(income) else 1)
