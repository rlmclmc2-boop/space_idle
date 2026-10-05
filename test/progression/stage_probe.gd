extends SceneTree
## Same-save/RNG short probes. No player actions; exact fixed1/60 remains mandatory.
const Game=preload("res://qa/presented_balance_game.gd")
const Driver=preload("res://qa/scene_driver.gd")
const Checkpoint=preload("res://qa/hyperspace_checkpoint.gd")
const N=preload("res://scripts/growth_number.gd")
const STEP:=1.0/60.0
func clean(value):
 if value is float and not is_finite(value):return str(value)
 if value is Array:
  var result:Array=[]
  for item in value:result.append(clean(item))
  return result
 if value is Dictionary:
  var result:Dictionary={}
  for key in value:result[key]=clean(value[key])
  return result
 return value
func signature(g)->Dictionary:
 var p:Dictionary=g.profile.duplicate(true)
 for key in ["hightechSavedAt","chronoSavedAt","resourceSamples"]:p.erase(key)
 var result:Dictionary={"profile":p,"rng":str(g.rng.state),"galaxies":g.galaxy.save_data(),"branch_weapons":g.enhancement_branches.weapons,"branch_defenses":g.enhancement_branches.defenses,"branch_sources":g.enhancement_branches.incoming_sources}
 for key in ["stage","group_index","state","distance","player","enemies","projectiles","missile_queue","cooldowns","drops","motion_clock","pending_unlocks","since_hit","clear_timer","guard_elapsed","guard_index","guard_engaged","guard_arrived","retreat_from","retreat_target","retreat_elapsed","retreat_boss_pending","run_resources","uid","projectile_serial","main_attack_serial","attack_instance_serial","auto_gen_elapsed","resource_prune_elapsed","jewel_repeats","jewel_defence_times","jewel_defence_damage","jewel_charged","enhancement_attack_contexts","enhancement_buffers","enhancement_buffer_owners","enhancement_memory_elapsed","enhancement_defense_time","enhancement_deferred_elapsed","enhancement_deferred_tick","enhancement_deferred","enemy_shield_time","enemy_shield_hit_time"]:result[key]=g.get(key)
 return clean(result)
func _initialize()->void:call_deferred("run")
func run()->void:
 var request:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("QA_STAGE_REQUEST")))
 var input:Dictionary=Checkpoint.read_one(str(request.checkpoint)).payload if request.get("format","")=="binary" else JSON.parse_string(FileAccess.get_file_as_string(request.checkpoint))
 var raw:Dictionary=input.save.duplicate(true);raw.chronoSavedAt=Time.get_unix_time_from_system()
 var g=Game.new(ShipDatabase.new());g.stat_cache_enabled=true;g.simulated_time=float(input.x1_seconds)
 if not g.load_hyperspace_routes():printerr("Route loader rejected");quit(2);return
 g.load_progress_data(raw);g.profile.chronoParticles=float(raw.get("chronoParticles",0));g.login_chrono_particles=0
 g.resume_progress();g.rng.state=int(str(input.rng_state))
 var modifications:Array=[]
 if request.scenario=="idle-growth":
  g.enemies.clear();g.projectiles.clear();g.missile_queue.clear();g.cooldowns.clear();g.state=g.State.LEVEL_SELECT
  modifications.append("Isolated growth branch: state=LEVEL_SELECT; clear battle actors/projectiles/cooldowns. No currency/equipment/affix grants; not natural combat continuation.")
 var driver
 if request.mode!="headless":
  driver=Driver.new();driver.production_ui_ticks=true;driver.setup(self,g)
  driver.ui_refresh_seconds=1.0 if request.mode=="ui1s" else 3600.0 if request.mode=="minimal-vfx" else 0.0
  root.size=Vector2i(1373,883);await process_frame;await process_frame
 var stream:=FileAccess.open(str(request.output)+"/states.jsonl",FileAccess.WRITE)
 stream.store_line(JSON.stringify({"step":0,"state":signature(g)},"",true))
 var timing:Dictionary={"before_tick_us":0,"game_tick_us":0,"after_tick_us":0,"state_log_us":0,"controller_us":0,"yield_us":0}
 var state_times:Dictionary={};var start:=Time.get_ticks_usec();var budget_start:=start
 var ticks:=roundi(float(request.seconds)*60.0)
 for tick in ticks:
  var label:String="combat" if g.state==g.State.COMBAT else "noncombat"
  var a:=Time.get_ticks_usec()
  if driver!=null:driver.before_tick(STEP)
  var b:=Time.get_ticks_usec();g.tick(STEP);var c:=Time.get_ticks_usec()
  if driver!=null:
   if request.mode=="minimal-vfx":
    # Full event handler and pre-tick poses remain. Only post-tick cosmetic containers are dropped.
    for key in ["particles","floats","pickup_effects","beam_visuals","projectile_visuals","destruction_events","missile_events","rail_events","enemy_impacts","pulse_events"]:driver.scene.get(key).clear()
    driver.scene.damage_pending.clear()
    driver.scene.hightech_page._process(STEP)
   else:driver.after_tick(STEP)
  var d:=Time.get_ticks_usec()
  timing.before_tick_us+=b-a;timing.game_tick_us+=c-b;timing.after_tick_us+=d-c
  if not state_times.has(label):state_times[label]={"ticks":0,"wall_us":0}
  state_times[label].ticks+=1;state_times[label].wall_us+=d-a
  if (tick+1)%60==0 or tick+1==ticks:
   var logging:=Time.get_ticks_usec();stream.store_line(JSON.stringify({"step":tick+1,"state":signature(g)},"",true));timing.state_log_us+=Time.get_ticks_usec()-logging
  # Batch fixed ticks, yielding only between logical steps. No dt, speed or chrono manipulation.
  if Time.get_ticks_usec()-budget_start>=24000:
   var yielding:=Time.get_ticks_usec();await process_frame;timing.yield_us+=Time.get_ticks_usec()-yielding;budget_start=Time.get_ticks_usec()
 var wall:float=float(Time.get_ticks_usec()-start)/1e6;stream.close()
 var result:Dictionary={"mode":request.mode,"scenario":request.scenario,"x1_seconds":float(ticks)*STEP,"wall_seconds":wall,"x1_per_wall":float(ticks)*STEP/wall,"ticks":ticks,"fixed_step":STEP,"timing":timing,"state_times":state_times,"input":request,"source_x1":input.x1_seconds,"final_x1":g.simulated_time,"final_stage":g.stage,"final_group":g.group_index,"final_rng":str(g.rng.state),"modifications":modifications,"policy":"No new player actions; existing saved crew/auto systems continue through production tick","normal_reload":"Formal journey regeneration; interrupted manual receipt handled by original production loader","headless_scope":"No scene launch/target/drone/rail providers: approximate combat; compare error before use" if request.mode=="headless" else "Original Presented game/provider before_tick fixed1/60; post-tick UI/VFX variant requires measured pairing"}
 FileAccess.open(str(request.output)+"/result.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
 print("STAGE_PROBE ",request.mode," ",request.scenario," x1=",result.x1_seconds," wall=",wall," speed=",result.x1_per_wall)
 if driver!=null:driver.close()
 quit()
