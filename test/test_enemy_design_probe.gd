extends SceneTree
const Presented=preload("res://scripts/presented_battle_game.gd")
const N=preload("res://scripts/growth_number.gd")
class ProbeGame extends "res://scripts/presented_battle_game.gd":
 var incoming_by_source: Dictionary={}
 func hit_player(raw,type:int,context:Dictionary={}) -> void:
  var source:=int(context.get("source_uid",0))
  incoming_by_source[source]=float(incoming_by_source.get(source,0.0))+float(raw)
  super.hit_player(raw,type,context)
var output: Array=[]
var options: Dictionary={}
var scene
func fixture(record:Dictionary,weapon:String,upgrade:int,seed_value:int):
 var db:=ShipDatabase.new()
 for key in options.get("weapon_damage",{}):db.equipment[key][0].dmg=options.weapon_damage[key]
 for key in options.get("enemies",{}):
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
 game.profile.loadout.defence=[{"key":"shield","level":level},{"key":"armour","level":level}]
 game.profile.crew=[];game.profile.enhancementLevel=0;game.profile.enhancementBranches=game.default_enhancement_branches()
 for key in game.profile.hightechLevels:game.profile.hightechLevels[key]=0
 for key in game.profile.reactorAllocation:game.profile.reactorAllocation[key]=0
 game.stat_cache_enabled=true;game.reset_player();game.start(1,false);game.spawn_group()
 if options.get("presentation",false):
  scene.db=db;scene.game=game;scene.current_hull="Destroyer"
  scene.enemy_poses.clear();scene.turret_visuals.clear();scene.fx_time=0.0;scene.demo_time=0.0
  scene.ship_view.set_hull("Destroyer")
  # Reused scene must start every match with the same carrier phase and pose.
  scene.ship_view.orbit_elapsed=0.0
  scene.ship_view.pose_initialized=false
  scene.ship_view.loadout_signature=""
  scene.ship_view.set_loadout(game.weapon_entries(),game.active_slot_count("weapons"))
  scene._set_reference_dimensions()
  game.launch_provider=scene._prototype_launch_pose;game.target_provider=scene._prototype_target_point
 return game
func presentation_before_tick(dt:float):
 scene.demo_time+=dt
 var aim:Vector2=scene.player_render_position()+Vector2(0,-450)
 if not scene.game.enemies.is_empty():aim=scene.enemy_render_position(scene.game.enemies[0])
 scene.ship_view.set_pose(scene.player_render_position()+scene.reference_offset,scene.reference_height,0.0,aim,scene.demo_time,scene.shield_enabled,false,dt)
 scene.fx_time+=dt;scene.advance_turrets(dt)
func _initialize():call_deferred("run")
func run():
 var args:=OS.get_cmdline_user_args()
 if not args.is_empty():options=JSON.parse_string(FileAccess.get_file_as_string(args[0]))
 if options.get("presentation",false):
  scene=load("res://main.tscn").instantiate();scene.automation_args=["--capture"]
  root.add_child(scene);scene.set_process(false);scene.game.save_enabled=false
  if not is_instance_valid(scene.ship_view):
   printerr("Fixture initialization failed: ship view unavailable");quit(1);return
 var records:Dictionary=ShipDatabase.new().data.battle_design
 for id in records:
  if options.has("groups") and not id in options.groups:continue
  var record:Dictionary=records[id]
  for weapon in options.get("weapons",["laser","missile","cannon","longLaser"]):
   if options.get("critical_only",false) and record.counter!="neutral":
    var preferred:String={"physical":"cannon","energy":"longLaser"}.get(record.counter,record.counter)
    if weapon!=preferred:continue
   var levels:Array=options.get("upgrades",[0,1,2,3])
   if options.get("critical_only",false):levels={"normal":[0,3],"elite":[0,1],"boss":[1,2],"ultimate":[2,3]}[record.tier]
   for upgrade in levels:
    var seed_value:=int(options.get("seed",1701))
    var game=fixture(record,weapon,int(upgrade),seed_value)
    var elapsed:=0.0;var result:Variant=null
    for step in 7200:
     if options.get("presentation",false):presentation_before_tick(1.0/60.0)
     game.tick(1.0/60.0);elapsed+=1.0/60.0
     if game.state==BattleGame.State.LEVEL_CLEAR:result=true;break
     if game.state==BattleGame.State.TRAVEL and not game.has_alive_enemy():result=true;break
     if game.state==BattleGame.State.RETREAT or N.compare(game.player.armour,0)<=0:result=false;break
    var hp:=0.0
    var incoming:Dictionary={}
    for enemy in game.enemies:hp+=float(enemy.hp)
    for enemy in game.enemies:
     var key:=str(int(enemy.id))
     incoming[key]=float(incoming.get(key,0.0))+float(game.incoming_by_source.get(int(enemy.uid),0.0))
    output.append({"id":id,"group_id":record.group_id,"tier":record.tier,"counter":record.counter,"weapon":weapon,"upgrade":upgrade,"module_level":int(record.base_level)+upgrade,"seed":seed_value,"win":result,"seconds":elapsed,"enemy_hp":hp,"player_armour":game.player.armour,"player_shield":game.player.shield,"incoming_raw_by_archetype":incoming,"projected_damage":game.equipment_stat(weapon,int(record.base_level)+int(upgrade)),"engine":Engine.get_version_info().string,"state":int(game.state),"presentation_providers":bool(options.get("presentation",false)),"config_sha256":FileAccess.get_sha256("res://data/game_data.json"),"base_critical_suppressed":bool(options.get("suppress_critical_leak",false)),"speed":game.speed})
  print("EXPLORATORY GROUP: ",id," completed; no acceptance claim")
  FileAccess.open(str(options.get("output","res://enemy-design-results.json")),FileAccess.WRITE).store_string(JSON.stringify(output))
 print("ENEMY DESIGN EXPLORATORY: ",output.size()," matches; speed1; Presented path; timeout120s")
 if is_instance_valid(scene):
  scene.queue_free();await process_frame;scene=null
 quit()
