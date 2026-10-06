extends "res://qa/early_page_route.gd"
## Native early controls plus serial visible-page domain actions for newly integrated systems.
const SpacePolicy=preload("res://qa/hyperspace_player_policy.gd")
const NoNewManualPolicy=preload("res://qa/no_new_manual_policy.gd")
var space_policy:=SpacePolicy.new()
func configure_manual_policy()->void:
 space_policy=SpacePolicy.new() if bool(options.get("allow_new_manual",true)) else NoNewManualPolicy.new()
 space_policy.affix_target_tier=clampi(int(options.get("affix_target_tier",0)),0,5)
# Optional isolated stage profiler; frozen P2 policy behavior is unchanged.
var stage_meter=null
const Checkpoint=preload("res://qa/hyperspace_checkpoint.gd")
const SafeFarm=preload("res://qa/hyperspace_safe_farm.gd")
var safe_farm:=SafeFarm.new()
var resume_lineage:Array=[]
var carried_wall_seconds:=0.0
var checkpoint_due:=true
var reforge_checkpoint_pending:Array=[]
var next_checkpoint_wall:=0
var manifest:Dictionary={}
var initial_scope:="fresh"
var farm_seconds:=0.0
var options:Dictionary={}
var crew_transfer_burst:Dictionary={}
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
var round_clears:Dictionary={}
var peak_projectiles:=0
var peak_missile_queue:=0
var model_rebuilds:=0
var last_domain_rejection:=""
var domain_rejections:=0
var operator_stopped:=false
var stop_request_path:=""
var next_stop_poll:=0
func save_snapshot(label:String)->void:
 var path:String=output+"/save_"+label+".json"
 var saved:Dictionary={"x1_seconds":game.simulated_time,"save":game.portable_save_data(),"rng_state":str(game.rng.state),"policy":space_policy.VERSION,"code_fingerprint":JSON.parse_string(FileAccess.get_file_as_string("res://qa-manifest.json")).fingerprint,"options":options,"page":page,"clears":clears,"rows":rows,"safe_farm":{"version":safe_farm.VERSION,"round":safe_farm.round_seen,"phase":safe_farm.phase,"plan":safe_farm.plan.duplicate(true),"known_wins":safe_farm.known.duplicate(true),"actual_defeats":safe_farm.failed.duplicate(true)}}
 var error:=Checkpoint.atomic_json(path,saved)
 if error!=OK:input_failure={"kind":"snapshot_io","error":error,"path":path}
 checkpoint_due=true
 snapshots[label]=path
func checkpoint_now()->void:
 trace.flush()
 # Called after the controller/tick returns, never from an event callback.
 var pending:Array=reforge_checkpoint_pending.duplicate(true)
 reforge_checkpoint_pending.clear()
 var captured:Dictionary=Checkpoint.capture(self,manifest)
 for entry in pending:
  var round_id:int=int(entry.round)
  if round_id!=int(game.profile.hyperspace.round_id) or game.manual_hyperspace.active:
   reforge_checkpoint_pending.assign(pending)
   input_failure={"kind":"reforge_checkpoint_boundary","round":round_id};record("checkpoint_write_failed",input_failure);return
  var archive_path:String=output+"/checkpoint-reforge-round-%d.bin"%round_id
  var archive_error:=Checkpoint.write_once(archive_path,captured,manifest)
  if archive_error==ERR_ALREADY_EXISTS:
   var existing:Dictionary=Checkpoint.read_one(archive_path)
   if not existing.error.is_empty() or int(existing.payload.save.hyperspace.round_id)!=round_id:
    input_failure={"kind":"reforge_checkpoint_existing_invalid","path":archive_path};record("checkpoint_write_failed",input_failure);return
   record("reforge_checkpoint_retained",{"path":archive_path,"round":round_id,"sha256":FileAccess.get_sha256(archive_path)})
  elif archive_error!=OK:
   reforge_checkpoint_pending.assign(pending)
   input_failure={"kind":"reforge_checkpoint_io","error":archive_error,"path":archive_path};record("checkpoint_write_failed",input_failure);return
  else:
   record("reforge_checkpoint_saved",{"path":archive_path,"round":round_id,"event_x1":entry.x1_seconds,"x1_seconds":captured.x1_seconds,"sha256":FileAccess.get_sha256(archive_path),"scope":"Full controller/statistics/clocks/RNG; formal reload regenerates battle and GUI drafts"})
 var error:=Checkpoint.write(output+"/checkpoint.bin",captured,manifest)
 if error!=OK:
  input_failure={"kind":"checkpoint_io","error":error};record("checkpoint_write_failed",input_failure)
 else:record("checkpoint_saved",{"path":output+"/checkpoint.bin","continuity_fingerprint":Checkpoint.continuity(manifest)})
 checkpoint_due=false;next_checkpoint_wall=Time.get_ticks_usec()+int(float(options.get("checkpoint_wall_seconds",30))*1000000)
