extends SceneTree
const R=preload("res://scripts/reactor_integer.gd")
func _initialize():
 var g=BattleGame.new(ShipDatabase.new(),false)
 for level in [97,98,120,140,150,1000,2500]:
  g.profile.reactorLevel=level
  print("ORACLE_CAP:",level,":",R.digits(g.reactor_capacity()))
  print("ORACLE_COST:",level,":",R.digits(R.from_growth(g.reactor_upgrade_cost())))
  var legacy_cost: float=float(g.db.config.reactorUpgradeBase)*pow(float(g.db.config.reactorUpgradeGrowth),level-1)
  if is_finite(legacy_cost):print("BASELINE_COST:",level,":",R.digits(R.float_floor(ceilf(legacy_cost))))
 g.profile.reactorLevel=97;print("ORACLE_EARLY:97:",R.digits(g.reactor_capacity(2.0)))
 quit()
