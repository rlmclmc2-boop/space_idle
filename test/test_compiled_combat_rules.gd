extends SceneTree
## Targeted acceptance for the opt-in compiled combat combination.
## In-memory authored fixtures; no player saves or production data writes.
const N=preload("res://scripts/growth_number.gd")
var checks:int=0
var failures:int=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func fixture(compiled:bool=true)->BattleGame:
 var db=ShipDatabase.new()
 for key in ["laser","missile","cannon","longLaser"]:
  db.equipment[key][0].dmg=100.0;db.equipment[key][0].dmgMulti=0.0;db.equipment[key][0].cri=0.0;db.equipment[key][0].criDmg=0.0
 for key in ["armour","shield"]:
  db.equipment[key][0].para1=100.0;db.equipment[key][0]["para2" if key=="armour" else "para4"]=0.0
 db.equipment.shield[0].para2=0.0;db.config.dmgReduce=0.5
 db.data.enhance_config.repeat_probability.value=0.0
 var g=BattleGame.new(db,false)
 g.profile.cleared=range(1,61);g.profile.highestLevel=61;g.rebuild_unlocks()
 g.profile.enhancementLevel=50
 g.profile.resources["1"]=1e100;g.profile.resources["2"]=1e100
 g.profile.loadout={"weapons":[{"key":"laser","level":150},{"key":"laser","level":150}],"defence":[{"key":"armour","level":150},{"key":"shield","level":150}]}
 g.invalidate_stat_cache();g.reset_player();g.spawn_group()
 for enemy in g.enemies:enemy.hp=1e10;enemy.max_hp=1e10;enemy.cooldowns=enemy.cooldowns.map(func(_cd):return 999.0)
 g.rng.seed=418
 if compiled:g.enable_compiled_combat_rules()
 return g
func choose(g,effect:String,node:int,choice:String="B")->void:
 check(g.set_enhancement_branch("weapons",effect,node,choice),"public branch "+effect+str(node)+choice)
