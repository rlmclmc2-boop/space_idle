extends SceneTree
func _initialize():
 var db=ShipDatabase.new();db.config.reactorEnergyBase=208.0
 var g=BattleGame.new(db,false);g.profile.cleared=[1]
 print("MODULES ",g.reactor_available_modules()," EQUAL ",g.equalize_reactor_allocation()," VALUES ",g.profile.reactorAllocation)
 quit(0 if g.profile.reactorAllocation.weapons==70 and g.profile.reactorAllocation.defence==69 and g.profile.reactorAllocation.smelting==69 else 1)
