extends SceneTree
## Legal late-stage profile from the natural-growth probe. Positive scan values
## create increasing ordinary-projectile density; no health/damage/CD cheats.
const Game = preload("res://scripts/balance_game.gd")
const Database = preload("res://scripts/balance_database.gd")
const Metrics = preload("res://scripts/balance_metrics.gd")
const Scan = preload("res://scripts/balance_scan.gd")
const Runner = preload("res://scripts/balance_runner.gd")
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var path := OS.get_environment("BALANCE_FIXTURE")
	var fixture := {}
	if path.is_empty():
		var runner = Runner.new()
		if runner.start({"duration":21600,"seed":12345,"speed":1000,"performance_diagnostics":false}) != "":quit(2); return
		while runner.status == "running" and runner.game.stage < 21:runner.step_once()
		if runner.game.stage < 21:printerr("Natural fixture did not reach stage 21 in 6h"); quit(2); return
		fixture = {"profile":runner.game.profile.duplicate(true),"rng_state":runner.game.rng.state,"jewel_serial":runner.game.jewel_serial,"stage":runner.game.stage,"data_sha256":runner.config.data_sha256,"natural_seconds":runner.metrics.time}
		var generated := FileAccess.open("res://.runtime/fast-natural-fixture.bin",FileAccess.WRITE)
		generated.store_var(fixture)
		generated.close()
		print("NATURAL_FIXTURE stage=",fixture.stage," game_seconds=",fixture.natural_seconds)
		runner.reset()
	else:
		var file := FileAccess.open(path,FileAccess.READ)
		if file == null:quit(2); return
		fixture = file.get_var()
		file.close()
	var rows := []
	for scale in [1.0,0.25,0.0625]:
		for repeat in 3:
			for mode in (["exact","fast"] if repeat%2 == 0 else ["fast","exact"]):
				var database = Database.new()
				if JSON.stringify(database.data).sha256_text() != fixture.data_sha256:
					printerr("Fixture config fingerprint mismatch; regenerate naturally")
					quit(2); return
				for actor in ["player","enemy"]:
					var path: Array=["weapon_motion",actor+"_projectile_pixels_per_unit","value"]
					var speed_value: float=Scan.read(database.data,path)*scale
					if not Scan.valid_value(path,speed_value):quit(2); return
					Scan.apply(database.data,path,speed_value)
				var game = Game.new(database)
				game.simulation_mode = mode
				game.profile = fixture.profile.duplicate(true)
				game.rng.state = fixture.rng_state
				game.jewel_serial = fixture.jewel_serial
				# Existing free-refit API, only enabled slots. Keep natural levels,
				# gems, enemies and economics; fixed build isolates flight cost.
				for index in game.weapon_entries().size():
					if not game.equip_slot("weapons",index,"cannon"):quit(2); return
				game.start(fixture.stage,false)
				game.spawn_group()
				game.metrics = Metrics.new()
				game.metrics.initialize(game)
				var peak := 0
				var total := 0
				var started := Time.get_ticks_usec()
				for step in 3600:
					game.tick(1.0/60.0)
					var count: int = game.projectiles.size()+game.pending_hits.size()
					peak = maxi(peak,count)
					total += count
				var seconds := float(Time.get_ticks_usec()-started)/1000000.0
				var row := {"scale":scale,"repeat":repeat,"simulation_mode":mode,"seconds":seconds,"peak":peak,"average":total/3600.0,"stage":game.stage,"scheduled":game.fast_scheduled,"fallback":game.fast_fallback,"fixture_hash":fixture.data_sha256,"metrics":game.metrics.report(game),"core_hash":JSON.stringify([game.profile,game.player,game.enemies,game.rng.state,game.metrics.damage]).sha256_text()}
				rows.append(row)
				print("FAST_PERFORMANCE ",JSON.stringify({"scale":scale,"repeat":repeat,"mode":mode,"seconds":seconds,"peak":peak,"average":row.average,"hash":row.core_hash}))
				var output := FileAccess.open("res://.runtime/fast_performance.json",FileAccess.WRITE)
				output.store_string(JSON.stringify(rows,"\t",true,true))
				output.close()
	quit()