func _initialize()->void:call_deferred("run")
func run()->void:
 var old=fixture(false);var candidate=fixture(true)
 # Dynamic counters and timed gains must remain live, not frozen in the configuration.
 for g in [old,candidate]:
  choose(g,"proficiency",1)
  g.begin_enhancement_attack(0,g.enemies[0]);g.finish_enhancement_attack(0)
 var builds=candidate.compiled_combat_rules.builds
 for dt in [0.99,0.01,1.0]:
  for g in [old,candidate]:g.enhancement_branches.advance_weapons(g,dt)
  check(N.compare(old.jewel_equipment_stat(old.weapon_entries()[0]),candidate.jewel_equipment_stat(candidate.weapon_entries()[0]))==0,"dwell live across exact threshold "+str(dt))
 check(candidate.compiled_combat_rules.builds==builds,"timed gain does not rebuild config")
 for g in [old,candidate]:g.begin_enhancement_attack(0,g.enemies[1]);g.finish_enhancement_attack(0)
 check(N.compare(old.jewel_equipment_stat(old.weapon_entries()[0]),candidate.jewel_equipment_stat(candidate.weapon_entries()[0]))==0,"retarget clears gain immediately")
 for g in [old,candidate]:
  choose(g,"critical",2)
  g.db.data.enhance_config.base_critical_rate.value=1.0;g.notify_configuration_changed()
 for i in 5:
  for g in [old,candidate]:
   g.begin_enhancement_attack(0,g.enemies[0]);g.jewel_attack(0);g.finish_enhancement_attack(0)
  check(N.compare(old.jewel_equipment_stat(old.weapon_entries()[0]),candidate.jewel_equipment_stat(candidate.weapon_entries()[0]))==0,"critical stack damage live "+str(i))
  check(old.jewel_critical(old.weapon_entries()[0])==candidate.jewel_critical(candidate.weapon_entries()[0]),"critical stack chance live "+str(i))
 check(candidate.enhancement_branches.weapon(candidate,0).stacks==3,"critical stacks cap at3")
 builds=candidate.compiled_combat_rules.builds
 for dt in [1.99,0.01]:
  for g in [old,candidate]:g.enhancement_branches.advance_weapons(g,dt)
  check(N.compare(old.jewel_equipment_stat(old.weapon_entries()[0]),candidate.jewel_equipment_stat(candidate.weapon_entries()[0]))==0,"stack expires at actual boundary "+str(dt))
 check(candidate.enhancement_branches.weapon(candidate,0).stacks==0,"temporary stacks expire")
 check(candidate.compiled_combat_rules.builds==builds,"stack expiry does not rebuild config")
 for g in [old,candidate]:g.record_enhancement_attack()
 check(N.compare(old.jewel_equipment_stat(old.weapon_entries()[0]),candidate.jewel_equipment_stat(candidate.weapon_entries()[0]))==0,"global counter remains live")
 # Upgrade/refit/config changes are public boundaries.
 check(candidate.upgrade_slot("weapons",0,1),"public module upgrade")
 var entry:Dictionary=candidate.weapon_entries()[0]
 check(candidate.combat_equipment_row(str(entry.key),int(entry.level)).dmg==candidate.db.equip(str(entry.key),int(entry.level)).dmg,"upgraded row immediate")
 check(candidate.equip_slot("weapons",0,"missile"),"public refit")
 check(candidate.combat_equipment_row("missile",int(candidate.weapon_entries()[0].level)).dmg==candidate.db.equip("missile",int(candidate.weapon_entries()[0].level)).dmg,"refit row immediate")
 # An equipped drone activates the cached combat-source array; refit must replace its module references too.
 var drone_rng=RandomNumberGenerator.new();drone_rng.seed=89
 var drone=preload("res://scripts/drone_rewards.gd").create_drone(drone_rng,candidate.hyperspace.config,"acceptance:refit","gold","laser",20,"1")
 var bag=preload("res://scripts/drone_inventory.gd").fresh()
 bag.drones[drone.id]=drone;bag.warehouse.append(drone.id)
 candidate.profile.hyperspace.inventory=bag;candidate.profile.hyperspace.unlocked_drones=true;candidate.invalidate_stat_cache()
 check(candidate.hyperspace.set_equipped(candidate,[drone.id]),"public drone equip activates combat-source array")
 check(candidate.combat_weapon_entries().size()>candidate.weapon_entries().size(),"fixture has drone combat source")
 var hull=""
 for key in candidate.db.ships:
  if str(key)!=str(candidate.profile.selectedShip) and candidate.ship_unlocked(str(key)) and int(candidate.hyperspace.config.hull_capacities.get(str(key),0))>0:hull=str(key);break
 check(not hull.is_empty(),"fixture has another unlocked hull")
 if not hull.is_empty():
  var loadout={"weapons":[],"defence":[]}
  for i in int(candidate.db.ship(hull).weaponSlots):loadout.weapons.append({"key":"longLaser" if i==0 else "laser","level":150})
  for i in int(candidate.db.ship(hull).defenseSlots):loadout.defence.append({"key":"armour","level":150})
  check(candidate.switch_ship(hull,loadout),"public hull plus loadout switch")
  check(candidate.combat_weapon_entries()[0].key=="longLaser" and is_same(candidate.combat_weapon_entries()[0],candidate.weapon_entries()[0]),"hull loadout source identity updates immediately")
  check(candidate.compiled_combat_rules.rows.has("longLaser:"+str(candidate.weapon_entries()[0].level)),"hull loadout compiled without priced fallback")
 var value=candidate.db.equipment.longLaser[0].dmg
 candidate.db.equipment.longLaser[0].dmg=value*1.5;candidate.notify_configuration_changed()
 entry=candidate.weapon_entries()[0]
 check(candidate.combat_equipment_row(str(entry.key),int(entry.level)).dmg==candidate.db.equip(str(entry.key),int(entry.level)).dmg,"table change immediate")
 # Carriers of one instance share state; separate instances of one root never share mutable chain state.
 var g=fixture(true)
 var snapshot={"id":999,"damage":10.0,"effects":[{"kind":"repeat","chain":true,"chain_targets":1,"weapon_key":"laser","main_attack_id":999}],"critical":false,"critical_bonus_applied":false}
 var first=g.new_attack_instance(snapshot);var second=g.new_attack_instance(snapshot)
 var a=g.attack_from_snapshot(snapshot,1.0,first);var b=g.attack_from_snapshot(snapshot,2.0,first);var c=g.attack_from_snapshot(snapshot,1.0,second)
 check(is_same(a.effects,b.effects) and not is_same(a.effects,c.effects),"same-instance sharing and cross-instance isolation")
 check(a.effects.is_read_only() and a.effects[0].is_read_only(),"immutable bound effects")
 first.chain.used=true;first.chain.links.append({"target":g.enemies[0],"broken":false})
 check(bool(b.effects[0].chain_state.used) and not bool(c.effects[0].chain_state.used) and second.chain.links.is_empty(),"mutable used/link state isolated")
 check(b.damage==a.damage*2.0,"multiplier does not modify shared payload")
 check(not bool(g.chain_damage_effects(a.effects)[0].chain) and bool(c.effects[0].chain),"continued effects do not corrupt sibling instance")
 # Shield type changes alter target order at the same actual settlement boundary.
 var e=g.enemies[0].duplicate(true);var other=e.duplicate(true)
 e.uid=100;e.slot=4;e.x=100.0;e.y=150.0;e.hp=100.0;e.max_hp=100.0;e.armourType=1;e.shieldType=2;e.shield=10.0;e.max_shield=10.0;e.shieldDelay=1.0;e.shieldRecovery=1.0;e.shield_hit_at=0.0;e.shield_updated_at=0.0;e.drops=[]
 other.uid=101;other.slot=0;other.x=180.0;other.y=150.0;other.hp=100.0;other.max_hp=100.0;other.armourType=2;other.shield=0.0;other.max_shield=0.0;other.drops=[]
 g.enemies.assign([e,other]);g.enemy_shield_time=0.0
 check(g.targets(1)[0].uid==100,"shield type gives original priority")
 g.hit_enemy(e,10.0,1)
 check(e.shield==0.0 and e.hp==100.0,"real hit exhausts shield without HP loss")
 check(g.targets(1)[0].uid==101,"armour type changes priority immediately")
 g.enemy_shield_time=0.5
 check(g.targets(1)[0].uid==101 and e.shield==0.0,"shield delay respected")
 g.enemy_shield_time=2.0
 check(g.targets(1)[0].uid==100 and e.shield==10.0,"regeneration restores shield priority")
 var root=g.new_attack_instance(snapshot);var damage=g.attack_from_snapshot(snapshot,1.0,root)
 g.hit_enemy(e,1000.0,1,damage.effects,false,preload("res://scripts/combat_context.gd").root(999,"module:0","laser"))
 check(e.hp<=0 and bool(root.chain.used),"lethal root hit consumes chain once")
 check(g.targets(1).size()==1 and g.targets(1)[0].uid==101,"dead target immediately excluded")
 check(g.projectiles.size()==1 and bool(g.projectiles[0].get("chain_hop",false)) and g.projectiles[0].target.uid==101,"one visible chain carrier to surviving target")
 g.tick_projectiles(1.0)
 check(other.hp<=0 and g.projectiles.is_empty(),"chain settles death and lifecycle without recursive carriers")
 print("COMPILED COMBAT RULES: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
