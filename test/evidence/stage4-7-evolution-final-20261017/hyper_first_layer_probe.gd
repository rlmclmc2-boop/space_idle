extends SceneTree
# Synthetic post-stage-7 loadout probe. This enters the production route and runs combat.
func _initialize()->void:
 var g=preload("res://scripts/presented_battle_game.gd").new(ShipDatabase.new(),false)
 g.profile.highestLevel=8
 g.profile.cleared=range(1,8)
 g.profile.loadout.weapons[0].level=19
 g.profile.loadout.defence[0].level=19
 g.profile.hightechLevels={BattleGame.ENERGY_FOCUS:1,BattleGame.DENSE_ARMOUR:1}
 g.profile.reactorAllocation={"weapons":50,"defence":50}
 g.invalidate_stat_cache()
 var loaded:bool=g.manual_hyperspace.load_production(g)
 print("HYPER_PACK ",loaded," gate=",g.hyperspace.config.unlock_stage," eligible=",g.hyperspace.eligible_level(g,"alpha",1))
 assert(loaded)
 var started:bool=g.manual_hyperspace.request(g,"alpha",1)
 print("HYPER_ENTER ",started," state=",g.state," active=",g.manual_hyperspace.active)
 assert(started)
 var frames:=0
 while g.manual_hyperspace.active and frames<72000:
  g.tick(1.0/60.0)
  frames+=1
 print("HYPER_RESULT ",JSON.stringify(g.manual_hyperspace.last_result)," frames=",frames)
 print("HYPER_MATERIAL ",g.profile.hyperspace.materials.degenerate_matter)
 quit()
