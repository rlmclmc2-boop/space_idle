extends SceneTree
# Synthetic post-stage-7 progression with real reactor purchase and manual alpha combat/reward.
func _initialize()->void:
 var g=preload("res://scripts/presented_battle_game.gd").new(ShipDatabase.new(),false)
 g.profile.highestLevel=8;g.profile.cleared=range(1,8)
 g.profile.loadout.weapons[0]={"key":"laser","level":19}
 g.profile.loadout.defence[0]={"key":"armour","level":19}
 g.profile.hightechLevels={BattleGame.ENERGY_FOCUS:1,BattleGame.DENSE_ARMOUR:1}
 g.profile.resources["2"]=400
 print("HYPER_SETUP ",JSON.stringify({"ship":g.profile.selectedShip,"weapon":g.profile.loadout.weapons,"defence":g.profile.loadout.defence,"ai":g.profile.hightechLevels,"reactor_before":g.profile.reactorLevel,"uranium_before":g.profile.resources["2"]}))
 var bought=g.upgrade_reactor(8)
 var cap=g.reactor_capacity()
 var wa=g.set_reactor_allocation("weapons",int(cap/2));var da=g.set_reactor_allocation("defence",cap-int(cap/2))
 g.invalidate_stat_cache()
 print("HYPER_INVEST ",JSON.stringify({"bought":bought,"reactor_after":g.profile.reactorLevel,"capacity":cap,"uranium_after":g.profile.resources["2"],"weapons":g.profile.reactorAllocation.get("weapons"),"defence":g.profile.reactorAllocation.get("defence"),"allocation_ok":[wa,da]}))
 assert(g.manual_hyperspace.load_production(g))
 print("HYPER_GATE ",JSON.stringify({"minimum":g.hyperspace.current_layer(g,"alpha")+1,"material_start":g.hyperspace.config.material_reward_start_level,"layer5_initial":g.hyperspace.eligible_level(g,"alpha",5)}))
 for layer in range(1,2):
  var started:bool=g.manual_hyperspace.request(g,"alpha",layer)
  print("HYPER_ENTER ",layer," ",started," current=",g.hyperspace.current_layer(g,"alpha")," reason=",g.manual_hyperspace.last_error)
  if not started:break
  var frames:=0
  while g.manual_hyperspace.active and frames<72000:
   g.tick(1.0/60.0);frames+=1
  var result:Dictionary=g.manual_hyperspace.last_result.duplicate(true)
  var receipt:Dictionary=g.profile.hyperspace.active.duplicate(true)
  print("HYPER_RESULT ",JSON.stringify({"layer":layer,"result":result,"frames":frames,"pending_reward":receipt.get("reward",{}).get("materials",{}),"material_before_claim":g.profile.hyperspace.materials.get("degenerate_matter",0)}))
  if result.get("reason")!="success":break
  var claimed=g.claim_hyperspace(int(receipt.round_id),int(receipt.run_id))
  print("HYPER_CLAIM ",JSON.stringify({"layer":layer,"claimed":claimed,"current":g.hyperspace.current_layer(g,"alpha"),"degenerate_matter":g.profile.hyperspace.materials.get("degenerate_matter",0)}))
  if not claimed:break
 quit()
