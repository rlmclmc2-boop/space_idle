extends SceneTree
const Rewards=preload("res://scripts/drone_rewards.gd")
const Bag=preload("res://scripts/drone_inventory.gd")
const PlayerDB=preload("res://scripts/player_weapon_database.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize()->void:
 var db:=ShipDatabase.new();db.config.offlineMax=0
 var g:=BattleGame.new(db,false);g.save_enabled=false
 g.profile.cleared=range(1,101);g.profile.highestLevel=101;g.rebuild_unlocks();g.pending_unlocks.clear()
 g.profile.selectedShip="Heavy_Battleship";g.profile.loadout=g.empty_loadout(g.profile.selectedShip)
 for entry in g.profile.loadout.weapons:entry.key="missile";entry.level=150
 g.invalidate_stat_cache()
 var view=g.combat_weapon_view();var first=g.combat_entry(0);var copies=g.combat_weapon_entries()
 check(view.is_read_only() and not copies.is_read_only(),"internal immutable container / public independent container")
 copies.clear();check(g.combat_entry(0)==first and is_same(first,g.profile.loadout.weapons[0]),"public edits retain source and authoritative identity")
 check(is_same(view,g.combat_weapon_view()),"stable sources reuse exact container")
 var replacement=first.duplicate(true);g.profile.loadout.weapons[0]=replacement
 check(is_same(g.combat_entry(0),replacement) and not is_same(g.combat_entry(0),first),"same-tick replacement visible without invalidation")
 for key in ["laser","cannon","missile","longLaser","armour","shield"]:
  for level in [1,2,150]:
   var full=db.equip(key,level);var basic=db.combat_equipment(key,level)
   check(basic.is_read_only() and db.combat_snapshot_equipment(key,level)==full,"fixed projection and snapshot metadata %s/%d"%[key,level])
   for field in basic:check(basic[field]==full[field],"combat field equality %s/%s/%d"%[key,field,level])
 var builds=db.combat_descriptor_builds;db.combat_equipment("missile",150)
 check(db.combat_descriptor_builds==builds,"stable descriptor no rebuild")
 var row=db._combat_base_row("missile");var original=row.cd;row.cd=float(original)+0.125
 check(db.combat_equipment("missile",150).cd==row.cd,"in-place authored change rebuild")
 row.cd=original
 var state=g.rng.state
 check(g.combat_player_weapon_row(replacement)==g.player_weapon_row(replacement),"dynamic cooldown projection matches public row")
 replacement.level=151
 check(g.combat_player_weapon_row(replacement)==g.player_weapon_row(replacement) and g.rng.state==state,"same-tick level upgrade reads new configuration, no RNG")
 for key in ["laser_mon","cannon_mon","missile_mon","longLaser_mon","absent_mon"]:
  check(db.combat_enemy_weapon(key)==db.enemy_weapon(key),"hostile fallback equality "+key)
 db.equipment["missing_mon"]=[{"level":1,"dmg":null,"cd":null,"dmgtype":null,"para1":null,"para2":null}]
 check(db.combat_enemy_weapon("missing_mon")==db.enemy_weapon("missing_mon"),"hostile null and missing fallback")
 var player_db=PlayerDB.new(db);player_db.equipment.laser[0].cd=1234
 check(player_db.combat_enemy_weapon("laser_mon")==db.enemy_weapon("laser_mon"),"hostile projection retains original enemy source")
 var rng=RandomNumberGenerator.new();rng.seed=123
 var d=Rewards.create_drone(rng,g.hyperspace.config,"descriptor-drone","white","laser",1,"1");d.affixes=[];d.hangings=[]
 check(Bag.insert(g.profile.hyperspace.inventory,d,g.hyperspace.config) and g.hyperspace.set_equipped(g,[d.id]),"equip drone through production transition")
 var before=g.combat_weapon_view();var source=before[-1]
 check(source.drone_id==d.id,"drone added to descriptor view")
 g.drone_combat.disabled.append(d.id);g.invalidate_stat_cache()
 check(g.combat_weapon_view().size()==before.size()-1,"disabled drone omitted immediately")
 g.drone_combat.restore_disabled(g,"wave_clear")
 check(g.combat_weapon_view().size()==before.size() and g.combat_weapon_view()[-1].drone_id==d.id,"wave clear restores drone immediately")
 for connection in g.event.get_connections():g.event.disconnect(connection.callable)
 print("COMBAT_DESCRIPTORS %d checks %d failures"%[checks,failures]);quit(1 if failures else 0)
