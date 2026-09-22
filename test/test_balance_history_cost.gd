extends SceneTree
## Controlled history-size comparison, NOT a natural long-duration simulation.
const Runner = preload("res://scripts/balance_runner.gd")
func _initialize() -> void:call_deferred("run")
func run() -> void:
	if OS.get_environment("BALANCE_FIXTURE").is_empty():
		printerr("Required benchmark environment variable: BALANCE_FIXTURE")
		quit(2)
		return
	var fixture_file := FileAccess.open(OS.get_environment("BALANCE_FIXTURE"),FileAccess.READ)
	if fixture_file == null:
		printerr("Cannot open benchmark fixture")
		quit(2)
		return
	var fixture: Dictionary = fixture_file.get_var()
	var expected := ""
	for repeat in 4:
		for full_history in [false,true]:
			var runner = Runner.new()
			runner.start({"duration":600,"speed":1000,"seed":12345,"performance_diagnostics":false})
			runner.game.profile = fixture.profile.duplicate(true)
			runner.game.rng.state = fixture.rng_state
			runner.game.jewel_serial = fixture.jewel_serial
			runner.game.start(fixture.stage,false)
			if full_history:
				var timeline = runner.metrics.timeline
				var point: Dictionary = timeline.samples[0].duplicate(true)
				while timeline.samples.size() < timeline.max_samples:timeline.samples.append(point.duplicate(true))
				while timeline.events.size() < timeline.max_events:timeline.events.append({"time":0.0,"stage":1,"kind":"UPGRADE","data":{},"count":1})
				for index in timeline.max_samples:timeline.decision_bins[str(index)] = 1
			var started := Time.get_ticks_usec()
			# Stop before report construction: only compare per-step history cost.
			for step in 1800:runner.step_once()
			var elapsed := Time.get_ticks_usec()-started
			var digest := JSON.stringify([runner.game.profile,runner.game.player,runner.game.enemies,runner.game.projectiles,runner.game.rng.state,runner.metrics.damage]).sha256_text()
			if expected.is_empty():expected = digest
			if digest != expected:
				printerr("FAIL history changed simulation")
				quit(1)
				return
			print("HISTORY full=",full_history," steps/s=",1800000000.0/elapsed," hash=",digest)
			runner.reset()
	quit()
