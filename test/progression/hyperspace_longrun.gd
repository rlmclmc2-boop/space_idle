extends "res://qa/early_page_route.gd"
## Native early controls plus serial visible-page domain actions for newly integrated systems.
const SpacePolicy=preload("res://qa/hyperspace_player_policy.gd")
var space_policy:=SpacePolicy.new()
var options:Dictionary={}
var snapshots:Dictionary={}
var wall_started:=0
var last_wall_report:=0
var last_state_report:=0.0
var space_runs:Array=[]
var active_space_record:Dictionary={}
var refeeds:Array=[]
var operation_seconds:=0.0
var space_seconds:=0.0
var last_frontier:=1
var peak_projectiles:=0
var peak_missile_queue:=0
var model_rebuilds:=0
var last_domain_rejection:=""
var domain_rejections:=0
func save_snapshot(label:String)->void:
 var path:String=output+"/save_"+label+".json"
 FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify({"x1_seconds":game.simulated_time,"save":game.portable_save_data(),"rng_state":str(game.rng.state),"policy":space_policy.VERSION,"code_fingerprint":JSON.parse_string(FileAccess.get_file_as_string("res://qa-manifest.json")).fingerprint,"options":options,"page":page,"clears":clears,"rows":rows},"\t"))
 snapshots[label]=path
func observe(kind:String,payload:Dictionary)->void:
 var manual:bool=game.manual_hyperspace.active
 if kind=="state" and manual:
  state_change()
 else:super.observe(kind,payload)
 if kind=="hyperspace_manual":
  if bool(payload.active):active_space_record={"route":payload.route,"level":payload.level,"start":game.simulated_time,"loadout":game.profile.loadout.duplicate(true),"equipped":game.profile.hyperspace.inventory.equipped.duplicate(),"source_count":game.combat_weapon_entries().size()}
  elif not active_space_record.is_empty():
   active_space_record.end=game.simulated_time;active_space_record.success=payload.success;active_space_record.seconds=game.simulated_time-float(active_space_record.start)
   space_runs.append(active_space_record.duplicate(true));record("space_actual_result",active_space_record);active_space_record={};save_snapshot("space_%d"%space_runs.size())
 if kind=="planet_reforged":
  refeeds.append({"planet":payload.id,"x1_seconds":game.simulated_time,"round":game.profile.hyperspace.round_id,"sealed":game.profile.hyperspace.inventory.sealed.duplicate()})
  save_snapshot("reforge_%d"%refeeds.size());next_tour=game.simulated_time;next_check=game.simulated_time
 if kind=="hyperspace_changed":record("space_feedback",{"payload":payload,"active":game.profile.hyperspace.active.duplicate(true),"energy":game.profile.hyperspace.energy,"warehouse":game.profile.hyperspace.inventory.warehouse.size(),"cores":game.profile.hyperspace.ultimate_cores})
 if kind=="retreat" or kind=="unlock":next_tour=minf(next_tour,game.simulated_time+0.3)
 if int(game.profile.highestLevel)>last_frontier:
  last_frontier=int(game.profile.highestLevel)
  save_snapshot("reach_%d_round_%d"%[last_frontier,int(game.profile.hyperspace.round_id)])
func crew_action()->Dictionary:
 var reserved:String=space_policy.pick_crew(game) if int(game.profile.highestLevel)>=7 else ""
 if reserved.is_empty() and not game.profile.hyperspace.history.is_empty() and not game.profile.hyperspace.auto.enabled:
  for job in ["jewel_auto","reactor_upgrade","hightech_scientists","equipment_upgrade"]:
   for member in game.profile.crew:
    if str(member.assignmentType)==job:return {"domain":true,"kind":"crew_release","crew":str(member.crewId),"reason":"First earned space record needs an actual worker; old automation stops"}
 var panel=driver.scene.crew_panel
 for member in game.profile.crew:
  var id:=str(member.crewId)
  if id==reserved:continue
  if not panel.rows.has(id):continue
  if not str(member.assignmentType).is_empty():
   if str(member.assignmentType) not in ["equipment_upgrade","hightech_scientists"]:continue
   var desired:="10" if member.assignmentType=="equipment_upgrade" else "max"
   if str(member.upgradeMode)==desired:continue
   if panel.selected!=id:return control_action("crew_select",panel.rows[id],{"crew":id})
   return picker_action("crew_mode_open",panel.upgrade_picker,panel.mode_ids.find(desired))
  if not game.crew_exploration(id).is_empty():continue
  if panel.selected!=id:return control_action("crew_select",panel.rows[id],{"crew":id})
  for job in ["equipment_upgrade","hightech_scientists","reactor_upgrade","jewel_auto"]:
   var job_index:int=panel.job_ids.find(job)
   if job_index<0 or panel.jobs.get_popup().is_item_disabled(job_index):continue
   if panel.jobs.selected!=job_index:return picker_action("crew_job_open",panel.jobs,job_index)
   # Target/amount options come from the actual selected inspector. Hidden
   # target pickers keep their production default; never select backend IDs.
   if panel.target_picker.is_visible_in_tree():
    for index in panel.target_ids.size():
     if panel.target_picker.get_popup().is_item_disabled(index):continue
     if panel.target_picker.selected!=index:return picker_action("crew_target_open",panel.target_picker,index)
     break
   # Assign the draft first. Changing the upgrade mode emits a member
   # refresh; the existing-assignment branch sets it on the next visit.
   if not panel.assign_button.disabled:return control_action("crew_assign",panel.assign_button,{"crew":id,"job":job})
 return {}
