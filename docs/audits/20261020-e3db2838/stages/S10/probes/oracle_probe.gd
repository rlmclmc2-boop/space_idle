extends SceneTree
const R=preload("res://scripts/reactor_integer.gd")
func _initialize():
 var g=BattleGame.new(ShipDatabase.new(),false)
 for level in [97,98,120,1000]:
  g.profile.reactorLevel=level
  print("ORACLE_CAP:",level,":",R.digits(g.reactor_capacity()))
  print("ORACLE_COST:",level,":",R.digits(R.from_growth(g.reactor_upgrade_cost())))
  print("BASELINE_COST:",level,":",R.digits(R.from_growth(ceilf(float(g.db.config.reactorUpgradeBase)*pow(float(g.db.config.reactorUpgradeGrowth),level-1)))))
 g.profile.reactorLevel=97;print("ORACLE_EARLY:97:",R.digits(g.reactor_capacity(2.0)))
 quit()
