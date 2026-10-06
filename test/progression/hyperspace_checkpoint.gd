extends RefCounted
## QA recovery only. Production journey reload regenerates the current battle.
const FORMAT=1
const QA_CONTINUITY=["early_page_route.gd","hyperspace_player_policy.gd","hyperspace_safe_farm.gd","player_input.gd","scene_driver.gd","presented_balance_game.gd"]
const CONTROLLER=["ultimate_upgrade_checkpoint_pending","tour_failed_encounters","tour_current_encounter","tour_seen_unlocks","reforge_checkpoint_pending","crew_transfer_burst","next_check","next_tour","next_button","tour","touring","tour_started","observed_weapons","tour_durations","busy","page","checks","clicks","visits","empty_checks","burst_start","bursts","rows","clears","deaths","unlock_id","unlock_since","unlock_confirmations","segment_start","segment_state","segment_stage","segments","rejected_inputs","input_failure","scientist_context","reactor_context","farm_seconds","space_runs","active_space_record","refeeds","operation_seconds","space_seconds","last_frontier","round_clears","peak_projectiles","peak_missile_queue","model_rebuilds","last_domain_rejection","domain_rejections","last_state_report"]
const POLICY=["last_frontier_attempt","manual_frontier_failures","affix_target_tier","affix_paid_windows","crew_transfer","crew_transfer_history","last_crew_transfer","reforge_observed","last_attempt","manual_failures","manual_pending","manual_watch","last_manual_boundary","forge_at","reserved_crew","last_reforge","reforge_since","known_weapons","wanted_weapons","wanted_defences","seen_encounter","encounter_plans","pending_encounters","encounter_failures","encounter_started","wanted_weapon","weapon_losses","last_weapon_change","last_galaxy_state","galaxy_needs_reserved_crew","idle_salvage_enabled","idle_salvage_budget","idle_salvage_success_times","space_crew_reservation","ultimate_upgrade_chain"]
const FARM=["round_seen","known","failed","attempted_stage","phase","plan"]

static func digest(bytes:PackedByteArray)->String:
 var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(bytes);return hash.finish().hex_encode()

static func continuity(manifest:Dictionary)->String:
 var selected:Dictionary={}
 var names:Array=manifest.get("files",{}).keys();names.sort()
 for name in names:
  if not str(name).begins_with("qa/") or str(name).trim_prefix("qa/") in QA_CONTINUITY:selected[name]=manifest.files[name]
 return digest(JSON.stringify(selected).to_utf8_buffer())

static func field_names_unique(names:Array)->bool:
 var seen:Dictionary={}
 for name in names:
  if seen.has(name):return false
  seen[name]=true
 return true

static func fields(object:Object,names:Array)->Dictionary:
 assert(field_names_unique(names),"Duplicate checkpoint capture field")
 var result:Dictionary={}
 for name in names:result[name]=object.get(name)
 return result

static func apply_fields(object:Object,values:Dictionary,names:Array)->void:
 assert(field_names_unique(names),"Duplicate checkpoint restore field")
 for name in names:
  if not values.has(name):continue
  var existing:Variant=object.get(name)
  if existing is Array and values[name] is Array:existing.assign(values[name])
  else:object.set(name,values[name])

static func atomic_bytes(path:String,bytes:PackedByteArray)->Error:
 var temporary:=path+".tmp"
 var file:=FileAccess.open(temporary,FileAccess.WRITE)
 if file==null:return FileAccess.get_open_error()
 file.store_buffer(bytes);file.flush();var error:=file.get_error();file.close()
 if error!=OK:return error
 return DirAccess.rename_absolute(temporary,path)

static func atomic_json(path:String,value:Dictionary)->Error:
 return atomic_bytes(path,JSON.stringify(value,"\t").to_utf8_buffer())

