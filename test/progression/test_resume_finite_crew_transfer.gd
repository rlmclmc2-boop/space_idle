extends "res://qa/hyperspace_longrun.gd"
var tested:=0
var failed:=0
func check(ok:bool,label:String)->void:
 tested+=1
 if not ok:failed+=1;printerr("FAIL: ",label)
func _initialize()->void:call_deferred("fixture_resume")
func fixture_resume()->void:
 output=OS.get_environment("QA_DIAGNOSTIC_RESULT_DIR");trace=FileAccess.open(output+"/actions.jsonl",FileAccess.WRITE);manifest=JSON.parse_string(FileAccess.get_file_as_string("res://qa-manifest.json"))
 var packet:Dictionary=Checkpoint.read_valid(OS.get_environment("QA_FINITE_RESUME"))
 if not packet.error.is_empty() or packet.header.code_fingerprint!=manifest.fingerprint:printerr("Matching actual mid-transfer packet required");quit(2);return
 options=packet.payload.options.duplicate(true);configure_manual_policy();game=Game.new(ShipDatabase.new());game.rng.seed=20261005;game.stat_cache_enabled=true;game.save_enabled=false;game.load_hyperspace_routes()
 driver=Driver.new();driver.production_ui_ticks=true;driver.setup(self,game);player_input=PlayerInput.new();player_input.setup(driver.scene,self);root.size=Vector2i(1373,883);await process_frame;await process_frame
 var restored:Dictionary=Checkpoint.restore(self,packet.payload);driver.before_tick(0.0);driver.scene.refresh_tab_visibility();driver.scene.equipment_tabs.current_tab=page;await process_frame;await process_frame
 check(restored.error.is_empty() and space_policy.crew_transfer.get("phase","")=="recalled","Actual formal reload preserves already-recalled paid plan")
 check(not crew_transfer_burst.is_empty() and page==6 and int(crew_transfer_burst.navigation_steps)==1,"Suspended ordinary context and actual phase/page restored")
 var history_before:int=space_policy.crew_transfer_history.size();var started:float=game.simulated_time;var ordinary_tour:float=float(crew_transfer_burst.controller.next_tour);game.event.connect(observe)
 while game.simulated_time<started+10.0 and input_failure.is_empty():
  await step_controller()
  if space_policy.crew_transfer_history.size()>history_before and crew_transfer_burst.is_empty():break
  driver.before_tick(STEP);game.tick(STEP);driver.after_tick(STEP)
 check(space_policy.crew_transfer_history.size()==history_before+1 and crew_transfer_burst.is_empty(),"Remaining real commands complete once after reload")
 check(game.simulated_time-started<5.0 and next_tour==ordinary_tour,"Continuation stays finite and preserves original300s tour")
 check(game.crew.entry(game,"crew_04").assignmentType=="equipment_upgrade" and str(game.planet_progress("1").crewId)=="engineer","Actual assignments correct after resumed transaction")
 check(input_failure.is_empty() and rejected_inputs==0,"Real restored native navigation accepted")
 trace.flush();var stream=FileAccess.open(output+"/actions.jsonl",FileAccess.READ);var counts:Dictionary={}
 while not stream.eof_reached():
  var line:String=stream.get_line()
  if line.strip_edges().is_empty():continue
  var event:Variant=JSON.parse_string(line)
  if event is Dictionary and event.kind=="domain_action":counts[str(event.choice.kind)]=int(counts.get(str(event.choice.kind),0))+1
 check(int(counts.get("crew_release",0))==0 and int(counts.get("crew_transfer_recall",0))==0,"Reload does not replay already completed release/recall")
 check(int(counts.get("crew_equipment_mode",0))==1 and int(counts.get("crew_assign_equipment",0))==1 and int(counts.get("crew_transfer_explore",0))==1,"Only three remaining domain commands applied exactly once")
 FileAccess.open(output+"/resume-transfer-result.json",FileAccess.WRITE).store_string(JSON.stringify({"source_packet":packet.path,"seconds":game.simulated_time-started,"domain_counts":counts,"formal_battle_regenerated":restored.battle_regenerated,"ordinary_next_tour":next_tour},"\t"))
 trace.close();driver.close();print("RESUME_FINITE_CREW_TRANSFER ",tested," checks ",failed," failures");quit(1 if failed else 0)
