extends SceneTree
const Rewards=preload("res://scripts/drone_rewards.gd")
const Bag=preload("res://scripts/drone_inventory.gd")
const Effects=preload("res://scripts/drone_effect_aggregator.gd")
var checks:=0
var failures:=0
var games:Array=[]
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func fixture()->BattleGame:
 var db:=ShipDatabase.new();db.config.offlineMax=0
 var g:=BattleGame.new(db,false);games.append(g)
 g.profile.cleared=range(1,101);g.profile.highestLevel=101;g.rebuild_unlocks();g.stat_cache_enabled=true
 for id in g.profile.resources:g.profile.resources[id]=1e30
 g.profile.selectedShip="Heavy_Battleship"
 g.profile.loadout=g.empty_loadout(g.profile.selectedShip)
 for entry in g.profile.loadout.weapons:entry.level=20
 g.profile.loadout.defence[0]={"key":"armour","level":8}
 g.profile.loadout.weapons[0]={"key":"laser","level":6}
 g.profile.loadout.weapons[1]={"key":"missile","level":20}
 g.invalidate_stat_cache();g.reset_player();g.start(8,false);g.spawn_group()
 var rng:=RandomNumberGenerator.new();rng.seed=4
 var d:=Rewards.create_drone(rng,g.hyperspace.config,"ordinary","blue","laser",5,"1")
 d.affixes=[];Bag.insert(g.profile.hyperspace.inventory,d,g.hyperspace.config)
 check(g.hyperspace.set_equipped(g,["ordinary"]),"equip fixture drone")
 return g