static func read_one(path:String)->Dictionary:
 var file:=FileAccess.open(path,FileAccess.READ)
 if file==null:return {"error":"unreadable_checkpoint","path":path}
 if file.get_length()>134217728:return {"error":"checkpoint_too_large","path":path}
 var header:Variant=JSON.parse_string(file.get_line())
 if not header is Dictionary or int(header.get("format",0))!=FORMAT:return {"error":"invalid_header","path":path}
 var bytes:=file.get_buffer(file.get_length()-file.get_position());file.close()
 if bytes.size()!=int(header.get("bytes",-1)) or digest(bytes)!=str(header.get("sha256","")):return {"error":"checksum_mismatch","path":path}
 var payload:Variant=bytes_to_var(bytes)
 if not payload is Dictionary or not payload.get("save") is Dictionary or not payload.get("controller") is Dictionary or not payload.get("space_policy") is Dictionary or not payload.get("safe_farm") is Dictionary:return {"error":"invalid_payload","path":path}
 if not is_finite(float(payload.get("x1_seconds",-1))) or float(payload.get("x1_seconds",-1))<0 or not payload.get("rng_state") is String:return {"error":"invalid_clock_or_rng","path":path}
 return {"header":header,"payload":payload,"path":path,"error":""}

static func read_valid(path:String)->Dictionary:
 var latest:=read_one(path)
 if latest.error.is_empty():return latest
 var previous:=read_one(path+".previous")
 if previous.error.is_empty():previous["fallback_reason"]=latest.error;return previous
 return {"error":"no_valid_checkpoint","latest_error":latest.error,"previous_error":previous.error,"path":path}

static func write(path:String,payload:Dictionary,manifest:Dictionary)->Error:
 var bytes:=var_to_bytes(payload)
 var header:Dictionary={"format":FORMAT,"sha256":digest(bytes),"bytes":bytes.size(),"code_fingerprint":manifest.fingerprint,"continuity_fingerprint":continuity(manifest),"source_commit":manifest.source_commit,"x1_seconds":payload.x1_seconds,"scope":"formal_journey_reload_not_live_combat_restore"}
 var packet:PackedByteArray=(JSON.stringify(header)+"\n").to_utf8_buffer();packet.append_array(bytes)
 # Never replace the valid backup with a corrupt primary.
 if FileAccess.file_exists(path) and read_one(path).error.is_empty():
  var previous_error:=atomic_bytes(path+".previous",FileAccess.get_file_as_bytes(path))
  if previous_error!=OK:return previous_error
 return atomic_bytes(path,packet)

static func write_once(path:String,payload:Dictionary,manifest:Dictionary)->Error:
 # One QA runner owns its diagnostic directory. Round archives never rotate
 # backups or replace an existing file, including duplicate callbacks.
 if FileAccess.file_exists(path):return ERR_ALREADY_EXISTS
 return write(path,payload,manifest)

static func capture(run:Object,manifest:Dictionary)->Dictionary:
 return {"x1_seconds":run.game.simulated_time,"save":run.game.portable_save_data(),"rng_state":str(run.game.rng.state),"controller":fields(run,CONTROLLER),"space_policy":fields(run.space_policy,POLICY),"safe_farm":fields(run.safe_farm,FARM),"progress_guard":run.progress_guard.failures.duplicate(true),"options":run.options.duplicate(true),"snapshots":run.snapshots.duplicate(),"lineage":run.resume_lineage.duplicate(true),"wall_seconds":run.carried_wall_seconds+float(Time.get_ticks_usec()-run.wall_started)/1e6,"origin_trace":run.output+"/actions.jsonl","trace_bytes":run.trace.get_position(),"code_fingerprint":manifest.fingerprint,"data_sha256":FileAccess.get_sha256("res://data/game_data.json"),"manual_interrupted_on_reload":run.game.manual_hyperspace.active,"ui_pending_picker_discarded_on_reload":not run.pending_picker.is_empty()}

