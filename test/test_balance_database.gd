extends SceneTree
const RunDatabase = preload("res://scripts/balance_database.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var original := ShipDatabase.new()
	var cached := RunDatabase.new()
	for key in original.equipment:
		for level in [-1,1,2,40,200,1000]:
			check(original.equip(key,level) == cached.equip(key,level),"real equipment projection %s/%d" % [key,level])
		check(original.enemy_weapon(key) == cached.enemy_weapon(key),"enemy fallback projection "+key)
	for unlock in original.data.unlock.values():
		check(cached.unlock_id(unlock.type,unlock.target) == original.unlock_id(unlock.type,unlock.target),"fixed config unlock lookup")
	for index in 600:cached.unlock_id("missing",str(index))
	check(cached.unlock_ids.size() <= cached.ROW_LIMIT,"unlock lookup is bounded even for missing IDs")
	var first_id: String = str(cached.data.unlock.keys()[0])
	var first: Dictionary = cached.data.unlock[first_id]
	cached.unlock_id(first.type,first.target)
	cached.data.unlock.erase(first_id)
	cached.clear_derived_cache()
	check(cached.unlock_id(first.type,first.target).is_empty(),"unlock source edits invalidate lookup")
	var row := cached.equip("laser",40)
	row.dmg = -123
	check(cached.equip("laser",40) == original.equip("laser",40),"returned equipment row has independent ownership")
	row = cached.enemy_weapon("laser-mon")
	row.cd = -123
	check(cached.enemy_weapon("laser-mon") == original.enemy_weapon("laser-mon"),"returned enemy row has independent ownership")
	for level in 600:cached.equip("laser",level+1)
	check(cached.equipment_rows.size() <= cached.ROW_LIMIT,"equipment cache stays bounded")
	for database in [original,cached]:
		for source in database.equipment.laser:
			if int(source.level) == 1:source.dmg *= 2
	cached.clear_derived_cache()
	check(cached.equip("laser",40) == original.equip("laser",40),"explicit source edit invalidation")
	check(cached.enemy_weapon("laser-mon") == original.enemy_weapon("laser-mon"),"fallback invalidation after source edit")
	# Lab adapter must preserve the shared numeric and current Research owners.
	var live := BattleGame.new(ShipDatabase.new(),false)
	var lab = preload("res://scripts/balance_game.gd").new(RunDatabase.new())
	for subject in [live,lab]:
		subject.profile.cleared = [3,4]
		subject.rebuild_unlocks()
		check(subject.select_tech("weapon_accuracy"),"current research selected")
		subject.advance_hightech(5.0)
	check(lab.research.progress("weapon_accuracy")>0,"Lab advances current research without legacy profile fields")
	check(live.research.save_data()==lab.research.save_data(),"Lab research uses shared advancement")
	var huge = GrowthNumber.make(2.0,400.0)
	lab.player_power_multiplier = 3.0
	for subject in [live,lab]:
		var equipment: Dictionary = subject.equipment.save_data()
		for entry in equipment.loadout.defence:entry.level = 6000
		check(subject.equipment.install_snapshot(equipment,subject.db),"large defence fixture installs")
		subject.configuration_committed()
	check(lab.stat("armour") is Dictionary and GrowthNumber.compare(lab.stat("armour"),GrowthNumber.multiply(live.stat("armour"),3.0))==0,"Lab stat preserves large value and multiplier")
	for subject in [live,lab]:
		var equipment: Dictionary = subject.equipment.save_data()
		equipment.loadout.weapons[0].level = 6000
		check(subject.equipment.install_snapshot(equipment,subject.db),"large attack fixture installs")
		subject.configuration_committed()
		subject.rng.seed = 44
	var live_attack: Dictionary = live.jewel_attack(0)
	var lab_attack: Dictionary = lab.jewel_attack(0)
	check(lab_attack.damage is Dictionary and GrowthNumber.compare(lab_attack.damage,GrowthNumber.multiply(live_attack.damage,3.0))==0,"Lab attack preserves large value and multiplier")
	lab.start(1,false)
	lab.spawn_group()
	var target: Dictionary = lab.enemies[0]
	lab.fire(lab.player,target,lab.db.equip("laser",1),huge,false,"laser")
	check(GrowthNumber.compare(lab.projectiles.back().damage,huge)==0,"Lab projectile preserves large raw damage")
	var metrics = preload("res://scripts/balance_metrics.gd").new()
	lab.metrics = metrics
	metrics.initialize(lab)
	metrics.add(metrics.damage,"laser",huge)
	metrics.add(metrics.income,"1",huge)
	metrics.spend("weapons",{"1":huge})
	metrics.time = 60.0
	metrics.combat_seconds = 60.0
	metrics.timeline.snapshot(lab,metrics,true)
	var large_report: Dictionary = metrics.report(lab)
	check(GrowthNumber.compare(large_report.dps,GrowthNumber.divide(huge,60.0))==0,"metrics preserve large DPS")
	check(large_report.weapon_damage_share.laser==1.0 and large_report.resources.system_share.weapons["1"]==1.0,"large metric shares use shared ratio")
	check(GrowthNumber.compare(large_report.timeline.samples.back().resource_income["1"],huge)==0,"timeline preserves large income")
	check(GrowthNumber.valid(large_report.defence.min_health),"large minimum health is reportable")
	lab.hit_player(GrowthNumber.multiply(lab.player.armour,0.1),0)
	check(GrowthNumber.compare(metrics.received,0)>0 and GrowthNumber.valid(metrics.received),"actual large player hit records valid damage")
	var report_api = preload("res://scripts/balance_report.gd")
	large_report.merge({"parameter_value":null,"strategy":"BALANCED","seed":1,"partial":false})
	large_report.analysis = preload("res://scripts/balance_analyzer.gd").analyze_run(large_report)
	var compiled_report: Dictionary = report_api.build({"simulation_mode":"exact"},[large_report,large_report],"completed")
	check(GrowthNumber.compare(compiled_report.summary.dps.mean,large_report.dps)==0,"report summary retains large mean")
	check(compiled_report.metrics_summary.has("dps") and not compiled_report.metrics_summary.has("dps/m"),"large metric is one quantity, not mantissa/exponent metrics")
	var accumulator: Dictionary = report_api.accumulator()
	report_api.accumulate(accumulator,huge)
	report_api.accumulate(accumulator,GrowthNumber.multiply(huge,3))
	var statistics: Dictionary = report_api.statistics(accumulator)
	check(GrowthNumber.compare(statistics.mean,GrowthNumber.multiply(huge,2))==0 and GrowthNumber.ratio(statistics.stddev,huge)>0.99999,"large mean and variance use shared arithmetic")
	check(report_api.finite_change(huge,GrowthNumber.multiply(huge,2))==100.0,"large values have finite relative comparison")
	check(report_api.finite_difference(huge,GrowthNumber.multiply(huge,2))==null,"unsupported signed absolute result is explicit")
	check(preload("res://scripts/balance_views.gd").value(huge)==GrowthNumber.text(huge),"report view renders large quantity")
	var exported: Dictionary = report_api.save(compiled_report,ProjectSettings.globalize_path("res://.runtime/s4-report"))
	check(not exported.has("error") and FileAccess.get_file_as_string(exported.csv).contains(GrowthNumber.input_text(huge)),"large report exports quantity text")
	var baseline_api = preload("res://scripts/balance_baseline.gd")
	var baseline_path := ProjectSettings.globalize_path("res://.runtime/s4-baseline-%d.json" % Time.get_ticks_usec())
	check(baseline_api.save_baseline(compiled_report,baseline_path).is_empty(),"large baseline saves")
	var restored: Dictionary = baseline_api.load_baseline(baseline_path)
	check(not restored.has("error"),"large baseline reloads")
	var compared: Dictionary = baseline_api.compare(restored.report,compiled_report)
	check(compared.rows.all(func(item):return item.change==null or is_zero_approx(float(item.change))),"large baseline roundtrip has zero changes")
	var auto_game = preload("res://scripts/balance_game.gd").new(RunDatabase.new())
	auto_game.profile.cleared = [3,4]
	auto_game.rebuild_unlocks()
	var expected_choice: String = auto_game.research.shortest_available(auto_game)
	var auto = preload("res://scripts/balance_autoplayer.gd").new()
	auto.act(auto_game,0.0)
	check(not expected_choice.is_empty() and auto_game.research.selected()==expected_choice,"Lab automatic selection reuses current Research choice")
	auto_game.advance_hightech(1.0)
	check(auto_game.research.progress(expected_choice)>0,"automatic Lab research actually advances")
	var auto_metrics = preload("res://scripts/balance_metrics.gd").new()
	auto_game.metrics=auto_metrics
	auto_metrics.initialize(auto_game)
	auto_game.economy.credit("1",1000.0)
	check(auto_game.set_tech_input("1",10.0),"research input selected")
	auto_game.ai_tech_last_resource_notice_ms=Time.get_ticks_msec()+100000
	var wallet_before: Variant = auto_game.economy.balance("1")
	auto_game.advance_hightech(1.0)
	check(GrowthNumber.compare(auto_metrics.spending.get("1",0),GrowthNumber.subtract(wallet_before,auto_game.economy.balance("1")))==0 and GrowthNumber.compare(auto_metrics.spending.get("1",0),0)>0,"research spending follows actual commit despite throttled UI")
	var spending_before: Variant = auto_metrics.spending["1"]
	var stale: Dictionary = auto_game.research.prepare_advance(auto_game,1.0)
	auto_game.economy.credit("1",1.0)
	var refused: Dictionary = auto_game.progress_runtime.commit_research_advance_result(auto_game,stale)
	check(refused.status!="committed" and auto_metrics.spending["1"]==spending_before,"rejected research proposal adds no spending")
	check(not auto_metrics.uses.has("scientists") and not auto_metrics.spending_by_system.has("scientists"),"obsolete scientist metrics exited")
	check(large_report.damage_basis=="enemy_hp_removed_excluding_shield","damage report names HP-only basis")
	var base := BattleGame.new(ShipDatabase.new(),false)
	base.economy.credit("1",huge)
	base.economy.credit("2",huge)
	var saved: Dictionary = base.portable_save_data()
	var upgraded: Dictionary = preload("res://scripts/player_loadout_generator.gd").upgraded_profile(base.db,{"ship":saved.selectedShip,"equipment":saved.loadout},saved,1)
	check(not upgraded.has("error") and int(upgraded.loadout.weapons[0].level)==2 and GrowthNumber.compare(upgraded.resources["1"],huge)==0,"Lab upgrade funding preserves out-of-precision large balances")
	var runner = preload("res://scripts/balance_runner.gd").new()
	check(runner.start({"duration":1.0,"performance_diagnostics":false}).is_empty(),"actual F8 runner starts")
	for step in 65:
		if runner.status!="running":break
		runner.step_once()
	check(runner.status=="completed" and runner.completed.summary.dps.count==1,"actual F8 runner completes report")
	var contract = preload("res://scripts/execution_contract.gd")
	check(not contract.lab(lab,"unknown").ok,"unknown Lab model rejected")
	check(contract.enemy_state({"hp":1.0,"max_shield":huge})=="unsupported_lab_enemy_scalar:max_shield","finite HP with large max shield rejected before float")
	check(contract.enemy_state({"hp":huge})=="unsupported_lab_enemy_scalar:hp","large enemy HP rejected before float")
	var rejected = preload("res://scripts/balance_runner.gd").new()
	check(rejected.start({"duration":1.0,"performance_diagnostics":false}).is_empty(),"admission fixture starts")
	rejected.game.spawn_group()
	rejected.game.enemies[0].max_shield=huge
	rejected.game.configuration_revision+=1
	rejected.step_once()
	check(rejected.status=="error" and rejected.execution_error=="unsupported_lab_enemy_scalar:max_shield" and rejected.steps==0,"version change rejection reaches actual F8 result without consuming time")
	var source_rejected = preload("res://scripts/balance_game.gd").new(RunDatabase.new())
	source_rejected.start(1,false)
	for row_id in source_rejected.db.enemies:source_rejected.db.enemies[row_id].shield=huge
	source_rejected.spawn_group()
	check(source_rejected.execution_error=="unsupported_lab_enemy_source:shield" and source_rejected.enemies.is_empty(),"large source shield rejected before enemy construction")
	check(not source_rejected.start(1,false,{"distance":0.0,"groupIndex":1,"retreatBossPending":false,"state":BattleGame.State.COMBAT,"guardArrived":false}),"checkpoint propagates rejected spawn")
	check(source_rejected.execution_error=="unsupported_lab_enemy_source:shield","checkpoint preserves admission reason")
	var rejected_baseline_path := "res://.runtime/s4-rejected-baseline.json"
	DirAccess.remove_absolute(rejected_baseline_path)
	check(preload("res://scripts/balance_baseline.gd").save_baseline(runner.completed,rejected_baseline_path).is_empty(),"valid baseline fixture saved")
	check(rejected.load_baseline(rejected_baseline_path).is_empty() and rejected.completed.comparison.reasons.has("no_comparable_report"),"baseline loads after admission error without comparing absent report")
	var identity_api = preload("res://scripts/execution_identity.gd")
	var captured: Dictionary = runner.config.execution_identity
	check(captured.status=="known" and captured.rules.has("res://scripts/game.gd"),"batch identity includes actual loaded core rules")
	var loaded_core: GDScript=load("res://scripts/game.gd")
	check(captured.rules["res://scripts/game.gd"]==loaded_core.source_code.sha256_text(),"identity hashes loaded implementation")
	check(identity_api.compare(captured,captured,"comparison").compatible,"known matching identity comparable")
	check(not identity_api.compare({}, {},"merge").compatible,"unknown identities never equal")
	var changed_identity: Dictionary=captured.duplicate(true)
	changed_identity.data_sha256="changed"
	check(identity_api.compare(captured,changed_identity,"comparison").compatible and identity_api.compare(captured,changed_identity,"comparison").differences.has("data_sha256"),"data comparison exposes intentional differences")
	check(not identity_api.compare(captured,changed_identity,"retest").compatible,"retest refuses changed data")
	changed_identity=captured.duplicate(true)
	changed_identity.rules_sha256="changed"
	check(not identity_api.compare(captured,changed_identity,"merge").compatible,"merge refuses changed rules")
	var probe_path := "res://scripts/s4_identity_probe.gd"
	var probe_file := FileAccess.open(probe_path,FileAccess.WRITE)
	probe_file.store_string("extends RefCounted\nconst VALUE = 1\n");probe_file.close()
	var first_capture = identity_api.new()
	var first_identity:Dictionary=first_capture.capture(original,[probe_path],"probe",{})
	probe_file=FileAccess.open(probe_path,FileAccess.WRITE)
	probe_file.store_string("extends RefCounted\nconst VALUE = 2\n");probe_file.close()
	var second_capture = identity_api.new()
	var retained_identity:Dictionary=second_capture.capture(original,[probe_path],"probe",{})
	check(first_identity.rules_sha256==retained_identity.rules_sha256,"disk edit after capture does not relabel retained loaded implementation")
	var dirty: GDScript=first_capture.retained_scripts[0]
	dirty.source_code="extends RefCounted\nconst VALUE = 3\n"
	check(dirty.reload()==OK,"dirty loaded implementation fixture compiles")
	var third_capture=identity_api.new()
	var dirty_identity:Dictionary=third_capture.capture(original,[probe_path],"probe",{})
	check(first_identity.rules_sha256!=dirty_identity.rules_sha256,"actual dirty loaded implementation changes identity")
	var fleet_db := ShipDatabase.new()
	var enemy_generator = preload("res://scripts/enemy_fleet_simulator.gd").new(fleet_db)
	var enemy_rows: Array = enemy_generator.generate({"count":1,"min_count":1,"max_count":1,"available_enemies":[fleet_db.enemies.keys()[0]],"seed":12,"min_strength":0,"max_strength":1000000}).results
	var player_generator = preload("res://scripts/player_loadout_generator.gd").new(fleet_db)
	var player_options: Dictionary=player_generator.default_options();player_options.count=1
	var player_rows: Array=player_generator.generate(player_options).results
	var fleet = preload("res://scripts/fleet_battle_runner.gd").new(fleet_db)
	check(fleet.start(enemy_rows,player_rows,{"runs":1,"max_total":1,"max_per_pair":1,"max_seconds":0.1,"directory":"res://.runtime/s4-fleet"}).is_empty(),"actual F9 batch starts with captured identity")
	var deadline := Time.get_ticks_msec()+5000
	while fleet.busy() and Time.get_ticks_msec()<deadline:fleet.process(10000)
	check(not fleet.busy() and fleet.completed==1 and fleet.execution_identity.status=="known","actual F9 batch finishes with identity")
	var saved_inputs: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(fleet.directory.path_join("inputs.json")))
	check(identity_api.digest(saved_inputs.execution_identity)==identity_api.digest(fleet.execution_identity),"F9 result inputs retain captured identity")
	var followup=preload("res://scripts/fleet_battle_runner.gd").new(fleet_db)
	var followup_options:Dictionary=saved_inputs.config.duplicate(true)
	followup_options.retest_saved_inputs=true;followup_options.data_sha256=saved_inputs.data_sha256
	followup_options.source_execution_identity=saved_inputs.execution_identity
	followup_options.replay_inputs=saved_inputs.replay_inputs
	followup_options.explicit_pairs=[{"enemy_index":0,"player_index":0,"runs":1}]
	check(followup.start(saved_inputs.enemy_fleets,saved_inputs.player_loadouts,followup_options).is_empty(),"actual F9 retest accepts captured persisted identity")
	deadline=Time.get_ticks_msec()+5000
	while followup.busy() and Time.get_ticks_msec()<deadline:followup.process(10000)
	var merged:Dictionary=preload("res://scripts/fleet_batch_retest.gd").combine(fleet.directory,followup.directory)
	check(merged.has("directory"),"actual F9 merge accepts compatible batches")
	var large_generator_db:=ShipDatabase.new()
	for rows in large_generator_db.equipment.values():
		for large_source_row in rows:
			if large_source_row.get("dmg")!=null and large_source_row.get("dmgMulti")!=null:large_source_row.dmg=1e300;large_source_row.dmgMulti=10.0
	large_generator_db.equipment.armour[0].para1=1e300
	large_generator_db.equipment.armour[0].para2=10.0
	var large_generator=preload("res://scripts/player_loadout_generator.gd").new(large_generator_db)
	var large_options:Dictionary=large_generator.default_options();large_options.count=1;large_options.module_level=100
	var large_generated:Dictionary=large_generator.generate(large_options)
	check(large_generated.status=="complete" and large_generated.results.size()==1,"player generator supports large quantities through shared number arithmetic")
	if not large_generated.results.is_empty():check(GrowthNumber.compare(large_generated.results[0].stats.burst,1e300)>0 and is_finite(large_generated.results[0].feature_scores.burst),"large generated score remains a finite ratio")
	for unsupported_row in large_generator_db.enemies.values():unsupported_row.shield=huge
	var unsupported_generator=preload("res://scripts/enemy_fleet_simulator.gd").new(large_generator_db)
	check(unsupported_generator.error=="unsupported_enemy_analysis_scalar:shield","static enemy analysis refuses unsupported source before float conversion")
	var timings := []
	for database in [original,cached]:
		var started := Time.get_ticks_usec()
		for index in 10000:database.equip("shield",40+index%3)
		timings.append(Time.get_ticks_usec()-started)
	print("ROW_PROJECTION_USEC=",timings)
	print("Balance Database: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
