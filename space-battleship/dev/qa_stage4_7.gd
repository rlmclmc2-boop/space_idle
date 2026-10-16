extends SceneTree
func encounter(stage:int,point:int,weapon:String,wlevel:int,alevel:int,invest:String="") -> Dictionary:
 var db:=ShipDatabase.new()
 var g:=BattleGame.new(db,false)
 g.profile.highestLevel=stage
 g.profile.cleared=range(1,stage)
 g.profile.loadout.weapons[0].key=weapon
 g.profile.loadout.weapons[0].level=wlevel
 g.profile.loadout.defence[0].level=alevel
 if invest in ["reactor","both"]:g.profile.reactorAllocation={"weapons":50,"defence":50}
 if invest in ["ai","both"]:g.profile.hightechLevels={BattleGame.ENERGY_FOCUS:1,BattleGame.DENSE_ARMOUR:1}
 g.invalidate_stat_cache()
 if not g.start(stage,false):return {"error":"start"}
 g.group_index=point-1
 g.spawn_group()
 var begin_hp:float=float(g.player.armour)
 var initial:int=g.enemies.size()
 var frames:=0
 while g.state==BattleGame.State.COMBAT and frames<6000:
  g.tick(1.0/60.0)
  frames+=1
 g.settle_drops()
 return {"stage":stage,"point":point,"weapon":weapon,"weapon_level":wlevel,"armour_level":alevel,"invest":invest,"enemies":initial,"iron_auto":g.profile.resources.get("1",0),"seconds":snappedf(frames/60.0,0.001),"state":g.state,"armour_start":begin_hp,"armour_end":float(g.player.armour),"armour_fraction":snappedf(float(g.player.armour)/maxf(1,begin_hp),0.001)}
func evolution_check() -> Dictionary:
 var db:=ShipDatabase.new()
 var g:=BattleGame.new(db,false)
 g.profile.resources["1"]=100000
 g.profile.hyperspace.materials["degenerate_matter"]=10
 g.profile.loadout.weapons[0].level=19
 g.profile.highestLevel=7
 var quote:Dictionary=g.slot_upgrade_cost("weapons",0)
 var blocked:=not g.can_upgrade_slot("weapons",0)
 var before:float=float(g.equipment_stat("laser",19))
 g.profile.highestLevel=8
 var allowed:=g.can_upgrade_slot("weapons",0)
 var bought:=g.upgrade_slot("weapons",0)
 var after:float=float(g.equipment_stat("laser",20))
 return {"quote":quote,"blocked_before_clear":blocked,"allowed_after_clear":allowed,"bought":bought,"level":g.profile.loadout.weapons[0].level,"material_left":g.profile.hyperspace.materials["degenerate_matter"],"stat_before":before,"stat_after":after,"jump":snappedf(after/before,0.001),"armour_jump":snappedf(float(db.equip("armour",20).para1)/float(db.equip("armour",19).para1),0.001),"shield_jump":snappedf(float(db.equip("shield",20).para1)/float(db.equip("shield",19).para1),0.001),"tier200":db.evolution_factor(200)}
func batch_check() -> Dictionary:
 var g:=BattleGame.new(ShipDatabase.new(),false)
 g.profile.highestLevel=8
 g.profile.resources["1"]=10000000
 g.profile.hyperspace.materials["degenerate_matter"]=10
 g.profile.loadout.weapons[0].level=19
 var ten_quote:Dictionary=g.slot_upgrade_cost("weapons",0,10)
 var max_amount:int=g.max_upgrade_amount_slot("weapons",0)
 var bought:=g.upgrade_slot("weapons",0,10)
 var after_ten:=int(g.profile.loadout.weapons[0].level)
 var material_after_ten:=int(g.profile.hyperspace.materials["degenerate_matter"])
 g.refund_equipment("laser",20)
 return {"ten_quote_material":ten_quote.get("degenerate_matter",0),"max_before_buy":max_amount,"ten_bought":bought,"level_after_ten":after_ten,"material_after_ten":material_after_ten,"material_after_refund":g.profile.hyperspace.materials["degenerate_matter"]}
func _initialize() -> void:
 var db:=ShipDatabase.new()
 var g:=BattleGame.new(db,false)
 print("QA_LAYOUT ",JSON.stringify({"startup_error":g.startup_error,"points":[db.levels[3].groups.size(),db.levels[4].groups.size(),db.levels[5].groups.size(),db.levels[6].groups.size()],"gate":g.hyperspace.config.unlock_stage,"old_early_groups":db.groups["30053"].slots.filter(func(x):return x!=null).size()}))
 print("QA_EVOLUTION ",JSON.stringify(evolution_check()))
 print("QA_BATCH ",JSON.stringify(batch_check()))
 for case in [[4,8,"cannon",8,7,""],[5,3,"missile",11,10,""],[5,8,"missile",11,10,""],[5,7,"laser",11,10,""],[5,9,"cannon",11,10,""],[6,9,"longLaser",15,14,""],[6,9,"longLaser",15,14,"reactor"],[6,9,"longLaser",15,14,"ai"],[6,9,"longLaser",15,14,"both"],[7,9,"longLaser",19,18,""]]:
  print("QA_BATTLE ",JSON.stringify(encounter(case[0],case[1],case[2],case[3],case[4],case[5])))
 quit()
