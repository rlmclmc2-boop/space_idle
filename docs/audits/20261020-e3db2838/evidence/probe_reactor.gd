extends SceneTree
func _initialize():
 var db=ShipDatabase.new();var g=BattleGame.new(db,false)
 g.profile.cleared=range(1,db.levels.size()+1);g.rebuild_unlocks()
 g.profile.planets["1"].conquered=true
 g.profile.resources["2"]=1e20
 g.stat_cache_enabled=true;g.invalidate_stat_cache()
 var before=g.equipment_stat("laser",1)
 var rev=g.stat_cache_revision
 var cap=g.reactor_capacity()
 var ok=g.upgrade_reactor(1)
 var cached=g.equipment_stat("laser",1)
 var rev_after=g.stat_cache_revision
 g.invalidate_stat_cache()
 var fresh=g.equipment_stat("laser",1)
 print("REACTOR_UPGRADE ok=",ok," free_ratio=",g.charge_free_ratio()," before_capacity=",cap," after_capacity=",g.reactor_capacity()," before=",before," cached=",cached," fresh=",fresh," rev_before=",rev," rev_after=",rev_after)
 g.profile.reactorLevel=97
 var actual_upgrade=g.upgrade_reactor(1)
 print("ACTUAL_97_TO_98 ok=",actual_upgrade," level=",g.profile.reactorLevel," capacity=",g.reactor_capacity())
 for level in [96,97,98,99,100,101]:
  g.profile.reactorLevel=level
  print("REACTOR_RANGE level=",level," energy=",g.reactor_energy()," capacity=",g.reactor_capacity()," cost=",g.reactor_upgrade_cost())
 quit()
