extends SceneTree
## Native-window benchmark using a test-only profile captured by the natural
## performance probe. This resumes a new encounter, not a runtime save restore.
const Metrics = preload("res://scripts/balance_metrics.gd")
var failures := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ",label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var path := OS.get_environment("BALANCE_PERF_FIXTURE")
	if path.is_empty() or not FileAccess.file_exists(path):
		printerr("BALANCE_PERF_FIXTURE must point to the isolated high-stage-fixture.bin")
		quit(2)
		return
	var file := FileAccess.open(path,FileAccess.READ)
	var fixture: Dictionary = file.get_var()
	file.close()
	root.gui_embed_subwindows = false
	var scene = load("res://main.tscn").instantiate()
	scene.automation_args = ["--capture"]
	root.add_child(scene)
	scene.set_process(false)
	scene.show_balance_lab()
	await process_frame
	var panel = scene.balance_lab
	panel.set_process(false)
	panel.directory.text = ProjectSettings.globalize_path("res://.runtime/ui_performance")
	var original_fps := Engine.max_fps
	var hashes := []
	for fps in [30,60,30,60]:
		Engine.max_fps = fps
		for budget in [12000,48000]:
			var runner = panel.runner
			runner.reset()
			runner.start({"duration":120,"seed":12345,"speed":1000})
			check(JSON.stringify(runner.game.db.data).sha256_text() == fixture.data_sha256,"fixture configuration matches")
			var game = runner.game
			game.profile = fixture.profile.duplicate(true)
			game.jewel_serial = int(fixture.jewel_serial)
			game.rng.state = fixture.rng_state
			game.reset_player()
			runner.metrics = Metrics.new()
			game.metrics = runner.metrics
			runner.metrics.initialize(game)
			game.start(int(fixture.stage),false)
			runner.policy.configure("BALANCED",12345)
			runner.affordable = runner.policy.act(game,0)
			runner.metrics.timeline.snapshot(game,runner.metrics,true)
			panel.refresh_status()
			await process_frame
			var started := Time.get_ticks_usec()
			var previous := started
			var frames := 0
			var compute := 0
			var peak := 0
			var refresh_seconds := 0.0
			while runner.status == "running":
				await process_frame
				var now := Time.get_ticks_usec()
				var delta := float(now-previous)/1000000.0
				runner.process(delta,budget)
				var cost := Time.get_ticks_usec()-now
				compute += cost
				peak = maxi(peak,cost)
				previous = now
				frames += 1
				refresh_seconds += delta
				if refresh_seconds >= 0.25:
					panel.refresh_status()
					refresh_seconds = 0.0
			var wall := float(Time.get_ticks_usec()-started)/1000000.0
			var fingerprint: String = JSON.stringify(runner.reports).sha256_text()
			hashes.append(fingerprint)
			print(JSON.stringify({"fps_limit":fps,"budget_usec":budget,"wall_seconds":wall,"compute_seconds":float(compute)/1000000.0,"effective_speed":120/wall,"frames":frames,"peak_process_usec":peak,"report_hash":fingerprint}))
			panel.refresh_status()
			check(not runner.game.tick_effects_active and runner.game.tick_effect_entries.is_empty(),"no effects retained between ticks")
	check(hashes.all(func(value):return value == hashes[0]),"identical outcomes across frame rates and budgets")
	Engine.max_fps = original_fps
	panel.close_lab()
	print("Native performance failures: ",failures)
	quit(1 if failures else 0)
