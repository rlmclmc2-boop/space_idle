extends SceneTree
const Driver=preload("res://qa/scene_driver.gd")
const N=preload("res://scripts/growth_number.gd")
const Formation=preload("res://scripts/enemy_formation.gd")
class ProbeGame extends "res://scripts/presented_battle_game.gd":
 var incoming_by_source:Dictionary={}
 var armour_damage=0.0
 var shield_damage=0.0
 func hit_player(raw,type:int,context:Dictionary={}) -> void:
  var old_armour=player.armour
  var old_shield=player.shield
  var source:=int(context.get("source_uid",0))
  incoming_by_source[source]=float(incoming_by_source.get(source,0.0))+float(raw)
  super.hit_player(raw,type,context)
  armour_damage=N.add(armour_damage,N.subtract(old_armour,player.armour))
  shield_damage=N.add(shield_damage,N.subtract(old_shield,player.shield))
var options:Dictionary={}
var scene
var driver=Driver.new()
func fixture(record:Dictionary,weapon:String,upgrade:int,seed_value:int):
 var db:=ShipDatabase.new()
 for key in options.get("candidate_groups",{}):db.groups[key]=options.candidate_groups[key].duplicate(true)
 for key in options.get("weapon_damage",{}):db.equipment[key][0].dmg=options.weapon_damage[key]
 for key in options.get("enemies",{}):
  if not db.enemies.has(key):db.enemies[key]={}
  for field in options.enemies[key]:db.enemies[key][field]=options.enemies[key][field]
 # Private one-encounter level; source level/progress is never edited.
 db.levels[0]=db.levels[0].duplicate(true)
 db.levels[0].groups=[{"id":int(record.group_id),"position":0.0}]
 if record.tier in ["normal","elite"]:
  db.levels[0].groups.append({"id":int(record.group_id),"position":0.99})
 db.levels[0].atkRatio=1.0;db.levels[0].lifeRatio=1.0;db.levels[0].resRatio=1.0
 # Historical 8b diagnostics need explicit leak suppression. Current-main
 # checks leave the real authored value intact and use its repaired gate.
 if options.get("suppress_critical_leak",false):db.data.enhance_config.base_critical_rate.value=0
 var game=ProbeGame.new(db,false);game.rng.seed=seed_value;game.speed=1
 game.profile.selectedShip="Destroyer";game.profile.grantedUnlocks=[db.unlock_id("ship","Destroyer")]
 game.profile.unlocked=BattleGame.EQUIPMENT.duplicate();game.profile.cleared=[];game.profile.highestLevel=1
 game.profile.loadout={"weapons":[],"defence":[]}
 var level:=int(record.base_level)+upgrade
 for i in 4:game.profile.loadout.weapons.append({"key":weapon,"level":level})
 game.profile.loadout.defence=[{"key":"armour","level":level},{"key":"shield","level":level}]
 game.profile.crew=[];game.profile.enhancementLevel=0;game.profile.enhancementBranches=game.default_enhancement_branches()
 for key in game.profile.hightechLevels:game.profile.hightechLevels[key]=0
 for key in game.profile.reactorAllocation:game.profile.reactorAllocation[key]=0
 game.stat_cache_enabled=true;game.reset_player();game.start(1,false);game.spawn_group()
 if options.get("presentation",false):
  if scene.game.event.is_connected(scene.on_event):scene.game.event.disconnect(scene.on_event)
  scene.db=db;scene.game=game;scene.current_hull="Destroyer"
  game.event.connect(scene.on_event)
  scene.enemy_poses.clear();scene.turret_visuals.clear();scene.fx_time=0.0;scene.demo_time=0.0
  for field in ["particles","floats","pickup_effects","damage_pending","destruction_events","missile_events","pulse_events","rail_events","enemy_impacts"]:scene.get(field).clear()
  scene.projectile_visuals.clear();scene.beam_visuals.clear()
  scene.ship_view.set_hull("Destroyer")
  # Reused scene must start every match with the same carrier phase and pose.
  scene.ship_view.orbit_elapsed=0.0
  scene.ship_view.pose_initialized=false
  scene.ship_view.loadout_signature=""
  scene.ship_view.set_loadout(game.weapon_entries(),game.active_slot_count("weapons"))
  scene._set_reference_dimensions()
  game.launch_provider=scene._prototype_launch_pose;game.target_provider=scene._prototype_target_point
 return game
