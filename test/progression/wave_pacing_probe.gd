extends SceneTree
## Authorized isolated calibration; fixed logical step and normal transaction APIs.
## Request/source saves and detailed results stay outside Git.
const Game=preload("res://qa/presented_balance_game.gd")
const Driver=preload("res://qa/scene_driver.gd")
const N=preload("res://scripts/growth_number.gd")
const STEP=1.0/60.0
var g
var stream
var defeats=0
var clears=0
var entry_seen={}
var initial_time=0.0
var policy={"interval_seconds":120,"reactor_uranium_fraction":0.5,"ai_budget_fraction":0.25,"ai_batch":10,"enhancement_max":true,"equalize_reactor":true}
func observe(kind:String,info:Dictionary):
 if kind=="battle_defeated":defeats+=1
 if kind=="wave_clear":clears+=1
 if kind in ["reactor_changed","hightech_changed","level_clear","resource","wave_clear","battle_defeated","state","encounter","upgrade","scientists_changed","enhancement_changed"]:
  if kind!="resource":stream.store_line(JSON.stringify({"t":g.simulated_time,"event":kind,"stage":g.stage,"wave":g.group_index,"info":info}))
func snapshot()->Dictionary:
 return {"t":g.simulated_time,"stage":g.stage,"wave":g.group_index,"state":g.state,"defeats":defeats,"wave_clears":clears,"wave_cursor_semantics":"COMBAT=current 1-based wave; TRAVEL=next 0-based group; LEVEL_CLEAR=count","resources":g.profile.resources.duplicate(true),"fragments":g.profile.jewelFragments,"reactor":g.profile.reactorLevel,"allocation":g.profile.reactorAllocation.duplicate(true),"gear":g.profile.loadout.duplicate(true),"research":g.profile.hightechLevels.duplicate(true),"ai":g.profile.scientists,"strength":g.enhancement_level(),"production_seconds":g.profile.productionElapsed,"iron_60s":g.resource_minute_total("1"),"uranium_60s":g.resource_minute_total("2"),"cleared":g.profile.cleared.duplicate(),"crew":g.profile.crew.duplicate(true),"ship":g.profile.selectedShip}
func transact():
 var before=snapshot()
 if g.ship_unlocked("Destroyer") and g.profile.selectedShip!="Destroyer":
  g.switch_ship("Destroyer")
  for i in g.active_slot_count("weapons"):
   if str(g.profile.loadout.weapons[i].get("key",""))=="":g.equip_slot("weapons",i,"longLaser")
 if g.content_unlocked("crew","navigator"):
  g.crew.assign(g,"navigator","equipment_upgrade","equipment","1")
 var reserve=N.multiply(g.profile.resources.get("2",0),float(policy.reactor_uranium_fraction))
 var total=0.0
 var count=0
 for offset in 100:
  var price=g.reactor_upgrade_cost(int(g.profile.reactorLevel)+offset)
  if N.compare(N.add(total,price),reserve)>0:break
  total=N.add(total,price);count+=1
 if count>0:g.upgrade_reactor(count)
 if policy.equalize_reactor:g.equalize_reactor_allocation()
 var quote=g.scientist_purchase(int(policy.ai_batch))
 var affordable=int(quote.get("count",0))==int(policy.ai_batch)
 for key in quote.get("costs",{}):
  if N.compare(quote.costs[key],N.multiply(g.profile.resources.get(str(key),0),float(policy.ai_budget_fraction)))>0:affordable=false
 if affordable:g.generate_scientist(int(policy.ai_batch))
 g.distribute_scientists()
 var levels=g.enhancement_max_upgrades()
 if levels>0 and policy.enhancement_max:g.upgrade_enhancement(levels)
 stream.store_line(JSON.stringify({"t":g.simulated_time,"event":"normal_transactions","before":before,"after":snapshot(),"reactor_debit":total if count>0 else 0}))