func projected(g)->Dictionary:return g.combat_entry(g.weapon_entries().size())
func _initialize()->void:
 var g:=fixture();var d:Dictionary=g.profile.hyperspace.inventory.drones.ordinary
 var bonus:int=Effects.weapon_bonus(d,g.hyperspace.config);var drop_level:int=d.level
 check(projected(g).level==6+bonus,"lowest unlocked module supplies drone level regardless of type")
 var old:Dictionary=projected(g)
 var target:Dictionary=g.enemies[0];target.hp=1e20;target.equipment=[]
 var index:int=g.weapon_entries().size();var row:Dictionary=g.player_weapon_row(old)
 g.begin_enhancement_attack(index,target);var attack:Dictionary=g.jewel_attack(index)
 g.launch_player_attack(index,target,row,attack,Vector2.ZERO,0);g.finish_enhancement_attack(index)
 var shot:Dictionary=g.projectiles.back();var damage=shot.damage
 check(g.upgrade_slot("weapons",0,1),"upgrade current main module through public API")
 check(projected(g).level==7+bonus and not is_same(old,projected(g)),"upgrade invalidates future drone source")
 check(old.level==6+bonus and shot.damage==damage and g.projectiles.has(shot),"already launched payload and old source remain frozen")
 check(g.equip_slot("weapons",1,"cannon") and projected(g).level==7+bonus,"changing main type retains module-level contribution")
 check(g.unequip_slot("weapons",1) and projected(g).level==7+bonus and g.module_entry("weapons",1).key.is_empty(),"removing weapon type does not alter module minimum")
 check(g.equip_slot("weapons",1,"missile") and projected(g).level==7+bonus,"changing empty type to missile preserves paid module level")
 check(g.equip_slot("weapons",7,"cannon") and g.upgrade_slot("weapons",7,39),"prepare higher rear module before hull shrink")
 check(projected(g).level==7+bonus,"raising nonminimum slot does not boost drones")
 check(g.switch_ship("Frigate"),"switch through public API to real smaller hull")
 check(projected(g).level==7+bonus and g.module_entry("weapons",7).level==59,"switching smaller hull cannot hide a lower unlocked slot")
 check(g.hyperspace.unequip_drone(g,"ordinary").ok and g.combat_weapon_entries().size()==g.weapon_entries().size(),"unequip invalidates source list")
 check(g.hyperspace.equip_drone(g,"ordinary").ok and projected(g).level==7+bonus,"reequip preserves inherited base")
 check(d.level==drop_level,"projection never changes earned drone level")
 # A larger unlock may introduce a level-one slot, but cannot erase earned base.
 var floor_g:=BattleGame.new(ShipDatabase.new(),false);games.append(floor_g)
 floor_g.profile.loadout.weapons[0].level=30
 floor_g.refresh_drone_weapon_floor()
 var earned:int=floor_g.drone_weapon_entry(d).level
 floor_g.profile.highestLevel=101;floor_g.profile.cleared=range(1,101);floor_g.rebuild_unlocks()
 check(floor_g.lowest_unlocked_weapon_level()==1 and floor_g.drone_weapon_entry(d).level==earned,"new unlock preserves historical base while new slots catch up")
 var prepared:=preload("res://scripts/save_transfer.gd").new().prepare_data(JSON.parse_string(JSON.stringify(floor_g.portable_save_data())),floor_g.db)
 check(prepared.error=="","history survives full JSON save validation")
 var reloaded:=BattleGame.new(floor_g.db,false);games.append(reloaded)
 reloaded.load_progress_data(prepared.data)
 check(reloaded.drone_weapon_entry(d).level==earned,"history survives full save reload")
 check(int(reloaded.fresh_profile().droneWeaponFloor)==1,"reforge fresh profile clears inherited history")
 reloaded.planet_buildings.state(reloaded,"1","shipyard").status="built"
 check(reloaded.can_reforge_planet("1") and reloaded.reforge_planet("1"),"real planet reforge succeeds")
 check(int(reloaded.profile.droneWeaponFloor)==1 and reloaded.drone_weapon_entry(d).level==1+bonus,"real reforge clears weapon history while quality bonus remains")
 var low_slot:int=g.module_entries("weapons").size()-1
 g.profile.loadout.weapons[low_slot].level=2;g.profile.droneWeaponFloor=1;g.invalidate_stat_cache()
 check(projected(g).level==2+bonus,"dormant unlocked weak slot still limits inheritance on smaller hull")

 # Real rebuild, followed by an ordinary nonfinal wave ending.
 g=fixture();var rng:=RandomNumberGenerator.new();rng.seed=8
 var legend:=Rewards.create_drone(rng,g.hyperspace.config,"legend","legendary","laser",5,"1")
 var definition:Dictionary=g.hyperspace.config.legendary_effects.drone_rebuild;var parameters:Dictionary={}
 for key in definition.parameters:parameters[key]=float(definition.parameters[key][1])
 legend.legendary_effect={"effect_id":"drone_rebuild","parameters":parameters};legend.affixes=[]
 Bag.insert(g.profile.hyperspace.inventory,legend,g.hyperspace.config)
 check(g.hyperspace.set_equipped(g,["ordinary","legend"]),"equip rebuild fixture")
 g.player.armour=0
 check(g.drone_combat.try_rebuild(g) and g.drone_combat.disabled==["ordinary"],"near death disables the sacrificed drone")
 var stacks:int=g.drone_combat.rebuild_stacks;var rebuild_bonus:float=g.drone_combat.rebuild_bonus
 check(g.combat_weapon_entries().size()==g.weapon_entries().size()+1,"disabled drone absent from current sources")
 var restored:Array=[]
 g.event.connect(func(kind,payload):
  if kind=="hyperspace_drone_restored":restored.append(payload))
 var wave:int=g.group_index
 for e in g.enemies:e.hp=0;e.equipment=[]
 g.tick(1.0/60.0)
 check(g.state==g.State.TRAVEL and g.group_index==wave and g.drone_combat.disabled.is_empty(),"wave clear restores before next wave, without whole-level start")
 check(g.combat_weapon_entries().size()==g.weapon_entries().size()+2,"restoration invalidates source cache")
 check(g.drone_combat.rebuild_stacks==stacks and g.drone_combat.rebuild_bonus==rebuild_bonus,"restoration preserves existing bonus and stack rules")
 check(restored.size()==1 and restored[0].drone_ids==["ordinary"],"UI receives one availability restoration event")
 g.drone_combat.disabled.append("ordinary");g.invalidate_stat_cache();g.begin_retreat()
 check(g.state==g.State.RETREAT and g.drone_combat.disabled.is_empty(),"defeat or explicit retreat restores without resetting bonuses")
 g.drone_combat.disabled.append("ordinary");g.invalidate_stat_cache();g.spawn_group(true)
 check(g.drone_combat.disabled.is_empty(),"same-wave retry cannot inherit disabled state")
 g.drone_combat.disabled.append("ordinary");g.invalidate_stat_cache();g.clear_level()
 check(g.state==g.State.LEVEL_CLEAR and g.drone_combat.disabled.is_empty(),"last-wave level clear restores availability")
 # Existing synthetic route protocol drives the same public manual lifecycle.
 g=fixture();var routes:Dictionary={};var serial:=9000;var mon:int=int(g.db.enemies.keys()[0])
 for route in ["alpha","beta","gamma","delta"]:
  routes[route]=[]
  for layer in 10:
   serial+=1;routes[route].append(serial)
   g.db.groups[str(serial)]={"slots":[mon],"combatTier":"normal" if layer<4 else "elite" if layer<8 else "boss" if layer==8 else "ultimate","formation_positions":[[100.0,100.0]]}
 check(g.configure_hyperspace_routes(routes) and g.start_hyperspace("alpha",1),"enter isolated manual route fixture")
 g.spawn_group();g.drone_combat.disabled.append("ordinary");g.invalidate_stat_cache()
 for e in g.enemies:e.hp=0;e.equipment=[]
 g.tick(1.0/60.0)
 check(g.manual_hyperspace.active and g.state==g.State.TRAVEL and g.drone_combat.disabled.is_empty(),"manual route also restores at each wave boundary")
 g.drone_combat.disabled.append("ordinary");g.invalidate_stat_cache()
 check(g.exit_hyperspace_challenge() and g.drone_combat.disabled.is_empty(),"manual exit cannot carry challenge disabled state into main battle")
 for sample in games:
  for connection in sample.event.get_connections():sample.event.disconnect(connection.callable)
 print("DRONE_WAVE_RULES %d checks %d failures" %[checks,failures])
 quit(1 if failures else 0)