func observe(kind:String,payload:Dictionary)->void:
 var farm_event:Dictionary=safe_farm.observe(game,kind,payload,game.simulated_time)
 if not farm_event.is_empty():record("safe_farm_event",farm_event)
 if kind=="retreat" or (kind=="hyperspace_manual" and not bool(payload.active) and not bool(payload.success)):
  var failure_feedback:Dictionary=space_policy.observe_failure(game,game.simulated_time)
  if not failure_feedback.is_empty():record("visible_loadout_failure",failure_feedback)
 var manual:bool=game.manual_hyperspace.active
 if kind=="state" and manual:
  state_change()
 else:super.observe(kind,payload)
 if kind=="state" and not manual and game.state==BattleGame.State.LEVEL_CLEAR:
  var round_key:String=str(game.profile.hyperspace.round_id)
  if not round_clears.has(round_key):round_clears[round_key]={}
  if not round_clears[round_key].has(str(game.stage)):
   round_clears[round_key][str(game.stage)]=game.simulated_time
   record("round_first_clear",{"round":int(game.profile.hyperspace.round_id),"stage":game.stage,"x1_seconds":game.simulated_time})
 if kind=="hyperspace_manual":
  if bool(payload.active):
   space_policy.manual_started(game,str(payload.route),int(payload.level),game.simulated_time)
   active_space_record={"route":payload.route,"level":payload.level,"start":game.simulated_time,"loadout":game.profile.loadout.duplicate(true),"equipped":game.profile.hyperspace.inventory.equipped.duplicate(),"source_count":game.combat_weapon_entries().size()}
  else:
   var manual_feedback:=space_policy.manual_finished(game,bool(payload.success),game.simulated_time)
   if not manual_feedback.is_empty():record("manual_retry_feedback",manual_feedback)
   if bool(payload.success) and not manual_feedback.get("paid_affix_supply",{}).is_empty() and page==9:
    # Finish this observed paid attempt on its already visible page, through ordinary finite actions.
    busy=true;burst_start=game.simulated_time;next_button=game.simulated_time+BUTTON_TIME
    record("paid_affix_finite_followup",{"supply":manual_feedback.paid_affix_supply,"reason":"Observed real paid manual completion; claim/equip/forge on same visible page, actual costs and0.3 actions; ordinary tour unchanged"})
  if not bool(payload.active) and not active_space_record.is_empty():
   active_space_record.end=game.simulated_time;active_space_record.success=payload.success;active_space_record.seconds=game.simulated_time-float(active_space_record.start)
   space_runs.append(active_space_record.duplicate(true));record("space_actual_result",active_space_record);active_space_record={};save_snapshot("space_%d"%space_runs.size())
 if kind=="planet_reforged":
  refeeds.append({"planet":payload.id,"x1_seconds":game.simulated_time,"round":game.profile.hyperspace.round_id,"sealed":game.profile.hyperspace.inventory.sealed.duplicate(),"first_visible_eligibility":space_policy.reforge_observed.get(str([int(game.profile.hyperspace.round_id)-1,payload.id]),{})})
  last_frontier=int(game.profile.highestLevel)
  save_snapshot("reforge_%d"%refeeds.size());next_tour=game.simulated_time;next_check=game.simulated_time
  reforge_checkpoint_pending.append({"round":int(game.profile.hyperspace.round_id),"x1_seconds":game.simulated_time})
  checkpoint_due=true
 if kind=="hyperspace_changed":record("space_feedback",{"payload":payload,"active":game.profile.hyperspace.active.duplicate(true),"energy":game.profile.hyperspace.energy,"warehouse":game.profile.hyperspace.inventory.warehouse.size(),"cores":game.profile.hyperspace.ultimate_cores})
 if kind=="retreat" or kind=="unlock":next_tour=minf(next_tour,game.simulated_time+0.3)
 if int(game.profile.highestLevel)>last_frontier:
  last_frontier=int(game.profile.highestLevel)
  save_snapshot("reach_%d_round_%d"%[last_frontier,int(game.profile.hyperspace.round_id)])
