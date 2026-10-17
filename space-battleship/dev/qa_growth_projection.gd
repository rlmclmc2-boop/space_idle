extends SceneTree
const AI=preload("res://scripts/ai_tech_tree.gd")
func row(stage:int,level:int,reactor:int,tech:int)->Dictionary:
 var g:=BattleGame.new(ShipDatabase.new(),false)
 g.profile.highestLevel=stage+1;g.profile.cleared=range(1,stage);g.rebuild_unlocks()
 g.profile.loadout.weapons[0]={"key":"longLaser","level":level};g.profile.loadout.defence[0]={"key":"shield","level":level}
 g.profile.reactorLevel=reactor;g.profile.aiTechLevels={"weapon_accuracy":tech,"equipment_reinforcement":tech}
 var cap=g.reactor_capacity();g.profile.reactorAllocation={"weapons":int(cap/2),"defence":cap-int(cap/2)};g.invalidate_stat_cache()
 return {"stage":stage,"level":level,"reactor":reactor,"tech_each":tech,"ai_factor":AI.combat_factor(g,"weapon_damage"),"reactor_capacity":cap,"reactor_multiplier":g.reactor_multiplier("weapons"),"beam_damage":g.equipment_stat("longLaser",level),"shield_capacity":g.equipment_stat("shield",level)}
func _initialize()->void:
 for values in [[6,12,5,1],[7,15,7,2],[7,17,8,3]]:
  print("QA_GROWTH ",JSON.stringify(row(values[0],values[1],values[2],values[3])))
 quit()
