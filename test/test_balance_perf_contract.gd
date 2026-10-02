extends SceneTree
const Runner = preload("res://scripts/balance_runner.gd")
const Timeline = preload("res://scripts/balance_timeline.gd")
const Report = preload("res://scripts/balance_report.gd")
const Scan = preload("res://scripts/balance_scan.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL ",message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	for path in [["defaults","projectilePixelsPerUnit"],["weapon_motion","player_projectile_pixels_per_unit","value"],["weapon_motion","enemy_projectile_pixels_per_unit","value"],["equipment","laser",0,"para1"],["equipment","cannon",0,"para1"],["equipment","missile",0,"para2"]]:
		check(not Scan.valid_value(path,0) and Scan.valid_value(path,1),"reject stationary projectile scan "+str(path))
	check(Scan.valid_value(["equipment","longLaser",0,"para1"],0),"zero beam ramp remains valid")
	var timeline := Timeline.new()
	timeline.configure(31536000,30,1200,10)
	for index in 52560:timeline.record("UPGRADE",index*600.0,1,{},true)
	var density: Dictionary = timeline.report(31536000).decision_density
	check(timeline.events.size() <= 10 and timeline.samples.size() <= 1200,"bounded events/samples")
	check(timeline.decision_bins.size() <= 1200 and density.per_window.size() <= 1200,"year-long density is bounded")
	check(density.count == 52560 and density.per_10_minutes.is_empty() and density.window_seconds > 600,"exact count and honest resolution")
	var count := 0
	for value in density.per_window.values():count += int(value)
	check(count == density.count,"no decisions lost to wider bins")
	var state := Report.accumulator()
	for value in [1000000000001.0,1000000000002.0,1000000000003.0]:Report.accumulate(state,value)
	var stats := Report.statistics(state)
	check(stats.mean == 1000000000002.0 and is_equal_approx(stats.stddev,sqrt(2.0/3.0)),"Welford population variance")
	check(Report.statistics(Report.accumulator()).mean == null,"empty summary remains null")
	var runner = Runner.new()
	check(runner.start({"duration":2,"speed":1000,"performance_directory":ProjectSettings.globalize_path("res://.runtime")}).is_empty(),"diagnostic run")
	while runner.status == "running":runner.step_once()
	var line: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(runner.performance_log.path).strip_edges())
	check(line.steps == 120 and line.containers.signal_connections == 1 and line.final,"streamed diagnostic record")
	check(line.run == 1 and line.status == "completed" and line.strategy == "BALANCED" and line.duration_seconds == 2 and line.data_sha256 == runner.config.data_sha256,"diagnostics identify the exact run/configuration")
	check(line.containers.timeline <= 1200 and line.containers.resource_samples < 100,"container sizes recorded")
	check(runner.performance_log.stream == null,"diagnostic file closed on completion")
	var row_input: Dictionary = runner.reports[0].duplicate(true)
	row_input.timeline.samples = [{"dps":NAN,"kills":3},{"dps":1.0,"kills":3},{"dps":2.0,"kills":3}]
	check(Report.row(row_input).dps_growth == 100.0,"DPS endpoint scan retains original NaN filtering")
	check(not is_same(runner.reports,runner.completed.runs) and is_same(runner.reports[0],runner.completed.runs[0]),"runner shares immutable finished rows, not the mutable array")
	var independent := Report.build(runner.config,runner.reports,"completed")
	check(not is_same(independent.runs[0],runner.reports[0]),"public report API retains independent copies by default")
	var retained: Dictionary = runner.completed.runs[0]
	runner.reset()
	check(not retained.timeline.samples.is_empty(),"reset does not mutate a retained finished row")
	check(runner.performance_log.records == 0 and runner.logic_steps_total == 0,"reset diagnostics")
	check(runner.start({"duration":1,"performance_diagnostics":false}).is_empty(),"disabled diagnostics")
	while runner.status == "running":runner.step_once()
	check(runner.performance_log.path.is_empty() and runner.performance_log.records == 0,"disabled writes nothing")
	check(runner.start({"duration":1,"speed":1}).is_empty(),"real-time sampling at 1x")
	runner.performance_log.next_time = 0
	runner.process(0.001)
	check(runner.logic_steps_total == 0 and runner.performance_log.records == 1,"diagnostics do not wait for 1024 steps at low speed")
	runner.reset()
	print("PERF CONTRACT failures=",failures)
	quit(1 if failures else 0)