func crew_action()->Dictionary:
 var redeploy:Dictionary=space_policy.crew_redeploy_action(game,5,driver.scene.crew_panel.rows.keys(),game.simulated_time)
 if not redeploy.is_empty():return redeploy
 if not space_policy.crew_transfer.is_empty():return {}
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
func preferred_weapon(index:int,tutorial_weapon:String)->String:
 return str(space_policy.wanted_weapons[index]) if index<space_policy.wanted_weapons.size() else tutorial_weapon
func preferred_defence(index:int)->String:
 return str(space_policy.wanted_defences[index]) if index<space_policy.wanted_defences.size() else super.preferred_defence(index)
func action()->Dictionary:
 if not pending_picker.is_empty() or not player_input.modal_windows().is_empty() or not game.pending_unlocks.is_empty():return super.action()
 if page==9:
  if not space_policy.manual_watch.is_empty() and not str(space_policy.manual_watch.exit_reason).is_empty() and game.manual_hyperspace.active:
   return control_action("space_exit_budget",driver.scene.hyperspace_panel.exit_button,{"reason":space_policy.manual_watch.exit_reason})
  if safe_farm.phase=="idle":
   var pending:Dictionary=space_policy.pending_manual_action(game,game.simulated_time)
   if not pending.is_empty():return pending
 var farm_event:Dictionary=safe_farm.consider(game,game.simulated_time)
 if not farm_event.is_empty():record("safe_farm_event",farm_event)
 var farm_command:Dictionary=safe_farm.next_command(game)
 if not farm_command.is_empty():
  if farm_command.kind=="farm_warp_open":
   var picker:OptionButton=driver.scene.loop_select
   var index:int=picker.get_item_index(int(farm_command.stage))
   return picker_action("farm_warp_open",picker,index)
  return control_action(str(farm_command.kind),driver.scene.loop_button)
 var feedback:Dictionary=space_policy.observe_visible(game,driver.scene,observed_weapons,game.simulated_time)
 if not feedback.is_empty():record("visible_loadout_decision",feedback)
 if page==9:
  var queued_before:Dictionary=space_policy.manual_pending.duplicate(true)
  var choice:Dictionary=space_policy.space_action(game,game.simulated_time,tour_started)
  if queued_before!=space_policy.manual_pending and not space_policy.manual_pending.is_empty():record("manual_request_queued",space_policy.manual_pending)
  if not choice.is_empty():return choice
 elif page==6:
  var choice:Dictionary=space_policy.crew_redeploy_action(game,6,[],game.simulated_time)
  if not choice.is_empty():return choice
  if not space_policy.crew_transfer.is_empty():return {}
  choice=space_policy.planet_action(game,game.simulated_time)
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
  var rejected_before:int=rejected_inputs
  await super.click_button(choice)
  if choice.kind=="space_exit_budget" and game.manual_hyperspace.active:
   input_failure={"kind":choice.kind,"reason":"Native exit input did not end the manual session"};record("input_failure_stop",input_failure)
  if input_failure.is_empty() and rejected_inputs==rejected_before:
   var effect:Dictionary=safe_farm.native_completed(game,choice,game.simulated_time)
   if effect.has("error"):
    input_failure={"kind":choice.kind,"reason":effect.error};record("input_failure_stop",input_failure)
   elif not effect.is_empty():record("safe_farm_event",effect)
  return
 var before:Dictionary={"resources":game.profile.resources.duplicate(true),"materials":game.profile.hyperspace.materials.duplicate(),"cores":game.profile.hyperspace.ultimate_cores,"energy":game.profile.hyperspace.energy,"round":game.profile.hyperspace.round_id}
 var dispatch_before:Dictionary={}
 if choice.kind=="space_manual":
  dispatch_before={"production_boundary_reason":game.manual_hyperspace.boundary_reason(game),"queued":game.manual_hyperspace.queued.duplicate(true),"state":game.state,"point":game.group_index,"live_enemies":game.enemies.filter(func(e):return game.N.compare(e.hp,0)>0).size(),"projectiles":game.projectiles.size(),"missile_queue":game.missile_queue.size(),"jewel_repeats":game.jewel_repeats.size(),"drone_delayed":game.drone_combat.delayed.size(),"eligible_level":game.hyperspace.eligible_level(game,str(choice.route),int(choice.level)),"production_accepted":game.manual_hyperspace.production_accepted,"armour_positive":game.N.compare(game.stat("armour"),0)>0}
 var ok:bool=game.set_enhancement_branch(choice.category,choice.effect,int(choice.node),choice.choice) if choice.kind=="enhancement_branch" else space_policy.execute(game,choice,game.simulated_time)
 if ok:
  clicks+=1;row(game.stage).clicks+=1;domain_rejections=0;last_domain_rejection=""
 else:
  rejected_inputs+=1
  record("domain_refusal",{"choice":choice,"hyperspace_error":game.hyperspace.last_error,"manual_error":game.manual_hyperspace.last_error,"dispatch_before":dispatch_before,"production_boundary_reason_after":game.manual_hyperspace.boundary_reason(game),"energy_delta":float(game.profile.hyperspace.energy)-float(before.energy),"reason_may_be_empty":true,"no_inferred_cause":true})
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
static func cumulative_totals_complete(lineage:Array)->bool:
 return not lineage.any(func(link):return not link.get("discontinuities",{}).get("legacy_missing_state",[]).is_empty())

