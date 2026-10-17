extends SceneTree
func run(wlevel:int,dlevel:int,reactor:int,tech:int)->Dictionary:
 var g:=BattleGame.new(ShipDatabase.new(),false)
 g.profile.highestLevel=8;g.profile.cleared=range(1,7);g.rebuild_unlocks();g.pending_unlocks.clear()
 g.profile.loadout.weapons[0]={"key":"longLaser","level":wlevel}
 g.profile.loadout.defence[0]={"key":"shield","level":dlevel}
 g.profile.reactorLevel=reactor
 g.profile.aiTechLevels={"weapon_accuracy":tech,"equipment_reinforcement":tech}
 var cap=g.reactor_capacity();g.profile.reactorAllocation={"weapons":int(cap/2),"defence":cap-int(cap/2)}
 g.invalidate_stat_cache();g.reset_player()
 var began=g.start(7,false)
 var max_shield=float(g.stat("shield"));var frames:=0;var retreat_count:=0
 while g.state!=BattleGame.State.LEVEL_CLEAR and g.state!=BattleGame.State.DEFEAT and frames<18000:
  g.tick(1.0/60.0);frames+=1
  if g.state==BattleGame.State.RETREAT:retreat_count+=1
 return {"weapon_level":wlevel,"shield_level":dlevel,"reactor":reactor,"tech_each":tech,"began":began,"state":g.state,"point":g.group_index,"seconds":snappedf(frames/60.0,.01),"shield_end":float(g.player.shield),"shield_max":max_shield,"retreat_frames":retreat_count}
func _initialize()->void:
 for row in [[12,12,5,1],[15,15,7,2],[17,17,8,3]]:
  print("QA_STAGE7_PRESSURE ",JSON.stringify(run(row[0],row[1],row[2],row[3])))
 quit()
