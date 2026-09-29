extends SceneTree
## Diagnostic probe; run through test/run.py. Timings are inclusive, not additive.
## Compare identical data fingerprints and all checkpoint hashes before timings.
const Runner = preload("res://scripts/balance_runner.gd")
const Metrics = preload("res://scripts/balance_metrics.gd")
class MeasuredGame extends "res://scripts/balance_game.gd":
	var timings := {"tick":0,"research":0,"projectiles":0,"repair":0,"effects":0,"stat":0,"equipment":0,"hit_player":0,"defence_sync":0}
	func hit_player(raw: float, type: int) -> void:
		var start := Time.get_ticks_usec()
		super.hit_player(raw,type)
		timings.hit_player += Time.get_ticks_usec()-start
	func sync_jewel_defence_damage() -> void:
		var start := Time.get_ticks_usec()
		super.sync_jewel_defence_damage()
		timings.defence_sync += Time.get_ticks_usec()-start
	func tick(dt: float) -> void:
		var start := Time.get_ticks_usec()
		super.tick(dt)
		timings.tick += Time.get_ticks_usec()-start
	func advance_hightech(dt: float, real_dt := -1.0, end_time := -1.0) -> void:
		var start := Time.get_ticks_usec()
		super.advance_hightech(dt,real_dt,end_time)
		timings.research += Time.get_ticks_usec()-start
	func tick_projectiles(dt: float) -> void:
		var start := Time.get_ticks_usec()
		super.tick_projectiles(dt)
		timings.projectiles += Time.get_ticks_usec()-start
	func advance_jewel_repair(dt: float) -> void:
		var start := Time.get_ticks_usec()
		super.advance_jewel_repair(dt)
		timings.repair += Time.get_ticks_usec()-start
	func jewel_effects(entry: Dictionary) -> Array:
		var start := Time.get_ticks_usec()
		var result := super.jewel_effects(entry)
		timings.effects += Time.get_ticks_usec()-start
		return result
	func stat(key: String) -> float:
		var start := Time.get_ticks_usec()
		var result := super.stat(key)
		timings.stat += Time.get_ticks_usec()-start
		return result
	func equipment_stat(key: String, level: int) -> float:
		var start := Time.get_ticks_usec()
		var result := super.equipment_stat(key,level)
		timings.equipment += Time.get_ticks_usec()-start
		return result
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var runner = Runner.new()
	var duration := float(OS.get_environment("BALANCE_PERF_SECONDS")) if OS.has_environment("BALANCE_PERF_SECONDS") else 4200.0
	var wall_limit := int(OS.get_environment("BALANCE_PERF_WALL_SECONDS")) if OS.has_environment("BALANCE_PERF_WALL_SECONDS") else 120
	runner.start({"speed":1000,"duration":duration,"seed":12345})
	var game := MeasuredGame.new(runner.game.db)
	game.rng.seed = 12345
	runner.game = game
	runner.metrics = Metrics.new()
	game.metrics = runner.metrics
	runner.metrics.initialize(game)
	runner.policy.configure("BALANCED",12345)
	runner.affordable = runner.policy.act(game,0)
	var started := Time.get_ticks_msec()
	var last := started
	var overhead := 0
	var prev_tick := 0
	var fixture_saved := false
	while runner.status == "running":
		var begin := Time.get_ticks_usec()
		runner.step_once()
		overhead += Time.get_ticks_usec()-begin
		if game.stage >= 21 and not fixture_saved:
			var fixture := FileAccess.open("res://.runtime/high-stage-fixture.bin",FileAccess.WRITE)
			fixture.store_var({"profile":game.profile,"jewel_serial":game.jewel_serial,"rng_state":game.rng.state,"stage":game.stage,"data_sha256":JSON.stringify(game.db.data).sha256_text()})
			fixture.close()
			fixture_saved = true
		if runner.steps % 18000 == 0:
			print(JSON.stringify({"seconds":game.simulated_time,"stage":game.stage,"wall_ms":Time.get_ticks_msec()-last,"timings":game.timings,"overhead_us":overhead-int(game.timings.tick)+prev_tick,"drops":game.drops.size(),"research":game.profile.hightechLevels,"scientists":game.profile.get("scientists"),"projectiles":game.projectiles.size(),"profile_hash":JSON.stringify(game.profile).sha256_text(),"rng":str(game.rng.state),"metrics_hash":JSON.stringify(game.metrics.report(game)).sha256_text()}))
			prev_tick = game.timings.tick
			overhead = 0
			last = Time.get_ticks_msec()
		if Time.get_ticks_msec()-started > wall_limit*1000:
			print("PERFORMANCE_TIME_LIMIT")
			quit(2)
			return
	print("PERFORMANCE_END ",game.simulated_time," stage=",game.stage)
	quit()
