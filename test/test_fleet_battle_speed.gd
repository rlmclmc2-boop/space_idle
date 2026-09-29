extends SceneTree
## Standalone lab benchmark: same battles, two UI frame budgets.
const Enemy := preload("res://scripts/enemy_fleet_simulator.gd")
const Player := preload("res://scripts/player_loadout_generator.gd")
const Runner := preload("res://scripts/fleet_battle_runner.gd")
func _initialize() -> void:call_deferred("run")
func run() -> void:
	Engine.max_fps=60
	var db:=ShipDatabase.new()
	var enemies: Array=Enemy.new(db).generate({"count":200,"min_count":1,"max_count":10,"available_enemies":db.enemies.keys(),"seed":12345,"min_strength":0,"max_strength":1000000}).results
	var generator=Player.new(db)
	var options=generator.default_options()
	options.count=200
	var players: Array=generator.generate(options).results
	var baseline: Array=[]
	var failed:=false
	for budget in [8000,int(ProjectSettings.get_setting("application/config/battle_frame_budget_usec",24000))]:
		var runner=Runner.new(db)
		var request={"max_total":100,"max_per_pair":3,"runs":3,"seed":12345,"directory":ProjectSettings.globalize_path("res://results/frame-profile")}
		if not runner.start(enemies,players,request).is_empty():failed=true;break
		var started:=Time.get_ticks_usec()
		var frames:=0
		while runner.busy():
			runner.process(budget)
			frames+=1
			await process_frame
		var duration=(Time.get_ticks_usec()-started)/1000.0
		print("BATTLE SPEED budget_us=",budget," wall_ms=",duration," frames=",frames," completed=",runner.completed)
		if runner.completed!=100 or (not baseline.is_empty() and baseline!=runner.results):failed=true
		baseline=runner.results.duplicate(true)
	print("BATTLE SPEED failures=",int(failed))
	quit(1 if failed else 0)
