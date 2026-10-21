extends SceneTree
const N=preload("res://scripts/growth_number.gd")
func _initialize():call_deferred("run")
func run():
 var g=BattleGame.new(ShipDatabase.new(),false);g.profile.cleared=[1];g.profile.reactorLevel=2500;g.profile.planets["1"].conquered=true
 g.profile.resources["2"]={"m":1.0,"e":400.0}
 var cap=g.reactor_capacity();var gain=g.reactor_multiplier("weapons")
 print("FREE ",g.charge_free_ratio()," ALLOC ",g.reactor_allocated()," GAIN ",N.text(gain))
 var bought=g.upgrade_reactor(1)
 var after=g.reactor_multiplier("weapons")
 print("BUY ",bought," LEVEL ",g.profile.reactorLevel," GREW ",N.compare(after,gain)>0," CACHE ",g.stat_cache_revision)
 quit(0 if bought and N.compare(after,gain)>0 and g.reactor_allocated()==0 and g.stat_cache_revision>0 else 1)