func finish_crew_transfer_burst(reason:String)->void:
 var now:float=game.simulated_time;var burst:Dictionary=crew_transfer_burst
 if burst.is_empty():return
 if reason!="completed":
  space_policy.crew_transfer={};space_policy.last_crew_transfer=now
 var saved:Dictionary=burst.controller
 tour.assign(saved.tour);touring=bool(saved.touring);tour_started=float(saved.tour_started);next_tour=float(saved.next_tour)
 busy=bool(saved.busy);burst_start=float(saved.burst_start);next_check=maxf(float(saved.next_check),now+BUTTON_TIME);next_button=now+BUTTON_TIME
 record("crew_transfer_burst_end",{"reason":reason,"seconds":now-float(burst.started),"steps":burst.steps,"navigation_steps":burst.navigation_steps,"ordinary_next_tour_preserved":next_tour==float(saved.next_tour),"ordinary_next_tour":next_tour,"actual_page":page,"old_175_second_wait_not_rewritten":true})
 crew_transfer_burst={}
func step_crew_transfer_burst()->bool:
 if crew_transfer_burst.is_empty() and space_policy.crew_transfer.is_empty():return false
 # Let the inherited native picker/modal/unlock path finish first; never jump through it.
 if not pending_picker.is_empty() or not player_input.modal_windows().is_empty() or not game.pending_unlocks.is_empty():return false
 var now:float=game.simulated_time
 if crew_transfer_burst.is_empty():
  crew_transfer_burst={"started":now,"steps":0,"navigation_steps":0,"returning":false,"history_count":space_policy.crew_transfer_history.size(),"controller":{"tour":tour.duplicate(),"touring":touring,"tour_started":tour_started,"next_tour":next_tour,"next_check":next_check,"busy":busy,"burst_start":burst_start,"page":page}}
  record("crew_transfer_burst_start",{"plan":space_policy.crew_transfer.duplicate(true),"scope":"Finite continuation of a plan found at a regular crew-page check; actual native navigation and 0.3 X1 per navigation/command; ordinary300s initiation schedule retained"})
 if now+0.000001<next_button:return true
 if int(crew_transfer_burst.steps)>=16 or now-float(crew_transfer_burst.started)>120.0:
  finish_crew_transfer_burst("finite_step_or_time_limit");return true
 if space_policy.crew_transfer.is_empty():
  var completed:bool=space_policy.crew_transfer_history.size()>int(crew_transfer_burst.history_count)
  var return_page:int=int(crew_transfer_burst.controller.page)
  if page!=return_page:
   var before:int=rejected_inputs;await visit_page(return_page);operation_seconds+=BUTTON_TIME
   crew_transfer_burst.steps+=1;crew_transfer_burst.navigation_steps+=1;next_button=now+BUTTON_TIME
   if rejected_inputs!=before:finish_crew_transfer_burst("return_navigation_rejected")
   return true
  finish_crew_transfer_burst("completed" if completed else "cancelled_by_current_state");return true
 var wanted:int=space_policy.crew_transfer_page(game)
 if wanted<0:
  finish_crew_transfer_burst("current_ownership_or_plan_invalid");return true
 if page!=wanted:
  var before:int=rejected_inputs;await visit_page(wanted);operation_seconds+=BUTTON_TIME
  crew_transfer_burst.steps+=1;crew_transfer_burst.navigation_steps+=1;next_button=now+BUTTON_TIME
  record("crew_transfer_navigation",{"requested":wanted,"actual":page,"seconds":BUTTON_TIME,"native_input":true})
  if rejected_inputs!=before:finish_crew_transfer_burst("navigation_rejected")
  return true
 await process_frame # Same real deferred layout boundary as ordinary page inspection.
 var choice:Dictionary=space_policy.crew_redeploy_action(game,page,driver.scene.crew_panel.rows.keys() if page==5 else [],now)
 if choice.is_empty():
  finish_crew_transfer_burst("no_legal_next_command");return true
 var rejected_before:int=rejected_inputs;await click_button(choice)
 crew_transfer_burst.steps+=1;next_button=now+BUTTON_TIME
 if rejected_inputs!=rejected_before:finish_crew_transfer_burst("domain_command_rejected")
 return true
