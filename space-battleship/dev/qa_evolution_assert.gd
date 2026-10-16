extends SceneTree
func fresh() -> BattleGame:
 return BattleGame.new(ShipDatabase.new(),false)
func _initialize() -> void:
 var g:=fresh()
 assert(g.startup_error.is_empty())
 var db:=g.db
 assert(db.levels[3].groups.size()==8 and db.levels[4].groups.size()==9 and db.levels[5].groups.size()==9 and db.levels[6].groups.size()==9)
 assert(int(g.hyperspace.config.unlock_stage)==8)
 g.profile.highestLevel=8
 g.profile.resources["1"]=1000000000000.0
 g.profile.loadout.weapons[0].level=19
 var material:String=db.evolution_material_id()
 assert(not g.can_upgrade_slot("weapons",0))
 g.profile.hyperspace.materials[material]=10
 var quote:Dictionary=g.slot_upgrade_cost("weapons",0)
 assert(int(quote[material])==10)
 assert(g.upgrade_slot("weapons",0))
 assert(int(g.profile.loadout.weapons[0].level)==20 and int(g.profile.hyperspace.materials[material])==0)
 assert(not g.upgrade_slot("weapons",0,20))
 g.profile.hyperspace.materials[material]=19
 g.profile.loadout.weapons[0].level=39
 assert(int(g.slot_upgrade_cost("weapons",0)[material])==20)
 assert(not g.can_upgrade_slot("weapons",0))
 g.profile.hyperspace.materials[material]=20
 assert(g.upgrade_slot("weapons",0))
 assert(int(g.profile.loadout.weapons[0].level)==40 and int(g.profile.hyperspace.materials[material])==0)
 g.profile.unlocked.append("missile")
 assert(g.equip_slot("weapons",0,"missile"))
 assert(int(g.profile.loadout.weapons[0].level)==40)
 assert(g.equip_slot("weapons",0,"laser"))
 assert(int(g.profile.loadout.weapons[0].level)==40)
 var b:=fresh()
 b.profile.highestLevel=8
 b.profile.resources["1"]=1000000000000.0
 b.profile.hyperspace.materials[material]=10
 b.profile.loadout.weapons[0].level=19
 b.profile.loadout.defence[0].level=19
 assert(b.upgrade_equipment_batch("1"))
 assert(int(b.profile.loadout.weapons[0].level)==20)
 assert(int(b.profile.loadout.defence[0].level)==19)
 assert(int(b.profile.hyperspace.materials[material])==0)
 var n:=preload("res://scripts/presented_battle_game.gd").new(ShipDatabase.new(),false)
 n.profile.highestLevel=8
 n.profile.resources["1"]=1000000000000.0
 n.profile.hyperspace.materials[material]=10
 n.profile.loadout.weapons[0].level=19
 n.profile.loadout.defence[0].level=19
 n.native_execution_auto=true
 assert(n.start(8,false))
 n.group_index=0
 n.spawn_group()
 assert(n.native_execution!=null)
 assert(n.upgrade_equipment_batch("1"))
 assert(int(n.profile.loadout.weapons[0].level)==20)
 assert(int(n.profile.loadout.defence[0].level)==19)
 assert(int(n.profile.hyperspace.materials[material])==0)
 var v:=fresh()
 v.profile.planets["1"].conquered=true
 v.invalidate_stat_cache()
 assert(v.equipment_level_bonus()==35)
 var raw_19=ShipDatabase.new().equip("laser",54).dmg
 var stat_19=v.equipment_stat("laser",19)
 assert(absf(float(stat_19)-float(raw_19)/float(db.evolution_factor(54)))<1)
 var raw_39=ShipDatabase.new().equip("laser",74).dmg
 var stat_39=v.equipment_stat("laser",39)
 assert(absf(float(stat_39)-float(raw_39)*float(db.evolution_factor(39))/float(db.evolution_factor(74)))<1)
 assert(db.data.equipment_evolution.visual_palette.size()==10)
 for tier in range(1,11):
  assert(int(db.equipment_cost("laser",tier*20)[material])==10*tier)
  assert(db.evolution_factor(tier*20)>db.evolution_factor((tier-1)*20))
 print("QA_ASSERT_OK gates=20,40 batch_shared=10 native_batch_shared=10 weapon_switch=40 virtual=19+35,39+35 tiers=10")
 quit()
