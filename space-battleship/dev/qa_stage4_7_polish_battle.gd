extends SceneTree
func encounter(stage:int,point:int,weapon:String,wlevel:int,defence:String,dlevel:int,reactor:int,tech:int)->Dictionary:
 var g:=BattleGame.new(ShipDatabase.new(),false)
 g.profile.highestLevel=stage+1;g.profile.cleared=range(1,stage)
 g.rebuild_unlocks();g.pending_unlocks.clear()
 g.profile.loadout.weapons[0]={"key":weapon,"level":wlevel}
 g.profile.loadout.defence[0]={"key":defence,"level":dlevel}
 g.profile.aiTechLevels={"weapon_accuracy":tech,"equipment_reinforcement":tech}
 g.profile.reactorLevel=reactor
 var cap=g.reactor_capacity();g.profile.reactorAllocation={"weapons":int(cap/2),"defence":cap-int(cap/2)}
 g.invalidate_stat_cache();g.reset_player()
 if not g.start(stage,false):return {"error":"start","stage":stage,"point":point}
 g.group_index=point-1;g.spawn_group()
 var begin_armour=float(g.player.armour);var begin_shield=float(g.player.shield);var initial=g.enemies.size()
 var frames:=0
 while g.state==BattleGame.State.COMBAT and frames<6000:
  g.tick(1.0/60.0);frames+=1
 return {"stage":stage,"point":point,"weapon":weapon,"weapon_level":wlevel,"defence":defence,"defence_level":dlevel,"reactor":reactor,"tech_each":tech,"enemies":initial,"seconds":snappedf(frames/60.0,.01),"state":g.state,"armour_begin":begin_armour,"armour_end":float(g.player.armour),"shield_begin":begin_shield,"shield_end":float(g.player.shield),"iron_drop":float(g.profile.resources.get("1",0))}
func _initialize()->void:
 for row in [[6,3,"longLaser",12,"shield",12,5,1],[6,4,"longLaser",12,"shield",12,5,1],[6,9,"longLaser",12,"shield",12,5,1],[7,4,"longLaser",15,"shield",15,7,2],[7,6,"longLaser",15,"shield",15,7,2],[7,9,"longLaser",15,"shield",15,7,2],[7,9,"longLaser",19,"shield",19,6,3],[6,4,"missile",12,"shield",12,5,1],[6,4,"cannon",12,"shield",12,5,1],[7,6,"missile",15,"shield",15,7,2],[7,6,"cannon",15,"shield",15,7,2],[6,3,"missile",12,"shield",12,5,1],[6,3,"cannon",12,"shield",12,5,1],[7,4,"missile",15,"shield",15,7,2],[7,4,"cannon",15,"shield",15,7,2]]:
  print("QA_BATTLE ",JSON.stringify(encounter(row[0],row[1],row[2],row[3],row[4],row[5],row[6],row[7])))
 quit()
