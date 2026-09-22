extends SceneTree
## FAST Accuracy Benchmark. Paired runs from identical fresh profiles/config.
## Timing includes fixed steps, unchanged AutoPlayer, metrics and final report.
const Runner = preload("res://scripts/balance_runner.gd")
const SEEDS := [12345,12346,12347,12348,12349,12350,12351,12352,12353,12354]
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var durations := OS.get_environment("BALANCE_FAST_DURATIONS")
	if durations.is_empty():durations = "600,3600"
	var count := 10 if OS.get_environment("BALANCE_FAST_SEEDS").is_empty() else int(OS.get_environment("BALANCE_FAST_SEEDS"))
	if count < 1 or count > SEEDS.size():quit(2); return
	for value in durations.split(","):
		for index in count:
			# Alternate ordering to reduce systematic warm-up/thermal bias.
			for mode in (["exact","fast"] if index%2 == 0 else ["fast","exact"]):
				var runner = Runner.new()
				var error: String = runner.start({"duration":float(value),"seed":SEEDS[index],"speed":1000,"simulation_mode":mode,"performance_diagnostics":false})
				if not error.is_empty():printerr(error); quit(2); return
				var started := Time.get_ticks_usec()
				while runner.status == "running":runner.step_once()
				var seconds := float(Time.get_ticks_usec()-started)/1000000.0
				var row: Dictionary = runner.reports[0]
				row.wall_seconds = seconds
				row.config = runner.config
				row.core_hash = JSON.stringify([runner.game.profile,runner.game.player,runner.game.rng.state,runner.metrics.damage,runner.metrics.uses]).sha256_text()
				var file := FileAccess.open("res://.runtime/accuracy_%d_%d_%s.json" % [float(value),SEEDS[index],mode],FileAccess.WRITE)
				file.store_string(JSON.stringify(row,"\t",true,true))
				file.close()
				print("FAST_ACCURACY duration=",value," seed=",SEEDS[index]," mode=",mode," seconds=",seconds," scheduled=",runner.game.fast_scheduled," stage=",row.final_stage," hash=",row.core_hash)
				runner.reset()
	quit()
