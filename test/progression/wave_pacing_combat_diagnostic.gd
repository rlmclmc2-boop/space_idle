extends SceneTree
## Paired cold-start encounter diagnostics; normal refit/purchase APIs; explicit enemy hypothesis, source save unchanged.
const Game=preload("res://qa/presented_balance_game.gd")
const Driver=preload("res://qa/scene_driver.gd")
const N=preload("res://scripts/growth_number.gd")
var g
var stream
var incoming={}
var last_hit={}
var finished=false
var outcome={}
var start_time=0.0
func enemies_state():
 return g.enemies.map(func(e):return {"uid":e.uid,"slot":e.slot,"hp":e.hp,"max_hp":e.max_hp,"shield":e.shield,"max_shield":e.max_shield,"armour_type":e.armourType,"shield_type":e.shieldType,"weapons":e.equipment})
func observe(kind:String,info:Dictionary):
 if kind=="hit" and info.get("player",false):
  var key=str(info.type)
  incoming[key]=N.add(incoming.get(key,0),info.amount)
  last_hit={"type":info.type,"paid":info.amount,"armour_after":g.player.armour,"shield_after":g.player.shield}
 if kind in ["battle_defeated","wave_clear"]:
  outcome={"event":kind,"stage":g.stage,"wave":g.group_index,"elapsed_seconds":g.simulated_time-start_time,"enemies":enemies_state(),"incoming_paid_by_type":incoming,"last_hit":last_hit,"player":g.player.duplicate(true)}
  stream.store_line(JSON.stringify(outcome));stream.flush();finished=true
func _initialize():call_deferred("run")
func run():
 var r:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("QA_COMBAT_DIAGNOSTIC")))
 var payload:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(r.save))
 var raw:Dictionary=payload.save.duplicate(true);raw.chronoSavedAt=Time.get_unix_time_from_system()
 g=Game.new(ShipDatabase.new())
 if r.has("enemy_attack_scale"):
  for i in range(5,9):
   var group:Dictionary=g.db.groups[str(int(g.db.levels[13].groups[i].id))]
   group.atkMultiplier=float(group.atkMultiplier)*float(r.enemy_attack_scale)
 g.stat_cache_enabled=true;g.simulated_time=float(payload.state.t);start_time=g.simulated_time
 g.load_progress_data(raw);g.resume_progress();g.paused=false;g.speed=1.0;g.rng.state=int(str(payload.rng_state))
 stream=FileAccess.open(r.output,FileAccess.WRITE)
 var before={"resources":g.profile.resources.duplicate(true),"reactor":g.profile.reactorLevel,"gear":g.profile.loadout.duplicate(true),"armour":g.stat("armour"),"shield":g.stat("shield")}
 var reactor_quote=0.0
 var reactor_ok=false
 if int(r.get("reactor_levels",0))>0:
  for offset in int(r.reactor_levels):reactor_quote=N.add(reactor_quote,g.reactor_upgrade_cost(int(g.profile.reactorLevel)+offset))
  reactor_ok=g.upgrade_reactor(int(r.reactor_levels))
  if reactor_ok:g.equalize_reactor_allocation()
 var changes=[]
 for action in r.get("refits",[]):
  changes.append({"action":action,"success":g.equip_slot(action.category,int(action.index),action.key)})
 stream.store_line(JSON.stringify({"event":"initial","checkpoint":r.save,"save_sha256":FileAccess.get_sha256(r.save),"data_sha256":FileAccess.get_sha256("res://data/game_data.json"),"game_sha256":FileAccess.get_sha256("res://scripts/game.gd"),"qa_sha256":FileAccess.get_sha256(get_script().resource_path),"declared_enemy_attack_scale":r.get("enemy_attack_scale",1),"reactor_purchase":{"quote":reactor_quote,"success":reactor_ok,"levels":r.get("reactor_levels",0)},"scope":"Same complete QA economic checkpoint and engine/RNG; declared enemy-attack scale identifies the balance variant; portable reload regenerates actors/full health, excludes live cooldowns. Normal free refit preserves paid module levels/assets. Stop at first clear/death; crew/research/production continue.","before":before,"after":{"resources":g.profile.resources.duplicate(true),"reactor":g.profile.reactorLevel,"gear":g.profile.loadout.duplicate(true),"armour":g.stat("armour"),"shield":g.stat("shield")},"refits":changes,"stage":g.stage,"wave":g.group_index,"enemies":enemies_state()}))
 g.event.connect(observe)
 var driver=Driver.new();driver.production_ui_ticks=true;driver.ui_refresh_seconds=60.0;driver.setup(self,g)
 await process_frame;await process_frame
 var wall=Time.get_ticks_usec();var budget=wall
 for tick in roundi(float(r.get("seconds",180))*60):
  if finished:break
  driver.before_tick(1.0/60.0);g.tick(1.0/60.0);driver.after_tick(1.0/60.0)
  if Time.get_ticks_usec()-budget>24000:await process_frame;budget=Time.get_ticks_usec()
 var result={"event":"final","finished":finished,"outcome":outcome,"elapsed_seconds":g.simulated_time-start_time,"wall_seconds":float(Time.get_ticks_usec()-wall)/1e6,"resources":g.profile.resources,"enemies":enemies_state(),"incoming_paid_by_type":incoming}
 stream.store_line(JSON.stringify(result));stream.close();print("COMBAT_DIAGNOSTIC ",JSON.stringify(result));driver.close();quit()
