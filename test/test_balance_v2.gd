extends SceneTree
const Runner := preload("res://scripts/balance_runner.gd")
const Scan := preload("res://scripts/balance_scan.gd")
const Baseline := preload("res://scripts/balance_baseline.gd")
const Report := preload("res://scripts/balance_report.gd")
const Timeline := preload("res://scripts/balance_timeline.gd")
const Analyzer := preload("res://scripts/balance_analyzer.gd")
const AutoPlayer := preload("res://scripts/balance_autoplayer.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",label)
func _initialize() -> void:call_deferred("run")
func finish(runner) -> void:
	while runner.status == "running":runner.process(0.1,100000)
func point(time: float) -> Dictionary:
	return {"game_time":time,"window_seconds":30.0,"stage":1,"highest_stage":1,"combat_seconds":30.0,"normal_ttk":2.0,
		"player_survivability":{"received_per_combat_second":1.0},"upgrade_idle":0.0,"upgrade_interval":10.0,"upgrades":3,"growth_idle":0.0,
		"resource_balance":{"1":100.0},"resource_income":{"1":10.0},"deaths":0,"dps":100.0,"kills":5,"choice_count":1,"system_uses":{"upgrade":1}}
func run() -> void:
	var db := ShipDatabase.new()
	var paths := Scan.parameters(db.data)
	for path in [["levels",0,"atkRatio"],["levels",0,"resRatio"],["equipment","laser",0,"costMulti_1"],["jewel","1","para_2"]]:check(paths.has(path),"real scan field "+str(path))
	var jobs := Scan.jobs({"duration":60,"runs":2,"strategies":["BALANCED","DAMAGE_FIRST"],"sweeps":[{"path":["levels",0,"lifeRatio"],"start":1.08,"end":1.20,"step":0.02},{"path":["equipment","laser",0,"cd"],"start":0.5,"end":0.6,"step":0.1}]},db.data)
	check(jobs.jobs.size() == 36,"queued one-at-a-time sweeps x strategies x seeds")
	check(jobs.jobs[0].seed == jobs.jobs[2].seed,"paired strategy seeds")
	check(Scan.jobs({"scan":{"path":["equipment","laser",0,"cd"],"start":0,"end":1,"step":0.1}},db.data).has("error"),"reject zero weapon CD")
	var runner = Runner.new()
	check(runner.start({"duration":90,"speed":1000,"seed":8,"sample_interval":30}).is_empty(),"start timeline experiment")
	finish(runner)
	var result: Dictionary = runner.reports[0]
	check(result.timeline.samples.size() == 4,"initial + 30/60/90 second snapshots")
	check(result.timeline.samples[1].game_time > 29.99,"game time snapshot cadence")
	check(result.timeline.events.any(func(event):return event.kind == "NEW_WEAPON"),"new weapon unlock event")
	check(result.timeline.decision_density.count > 0,"successful choices recorded")
	var before: Dictionary = runner.game.profile.duplicate(true)
	Analyzer.analyze_run(result)
	check(runner.game.profile == before,"analysis never writes live state")
	var path := ProjectSettings.globalize_path("res://.runtime/baseline-v2.json")
	check(runner.save_baseline(path).is_empty(),"save independent baseline")
	check(not Baseline.save_baseline(runner.completed,path).is_empty(),"baseline never silently overwritten")
	var saved := Baseline.load_baseline(path)
	check(not saved.has("error"),"read baseline")
	var same := Baseline.compare(saved.report,runner.completed)
	if not same.compatible:print("COMPARABILITY=",same.reasons," signatures=",Baseline.signature(saved.report),Baseline.signature(runner.completed))
	check(same.compatible and same.rows.all(func(row):return row.change == null or is_zero_approx(float(row.change))),"baseline roundtrip produces zero changes")
	var changed: Dictionary = runner.completed.duplicate(true)
	changed.metrics_summary["weapon_damage_share/missile"].mean = 0.42
	var base: Dictionary = saved.report.duplicate(true)
	base.metrics_summary["weapon_damage_share/missile"].mean = 0.18
	var comparison := Baseline.compare(base,changed)
	var missile: Dictionary = comparison.rows.filter(func(row):return row.metric == "weapon_damage_share/missile")[0]
	check(is_equal_approx(missile.change,24.0) and missile.unit == "pp","share change uses percentage points")
	changed.runs[0].seed += 1
	check(not Baseline.compare(base,changed).compatible,"unpaired seeds labelled incompatible")
	var timeline = Timeline.new()
	timeline.configure(36000,30,10,2)
	for index in 20:timeline.record("UPGRADE",1.0,1,{},true)
	check(timeline.decisions == 1,"same instant batch is one decision opportunity")
	timeline.record("DEATH",2,1)
	timeline.record("NEW_WEAPON",3,1,{"key":"missile"},true)
	check(timeline.events.size() <= 2 and timeline.dropped_events > 0 and timeline.decisions == 2,"bounded events retain exact decision counts")
	check(timeline.interval >= 4000,"long-run sampling capped")
	var report := Report.build(runner.config,runner.reports,"completed")
	check(report.schema_version == 2 and report.summary.has("decision_interval"),"v2 summary fields")
	var exported := Report.save(report,ProjectSettings.globalize_path("res://.runtime/v2-report"))
	check(not exported.has("error") and FileAccess.get_file_as_string(exported.csv).contains("/timeline/samples"),"timeline included in export")
	runner.start({"duration":60,"speed":1000})
	check(not runner.baseline_report.is_empty(),"baseline survives new run/reset")
	runner.stop()
	check(not runner.completed.comparison.compatible,"cancelled report not silently compared as complete")
	# Independent strategy RNG: same game seed, repeatable RANDOM_VALID decisions.
	var multi = Runner.new()
	check(multi.start({"duration":180,"speed":1000,"seed":912,"strategies":Scan.STRATEGIES}).is_empty(),"all five policies accepted")
	finish(multi)
	check(multi.reports.size() == 5 and multi.completed.scan.size() == 5,"one result per strategy")
	for index in 5:check(multi.reports[index].strategy == Scan.STRATEGIES[index] and multi.reports[index].seed == 912,"strategy seed paired "+str(index))
	var repeat = Runner.new()
	repeat.start({"duration":180,"speed":100,"seed":912,"strategies":["RANDOM_VALID"]})
	finish(repeat)
	check(repeat.reports[0] == multi.reports[4],"random policy deterministic across speed and job order")
	check(multi.reports[0].damage != multi.reports[1].damage or multi.reports[0].resources.spending != multi.reports[1].resources.spending,"policies change real actions/results")
	var policy = AutoPlayer.new()
	var game := BattleGame.new(db,false)
	check(policy.weapon_value(game,"longLaser",1) > policy.weapon_value(game,"laser",1),"beam estimate includes real ramp and charge time")
	policy.configure("RANDOM_VALID",42)
	var state_before := game.rng.state
	policy.act(game,0)
	check(game.rng.state == state_before,"policy RNG does not consume battle RNG")
	check(game.stat("armour") > 0,"random valid build keeps hull health")
	var capped = Runner.new()
	capped.start({"duration":61,"speed":1000,"max_samples":2,"sample_interval":30})
	finish(capped)
	check(capped.reports[0].timeline.samples.size() == 2 and absf(capped.reports[0].timeline.samples.back().game_time-61) < 0.001,"sample cap retains final endpoint")
	# Prescribed windows exercise independent diagnostics with numerical evidence.
	var points := []
	for index in 20:
		var sample := point((index+1)*30.0)
		sample.normal_ttk = 10.0
		sample.upgrade_idle = (index+1)*30.0
		sample.growth_idle = (index+1)*30.0
		sample.player_survivability.received_per_combat_second = 0.0
		sample.resource_balance = {"1":0.0,"2":100000.0}
		sample.resource_income = {"1":10.0,"2":1.0}
		sample.deaths = 3 if index == 5 else 0
		sample.highest_stage = 1+index/3
		points.append(sample)
	points[3].dps = 400.0
	var issues := Analyzer.analyze_timeline(points)
	var codes := []
	for item in issues:
		codes.append(item.code)
		check(item.has_all(["severity","time","start_time","stage","evidence"]),"diagnostic evidence contract")
	for code in ["ttk_wall","defence_low_value","growth_stalled","growth_vacuum","resource_zero","resource_hoarding","death_burst","dps_breakthrough","dps_stagnation","few_new_choices","system_inactive"]:
		check(codes.has(code),"diagnostic "+code)
	var fast := []
	for index in 4:
		var sample := point((index+1)*30.0)
		sample.upgrade_interval = 0.5
		fast.append(sample)
	check(Analyzer.analyze_timeline(fast).any(func(item):return item.code == "upgrades_too_fast"),"sustained fast upgrades diagnosed")
	var invalid_path := ProjectSettings.globalize_path("res://.runtime/invalid-baseline.json")
	var invalid_file := FileAccess.open(invalid_path,FileAccess.WRITE)
	invalid_file.store_string('{"kind":"balance_baseline","report":{"status":"completed","runs":[],"config":{},"summary":{"dps":"bad"},"metrics_summary":{}}}')
	invalid_file.close()
	check(Baseline.load_baseline(invalid_path).has("error"),"malformed baseline rejected before comparison")
	print("Balance V2: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