static func legacy_payload(checkpoint:Dictionary)->Dictionary:
 var saved:Dictionary=checkpoint.save
 var farm:Dictionary=checkpoint.get("safe_farm",{})
 var known:Dictionary={};var failed:Dictionary={}
 var totals:Dictionary={"clicks":0,"checks":0,"visits":0,"empty_checks":0}
 for row in checkpoint.get("rows",{}).values():
  totals.clicks+=int(row.get("clicks",0));totals.checks+=int(row.get("checks",0));totals.visits+=int(row.get("page_visits",0));totals.empty_checks+=int(row.get("growth_blocked_checks",0))
 for key in farm.get("known_wins",{}):known[int(key)]=farm.known_wins[key]
 for key in farm.get("actual_defeats",{}):failed[int(key)]=int(farm.actual_defeats[key])
 return {"x1_seconds":checkpoint.x1_seconds,"save":saved,"rng_state":checkpoint.rng_state,"controller":{"clicks":totals.clicks,"checks":totals.checks,"visits":totals.visits,"empty_checks":totals.empty_checks,"page":int(checkpoint.get("page",0)),"clears":checkpoint.get("clears",{}),"rows":checkpoint.get("rows",{}),"next_check":float(checkpoint.x1_seconds),"next_tour":float(checkpoint.x1_seconds),"last_frontier":int(saved.highestLevel),"last_state_report":float(checkpoint.x1_seconds)},"safe_farm":{"round_seen":int(farm.get("round",saved.hyperspace.round_id)),"known":known,"failed":failed,"attempted_stage":int(saved.get("journey",{}).get("stage",saved.highestLevel)),"phase":str(farm.get("phase","idle")),"plan":farm.get("plan",{})},"space_policy":{},"options":checkpoint.get("options",{}),"snapshots":{},"lineage":[],"wall_seconds":0.0,"legacy_missing_state":["space policy memory and RNG-independent decision history","GUI drafts and scheduling","old deaths/space/farm/operation totals unavailable; clicks/checks/navigation recovered from rows","round clear times and active manual run bookkeeping"],"manual_interrupted_on_reload":not saved.hyperspace.active.is_empty() and str(saved.hyperspace.active.get("mode",""))=="manual"}

static func restore(run:Object,payload:Dictionary)->Dictionary:
 var raw:Dictionary=payload.save.duplicate(true)
 # Diagnostic downtime accrues neither logical progress nor offline currency.
 raw.chronoSavedAt=Time.get_unix_time_from_system()
 run.game.simulated_time=float(payload.x1_seconds)
 run.game.load_progress_data(raw)
 if not run.game.hyperspace.last_error.is_empty():return {"error":run.game.hyperspace.last_error}
 if int(run.game.profile.highestLevel)!=int(raw.highestLevel) or int(run.game.profile.hyperspace.round_id)!=int(raw.hyperspace.round_id):return {"error":"production_save_rejected"}
 run.game.profile.chronoParticles=float(raw.get("chronoParticles",0));run.game.login_chrono_particles=0
 run.game.resume_progress();run.game.rng.state=int(str(payload.rng_state))
 apply_fields(run,payload.controller,CONTROLLER)
 apply_fields(run.space_policy,payload.space_policy,POLICY)
 apply_fields(run.safe_farm,payload.safe_farm,FARM)
 run.progress_guard.failures=payload.get("progress_guard",{}).duplicate(true)
 run.snapshots=payload.get("snapshots",{}).duplicate()
 run.resume_lineage=payload.get("lineage",[]).duplicate(true)
 run.carried_wall_seconds=float(payload.get("wall_seconds",0))
 run.pending_picker={};run.scientist_context="";run.reactor_context=""
 # A manual started receipt is failed/refunded by the production loader.
 # It is an interrupted operation, not an observed new combat result.
 run.active_space_record={}
 if bool(payload.get("manual_interrupted_on_reload",false)) and not run.space_policy.manual_watch.is_empty():
  run.space_policy.manual_watch.exit_reason="Interrupted by formal production checkpoint reload"
  run.space_policy.manual_finished(run.game,false,run.game.simulated_time)
 if int(payload.controller.get("segment_state",-1))>=0:
  run.segments.append({"stage":int(payload.controller.segment_stage),"state":int(payload.controller.segment_state),"seconds":run.game.simulated_time-float(payload.controller.segment_start),"end":"checkpoint_reload"})
 run.segment_state=run.game.state;run.segment_stage=run.game.stage;run.segment_start=run.game.simulated_time
 if payload.has("legacy_missing_state"):
  run.observed_weapons.assign(run.game.WEAPON_KEYS.filter(func(key):return run.game.content_unlocked("equipment",str(key))))
 return {"error":"","battle_regenerated":true,"manual_failed_by_production_reload":bool(payload.get("manual_interrupted_on_reload",false)),"gui_drafts_reset":true,"legacy_missing_state":payload.get("legacy_missing_state",[]),"qa_policy_upgrade":payload.get("qa_policy_upgrade",{}),"candidate_transition":payload.get("candidate_transition",{})}