func record_entry(output:String):
 if entry_seen.has(g.stage):return
 entry_seen[g.stage]=true
 var path=output.get_base_dir().path_join("entry_stage_%02d.json"%g.stage)
 FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify({"save":g.portable_save_data(),"state":snapshot(),"rng_state":str(g.rng.state),"data_sha256":FileAccess.get_sha256("res://data/game_data.json"),"scope":"QA first-entry portable checkpoint; reload regenerates combat and does not preserve live actors"}))
func _initialize():call_deferred("run")
func run():
 var r:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("QA_PACING_REQUEST")))
 policy.merge(r.get("policy",{}),true)
 var interval_ticks=maxi(1,roundi(float(policy.interval_seconds)*60))
 stream=FileAccess.open(r.output,FileAccess.WRITE)
 var payload:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(r.save))
 var raw:Dictionary=payload.get("save",payload)
 raw.chronoSavedAt=Time.get_unix_time_from_system()
 g=Game.new(ShipDatabase.new());g.stat_cache_enabled=true
 g.simulated_time=float(payload.get("state",{}).get("t",0));initial_time=g.simulated_time
 g.load_progress_data(raw);g.resume_progress();g.paused=false;g.speed=1.0;g.rng.seed=20261010
 if r.has("rng_state") or payload.has("rng_state"):g.rng.state=int(str(r.get("rng_state",payload.get("rng_state"))))
 g.event.connect(observe)
 var driver=Driver.new();driver.production_ui_ticks=true;driver.ui_refresh_seconds=60.0
 driver.setup(self,g)
 if not is_instance_valid(driver.scene) or not driver.scene.has_method("before_logical_game_tick"):
  printerr("Calibration scene failed to load");quit(2);return
 await process_frame;await process_frame
 stream.store_line(JSON.stringify({"event":"initial","state":snapshot(),"request":r,"strategy_parameters":policy,"data_sha256":FileAccess.get_sha256("res://data/game_data.json"),"source_save_sha256":FileAccess.get_sha256(r.save),"qa_script_sha256":FileAccess.get_sha256("res://qa/wave_pacing_probe.gd"),"engine_version":Engine.get_version_info(),"scope":"Accelerated fixed1/60 calibration; restored journey regenerates battle; deterministic QA RNG; saved production/research continue; transactions per recorded strategy; scene launch/target providers retained; no player scoring or total-duration acceptance."}))
 var wall=Time.get_ticks_usec();var budget=wall
 for tick in roundi(float(r.seconds)*60.0):
  if tick%interval_ticks==0 and r.get("transactions",false):transact()
  if not g.pending_unlocks.is_empty():g.acknowledge_unlocks()
  if g.state==g.State.LEVEL_CLEAR:
   if g.stage>=int(r.get("stop_clear",20)):break
   g.advance_after_clear()
  for action in r.get("actions",[]):
   if action.get("applied",false) or g.simulated_time-initial_time<float(action.get("at_seconds",0)):continue
   action.applied=true
   var before=snapshot();var count=int(action.get("reactor_levels",0));var quote=0.0
   for offset in count:quote=N.add(quote,g.reactor_upgrade_cost(int(g.profile.reactorLevel)+offset))
   var ok=g.upgrade_reactor(count)
   if ok and action.get("equalize",false):g.equalize_reactor_allocation()
   stream.store_line(JSON.stringify({"event":"scripted_transaction","t":g.simulated_time,"request":action,"quote":quote,"success":ok,"before":before,"after":snapshot()}))
  record_entry(r.output)
  driver.before_tick(STEP);g.tick(STEP);driver.after_tick(STEP)
  if tick%3600==0:
   stream.store_line(JSON.stringify({"event":"sample","state":snapshot()}));stream.flush()
  if Time.get_ticks_usec()-budget>24000:await process_frame;budget=Time.get_ticks_usec()
 var result=snapshot();result.elapsed_seconds=g.simulated_time-initial_time;result.wall_seconds=float(Time.get_ticks_usec()-wall)/1e6
 stream.store_line(JSON.stringify({"event":"final","state":result}));stream.close()
 print("PACING_RESULT ",JSON.stringify(result))
 driver.close();quit()
