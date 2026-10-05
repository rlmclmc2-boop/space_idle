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

const PlayerInput=preload("res://qa/player_input.gd")
var records:Array=[]
var events:Array=[]
var output_path:=""
var tracked_game
func _initialize():call_deferred("run_native")
func panel_snapshot(driver,player_input,g)->Dictionary:
 var panel=driver.scene.enhancement_panel
 var cards:Dictionary={}
 for category in panel.effect_cards:
  var list:Array=[]
  for card in panel.effect_cards[category]:
   list.append({"title":card.title.text,"description":card.description.text,"state":card.state.text,"up_disabled":card.up.disabled,"down_disabled":card.down.disabled,"branches_disabled":card.branches.disabled,"branches_tooltip":card.branches.tooltip_text})
  cards[category]=list
 var gate:Dictionary=player_input.gate(panel.upgrade_button)
 gate.erase("path")
 return {"x1":g.simulated_time,"page":driver.scene.equipment_tabs.current_tab,"visible":panel.is_visible_in_tree(),"upgrade_disabled":panel.upgrade_button.disabled,"max_disabled":panel.max_button.disabled,"upgrade_gate":gate,"game_eligible":g.can_upgrade_enhancement(),"level":g.enhancement_level(),"fragments":g.profile.jewelFragments,"cost":g.enhancement_cost(),"level_label":panel.level_label.text,"balance_label":panel.balance_label.text,"cost_label":panel.cost_label.text,"history_tooltip":panel.level_label.tooltip_text,"progress":panel.progress.value,"feedback":panel.feedback.text,"cards":cards}
func observe_event(kind:String,info:Dictionary):
 if kind in ["enhancement_changed","jewels_changed","jewel_pickup","enhancement_currency","upgrade","upgrades_completed","module_changed","ship_changed"]:
  events.append({"x1":tracked_game.simulated_time,"kind":kind,"amount":info.get("amount"),"purchased":info.get("purchased"),"slot":info.get("slot")})
func normalized_gate(gate:Dictionary)->Dictionary:
 var result=gate.duplicate(true)
 result.erase("path");result.erase("hovered")
 return result
func run_native():
 var request:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("QA_NATIVE_REQUEST")))
 output_path=request.output
 var input:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(request.checkpoint))
 var raw:Dictionary=input.save.duplicate(true);raw.chronoSavedAt=Time.get_unix_time_from_system()
 var g=Game.new(ShipDatabase.new());g.stat_cache_enabled=true;g.simulated_time=float(input.x1_seconds)
 if not g.load_hyperspace_routes():printerr("Route load failed");quit(2);return
 g.load_progress_data(raw);g.profile.chronoParticles=float(raw.get("chronoParticles",0));g.login_chrono_particles=0;g.resume_progress();g.rng.state=int(str(input.rng_state))
 tracked_game=g;g.event.connect(observe_event)
 var driver=Driver.new();driver.production_ui_ticks=true
 driver.scene_path="res://qa/cached_battlefield.tscn" if request.mode=="cached" else "res://main.tscn"
 driver.drop_post_vfx=request.mode=="cached";driver.ui_refresh_seconds=3600.0 if request.mode=="cached" else 0.0
 driver.setup(self,g);root.size=Vector2i(1373,883);root.grab_focus();await process_frame;await process_frame
 var player_input=PlayerInput.new();player_input.setup(driver.scene,self)
 var nav=await player_input.press(driver.scene.system_nav_buttons[4])
 records.append({"kind":"native_page_visit","x1":g.simulated_time,"ok":nav,"page":driver.scene.equipment_tabs.current_tab,"gate":normalized_gate(player_input.last_gate)})
 if not nav or driver.scene.equipment_tabs.current_tab!=4:printerr("Native enhancement navigation rejected");quit(2);return
 var states:=FileAccess.open(output_path+"/states.jsonl",FileAccess.WRITE)
 var panels:=FileAccess.open(output_path+"/panels.jsonl",FileAccess.WRITE)
 states.store_line(JSON.stringify({"step":0,"state":signature(g)},"",true));panels.store_line(JSON.stringify({"step":0,"panel":panel_snapshot(driver,player_input,g)},"",true))
 var attempted:Array=[0,720,1320,1800]
 var start:=Time.get_ticks_usec();var budget_start:=start
 for tick in range(1801):
  if tick in attempted:
   if request.mode=="cached":
    driver.scene.refresh_visible_cards(0.0);driver.scene.refresh_navigation();driver.scene.enhancement_panel.refresh();await process_frame
   var before=panel_snapshot(driver,player_input,g)
   var ok=await player_input.press(driver.scene.enhancement_panel.upgrade_button)
   records.append({"kind":"native_upgrade_attempt","step":tick,"x1":g.simulated_time,"ok":ok,"gate":normalized_gate(player_input.last_gate),"before":before,"after":panel_snapshot(driver,player_input,g)})
  if tick==1800:break
  driver.before_tick(STEP);g.tick(STEP);driver.after_tick(STEP)
  if (tick+1)%60==0:
   states.store_line(JSON.stringify({"step":tick+1,"state":signature(g)},"",true));panels.store_line(JSON.stringify({"step":tick+1,"panel":panel_snapshot(driver,player_input,g)},"",true))
  if Time.get_ticks_usec()-budget_start>=24000:await process_frame;budget_start=Time.get_ticks_usec()
 states.close();panels.close()
 FileAccess.open(output_path+"/actions.json",FileAccess.WRITE).store_string(JSON.stringify(records,"\t"))
 FileAccess.open(output_path+"/events.json",FileAccess.WRITE).store_string(JSON.stringify(events,"\t"))
 FileAccess.open(output_path+"/save_final.json",FileAccess.WRITE).store_string(JSON.stringify({"x1_seconds":g.simulated_time,"rng_state":str(g.rng.state),"save":g.portable_save_data()},"\t"))
 var r={"mode":request.mode,"seconds":30,"ticks":1800,"wall_seconds":float(Time.get_ticks_usec()-start)/1e6,"source":request,"initial_phase":raw.journey,"final_phase":g.portable_save_data().journey,"final_rng":str(g.rng.state),"native_action_plan":["page4 at source time","upgrade single at0/12/22/30X1 regardless of availability"],"scope":"Real same-source save, formal reload, original provider fixed1/60, native Input.parse_input_event. Rejected disabled intents are retained. No extra currency/equipment, no player save writes."}
 FileAccess.open(output_path+"/result.json",FileAccess.WRITE).store_string(JSON.stringify(r,"\t"));print("NATIVE_UI_DONE ",request.mode," ",r.wall_seconds)
 driver.close();quit()
