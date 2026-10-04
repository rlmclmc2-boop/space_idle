extends SceneTree
const Rewards=preload("res://scripts/drone_rewards.gd")
const Bag=preload("res://scripts/drone_inventory.gd")
class Probe extends "res://scripts/presented_battle_game.gd":
 var measured:=false
 var counters:Dictionary={}
 func bump(key:String)->void:
  if measured:counters[key]=int(counters.get(key,0))+1
 func upgrade_cost_for_level(key:String,level:int)->Dictionary:
  bump("cost_projection_calls")
  return super.upgrade_cost_for_level(key,level)
 func hyperspace_totals()->Dictionary:
  if not stat_cache.has("hyperspace_totals"):bump("drone_projection_builds")
  return super.hyperspace_totals()
 func hit_enemy(enemy:Dictionary,raw,type:int,effects:Array=[],critical:bool=false,context:Dictionary={})->void:
  bump("hits_depth_%d"%int(context.get("trigger_depth",0)))
  if int(context.get("trigger_depth",0))>1:bump("illegal_depth")
  if str(context.get("source_id","")).begins_with("drone:"):bump("drone_hits")
  if not str(context.get("trigger","")).is_empty():bump("trigger_"+str(context.trigger))
  super.hit_enemy(enemy,raw,type,effects,critical,context)
var failures:=0
func require(ok:bool,label:String)->void:
 if not ok:failures+=1;printerr("FAIL ",label)
func fixture(count:int)->Probe:
 var g:=Probe.new(ShipDatabase.new(),false)
 g.profile.cleared=range(1,41);g.profile.highestLevel=40;g.rebuild_unlocks()
 g.profile.grantedUnlocks=[g.db.unlock_id("feature","jewels")]
 g.profile.selectedShip="Heavy_Battleship"
 g.profile.resources={"1":1e100,"2":1e100}
 g.profile.loadout={"weapons":[],"defence":[]}
 for key in ["laser","laser","laser","missile","missile","longLaser","longLaser","longLaser"]:g.profile.loadout.weapons.append({"key":key,"level":150})
 for key in ["armour","armour","shield","shield"]:g.profile.loadout.defence.append({"key":key,"level":1500})
 g.profile.enhancementLevel=479
 for category in ["weapons","defence"]:
  for effect in g.default_enhancement_order()[category]:
   for node in [1,2,3]:require(g.set_enhancement_branch(category,effect,node,"A" if effect=="repeat" and node==2 or effect=="critical" and node==3 else "B"),"branch selectable "+category+effect+str(node))
 var rng:=RandomNumberGenerator.new();rng.seed=234
 var ids:Array=[]
 for i in 200:
  var quality:String="legendary" if i<2 else "blue" if i<5 else "white"
  var weapon:String=["laser","longLaser","missile","laser","longLaser"][i%5]
  var d:=Rewards.create_drone(rng,g.hyperspace.config,"stress:%d"%i,quality,weapon,40,"1")
  if i<5:
   d.affixes=[{"key":"attack_speed","tier":1,"value":0.15,"locked":false},{"key":"repeat_chance","tier":1,"value":0.15,"locked":false}]
   if i<2:
    d.affixes.append({"key":"global_damage","tier":1,"value":1.0,"locked":false})
    d.legendary_effect={"effect_id":"scatter_pulse" if i==0 else "prism_tower","parameters":{"single_target_bonus":2.0} if i==0 else {"maximum_multiplier_bonus":1.3}}
   if i==2:d.ultimate=true;d.ultimate_affix={"key":"chain_count","tier":1,"value":2.0,"locked":false}
   d.hanging_slots=0;d.hangings=[]
  require(Bag.insert(g.profile.hyperspace.inventory,d,g.hyperspace.config),"inventory insert")
  if i<count:ids.append(d.id)
 g.stat_cache_enabled=true;g.invalidate_stat_cache()
 require(g.hyperspace.set_equipped(g,ids),"equip")
 require(g.start(40,false),"start stage40")
 g.spawn_group()
 var template:Dictionary=g.enemies[0].duplicate(true)
 g.enemies.clear()
 for i in 16:
  var enemy:Dictionary=template.duplicate(true)
  enemy.uid=i+1;enemy.slot=i;enemy.x=70.0+i%4*80;enemy.y=65.0+floori(i/4.0)*55
  enemy.hp=1e90;enemy.max_hp=1e90;enemy.shield=0;enemy.max_shield=0
  enemy.equipment=[{"name":["laser_mon","missile_mon","cannon_mon","longLaser_mon"][i%4]}]
  enemy.cooldowns=[float(g.db.enemy_weapon(enemy.equipment[0].name).cd)]
  g.enemies.append(enemy)
 g.launch_provider=func(mount,aim,_ordinal):
  var pos:=Vector2(g.player.x,g.player.y)+g.player_weapon_offset(mount)
  return {"position":pos,"direction":(aim-pos).normalized()}
 g.drone_launch_provider=func(id,aim,_ordinal):
  var index:int=g.combat_weapon_entries().find(g.combat_weapon_entries().filter(func(entry):return entry.get("drone_id","")==id)[0])
  var pos:=Vector2(g.player.x,g.player.y)+g.player_weapon_offset(index)
  return {"position":pos,"direction":(aim-pos).normalized()}
 g.refresh_missile_target_registry();g.rng.seed=91531
 g.event.connect(func(kind,_info):g.bump("event_"+str(kind)))
 return g
