extends SceneTree
const Presented=preload("res://scripts/presented_battle_game.gd")
const Rewards=preload("res://scripts/drone_rewards.gd")
const Bag=preload("res://scripts/drone_inventory.gd")
var checks:=0
var failures:=0
var observed:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
class Observed extends "res://scripts/presented_battle_game.gd":
 var prepare_observations:Array=[]
 func prepare_projectile(shot:Dictionary,source:Dictionary,weapon:Dictionary,spread:float)->void:
  if not shot.hostile:prepare_observations.append({"entry":shot.get("entry",{}),"mount":shot.get("mount",-1),"context":shot.get("combat_context",{})})
  super.prepare_projectile(shot,source,weapon,spread)
func _initialize()->void:
 for drone in [false,true]:
  for key in ["laser","cannon","missile","longLaser"]:
   var g:=Observed.new(ShipDatabase.new(),false);g.profile.cleared=range(1,41);g.rebuild_unlocks()
   g.profile.loadout={"weapons":[{"key":key,"level":10}],"defence":[{"key":"armour","level":100}]}
   var rng:=RandomNumberGenerator.new();rng.seed=6
   if drone:
    var d:=Rewards.create_drone(rng,g.hyperspace.config,"source-test","blue",key,5,"1");d.affixes=[]
    Bag.insert(g.profile.hyperspace.inventory,d,g.hyperspace.config);g.hyperspace.set_equipped(g,[d.id])
   g.reset_player();g.state=g.State.COMBAT
   var target:Dictionary={"uid":1,"hp":1e90,"max_hp":1e90,"x":280.0,"y":100.0,"armourType":99,"slot":0,"equipment":[],"drops":[],"res_ratio":1.0}
   g.enemies=[target];g.refresh_missile_target_registry()
   var index:int=g.weapon_entries().size() if drone else 0
   var entry:Dictionary=g.combat_entry(index)
   var origin:=Vector2(340,370) if drone else Vector2(220,390)
   var provider_counts:Dictionary={"ordinary":0,"drone":0}
   g.launch_provider=func(_mount,_aim,_ordinal):provider_counts.ordinary+=1;return {"position":Vector2(220,390),"direction":Vector2.UP}
   g.drone_launch_provider=func(id,_aim,_ordinal):provider_counts.drone+=1;check(id=="source-test","exact provider identity");return {"position":Vector2(340,370),"direction":Vector2.UP}
   var watch:Callable=func(kind,info):
    if kind=="fire" or kind=="beam_started":
     observed+=1
     var shot:Dictionary=info.shot
     check(is_same(shot.entry,entry) and int(shot.mount)==index,"event has committed identity "+key)
     check(shot.combat_context.source_id==("drone:source-test" if drone else "module:0"),"event has provenance "+key)
     check(Vector2(shot.x,shot.y)==origin,"event starts at physical provider "+key)
   g.event.connect(watch)
   if key=="longLaser":g.lock_long_laser(g.player,g.player_weapon_row(entry),false,index,entry)
   else:
    g.begin_enhancement_attack(index,target)
    var attack:Dictionary=g.jewel_attack(index)
    g.launch_player_attack(index,target,g.player_weapon_row(entry),attack,g.player_weapon_offset(index),0.0)
    g.finish_enhancement_attack(index)
    if key=="missile":g.tick_projectiles(0.0)
   check(g.prepare_observations.size()==1 and g.prepare_observations[0].context.source_id==("drone:source-test" if drone else "module:0"),"prepare sees identity "+key)
   check(provider_counts.drone==(1 if drone else 0) and provider_counts.ordinary==(0 if drone else 1),"isolated physical provider "+key)
   check(g.projectiles.back().launch_point==origin,"committed launch point "+key)
   g.event.disconnect(watch)
 check(observed==10,"eight launches plus two beam events")
 print("LAUNCH_SOURCES ",checks," checks ",failures," failures")
 quit(1 if failures else 0)
