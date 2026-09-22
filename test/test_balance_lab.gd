extends SceneTree
const Runner := preload("res://scripts/balance_runner.gd")
const Report := preload("res://scripts/balance_report.gd")
const Scan := preload("res://scripts/balance_scan.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",label)

func _initialize() -> void:call_deferred("run")

func simulate(speed: int, seconds := 180.0, seed_value := 7):
	var runner = Runner.new()
	check(runner.start({"speed":speed,"duration":seconds,"runs":1,"seed":seed_value}).is_empty(),"start accepted")
	while runner.status == "running":runner.process(0.1,100000)
	return runner

func run() -> void:
	check(UIText.reload_catalog().is_empty(),"text contracts")
	var save_exists := FileAccess.file_exists(BattleGame.SAVE_PATH)
	var before_save := FileAccess.get_file_as_string(BattleGame.SAVE_PATH) if save_exists else ""
	var baseline = simulate(1)
	for speed in [10,100,1000]:
		var other = simulate(speed)
		check(baseline.reports == other.reports,"identical report across speed %d" % speed)
		check(baseline.game.profile == other.game.profile,"identical profile across speed %d" % speed)
		check(baseline.game.rng.state == other.game.rng.state,"identical RNG state across speed %d" % speed)
	var different = simulate(100,60,8)
	check(different.game.rng.state != baseline.game.rng.state,"seed controls game RNG")
	var runner = Runner.new()
	runner.start({"speed":100,"duration":120,"runs":2,"seed":42})
	runner.process(0.1)
	runner.pause()
	var paused_steps: int = runner.steps
	runner.process(1)
	check(runner.steps == paused_steps,"pause stops simulation")
	runner.pause()
	runner.process(0.1)
	check(runner.steps > paused_steps,"resume advances")
	runner.stop()
	check(runner.status == "stopped" and runner.completed.runs[0].partial,"stop returns labelled partial result")
	runner.reset()
	check(runner.status == "idle" and runner.game == null and runner.reports.is_empty(),"reset clears run state")
	var scan_request := {"speed":1000,"duration":2,"runs":2,"seed":10,"scan":{"path":["levels",0,"lifeRatio"],"start":1.08,"end":1.20,"step":0.02}}
	check(runner.start(scan_request).is_empty(),"scan accepted")
	check(is_equal_approx(float(runner.game.db.levels[0].lifeRatio),1.08),"first scan value applied to live database field")
	while runner.status == "running":runner.process(0.1,100000)
	check(runner.reports.size() == 14 and runner.completed.scan.size() == 7,"inclusive scan grid with repeats")
	check(is_equal_approx(float(runner.game.db.levels[0].lifeRatio),1.20),"final scan value applied to live database field")
	check(runner.reports[0].seed == runner.reports[2].seed,"paired seeds per parameter")
	check(ShipDatabase.new().levels[0].lifeRatio == baseline.baseline.levels[0].lifeRatio,"scan leaves source DB unchanged")
	check(runner.completed.summary.dps.count == 14,"aggregate sample count")
	check(Scan.jobs({"duration":0},baseline.baseline).has("error"),"reject invalid duration")
	check(Scan.jobs({"scan":{"path":["levels",0,"lifeRatio"],"start":1,"end":2,"step":0}},baseline.baseline).has("error"),"reject zero scan step")
	var exported := Report.save(runner.completed,ProjectSettings.globalize_path("res://.runtime/balance_lab"))
	check(not exported.has("error"),"JSON/CSV export succeeds")
	var decoded: Variant = JSON.parse_string(FileAccess.get_file_as_string(exported.json))
	# JSON parses numeric path segments as floats; compare their numeric values.
	check(decoded.runs.size() == 14 and decoded.config.scan.path[0] == "levels" and int(decoded.config.scan.path[1]) == 0 and decoded.config.scan.path[2] == "lifeRatio","JSON contains configuration and complete runs")
	check(FileAccess.get_file_as_string(exported.csv).contains("/resources/income"),"CSV includes detailed economy")
	check(FileAccess.get_file_as_string(exported.scan_csv).split("\n",false).size() == 8,"scan CSV has one row per parameter")
	# Full requested one-hour experiment, no invented starting budget/unlocks.
	var started := Time.get_ticks_msec()
	var hour = simulate(100,3600)
	print("ONE_HOUR_WALL_MS=",Time.get_ticks_msec()-started)
	var report: Dictionary = hour.reports[0]
	check(absf(report.game_seconds-3600) < 0.00001,"one game hour completes")
	check(report.kills > 0 and report.upgrades > 0,"real battle and automatic upgrades participate")
	var damage := 0.0
	for value in report.damage.values():damage += float(value)
	check(is_equal_approx(report.dps*report.game_seconds,damage),"actual damage reconciles with DPS")
	for id in report.resources.balance:
		var expected := float(report.initial_resources[id])+float(report.resources.income.get(id,0))-float(report.resources.spending.get(id,0))
		check(is_equal_approx(expected,float(report.resources.balance[id])),"resource conservation "+id)
	var hour_export := Report.save(hour.completed,ProjectSettings.globalize_path("res://.runtime/balance_lab"))
	print("ONE_HOUR_REPORT=",hour_export)
	check(FileAccess.file_exists(BattleGame.SAVE_PATH) == save_exists,"lab does not create save")
	if save_exists:check(FileAccess.get_file_as_string(BattleGame.SAVE_PATH) == before_save,"lab does not change save")
	# Debug disable is enforced at the runner boundary, not just the UI.
	ProjectSettings.set_setting("debug/balance_lab/enabled",false)
	check(Runner.new().start({}) == "disabled","global kill switch")
	ProjectSettings.set_setting("debug/balance_lab/enabled",true)
	print("Balance Lab: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
