extends SceneTree
func _initialize()->void:
 var db:=ShipDatabase.new()
 var g:=BattleGame.new(db,false)
 g.profile.highestLevel=8;g.profile.cleared=range(1,8)
 print("QA_DATA ",JSON.stringify({"points":[db.levels[3].groups.size(),db.levels[4].groups.size(),db.levels[5].groups.size(),db.levels[6].groups.size()],"stage7_iron_ratio":db.levels[6].resRatio,"stage6_3":db.groups["90603"].slots.filter(func(x):return x!=null).size(),"stage7_4":db.groups["90704"].slots.filter(func(x):return x!=null).size(),"stage6_name":db.enemies["600001"].des}))
 assert([db.levels[3].groups.size(),db.levels[4].groups.size(),db.levels[5].groups.size(),db.levels[6].groups.size()]==[8,9,9,9])
 var stage5=[]
 for encounter in db.levels[4].groups:
  var id=int(db.groups[str(int(encounter.id))].slots.filter(func(x):return x!=null)[0])
  stage5.append(str(db.enemies[str(id)].archetype_id))
 assert(stage5==["sentry","sentry","swarm","swarm","anchor","anchor","sentry","swarm","anchor"])
 assert(g.hyperspace.config.unlock_stage==8)
 var loaded=g.manual_hyperspace.load_production(g)
 print("QA_HYPER_PACK ",loaded," reason=",g.manual_hyperspace.last_error)
 assert(loaded)
 quit()
