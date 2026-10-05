extends "res://qa/hyperspace_longrun.gd"
var tested:=0
var failed:=0
func check(ok:bool,label:String)->void:
 tested+=1
 if not ok:failed+=1;printerr("FAIL: ",label)
func _initialize()->void:call_deferred("fixture_run")
func fixture_run()->void:
 output=OS.get_environment("QA_DIAGNOSTIC_RESULT_DIR");trace=FileAccess.open(output+"/actions.jsonl",FileAccess.WRITE);manifest=JSON.parse_string(FileAccess.get_file_as_string("res://qa-manifest.json"))
 var source:String=OS.get_environment("QA_CREW_SOURCE");var snapshot:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(source))
 if snapshot.is_empty():printerr("Actual source required");quit(2);return
 options={"allow_new_manual":false,"allow_reforge":false,"visit_seconds":300.0};configure_manual_policy()
 game=Game.new(ShipDatabase.new());game.rng.seed=20261005;game.stat_cache_enabled=true;game.save_enabled=false;check(game.load_hyperspace_routes(),"Actual production route loads")
 driver=Driver.new();driver.production_ui_ticks=true;driver.setup(self,game);player_input=PlayerInput.new();player_input.setup(driver.scene,self)
 root.size=Vector2i(1373,883);root.grab_focus();await process_frame;await process_frame
 var restored:Dictionary=Checkpoint.restore(self,Checkpoint.legacy_payload(snapshot));check(restored.error.is_empty(),"Actual31 legacy source formally accepted")
 driver.before_tick(0.0);driver.scene.refresh_tab_visibility();await process_frame;await process_frame;await visit_page(5)
 check(page==5 and player_input.modal_windows().is_empty(),"Real native crew-page starting boundary")
 game.event.connect(observe)
 var started:float=game.simulated_time;next_tour=started+300.0;next_check=started;busy=false;touring=false;tour=[]
 var ordinary_tour:float=next_tour;var owner:String=preload("res://scripts/hyperspace_permissions.gd").reserved_crew(game.profile.hyperspace);var history_before:int=space_policy.crew_transfer_history.size()
 var saw_burst:=false;var checkpoint_checked:=false;var ticks:=0
 while game.simulated_time<started+30.0 and input_failure.is_empty():
  await step_controller()
  if not crew_transfer_burst.is_empty():
   saw_burst=true
   if not checkpoint_checked and space_policy.crew_transfer.get("phase","")=="recalled":
    var captured:Dictionary=Checkpoint.capture(self,manifest);var packet:String=output+"/mid-transfer.bin"
    check(Checkpoint.write(packet,captured,manifest)==OK,"Finite controller context stored atomically mid-transfer")
    var loaded:Dictionary=Checkpoint.read_valid(packet)
    check(loaded.error.is_empty() and loaded.payload.controller.crew_transfer_burst==crew_transfer_burst and loaded.payload.space_policy.crew_transfer==space_policy.crew_transfer,"Checksum-validated pending plan and suspended ordinary tour survive checkpoint")
    checkpoint_checked=true
  if space_policy.crew_transfer_history.size()>history_before and crew_transfer_burst.is_empty():break
  driver.before_tick(STEP);game.tick(STEP);driver.after_tick(STEP);ticks+=1
 var elapsed:float=game.simulated_time-started
 check(saw_burst and space_policy.crew_transfer_history.size()==history_before+1 and crew_transfer_burst.is_empty(),"Real controller completes exactly one bounded exchange")
 check(elapsed<10.0,"Finite exchange completes before another300s巡页 instead of175s gap")
 check(next_tour==ordinary_tour,"Ordinary next tour remains exactly300s after initiation boundary")
 check(page==5 and driver.scene.equipment_tabs.current_tab==5,"Actual native return restores original crew page")
 check(preload("res://scripts/hyperspace_permissions.gd").reserved_crew(game.profile.hyperspace)==owner and owner=="navigator","Navigator actual auto ownership preserved")
 check(game.crew.entry(game,"crew_04").assignmentType=="equipment_upgrade" and game.crew.entry(game,"crew_04").upgradeMode=="10" and str(game.planet_progress("1").crewId)=="engineer","Earned veteran +10 equipment and real replacement explorer both active")
 check(input_failure.is_empty() and rejected_inputs==0,"No native input or domain rejection")
 var after_plan:Dictionary=space_policy.crew_transfer.duplicate(true)
 check(space_policy.crew_redeploy_action(game,5,driver.scene.crew_panel.rows.keys(),game.simulated_time).is_empty() and space_policy.crew_transfer==after_plan,"Completion does not create a free high-frequency new plan")
 trace.flush();var events:Array=[];var stream=FileAccess.open(output+"/actions.jsonl",FileAccess.READ)
 while not stream.eof_reached():
  var line:String=stream.get_line()
  if line.strip_edges().is_empty():continue
  var event:Variant=JSON.parse_string(line)
  if event is Dictionary and (event.kind in ["domain_action","crew_transfer_navigation","crew_transfer_burst_start","crew_transfer_burst_end","page_visit"]):events.append(event)
 var domain_times:Array=[];var navigation_count:=0;var burst_end:Dictionary={}
 for event in events:
  if event.kind=="domain_action" and str(event.choice.kind).begins_with("crew_"):domain_times.append(float(event.x1_seconds))
  if event.kind=="crew_transfer_navigation":navigation_count+=1
  if event.kind=="crew_transfer_burst_end":burst_end=event
 check(domain_times.size()==5 and navigation_count==3 and int(burst_end.get("navigation_steps",0))==4,"Five real domain commands and four native cross-page/return gestures")
 var max_gap:=0.0
 for i in range(1,domain_times.size()):max_gap=maxf(max_gap,float(domain_times[i])-float(domain_times[i-1]))
 check(max_gap<1.0 and elapsed>=2.4,"Real0.3 command/navigation intervals retained; no175s inter-step gap")
 FileAccess.open(output+"/finite-transfer-result.json",FileAccess.WRITE).store_string(JSON.stringify({"source":source,"start":started,"end":game.simulated_time,"seconds":elapsed,"ticks":ticks,"maximum_domain_gap":max_gap,"ordinary_next_tour":ordinary_tour,"events":events,"transfer_history":space_policy.crew_transfer_history,"no_injected_currency_drones_levels":true,"scope":"Actual legacy31 start at an explicitly due visible crew-page check; real native navigation, disclosed domain commands and actual fixed1/60 world ticks; not a full campaign"},"\t"))
 trace.close();driver.close();print("FINITE_CREW_TRANSFER ",tested," checks ",failed," failures; elapsed ",elapsed);quit(1 if failed else 0)
