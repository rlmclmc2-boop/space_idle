extends SceneTree
func _initialize():
 var db=ShipDatabase.new();db.config.reactorEnergyBase=207.0
 var g=BattleGame.new(db,false);g.profile.cleared=[1];g.profile.planets["1"].conquered=true
 var free=g.charge_free_ratio()
 g.set_reactor_allocation("weapons",207)
 var ratio=g.reactor_effective_ratio("weapons")
 var expected=1.0+pow(207.0+207.0*free,float(db.config.reactorBoostExponent))/float(db.config.reactorPercentScale)
 print("FREE ",free," RATIO ",ratio," GAIN_MATCH ",is_equal_approx(g.reactor_multiplier("weapons"),expected))
 quit(0 if is_equal_approx(ratio,1.1) and is_equal_approx(g.reactor_multiplier("weapons"),expected) else 1)
