extends SceneTree
## Actual fixed-step runs, no clock jumps or game state shortcuts.
const Runner = preload("res://scripts/balance_runner.gd")
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var durations := OS.get_environment("BALANCE_LONG_DURATIONS")
	if durations.is_empty():durations = "600,3600,36000,360000"
	for value in durations.split(","):
		var runner = Runner.new()
		var duration := float(value)
		var error: String = runner.start({"speed":1000,"duration":duration,"seed":12345,"performance_directory":ProjectSettings.globalize_path("res://.runtime")})
		if not error.is_empty():
			push_error(error)
			quit(1)
			return
		var started := Time.get_ticks_usec()
		while runner.status == "running":runner.step_once()
		var elapsed := float(Time.get_ticks_usec()-started)/1000000.0
		var core := {"profile":runner.game.profile,"player":runner.game.player,"rng":str(runner.game.rng.state),"stage":runner.game.stage,"damage":runner.metrics.damage,"upgrades":runner.metrics.upgrades,"deaths":runner.metrics.deaths,"income":runner.metrics.income,"spending":runner.metrics.spending,"uses":runner.metrics.uses}
		var result := {"duration":duration,"wall_seconds":elapsed,"steps_per_second":runner.logic_steps_total/elapsed,"performance":runner.performance_log.summary(),"core":core,"core_hash":JSON.stringify(core).sha256_text(),"data_hash":runner.config.data_sha256}
		var output := FileAccess.open("res://.runtime/long_%d.json" % duration,FileAccess.WRITE)
		output.store_string(JSON.stringify(result,"\t"))
		output.close()
		print("LONG_RESULT ",duration," seconds wall=",elapsed," steps/s=",runner.logic_steps_total/elapsed," hash=",result.core_hash)
		runner.reset()
	quit()