func step_controller()->void:
 if game.manual_hyperspace.active and not space_policy.manual_watch.is_empty() and game.simulated_time>=float(space_policy.manual_watch.next_check):
  var feedback:=space_policy.check_manual_budget(game,space_policy.manual_visible_bars(game,driver.scene),game.simulated_time)
  if not feedback.is_empty():record("manual_visible_budget_check",feedback)
 var exit_due:bool=game.manual_hyperspace.active and not space_policy.manual_watch.is_empty() and not str(space_policy.manual_watch.exit_reason).is_empty()
 if not exit_due and await step_crew_transfer_burst():return
 var start_due:bool=crew_transfer_burst.is_empty() and space_policy.crew_transfer.is_empty() and safe_farm.phase=="idle" and not space_policy.pending_manual_action(game,game.simulated_time).is_empty()
 if ((exit_due and (page!=9 or not busy)) or (start_due and not busy)) and pending_picker.is_empty() and player_input.modal_windows().is_empty() and game.pending_unlocks.is_empty():
  await visit_page(9)
  busy=true;burst_start=game.simulated_time;next_button=game.simulated_time+BUTTON_TIME
  record("manual_boundary_dispatch" if start_due else "manual_exit_dispatch",{"boundary":space_policy.main_boundary(game),"reason":"One visible page action after 0.3 X1 seconds; revalidate at execution"})
 await super.step_controller()
 if game.profile.cleared.has(10) and not busy and not touring:next_check=maxf(next_check,game.simulated_time+float(options.get("visit_seconds",300)))