func _initialize():call_deferred("run")
func run():
 var args:=OS.get_cmdline_user_args()
 if args.is_empty():printerr("A pinned options JSON is required");quit(2);return
 options=JSON.parse_string(FileAccess.get_file_as_string(args[0]))
 options.presentation=true
 scene=load("res://main.tscn").instantiate();scene.automation_args=["--capture"]
 root.add_child(scene);scene.set_process(false);scene.game.save_enabled=false;driver.scene=scene
 if not is_instance_valid(scene.ship_view):printerr("Real ship_view unavailable");quit(2);return
 var records:Dictionary=ShipDatabase.new().data.battle_design.duplicate(true)
 records.merge(options.candidate_records,true)
 var count:=0
 var result_file:=FileAccess.open(str(options.output),FileAccess.WRITE)
 for id in records:
  if options.has("groups") and not id in options.groups:continue
  var record:Dictionary=records[id]
  for weapon in options.get("weapons",["laser","missile","cannon","longLaser"]):
   for upgrade in options.get("upgrades",[0,1,2,3]):
    for seed_value in options.get("seeds",[1701]):
     var game=fixture(record,str(weapon),int(upgrade),int(seed_value))
     var armour_start=game.player.armour
     var shield_start=game.player.shield
     var geometry_errors:Array=scene.validate_explicit_formation() if id.begins_with("N") else []
     if id.begins_with("N"):
      var source_group:Dictionary=game.db.groups[str(int(record.group_id))]
      var input_error:=Formation.explicit_error(source_group.slots,game.db.enemies,source_group.formation_positions)
      if not input_error.is_empty():geometry_errors.append(input_error)
      if game.enemies.is_empty():geometry_errors.append("No enemies spawned; input rejection cannot count as valid preflight")
     var elapsed:=0.0
     var win:Variant=null
     if geometry_errors.is_empty() and options.get("phase","preflight")=="battle":
      for step in int(float(options.get("timeout_seconds",120.0))*60.0):
       driver.before_tick(1.0/60.0);game.tick(1.0/60.0);driver.after_tick(1.0/60.0)
       elapsed+=1.0/60.0
       if game.state==BattleGame.State.LEVEL_CLEAR or (game.state==BattleGame.State.TRAVEL and not game.has_alive_enemy()):win=true;break
       if game.state==BattleGame.State.RETREAT or N.compare(game.player.armour,0)<=0:win=false;break
     var points:Array=[]
     for enemy in game.enemies:points.append({"slot":enemy.slot,"logical":[enemy.x,enemy.y],"render":str(scene.enemy_render_position(enemy)),"explicit":enemy.get("explicit_formation",false)})
     var row:Dictionary={"id":id,"tier":record.tier,"group_id":record.group_id,"weapon":weapon,"upgrade":upgrade,"module_level":int(record.base_level)+int(upgrade),"seed":seed_value,"win":win,"seconds":elapsed,"geometry_errors":geometry_errors,"positions":points,"player_armour":game.player.armour,"player_shield":game.player.shield,"armour_start":armour_start,"shield_start":shield_start,"armour_damage":game.armour_damage,"shield_damage":game.shield_damage,"armour_remaining_ratio":N.ratio(game.player.armour,armour_start),"incoming_raw_by_source":game.incoming_by_source,"engine":Engine.get_version_info().string,"presentation_providers":game.launch_provider.is_valid() and game.target_provider.is_valid(),"state":game.state,"speed":game.speed,"source_sha256":FileAccess.get_sha256("res://data/game_data.json"),"input_sha256":FileAccess.get_sha256(args[0]),"status":"geometry_rejected" if not geometry_errors.is_empty() else "preflight_only" if options.get("phase","preflight")!="battle" else "timeout" if win==null else "measured"}
     result_file.store_line(JSON.stringify(row));result_file.flush();count+=1
     if count%8==0:print("PAIRED SCENE: ",count," rows; no balance acceptance claim");await process_frame
 result_file.close()
 scene.queue_free();await process_frame;quit()
