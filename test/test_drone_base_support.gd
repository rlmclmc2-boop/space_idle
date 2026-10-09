extends SceneTree
const Rewards=preload("res://scripts/drone_rewards.gd")
const Bag=preload("res://scripts/drone_inventory.gd")
const Effects=preload("res://scripts/drone_effect_aggregator.gd")
const N=preload("res://scripts/growth_number.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String) -> void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var g=BattleGame.new(ShipDatabase.new(),false);g.save_enabled=false;g.profile.cleared=range(1,20);g.profile.highestLevel=20;g.rebuild_unlocks();g.pending_unlocks.clear();g.profile.hyperspace.unlocked_drones=true
 g.profile.selectedShip="Destroyer";g.profile.loadout=g.empty_loadout("Destroyer");g.equip_slot("weapons",0,"laser");g.equip_slot("defence",0,"armour");g.equip_slot("defence",1,"shield")
 var rng=RandomNumberGenerator.new();rng.seed=912
 var d=Rewards.create_drone(rng,g.hyperspace.config,"base-white","white","laser",1,"1");d.hanging_slots=0;d.affixes=[];d.hangings=[]
 var b=Rewards.create_drone(rng,g.hyperspace.config,"base-second","white","missile",1,"1");b.hanging_slots=0;b.affixes=[];b.hangings=[]
 Bag.insert(g.profile.hyperspace.inventory,d,g.hyperspace.config);Bag.insert(g.profile.hyperspace.inventory,b,g.hyperspace.config)
 var weapon=g.loadout_entries("weapons")[0];var dmg=g.jewel_equipment_stat(weapon);var armour=g.stat("armour");var shield=g.stat("shield");var state=g.rng.state
 check(armour>0 and shield>0 and Bag.valid_drone(d,g.hyperspace.config) and not Bag.valid_drone(dict(d,{"level":0}),g.hyperspace.config),"Valid body levels begin at1; fixture has both real defence layers")
 check(g.hyperspace.equip_drone(g,d.id).ok,"Zero-slot white with no affix equips normally")
 check(is_equal_approx(float(g.jewel_equipment_stat(weapon))/float(dmg),1.05) and is_equal_approx(float(g.stat("armour"))/float(armour),1.05) and is_equal_approx(float(g.stat("shield"))/float(shield),1.05),"First white provides actual5-percent weapon damage and armour/shield capacity without affix or hanging")
 var entry=g.drone_weapon_entry(d);var own=g.jewel_equipment_stat(entry);var without=Effects.empty()
 check(is_equal_approx(float(own)/float(g.jewel_equipment_stat(entry,-1,null,true,without)),1.05),"The inherited drone weapon also receives the global layer exactly once without recursion")
 check(g.hyperspace.equip_drone(g,b.id).ok and is_equal_approx(float(g.hyperspace_totals().base_damage),1.10),"Two first-level drones add extra bonuses into one1.10 layer rather than multiply1.05 twice")
 g.profile.hyperspace.inventory.drones[d.id].level=2;g.invalidate_stat_cache()
 check(is_equal_approx(float(g.hyperspace_totals().base_damage),1.1525) and is_equal_approx(float(g.hyperspace_totals().base_damage)/1.10,1.0477272727),"One of two level1 drones advances to2 with the agreed4.77-percent relative fleet-layer change")
 g.drone_combat.disabled.append(d.id);g.invalidate_stat_cache()
 check(is_equal_approx(float(g.hyperspace_totals().base_damage),1.05),"Temporarily disabled drone contributes no base layer")
 g.drone_combat.restore_disabled(g,"test");check(is_equal_approx(float(g.hyperspace_totals().base_damage),1.1525),"Restoration invalidates cached base projection")
 check(g.hyperspace.unequip_drone(g,d.id).ok and is_equal_approx(float(g.hyperspace_totals().base_damage),1.05),"Unequip removes only its own layer and invalidates cache")
 for level in [1,5,10,20]:
  var row=d.duplicate(true);row.level=level
  check(is_equal_approx(float(Effects.base_multiplier(row,g.hyperspace.config)),pow(1.05,level)),"Body level uses configured exponential independent of dynamic weapon level")
 var alternative=g.hyperspace.config.duplicate(true);alternative.drone_base_growth=1.02
 check(is_equal_approx(float(Effects.base_multiplier(d,alternative)),1.02) and preload("res://scripts/hyperspace_config.gd").valid(alternative),"Distinct valid base coefficient changes formula through config authority")
 alternative.drone_base_growth=0.99;check(not preload("res://scripts/hyperspace_config.gd").valid(alternative),"Invalid base coefficient is rejected by runtime config validation")
 check(Effects.base_multiplier(dict(d,{"level":20000}),g.hyperspace.config) is Dictionary,"High body levels use existing large-number representation without float overflow")
 check(g.rng.state==state,"Stat calculation/equipment changes do not roll combat RNG")
 # Large affix additive values cannot dilute the independent base layer.
 var old=g.profile.hyperspace.inventory.drones[b.id];old.affixes=[{"key":"global_damage","value":100.0,"tier":1,"locked":false}];g.invalidate_stat_cache()
 var total=g.hyperspace_totals();var unbased=total.duplicate(true);unbased.base_damage=1.0;unbased.base_defence=1.0
 check(is_equal_approx(float(g.jewel_equipment_stat(weapon))/float(g.jewel_equipment_stat(weapon,-1,null,true,unbased)),1.05),"Existing101x global affix still receives the full independent5-percent factor")
 var scene=load("res://main.tscn").instantiate();scene.automation_args=["--capture"];root.add_child(scene);scene.set_process(false);scene.game.save_enabled=false
 scene.game.profile.cleared=range(1,20);scene.game.profile.highestLevel=20;scene.game.rebuild_unlocks();scene.game.pending_unlocks.clear();scene.game.profile.hyperspace.unlocked_drones=true
 var fresh=d.duplicate(true);fresh.level=1;Bag.insert(scene.game.profile.hyperspace.inventory,fresh,scene.game.hyperspace.config)
 scene.refresh_tab_visibility();scene.select_system(9);await process_frame
 var p=scene.hyperspace_panel;p.refresh_manual_status();p.selected_id=fresh.id;p.select_section(1)
 check(p.drone_description(fresh,false,true).contains("武器伤害 +5%") and p.drone_description(fresh,false,true).contains("装甲/护盾上限 +5%"),"Compact card states the actual damage and capacity objects")
 p.equipment_ui.activate()
 check(p.equipment_ui.feedback.text.contains("基础层变化") and p.equipment_ui.feedback.text.contains("+5%"),"Native equipment action reports actual before/after base-layer change")
 scene.queue_free();await process_frame
 print("Drone base support: ",checks," checks, ",failures," failures");quit(1 if failures else 0)
func dict(source:Dictionary,changes:Dictionary) -> Dictionary:
 var result=source.duplicate(true);result.merge(changes,true);return result