func galaxy_complete()->bool:
 if not game.galaxy.available() or not game.galaxy.regions.has("galaxy_1"):return false
 var region=game.galaxy.regions.galaxy_1
 return region.slots.size()==30 and region.slots.all(func(slot):return int(slot.level)>=5)
func run()->void:
 options={"seed":20261005,"duration":216000.0,"visit_seconds":300,"allow_reforge":true,"stop_clear":0,"wall_limit_seconds":36000.0,"checkpoint_wall_seconds":30.0,"allow_new_manual":true}
 var parsed=JSON.parse_string(OS.get_environment("HYPERSPACE_LONGRUN_OPTIONS"))
 manifest=JSON.parse_string(FileAccess.get_file_as_string("res://qa-manifest.json"))
 var resume_path:=OS.get_environment("HYPERSPACE_RESUME_PATH")
 var recovery:Dictionary={};var payload:Dictionary={}
 if not resume_path.is_empty():
  if OS.get_environment("HYPERSPACE_RESUME_LEGACY")=="1":
   var old:Variant=JSON.parse_string(FileAccess.get_file_as_string(resume_path))
   var old_manifest:Variant=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("HYPERSPACE_RESUME_MANIFEST")))
   if not old is Dictionary or not old.get("save") is Dictionary or not old_manifest is Dictionary or old.get("code_fingerprint","")!=old_manifest.get("fingerprint","") or Checkpoint.continuity(old_manifest)!=Checkpoint.continuity(manifest):
    printerr("Legacy checkpoint/manifest continuity rejected");quit(2);return
   payload=Checkpoint.legacy_payload(old);recovery={"path":resume_path,"legacy":true}
  else:
   recovery=Checkpoint.read_valid(resume_path)
   if not recovery.error.is_empty() or recovery.header.get("code_fingerprint","")!=manifest.fingerprint or recovery.header.get("continuity_fingerprint","")!=Checkpoint.continuity(manifest):
    printerr("Checkpoint integrity/version rejected: ",recovery);quit(2);return
   payload=recovery.payload
  options.merge(payload.get("options",{}),true)
 if parsed is Dictionary:options.merge(parsed,true)
 configure_manual_policy()
 if float(options.get("checkpoint_wall_seconds",0))<=0:
  printerr("Checkpoint interval must be positive");quit(2);return
 output=OS.get_environment("QA_DIAGNOSTIC_RESULT_DIR")
 if output.is_empty():printerr("Isolated output required");quit(2);return
 stop_request_path=OS.get_environment("QA_STOP_REQUEST_FILE")
 if stop_request_path.is_empty():stop_request_path=output+"/STOP"
 DirAccess.make_dir_recursive_absolute(output)
 trace=FileAccess.open(output+"/actions.jsonl",FileAccess.WRITE)
 game=Game.new(ShipDatabase.new());game.rng.seed=int(options.seed);game.stat_cache_enabled=true
 if not game.load_hyperspace_routes():printerr("Production route/reward loader failed: ",game.manual_hyperspace.last_error);quit(2);return
 driver=Driver.new();driver.ui_refresh_seconds=0.0;driver.production_ui_ticks=true;driver.setup(self,game)
 player_input=PlayerInput.new();player_input.setup(driver.scene,self)
 root.size=Vector2i(1373,883);root.grab_focus();await process_frame;await process_frame
 wall_started=Time.get_ticks_usec();last_wall_report=wall_started
 if resume_path.is_empty():
  game.event.connect(observe);game.start(1,false);save_snapshot("fresh")
 else:
  var restored:=Checkpoint.restore(self,payload)
  if not restored.error.is_empty():printerr("Production reload rejected: ",restored);trace.close();driver.close();quit(2);return
  game.event.connect(observe)
  page=clampi(page,0,driver.scene.equipment_tabs.get_tab_count()-1);driver.scene.equipment_tabs.current_tab=page
  driver.scene.refresh_navigation();driver.scene.refresh_visible_cards();await process_frame;await process_frame
  initial_scope="legacy_checkpoint_continuation_with_missing_tool_state" if recovery.get("legacy",false) else "checkpoint_continuation_with_formal_journey_regeneration"
  if payload.has("qa_policy_upgrade"):initial_scope="explicit_qa_policy_upgrade_with_formal_journey_regeneration"
  if payload.has("candidate_transition"):initial_scope="explicit_production_candidate_transition_with_formal_journey_regeneration"
  var link:Dictionary={"checkpoint":recovery.path,"source_x1":payload.x1_seconds,"origin_trace":payload.get("origin_trace","legacy parent trace"),"fallback_reason":recovery.get("fallback_reason",""),"discontinuities":restored}
  resume_lineage.append(link);record("checkpoint_resumed",link);save_snapshot("resumed")
 checkpoint_now()
 if not bool(options.allow_new_manual):record("qa_policy_modifier",{"kind":"suppress_new_manual","history_and_gains_preserved":true,"existing_manual_watchdog_preserved":true,"base_policy":SpacePolicy.VERSION,"scope":"A/B experiment, not unchanged baseline player strategy"})
 record("run_start",{"initial_scope":initial_scope,"options":options,"source_commit":JSON.parse_string(FileAccess.get_file_as_string("res://qa-manifest.json")).source_commit,"scene_provider_scope":"production before_logical_game_tick, ordinary/drone/rail/target callbacks, exact Presented fixed steps"})
 while game.simulated_time<float(options.duration) and input_failure.is_empty() and not galaxy_complete():
  if int(options.stop_clear)>0 and clears.has(str(int(options.stop_clear))):break
  if float(Time.get_ticks_usec()-wall_started)/1e6>=float(options.wall_limit_seconds):break
  var controller_start:int=Time.get_ticks_usec() if stage_meter!=null else 0
  await step_controller()
  var controller_elapsed:int=Time.get_ticks_usec()-controller_start if stage_meter!=null else 0
  if not input_failure.is_empty():break
  # Reforge command and policy bookkeeping have returned. Capture before
  # the next logical tick consumes the new round's random streams.
  if not reforge_checkpoint_pending.is_empty():checkpoint_now()
  if not input_failure.is_empty():break
  var before_stage:int=game.stage;var before_state:int=game.state;var manual:bool=game.manual_hyperspace.active
  if stage_meter==null:driver.before_tick(STEP);game.tick(STEP);driver.after_tick(STEP)
  else:
   var timing_start:=Time.get_ticks_usec();driver.before_tick(STEP);var timing_pre:=Time.get_ticks_usec()
   game.tick(STEP);var timing_core:=Time.get_ticks_usec();driver.after_tick(STEP);var timing_post:=Time.get_ticks_usec()
   stage_meter.tick(game,before_state,controller_elapsed,timing_pre-timing_start,timing_core-timing_pre,timing_post-timing_core)
  if manual:space_seconds+=STEP
  else:
   if safe_farm.phase!="idle":farm_seconds+=STEP
   var state_key:String="travel" if before_state==BattleGame.State.TRAVEL else "combat" if before_state==BattleGame.State.COMBAT else "retreat" if before_state==BattleGame.State.RETREAT else "clear_notice" if before_state==BattleGame.State.LEVEL_CLEAR else "other"
   row(before_stage)[state_key]+=STEP
  peak_projectiles=maxi(peak_projectiles,game.projectiles.size());peak_missile_queue=maxi(peak_missile_queue,game.missile_queue.size())
  var wall_now:int=Time.get_ticks_usec()
  if checkpoint_due or wall_now>=next_checkpoint_wall:checkpoint_now()
  # Wall-clock file polling never advances logical time or changes a normal run.
  if wall_now>=next_stop_poll:
   next_stop_poll=wall_now+1000000
   if FileAccess.file_exists(stop_request_path):
    operator_stopped=true
    record("operator_stop",{"request_file":stop_request_path,"x1_seconds":game.simulated_time})
    break
  if wall_now-last_wall_report>=30000000:
   last_wall_report=wall_now
   var status:Dictionary={"x1_seconds":game.simulated_time,"wall_seconds":float(wall_now-wall_started)/1e6,"stage":game.stage,"frontier":game.profile.highestLevel,"clears":clears,"deaths":deaths,"clicks":clicks,"space_runs":space_runs.size(),"drones":game.profile.hyperspace.inventory.drones.size(),"round":game.profile.hyperspace.round_id,"projectiles_peak":peak_projectiles,"missile_queue_peak":peak_missile_queue,"data_sha256":FileAccess.get_sha256("res://data/game_data.json")}
   FileAccess.open(output+"/heartbeat.json",FileAccess.WRITE).store_string(JSON.stringify(status,"\t"));trace.flush();print("LONGRUN_HEARTBEAT ",JSON.stringify(status))
   await process_frame
  if game.simulated_time-last_state_report>=1800.0:last_state_report=game.simulated_time;save_snapshot("periodic_%d"%int(game.simulated_time))
 state_change();save_snapshot("final");checkpoint_now();trace.close()
 var result:Dictionary={"status":"input_failure" if not input_failure.is_empty() else "operator_stopped" if operator_stopped else "galaxy_complete" if galaxy_complete() else "bounded_partial","initial_scope":initial_scope,"resume_lineage":resume_lineage,"cumulative_totals_complete":cumulative_totals_complete(resume_lineage),"cumulative_wall_seconds":carried_wall_seconds+float(Time.get_ticks_usec()-wall_started)/1e6,"stop_request_file":stop_request_path,"options":options,"x1_seconds":game.simulated_time,"wall_seconds":float(Time.get_ticks_usec()-wall_started)/1e6,"clears":clears,"stage":game.stage,"frontier":game.profile.highestLevel,"input_failure":input_failure,"rows":rows,"segments":segments,"operation_seconds":operation_seconds,"space_seconds":space_seconds,"farm_seconds":farm_seconds,"safe_farm":safe_farm.snapshot(),"space_runs":space_runs,"reforges":refeeds,"round_clears":round_clears,"snapshots":snapshots,"deaths":deaths,"clicks":clicks,"peak_projectiles":peak_projectiles,"peak_missile_queue":peak_missile_queue,"policy":space_policy.VERSION,"data_sha256":FileAccess.get_sha256("res://data/game_data.json"),"manifest":JSON.parse_string(FileAccess.get_file_as_string("res://qa-manifest.json")),"scope":"Fresh real main/Presented scene, native early inputs, serial visible-page new-system domain commands, exact X1 fixed1/60, no injected resources/drones/affix tiers. Real native first-normal safe farming after two actual defeats, resume after five earned module levels; before clear10 checks3s/tours10s, afterwards300s. Reforge chosen low-tier goal is paid planning goal, no cap."}
 FileAccess.open(output+"/longrun-summary.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
 print("LONGRUN_DONE ",result.status," x1=",game.simulated_time," stage=",game.stage)
 if stage_meter!=null:stage_meter.finish(output,game)
 driver.close();await process_frame;quit(2 if not input_failure.is_empty() else 0)
