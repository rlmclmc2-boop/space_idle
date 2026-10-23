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
	var timings := []
	for database in [original,cached]:
		var started := Time.get_ticks_usec()
		for index in 10000:database.equip("shield",40+index%3)
		timings.append(Time.get_ticks_usec()-started)
	print("ROW_PROJECTION_USEC=",timings)
	print("Balance Database: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
