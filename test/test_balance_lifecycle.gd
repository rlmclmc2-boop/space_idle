extends SceneTree
const Runner = preload("res://scripts/balance_runner.gd")
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var runner = Runner.new()
	var times := []
	var expected := ""
	for index in 100:
		assert(runner.start({"duration":10,"speed":1000,"seed":12345,"performance_diagnostics":false}).is_empty())
		var old_game: WeakRef = weakref(runner.game)
		var old_metrics: WeakRef = weakref(runner.metrics)
		var old_database: WeakRef = weakref(runner.game.db)
		assert(runner.game.event.get_connections().size() == 1)
		var started := Time.get_ticks_usec()
		while runner.status == "running":runner.step_once()
		times.append(Time.get_ticks_usec()-started)
		var digest := JSON.stringify([runner.game.profile,runner.game.rng.state,runner.metrics.damage]).sha256_text()
		if index == 0:expected = digest
		assert(digest == expected)
		runner.reset()
		assert(old_game.get_ref() == null and old_metrics.get_ref() == null and old_database.get_ref() == null,"run references leaked")
	assert(runner.start({"duration":10,"performance_diagnostics":false}).is_empty())
	runner.pause()
	runner.stop()
	assert(runner.status == "stopped")
	runner.reset()
	var first := 0.0
	var last := 0.0
	for index in 10:
		first += times[index]
		last += times[90+index]
	print("LIFECYCLE 100 identical runs; objects released; first10_us=",first," last10_us=",last," throughput_ratio=",first/last)
	assert(runner.start({"duration":2,"runs":100,"speed":1000,"performance_diagnostics":false}).is_empty())
	var batch_first := 0.0
	var batch_last := 0.0
	while runner.status == "running":
		var index: int = runner.job_index
		var previous: WeakRef = weakref(runner.game)
		var started := Time.get_ticks_usec()
		while runner.status == "running" and runner.job_index == index:runner.step_once()
		if index < 10:batch_first += Time.get_ticks_usec()-started
		# Last run also builds the final batch report; measure that separately.
		if index >= 89 and index < 99:batch_last += Time.get_ticks_usec()-started
		if runner.status == "running":assert(previous.get_ref() == null,"prior batch game retained")
		assert(runner.game.event.get_connections().size() == 1)
	assert(runner.reports.size() == 100)
	runner.reset()
	print("BATCH 100 runs released; first10_us=",batch_first," last10_before_report_us=",batch_last," throughput_ratio=",batch_first/batch_last)
	quit()