func action()->Dictionary:
 if not pending_picker.is_empty() or not player_input.modal_windows().is_empty() or not game.pending_unlocks.is_empty():return super.action()
 if page==9:
  var choice:Dictionary=space_policy.space_action(game,game.simulated_time)
  if not choice.is_empty():return choice
 elif page==6:
  var choice:Dictionary=space_policy.planet_action(game)
  if not bool(options.get("allow_reforge",true)) and choice.get("kind")=="planet_reforge":return {}
  if not choice.is_empty():return choice
 elif page==8:
  var choice:Dictionary=space_policy.galaxy_action(game)
  if not choice.is_empty():return choice
 elif page==4:
  for category in game.default_enhancement_order():
   for effect in game.default_enhancement_order()[category]:
    for node in [1,2,3]:
     if game.enhancement_branch_unlocked(category,effect,node) and game.enhancement_branch_choice(category,effect,node).is_empty():return {"domain":true,"kind":"enhancement_branch","category":category,"effect":effect,"node":node,"choice":"A"}
 return super.action()
func click_button(choice:Dictionary)->void:
 operation_seconds+=BUTTON_TIME
 if not bool(choice.get("domain",false)):
  await super.click_button(choice);return
 var before:Dictionary={"resources":game.profile.resources.duplicate(true),"materials":game.profile.hyperspace.materials.duplicate(),"cores":game.profile.hyperspace.ultimate_cores,"energy":game.profile.hyperspace.energy,"round":game.profile.hyperspace.round_id}
 var ok:bool=game.set_enhancement_branch(choice.category,choice.effect,int(choice.node),choice.choice) if choice.kind=="enhancement_branch" else space_policy.execute(game,choice,game.simulated_time)
 if ok:
  clicks+=1;row(game.stage).clicks+=1;domain_rejections=0;last_domain_rejection=""
 else:
  rejected_inputs+=1
  var signature:String=JSON.stringify(choice)
  domain_rejections=domain_rejections+1 if signature==last_domain_rejection else 1;last_domain_rejection=signature
  if domain_rejections>=3:
   # User-authorized workaround: stop retrying this operation, keep the save and push.
   record("domain_blocker_bypassed",{"choice":choice,"reason":game.hyperspace.last_error,"manual_error":game.manual_hyperspace.last_error})
   if choice.kind=="space_manual":space_policy.last_attempt[str([game.profile.hyperspace.round_id,choice.route,choice.level])]=game.simulated_time
   busy=false;next_check=game.simulated_time+300.0
 record("domain_action",{"choice":choice,"ok":ok,"before":before,"after":{"resources":game.profile.resources.duplicate(true),"materials":game.profile.hyperspace.materials.duplicate(),"cores":game.profile.hyperspace.ultimate_cores,"energy":game.profile.hyperspace.energy},"policy":space_policy.VERSION,"input_scope":"one visible system page, real domain command, 0.3 X1 action; native early controls inherited"})
func check_page()->void:
 var before:float=next_tour
 await super.check_page()
 if game.profile.cleared.has(10) and next_tour!=before:
  next_tour=tour_started+float(options.get("visit_seconds",300))
func step_controller()->void:
 await super.step_controller()
 if game.profile.cleared.has(10) and not busy and not touring:next_check=maxf(next_check,game.simulated_time+float(options.get("visit_seconds",300)))
func galaxy_complete()->bool:
 if not game.galaxy.available() or not game.galaxy.regions.has("galaxy_1"):return false
 var region=game.galaxy.regions.galaxy_1
 return region.slots.size()==30 and region.slots.all(func(slot):return int(slot.level)>=5)
