extends "res://qa/hyperspace_longrun.gd"
var tested:=0
var failed:=0
var paid_events:Array=[]
var formation_rejections:Array=[]
func check(ok:bool,label:String)->void:
 tested+=1
 if not ok:failed+=1;printerr("FAIL: ",label)
func _initialize()->void:call_deferred("source_run")
func source_run()->void:
 output=OS.get_environment("QA_DIAGNOSTIC_RESULT_DIR");trace=FileAccess.open(output+"/actions.jsonl",FileAccess.WRITE);manifest=JSON.parse_string(FileAccess.get_file_as_string("res://qa-manifest.json"))
 var source:String=OS.get_environment("QA_AFFIX_SOURCE");var snapshot:Variant=JSON.parse_string(FileAccess.get_file_as_string(source))
 if not snapshot is Dictionary:printerr("Actual post-reforge source required");quit(2);return
 options={"allow_new_manual":true,"allow_reforge":false,"visit_seconds":300.0,"affix_target_tier":4};configure_manual_policy()
 game=Game.new(ShipDatabase.new());game.rng.seed=20261005;game.stat_cache_enabled=true;game.save_enabled=false;check(game.load_hyperspace_routes(),"Actual production route loads")
 driver=Driver.new();driver.production_ui_ticks=true;driver.setup(self,game);player_input=PlayerInput.new();player_input.setup(driver.scene,self)
 root.size=Vector2i(1373,883);root.grab_focus();await process_frame;await process_frame
 var restored:Dictionary=Checkpoint.restore(self,Checkpoint.legacy_payload(snapshot));check(restored.error.is_empty(),"Actual post-reforge source formally loads; battle regeneration disclosed")
 var original:String=JSON.stringify(snapshot.save.hyperspace.materials)
 check(JSON.stringify(game.profile.hyperspace.materials)==original and game.profile.hyperspace.inventory.drones==snapshot.save.hyperspace.inventory.drones,"Before observation actual source materials and drone dictionaries untouched")
 driver.before_tick(0.0);driver.scene.refresh_tab_visibility();await process_frame;await process_frame
 var preparation_start:float=game.simulated_time
 while not game.pending_unlocks.is_empty() and game.simulated_time<preparation_start+15.0 and input_failure.is_empty():
  await step_controller();driver.before_tick(STEP);game.tick(STEP);driver.after_tick(STEP)
 check(game.pending_unlocks.is_empty() and input_failure.is_empty(),"Real source pending unlock notices finish by native production countdown, not free acknowledgement")
 await visit_page(9)
 check(page==9 and player_input.modal_windows().is_empty(),"Actual due exploration page reached by native input")
 var initial:Dictionary=game.portable_save_data();var initial_rng:String=str(game.rng.state);var started:float=game.simulated_time
 game.event.connect(func(kind:String,_info:Dictionary):
  if kind!="encounter" or not game.enemies.any(func(e):return e.get("explicit_formation",false)):return
  var errors:Array=driver.scene.validate_explicit_formation()
  if errors.is_empty():return
  var actors:Array=[]
  for e in game.enemies:actors.append({"entity":e.duplicate(true),"pose":driver.scene.enemy_pose(e).duplicate(true),"frontline_limit":driver.scene.enemy_frontline_y_limit(e)})
  formation_rejections.append({"x1":game.simulated_time,"route":game.profile.hyperspace.active.get("route",""),"point":game.group_index,"rng":str(game.rng.state),"uid":game.uid,"fx_time":driver.scene.fx_time,"window":str(root.size),"errors":errors,"actors":actors,"source_profile":game.portable_save_data()})
  record("formation_rejection_observed",formation_rejections[-1])
 )
 game.event.connect(observe);game.event.connect(func(kind:String,info:Dictionary):
  if kind in ["hyperspace_manual","hyperspace_claimed","hyperspace_changed"]:paid_events.append({"kind":kind,"info":info.duplicate(true),"x1":game.simulated_time,"energy":game.profile.hyperspace.energy,"materials":game.profile.hyperspace.materials.duplicate(true),"history":game.profile.hyperspace.history.duplicate(true),"drone_state":game.profile.hyperspace.inventory.drones.duplicate(true)})
 )
 next_tour=started+300.0;next_check=started;busy=false;touring=false;tour=[]
 var paid_forges:=0;var spent_antiproton:=0;var ticks:=0;var previous_seq:int=int(game.profile.hyperspace.command_seq)
 while game.simulated_time<started+600.0 and input_failure.is_empty() and formation_rejections.is_empty():
  var before_materials:Dictionary=game.profile.hyperspace.materials.duplicate(true);var before_drones:Dictionary=game.profile.hyperspace.inventory.drones.duplicate(true)
  await step_controller()
  if int(game.profile.hyperspace.command_seq)>previous_seq and int(before_materials.antiproton)>int(game.profile.hyperspace.materials.antiproton):
   paid_forges+=1;spent_antiproton+=int(before_materials.antiproton)-int(game.profile.hyperspace.materials.antiproton)
   record("paid_affix_affix_witness",{"before_materials":before_materials,"after_materials":game.profile.hyperspace.materials.duplicate(true),"before_drones":before_drones,"after_drones":game.profile.hyperspace.inventory.drones.duplicate(true),"actual_paid_command":true})
  previous_seq=int(game.profile.hyperspace.command_seq)
  if paid_forges>0 and not game.manual_hyperspace.active and (int(game.profile.hyperspace.materials.antiproton)==0 or space_policy.affix_supply(game).is_empty()):break
  driver.before_tick(STEP);game.tick(STEP);driver.after_tick(STEP);ticks+=1
 if not formation_rejections.is_empty() and game.manual_hyperspace.active:
  driver.scene.hyperspace_panel.refresh();await process_frame;await process_frame
  await click_button(control_action("space_exit_budget",driver.scene.hyperspace_panel.exit_button,{"reason":"Observed production formation rejection; preserve cost/refund and stop, no retry"}))
 trace.flush();var events:Array=[];var file=FileAccess.open(output+"/actions.jsonl",FileAccess.READ)
 while not file.eof_reached():
  var line:String=file.get_line()
  if line.strip_edges().is_empty():continue
  var event:Variant=JSON.parse_string(line)
  if event is Dictionary and event.kind in ["domain_action","domain_refusal","manual_request_queued","space_actual_result","paid_affix_affix_witness","paid_affix_finite_followup"]:events.append(event)
 var starts:Array=[];var stops:=0;var paid_promotions:=0
 for event in events:
  if event.kind!="domain_action":continue
  if event.choice.kind=="space_manual" and event.ok:starts.append(event)
  if event.choice.kind=="space_auto_pause" and event.ok:stops+=1
  if event.choice.kind=="space_forge" and event.choice.get("paid_affix",false) and event.ok:paid_promotions+=1
 check(stops>0,"Future recurrence legally stopped without fabricated receipt completion")
 var already_cleared:=0
 for level in initial.cleared:already_cleared=maxi(already_cleared,int(level))
 var expected_target:int=mini(maxi(10,((already_cleared-1)/5)*5),int(initial.highestLevel))
 check(starts.size()==1 and starts[0].choice.route=="gamma" and int(starts[0].choice.level)==expected_target,"Exactly one genuinely paid higher-source challenge backed by already visible main victories, not a free history record")
 if not starts.is_empty():check(absf(float(starts[0].before.energy)-float(starts[0].after.energy)-float(game.hyperspace.config.ticket))<0.001,"Actual manual ticket debited exactly from source energy")
 check(game.hyperspace.best_x1(game,"gamma",expected_target)>0 and space_runs.size()==1 and bool(space_runs[0].success),"All ten actual manual waves won and higher source record earned")
 check(paid_forges>0 and spent_antiproton==paid_forges and paid_promotions==paid_forges,"Paid promotions consume actual earned antiproton one per attempt")
 check(input_failure.is_empty() and rejected_inputs==0,"No native or domain refusal in actual bounded source run")
 check(game.profile.hyperspace.inventory.warehouse.size()<=int(game.hyperspace.config.warehouse_capacity) and game.profile.hyperspace.inventory.overflow.size()<=int(game.hyperspace.config.overflow_capacity),"Actual claim respects formal warehouse/overflow limits")
 FileAccess.open(output+"/paid-affix-source-result.json",FileAccess.WRITE).store_string(JSON.stringify({"source":source,"start":started,"end":game.simulated_time,"seconds":game.simulated_time-started,"preparation_seconds":started-preparation_start,"ticks":ticks,"before":initial,"initial_rng":initial_rng,"after":game.portable_save_data(),"events":events,"production_events":paid_events,"formation_rejections":formation_rejections,"paid_forges":paid_forges,"spent_antiproton":spent_antiproton,"no_injected_currency_drones_levels":true,"scope":"One actual post-reforge paid supply attempt bounded600X1; natural fixed ticks/native page plus disclosed domain actions; not fullchosen low-tier goal or time-target acceptance"},"\t"))
 # Record the actual natural result before the following isolated boundary fixtures.
 var packet:String=output+"/actual-paid-source.bin"
 check(Checkpoint.write(packet,Checkpoint.capture(self,manifest),manifest)==OK,"Actual source after paid operations stored through atomic checkpoint")
 var loaded:Dictionary=Checkpoint.read_valid(packet)
 check(loaded.error.is_empty() and loaded.payload.space_policy.affix_paid_windows==space_policy.affix_paid_windows,"Paid finite-window counts survive checksum checkpoint, not free reset")
 var isolated=Game.new(ShipDatabase.new());isolated.save_enabled=false
 var raw:Dictionary=initial.duplicate(true);raw.chronoSavedAt=Time.get_unix_time_from_system();isolated.load_progress_data(raw)
 var policy=SpacePolicy.new();policy.affix_target_tier=4;var need:Dictionary=policy.affix_supply(isolated)
 check(not need.is_empty() and need.route=="gamma","Actual abovechosen low-tier goal earned affixes select antiproton regardless current delta or main longLaser")
 # Explicit cap-energy fixture only; it is excluded from the natural result/checkpoint above.
 isolated.profile.hyperspace.energy=isolated.hyperspace.online_config(isolated).energy_cap
 var crew:String=str(isolated.profile.hyperspace.auto.crew_id)
 check(isolated.hyperspace.set_auto(isolated,true,"beta",5,crew) and isolated.hyperspace.start_auto(isolated),"Isolated actual recorded auto receipt starts with real reduced ticket")
 var receipt:Dictionary=isolated.profile.hyperspace.active.duplicate(true);var materials:Dictionary=isolated.profile.hyperspace.materials.duplicate(true)
 var stop:Dictionary=policy.paid_affix_supply_action(isolated,0.0,need)
 check(stop.get("kind","")=="space_auto_pause" and policy.execute(isolated,stop,0.0),"Planned paid supply legally stops only future recurrence")
 check(isolated.profile.hyperspace.active==receipt and isolated.profile.hyperspace.materials==materials and preload("res://scripts/hyperspace_permissions.gd").reserved_crew(isolated.profile.hyperspace)==crew,"Current receipt, pending earned reward and real crew reservation remain untouched")
 check(policy.pending_manual_action(isolated,1.0).is_empty(),"No simultaneous manual while preserved auto receipt is running")
 var disabled=NoNewManualPolicy.new();disabled.affix_target_tier=4;var existing:Dictionary=disabled.paid_affix_supply_action(isolated,1.0,need)
 check(existing.get("kind","")=="space_auto" and existing.route=="gamma" and int(existing.level)==5 and disabled.manual_pending.is_empty(),"No-new-manual modifier chooses only already recorded gamma5 and never creates higher record")
 check(disabled.execute(isolated,existing,1.0) and isolated.profile.hyperspace.active==receipt,"Next gamma auto configuration preserves current beta receipt")
 check(isolated.crew.entry(isolated,str(existing.crew)).assignmentType=="" and str(existing.crew)==crew,"Supply keeps actual reserved worker rather than a free novice or busy equipment worker")
 var future:Dictionary=isolated.profile.hyperspace.history.duplicate(true);isolated.profile.hyperspace.history.gamma["999"]=1.0
 check(disabled.best_record(isolated,"gamma")==5,"Future/above-current history is ineligible for source selection")
 isolated.profile.hyperspace.history=future
 var natural=SpacePolicy.new()
 check(natural.affix_target_tier==0 and natural.affix_supply(isolated).is_empty(),"Natural default has no affix-tier spending target or prerequisite")
 disabled.affix_target_tier=0
 check(disabled.affix_supply(isolated).is_empty(),"Optional affix preference can be disabled; no tier prerequisite for progression")
 # Separate in-memory modernization-cost fixture, excluded from actual result/checkpoint.
 # The hypothetical history is not executed or supplied to any campaign.
 isolated.profile.hyperspace.history.alpha["10"]=50.0
 for key_module in isolated.profile.hyperspace.hanging_modules:isolated.profile.hyperspace.hanging_modules[key_module].unlocked=false
 var cost_rng:String=str(isolated.profile.hyperspace.random_state);var cost_materials:Dictionary=isolated.profile.hyperspace.materials.duplicate(true)
 var normal_need:Dictionary=natural.growth_supply(isolated)
 check(normal_need.get("route","")=="alpha" and normal_need.get("operation","")=="modernize" and int(normal_need.get("minimum",0))>0,"With no tier target, actual modernization preview cost selects alpha material rather than main longLaser delta")
 check(str(isolated.profile.hyperspace.random_state)==cost_rng and isolated.profile.hyperspace.materials==cost_materials,"Cost-source planning is read-only; hypothetical record never commits currency or RNG")
 var key:String=str([isolated.profile.hyperspace.round_id,"bounded-fixture"])
 policy.affix_paid_windows[key]={"started":0.0,"attempts":32}
 check(not policy.affix_paid_window(isolated,"bounded-fixture",299.0) and policy.affix_paid_window(isolated,"bounded-fixture",300.0),"Finite paid operations capped32 per300s; no unbounded same-page spending")
 trace.close();driver.close();print("PAID_AFFIX_SOURCE ",tested," checks ",failed," failures; paid ",paid_forges,"; seconds ",game.simulated_time-started);quit(1 if failed else 0)