func quotes(g:Probe,mode:String)->Dictionary:
 var cache:Dictionary={};var output:Dictionary={}
 for category in ["weapons","defence"]:
  for i in g.loadout_entries(category).size():
   var entry:Dictionary=g.slot_entry(category,i)
   var key:String=str([category,entry.level,mode])
   if not cache.has(key):
    var count:int=g.max_upgrade_amount_slot(category,i) if mode=="MAX" else 1
    var costs:Dictionary=g.slot_upgrade_cost(category,i,maxi(1,count))
    cache[key]={"amount":count,"costs":costs,"available":count>0 and g.can_afford_upgrade_costs(costs)}
   output[key]=cache[key]
 return output
func stats(samples:Array)->Dictionary:
 var sum:float=0.0
 for n in samples:sum+=float(n)
 var sorted:Array=samples.duplicate();sorted.sort()
 return {"mean_us":sum/samples.size(),"p95_us":sorted[ceili(samples.size()*0.95)-1],"max_us":sorted[-1]}
func run(count:int,mode:String)->Dictionary:
 var g:=fixture(count);var inventory_before:String=JSON.stringify(g.profile.hyperspace.inventory)
 for i in 180:g.tick(1.0/60.0);quotes(g,mode)
 var initial_rng:String=str(g.rng.state);g.measured=true
 var ticks:Array=[];var costs:Array=[];var totals:Array=[];var peak:Dictionary={};var quote:Dictionary={}
 for i in 120:
  var start:int=Time.get_ticks_usec();g.tick(1.0/60.0);var middle:int=Time.get_ticks_usec()
  quote=quotes(g,mode);var end:int=Time.get_ticks_usec()
  ticks.append(middle-start);costs.append(end-middle);totals.append(end-start)
  var now:Dictionary={"projectiles":g.projectiles.size(),"missile_queue":g.missile_queue.size(),"repeats":g.jewel_repeats.size(),"deferred_slots":g.enhancement_deferred.size()}
  for key in now:peak[key]=maxi(int(peak.get(key,0)),int(now[key]))
 require(g.state==g.State.COMBAT,"sustained combat")
 require(g.enemies.size()==16 and g.has_alive_enemy(),"durable target fixture")
 require(JSON.stringify(g.profile.hyperspace.inventory)==inventory_before,"warehouse unchanged")
 require(g.projectiles.size()>5 and int(peak.get("missile_queue",0))>0,"active projectiles and ejection queue")
 require(g.enhancement_effects(g.weapon_entries()[0]).size()==3,"three active weapon enhancement effects")
 var row:Dictionary={"drones":count,"mode":mode,"seed":91531,"warmup_steps":180,"samples":120,"dt":1.0/60.0,"rng_measure_start":initial_rng,"rng_final":str(g.rng.state),"tick":stats(ticks),"quotes":stats(costs),"combined":stats(totals),"peaks":peak,"counters":g.counters,"quotes_final":quote,"branches":g.profile.enhancementBranches,"inventory_count":g.profile.hyperspace.inventory.drones.size(),"source_count":g.combat_weapon_entries().size(),"end_projectiles":g.projectiles.size()}
 g.launch_provider=Callable();g.drone_launch_provider=Callable()
 for connection in g.event.get_connections():g.event.disconnect(connection.callable)
 print("PERFORMANCE_ROW ",JSON.stringify(row))
 return row
func dirty_quotes()->void:
 var g:=fixture(0);g.measured=true
 var samples:Array=[]
 for i in 6:
  g.profile.resources["1"]=1e100*(1.0+float(i)*0.00001)
  var start:int=Time.get_ticks_usec();quotes(g,"MAX");samples.append(Time.get_ticks_usec()-start)
 print("DIRTY_MAX ",JSON.stringify({"samples":6,"quotes":stats(samples),"counters":g.counters}))
 g.launch_provider=Callable();g.drone_launch_provider=Callable()
 for connection in g.event.get_connections():g.event.disconnect(connection.callable)
func _initialize()->void:
 if OS.get_cmdline_user_args().has("--dirty-only"):
  dirty_quotes();quit(1 if failures else 0);return
 var rows:Array=[]
 for count in [0,5]:
  for mode in ["ordinary","MAX"]:rows.append(run(count,mode))
 for count in [0,5]:
  var a:Dictionary=rows[count/5*2];var b:Dictionary=rows[count/5*2+1]
  require(a.rng_final==b.rng_final and a.counters.get("hits_depth_0",0)==b.counters.get("hits_depth_0",0),"quotes do not alter battle")
 dirty_quotes()
 print("PERFORMANCE_CHECK failures=",failures)
 quit(1 if failures else 0)
