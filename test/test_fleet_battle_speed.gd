extends SceneTree
## Standalone lab benchmark: same battles, two UI frame budgets.
const Enemy := preload("res://scripts/enemy_fleet_simulator.gd")
const Player := preload("res://scripts/player_loadout_generator.gd")
const Runner := preload("res://scripts/fleet_battle_runner.gd")
func _initialize() -> void:call_deferred("run")
func run() -> void:
	Engine.max_fps=60
	var setup_started:=Time.get_ticks_usec()
	var total:=int(OS.get_environment("FLEET_PERF_TOTAL")) if OS.has_environment("FLEET_PERF_TOTAL") else 100
	var candidates:=int(OS.get_environment("FLEET_PERF_CANDIDATES")) if OS.has_environment("FLEET_PERF_CANDIDATES") else 200
	var db:=ShipDatabase.new()
	var enemies: Array=Enemy.new(db).generate({"count":candidates,"min_count":1,"max_count":2 if OS.has_environment("FLEET_PERF_CANDIDATES") else 10,"available_enemies":[db.enemies.keys()[0]] if OS.has_environment("FLEET_PERF_CANDIDATES") else db.enemies.keys(),"seed":12345,"min_strength":0,"max_strength":1000000}).results
	var generator=Player.new(db)
	var options=generator.default_options()
	options.count=candidates
	if OS.has_environment("FLEET_PERF_CANDIDATES"):options.module_level=10
	var players: Array=generator.generate(options).results
	print("BATTLE_SETUP_US ",Time.get_ticks_usec()-setup_started)
	var baseline: Array=[]
	var failed:=false
	for budget in [8000,int(ProjectSettings.get_setting("application/config/battle_frame_budget_usec",24000))]:
		var runner=Runner.new(db)
		var request={"max_total":total,"max_per_pair":3,"runs":3,"seed":12345,"directory":ProjectSettings.globalize_path("res://results/frame-profile")}
		if not runner.start(enemies,players,request).is_empty():failed=true;break
		var started:=Time.get_ticks_usec()
		var frames:=0
		var cpu_us:=0
		while runner.busy():
			var cpu_started:=Time.get_ticks_usec()
			runner.process(budget)
			cpu_us+=Time.get_ticks_usec()-cpu_started
			frames+=1
			await process_frame
		var duration=(Time.get_ticks_usec()-started)/1000.0
		print("BATTLE SPEED budget_us=",budget," wall_ms=",duration," frames=",frames," completed=",runner.completed," cpu_us=",cpu_us)
		print("BATTLE_WORK ",JSON.stringify(runner.results))
		if runner.completed!=total or (not baseline.is_empty() and baseline!=runner.results):failed=true
		baseline=runner.results.duplicate(true)
	print("BATTLE SPEED failures=",int(failed))
	quit(1 if failed else 0)