func run()->void:
 options={"seed":20261005,"duration":216000.0,"visit_seconds":300,"allow_reforge":true,"stop_clear":0,"wall_limit_seconds":36000.0}
 var parsed=JSON.parse_string(OS.get_environment("HYPERSPACE_LONGRUN_OPTIONS"))
 if parsed is Dictionary:options.merge(parsed,true)
 output=OS.get_environment("QA_DIAGNOSTIC_RESULT_DIR")
 if output.is_empty():printerr("Isolated output required");quit(2);return
 DirAccess.make_dir_recursive_absolute(output)
 trace=FileAccess.open(output+"/actions.jsonl",FileAccess.WRITE)
 game=Game.new(ShipDatabase.new());game.rng.seed=int(options.seed);game.stat_cache_enabled=true
 if not game.load_hyperspace_routes():printerr("Production route/reward loader failed: ",game.manual_hyperspace.last_error);quit(2);return
 driver=Driver.new();driver.ui_refresh_seconds=0.0;driver.production_ui_ticks=true;driver.setup(self,game)
 player_input=PlayerInput.new();player_input.setup(driver.scene,self)
 root.size=Vector2i(1373,883);root.grab_focus();await process_frame;await process_frame
 game.event.connect(observe);game.start(1,false);save_snapshot("fresh")
 wall_started=Time.get_ticks_usec();last_wall_report=wall_started
 record("run_start",{"options":options,"source_commit":JSON.parse_string(FileAccess.get_file_as_string("res://qa-manifest.json")).source_commit,"scene_provider_scope":"production before_logical_game_tick, ordinary/drone/rail/target callbacks, exact Presented fixed steps"})
 while game.simulated_time<float(options.duration) and input_failure.is_empty() and not galaxy_complete():
  if int(options.stop_clear)>0 and clears.has(str(int(options.stop_clear))):break
  if float(Time.get_ticks_usec()-wall_started)/1e6>=float(options.wall_limit_seconds):break
  await step_controller()
  if not input_failure.is_empty():break
  var before_stage:int=game.stage;var before_state:int=game.state;var manual:bool=game.manual_hyperspace.active
  driver.before_tick(STEP);game.tick(STEP);driver.after_tick(STEP)
  if manual:space_seconds+=STEP
  else:
   var state_key:String="travel" if before_state==BattleGame.State.TRAVEL else "combat" if before_state==BattleGame.State.COMBAT else "retreat" if before_state==BattleGame.State.RETREAT else "clear_notice" if before_state==BattleGame.State.LEVEL_CLEAR else "other"
   row(before_stage)[state_key]+=STEP
  peak_projectiles=maxi(peak_projectiles,game.projectiles.size());peak_missile_queue=maxi(peak_missile_queue,game.missile_queue.size())
  var wall_now:int=Time.get_ticks_usec()
  if wall_now-last_wall_report>=30000000:
   last_wall_report=wall_now
   var status:Dictionary={"x1_seconds":game.simulated_time,"wall_seconds":float(wall_now-wall_started)/1e6,"stage":game.stage,"frontier":game.profile.highestLevel,"clears":clears,"deaths":deaths,"clicks":clicks,"space_runs":space_runs.size(),"drones":game.profile.hyperspace.inventory.drones.size(),"round":game.profile.hyperspace.round_id,"projectiles_peak":peak_projectiles,"missile_queue_peak":peak_missile_queue,"data_sha256":FileAccess.get_sha256("res://data/game_data.json")}
   FileAccess.open(output+"/heartbeat.json",FileAccess.WRITE).store_string(JSON.stringify(status,"\t"));trace.flush();print("LONGRUN_HEARTBEAT ",JSON.stringify(status))
   await process_frame
  if game.simulated_time-last_state_report>=1800.0:last_state_report=game.simulated_time;save_snapshot("periodic_%d"%int(game.simulated_time))
 state_change();save_snapshot("final");trace.close()
 var result:Dictionary={"status":"input_failure" if not input_failure.is_empty() else "galaxy_complete" if galaxy_complete() else "bounded_partial","options":options,"x1_seconds":game.simulated_time,"wall_seconds":float(Time.get_ticks_usec()-wall_started)/1e6,"clears":clears,"stage":game.stage,"frontier":game.profile.highestLevel,"input_failure":input_failure,"rows":rows,"segments":segments,"operation_seconds":operation_seconds,"space_seconds":space_seconds,"space_runs":space_runs,"reforges":refeeds,"snapshots":snapshots,"deaths":deaths,"clicks":clicks,"peak_projectiles":peak_projectiles,"peak_missile_queue":peak_missile_queue,"policy":space_policy.VERSION,"data_sha256":FileAccess.get_sha256("res://data/game_data.json"),"manifest":JSON.parse_string(FileAccess.get_file_as_string("res://qa-manifest.json")),"scope":"Fresh real main/Presented scene, native early inputs, serial visible-page new-system domain commands, exact X1 fixed1/60, no injected resources/drones/affix tiers. Reforge T3 is paid planning goal, no cap."}
 FileAccess.open(output+"/longrun-summary.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
 print("LONGRUN_DONE ",result.status," x1=",game.simulated_time," stage=",game.stage)
 driver.close();await process_frame;quit(2 if not input_failure.is_empty() else 0)
