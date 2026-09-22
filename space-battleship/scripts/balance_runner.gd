extends RefCounted
const LabGame := preload("res://scripts/balance_game.gd")
const Metrics := preload("res://scripts/balance_metrics.gd")
const AutoPlayer := preload("res://scripts/balance_autoplayer.gd")
const Scan := preload("res://scripts/balance_scan.gd")
const Report := preload("res://scripts/balance_report.gd")
const Baseline := preload("res://scripts/balance_baseline.gd")
const Analyzer := preload("res://scripts/balance_analyzer.gd")
const RunDatabase := preload("res://scripts/balance_database.gd")
const PerformanceLog := preload("res://scripts/balance_performance.gd")
const STEP := 1.0/60.0
const FRAME_BUDGET_USEC := 12000
const HIGH_SPEED_BUDGET_USEC := 48000
var game: BattleGame
var metrics
var policy = AutoPlayer.new()
var config := {}
var baseline := {}
var jobs := []
var reports := []
var status := "idle"
var speed := 100.0
var credit := 0.0
var steps := 0
var job_index := 0
var completed: Dictionary = {}
var last_decision := 0.0
var affordable := false
var wall_seconds := 0.0
var total_game_seconds := 0.0
var baseline_report := {}
var baseline_path := ""
var performance_log = PerformanceLog.new()
var logic_steps_total := 0
var warning_count := 0

func start(request: Dictionary) -> String:
	if not OS.has_feature("debug") or not ProjectSettings.get_setting("debug/balance_lab/enabled",true):return "disabled"
	if status in ["running","paused"]:return "already_running"
	var normalized := {"simulation_mode":"exact","duration":3600.0,"runs":1,"seed":1,"speed":100,"strategies":["BALANCED"],"sample_interval":30.0,"max_samples":1200}
	normalized.merge(request,true)
	if normalized.simulation_mode not in ["exact","fast"]:return "invalid_simulation_mode"
	var database := ShipDatabase.new()
	var planned := Scan.jobs(normalized,database.data)
	if planned.has("error"):return str(planned.error)
	var requested_speed := float(normalized.speed)
	if requested_speed not in [1.0,10.0,100.0,1000.0]:return "invalid_speed"
	if float(normalized.sample_interval) < 1 or not is_finite(float(normalized.sample_interval)) or int(normalized.max_samples) < 2 or int(normalized.max_samples) > 2000:return "invalid_sampling"
	reset()
	baseline = database.data.duplicate(true)
	config = normalized.duplicate(true)
	config.data_sha256 = JSON.stringify(baseline).sha256_text()
	config.step_seconds = STEP
	config.policy = "rules_v2"
	config.initial_state = "fresh_profile"
	config.engine_version = Engine.get_version_info().string
	jobs = planned.jobs
	speed = requested_speed
	status = "running"
	performance_log.configure(str(normalized.get("performance_directory",ProjectSettings.globalize_path("res://../test/work/balance_lab"))),bool(normalized.get("performance_diagnostics",true)))
	next_run()
	return ""

func next_run() -> void:
	var database := RunDatabase.new()
	database.data = baseline.duplicate(true)
	var job: Dictionary = jobs[job_index]
	if job.value != null:Scan.apply(database.data,job.path,float(job.value))
	database.equipment = database.data.equipment
	database.enemies = database.data.enemies
	database.groups = database.data.groups
	database.levels = database.data.levels
	database.config = database.data.config
	database.defaults = database.data.defaults
	database.ships = database.data.get("ship",{})
	game = LabGame.new(database)
	game.simulation_mode = config.simulation_mode
	game.rng.seed = int(job.seed)
	metrics = Metrics.new()
	game.metrics = metrics
	metrics.timeline.configure(float(config.duration),float(config.sample_interval),mini(int(config.max_samples),maxi(2,20000/jobs.size())),mini(5000,maxi(10,100000/jobs.size())))
	metrics.initialize(game)
	steps = 0
	last_decision = 0.0
	if policy.has_method("configure"):policy.configure(str(job.strategy),int(job.seed))
	affordable = policy.act(game,0)
	metrics.timeline.snapshot(game,metrics,true)
	# Metrics describe the build used during the next decision interval.

