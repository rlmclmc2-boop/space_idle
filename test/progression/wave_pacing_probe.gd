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
var receipts={}
func observe(kind:String,info:Dictionary):
 if kind=="battle_defeated":defeats+=1
 if kind=="wave_clear":clears+=1
 if kind in ["reactor_changed","hightech_changed","level_clear","resource","wave_clear","battle_defeated"]:
  if kind!="resource":stream.store_line(JSON.stringify({"t":g.simulated_time,"event":kind,"info":info}))
func snapshot()->Dictionary:
 return {"t":g.simulated_time,"stage":g.stage,"wave":g.group_index,"state":g.state,"defeats":defeats,"wave_clears":clears,"resources":g.profile.resources.duplicate(true),"reactor":g.profile.reactorLevel,"allocation":g.profile.reactorAllocation.duplicate(true),"gear":g.profile.loadout.duplicate(true),"research":g.profile.hightechLevels.duplicate(true),"ai":g.profile.scientists,"strength":g.enhancement_level(),"production_seconds":g.profile.productionElapsed,"iron_60s":g.resource_minute_total("1"),"uranium_60s":g.resource_minute_total("2"),"cleared":g.profile.cleared.duplicate()}
func transact():
 var before=snapshot()
 if g.ship_unlocked("Destroyer") and g.profile.selectedShip!="Destroyer":
  g.switch_ship("Destroyer")
  for i in g.active_slot_count("weapons"):
   if str(g.profile.loadout.weapons[i].get("key",""))=="":g.equip_slot("weapons",i,"longLaser")
 if g.content_unlocked("crew","navigator"):
  g.crew.assign(g,"navigator","equipment_upgrade","equipment","1")
 var reserve=N.multiply(g.profile.resources.get("2",0),0.5)
 var total=0.0
 var count=0
 for offset in 100:
  var price=g.reactor_upgrade_cost(int(g.profile.reactorLevel)+offset)
  if N.compare(N.add(total,price),reserve)>0:break
  total=N.add(total,price);count+=1
 if count>0:g.upgrade_reactor(count)
 g.equalize_reactor_allocation()
 var quote=g.scientist_purchase(10)
 var affordable=int(quote.get("count",0))==10
 for key in quote.get("costs",{}):
  if N.compare(quote.costs[key],N.multiply(g.profile.resources.get(str(key),0),0.25))>0:affordable=false
 if affordable:g.generate_scientist(10)
 g.distribute_scientists()
 var levels=g.enhancement_max_upgrades()
 if levels>0:g.upgrade_enhancement(levels)
 stream.store_line(JSON.stringify({"t":g.simulated_time,"event":"normal_transactions","before":before,"after":snapshot(),"reactor_debit":total if count>0 else 0}))
func _initialize():call_deferred("run")
func run():
 var r:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("QA_PACING_REQUEST")))
 stream=FileAccess.open(r.output,FileAccess.WRITE)
 var raw:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(r.save))
 raw.chronoSavedAt=Time.get_unix_time_from_system()
 g=Game.new(ShipDatabase.new());g.stat_cache_enabled=true
 g.load_progress_data(raw);g.resume_progress();g.paused=false;g.speed=1.0;g.rng.seed=20261010
 g.event.connect(observe)
 var driver=Driver.new();driver.production_ui_ticks=true;driver.ui_refresh_seconds=60.0
 driver.setup(self,g)
 if not is_instance_valid(driver.scene) or not driver.scene.has_method("before_logical_game_tick"):
  printerr("Calibration scene failed to load");quit(2);return
 await process_frame;await process_frame
 stream.store_line(JSON.stringify({"event":"initial","state":snapshot(),"request":r,"scope":"Accelerated fixed1/60 calibration; restored journey regenerates battle; deterministic QA RNG; saved production/research continue; optional transactions every120s; scene launch/target providers retained; no player scoring or total-duration acceptance."}))
 var wall=Time.get_ticks_usec();var budget=wall
 for tick in roundi(float(r.seconds)*60.0):
  if tick%7200==0 and r.get("transactions",false):transact()
  if not g.pending_unlocks.is_empty():g.acknowledge_unlocks()
  if g.state==g.State.LEVEL_CLEAR:
   if g.stage>=int(r.get("stop_clear",20)):break
   g.advance_after_clear()
  driver.before_tick(STEP);g.tick(STEP);driver.after_tick(STEP)
  if tick%3600==0:
   stream.store_line(JSON.stringify({"event":"sample","state":snapshot()}));stream.flush()
  if Time.get_ticks_usec()-budget>24000:await process_frame;budget=Time.get_ticks_usec()
 var result=snapshot();result.wall_seconds=float(Time.get_ticks_usec()-wall)/1e6
 stream.store_line(JSON.stringify({"event":"final","state":result}));stream.close()
 print("PACING_RESULT ",JSON.stringify(result))
 driver.close();quit()
