extends SceneTree
var checks=0
var failures=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func fixture(compiled:bool):
 var db=ShipDatabase.new()
 db.ships.Heavy_Battleship.weaponSlots=8;db.ships.Heavy_Battleship.defenseSlots=4
 var g=BattleGame.new(db,false)
 g.profile.cleared=range(1,61);g.rebuild_unlocks()
 g.economy.credit_many({"1":1e30,"2":1e30});g.profile.unlocked=BattleGame.EQUIPMENT.duplicate()
 var equipment=g.equipment.save_data();equipment.selectedShip="Heavy_Battleship"
 equipment.loadout={"weapons":[],"defence":[]}
 for key in ["laser","missile","cannon","longLaser","laser","missile","cannon","longLaser"]:equipment.loadout.weapons.append({"key":key,"level":5})
 for key in ["armour","shield","armour","shield"]:equipment.loadout.defence.append({"key":key,"level":5})
 check(g.equipment.install_snapshot(equipment,g.db),"Current equipment snapshot installs")
 var growth=g.enhancement_growth.save_data();growth.enhancementLevel=40
 check(g.enhancement_growth.install_snapshot(growth),"Current enhancement snapshot installs")
 g.notify_configuration_changed();g.reset_player();g.rng.seed=29
 if compiled:g.enable_compiled_combat_rules()
 return g
func _initialize()->void:call_deferred("run")
func run()->void:
 var old=fixture(false);var cached=fixture(true)
 for category in ["weapons","defence"]:
  for i in cached.loadout_entries(category).size():
   var a=old.slot_entry(category,i);var b=cached.slot_entry(category,i)
   check(old.N.compare(old.jewel_equipment_stat(a),cached.jewel_equipment_stat(b))==0,"canonical stat "+category+str(i))
   check(old.enhancement_effects(a)==cached.enhancement_effects(b),"canonical effects "+category+str(i))
   for effect in old.default_enhancement_order()[category]:
    for node in [1,2,3]:
     for choice in ["A","B"]:check(old.enhancement_branches.active(old,a,effect,node,choice)==cached.enhancement_branches.active(cached,b,effect,node,choice),"canonical branch qualification")
 check(cached.upgrade_equipment_batch("1") and old.upgrade_equipment_batch("1"),"original main batch purchases")
 check(cached.equipment.save_data()==old.equipment.save_data() and cached.economy.save_data()==old.economy.save_data(),"batch level/cost preserved")
 for entry in cached.combat_weapon_entries()+cached.defense_entries():
  check(cached.combat_equipment_row(entry.key,int(entry.level))==cached.compiled_combat_rules.row(entry.key,int(entry.level)),"final batch cached row")
 var entry=cached.combat_entry(0);var snapshot={"id":7,"damage":10.0,"critical":false,"critical_bonus_applied":false,"effects":[{"kind":"repeat","chain":true,"chain_targets":1}]}
 var instance=cached.new_attack_instance(snapshot);var a=cached.attack_from_snapshot(snapshot,1.0,instance);var b=cached.attack_from_snapshot(snapshot,2.0,instance)
 check(is_same(a.effects,b.effects) and cached.N.compare(b.damage,20.0)==0,"one instance shares immutable payload")
 check(not ClassDB.class_exists("SpaceNativePipeline") and not ClassDB.class_exists("SpaceStepSnapshot"),"old pipeline and snapshot classes excluded")
 print("STABLE COMPILED: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