func frame_budget_usec() -> int:
	# High-speed runs must not spend most of a low-FPS window's time waiting
	# between tiny work slices. Still yield every ~48ms for pause/stop input.
	return HIGH_SPEED_BUDGET_USEC if speed >= 100 else FRAME_BUDGET_USEC

func process(delta: float, budget_usec := -1) -> void:
	if status != "running":return
	if budget_usec < 0:budget_usec = frame_budget_usec()
	wall_seconds += maxf(delta,0)
	credit += clampf(delta,0,0.25)*speed
	# Keep pending time when CPU limited, but bound debt to avoid an unbounded queue.
	credit = minf(credit,speed*2.0)
	var deadline := Time.get_ticks_usec()+budget_usec
	while status == "running" and credit+0.000000001 >= STEP and Time.get_ticks_usec() < deadline:
		step_once()
		credit = maxf(0,credit-STEP)
	# Real-time cadence also applies at 1x, where 1024 logic steps take ~17s.
	# sample only reads the clock until due; JSON/container inspection stays rare.
	performance_log.sample(self)

func step_once() -> void:
	if status != "running":return
	var remaining := float(config.duration)-steps*STEP
	var dt := minf(STEP,remaining)
	game.tick(dt)
	total_game_seconds += dt
	steps += 1
	logic_steps_total += 1
	if logic_steps_total % 1024 == 0:performance_log.sample(self)
	if steps % 60 == 0 or remaining <= STEP+0.000000001:
		metrics.sample(game,metrics.time-last_decision,affordable)
		last_decision = metrics.time
		if remaining > STEP+0.000000001:affordable = policy.act(game,steps*STEP)
		metrics.timeline.snapshot(game,metrics,remaining <= STEP+0.000000001)
	if remaining <= STEP+0.000000001:
		finish_run(false)
		job_index += 1
		if job_index >= jobs.size():
			status = "completed"
			complete_report()
		else:next_run()

func finish_run(partial: bool) -> void:
	metrics.timeline.snapshot(game,metrics,true)
	var result: Dictionary = metrics.report(game)
	result.seed = jobs[job_index].seed
	result.simulation_mode = config.simulation_mode
	result.projectile_processing = {"scheduled":game.fast_scheduled,"resolved":game.fast_resolved,"pending_peak":game.fast_peak,"fallback":game.fast_fallback}
	result.parameter_value = jobs[job_index].value
	result.parameter_id = jobs[job_index].parameter_id
	result.strategy = jobs[job_index].strategy
	result.partial = partial
	result.initial_resources = {"1":ceilf(float(game.db.defaults.startingIron)),"2":ceilf(float(game.db.defaults.startingTitanium)),"jewel_fragments":0.0}
	result.analysis = Analyzer.analyze_run(result)
	warning_count += result.anomalies.size()+result.analysis.warnings.size()
	reports.append(result)

func complete_report() -> void:
	# Finished run dictionaries are immutable here and in the report views.
	# Own a separate array, without duplicating every timeline/event a second time.
	completed = Report.build(config,reports,status,false)
	completed.comparison = Baseline.compare(baseline_report,completed)
	performance_log.sample(self,true)
	performance_log.close()

func load_baseline(path: String) -> String:
	var result := Baseline.load_baseline(path)
	if result.has("error"):return str(result.error)
	baseline_report = result.report
	baseline_path = path
	if not completed.is_empty():completed.comparison = Baseline.compare(baseline_report,completed)
	return ""

func save_baseline(path: String) -> String:
	var error := Baseline.save_baseline(completed,path)
	if not error.is_empty():return error
	return load_baseline(path)

func pause() -> void:
	if status == "running":status = "paused"
	elif status == "paused":
		status = "running"
		performance_log.resume(logic_steps_total)

func stop() -> void:
	if status not in ["running","paused"]:return
	metrics.sample(game,metrics.time-last_decision,affordable)
	finish_run(true)
	status = "stopped"
	complete_report()
	credit = 0.0

func reset() -> void:
	performance_log.close()
	performance_log = PerformanceLog.new()
	logic_steps_total = 0
	warning_count = 0
	game = null
	metrics = null
	jobs.clear()
	reports.clear()
	completed.clear()
	config.clear()
	baseline.clear()
	job_index = 0
	steps = 0
	credit = 0
	wall_seconds = 0
	total_game_seconds = 0
	status = "idle"
