extends SceneTree
const Game = preload("res://scripts/balance_game.gd")
const Database = preload("res://scripts/balance_database.gd")
func _initialize() -> void:call_deferred("run")
func run() -> void:
	for variable in ["BALANCE_FIXTURE","BALANCE_REFERENCE_GAME","BALANCE_REFERENCE_DATABASE"]:
		if OS.get_environment(variable).is_empty():
			printerr("Required benchmark environment variable: ",variable)
			quit(2)
			return
	var file := FileAccess.open(OS.get_environment("BALANCE_FIXTURE"),FileAccess.READ)
	if file == null:
		printerr("Cannot open benchmark fixture")
		quit(2)
		return
	var fixture: Dictionary = file.get_var()
	var reference_game = load(OS.get_environment("BALANCE_REFERENCE_GAME"))
	var reference_database = load(OS.get_environment("BALANCE_REFERENCE_DATABASE"))
	var expected := ""
	for repeat in 4:
		for cached in [false,true]:
			var database = Database.new() if cached else reference_database.new()
			assert(JSON.stringify(database.data).sha256_text() == fixture.data_sha256)
			var game = Game.new(database) if cached else reference_game.new(database)
			game.profile = fixture.profile.duplicate(true)
			game.rng.state = fixture.rng_state
			game.jewel_serial = fixture.jewel_serial
			game.start(fixture.stage,false)
			var started := Time.get_ticks_usec()
			for step in 3600:game.tick(1.0/60.0)
			var elapsed := Time.get_ticks_usec()-started
			var digest := JSON.stringify([game.profile,game.player,game.enemies,game.projectiles,game.rng.state]).sha256_text()
			if expected.is_empty():expected = digest
			if expected != digest:
				printerr("FAIL research reuse changed core")
				quit(1)
				return
			print("RESEARCH cached=",cached," usec=",elapsed," hash=",digest)
	quit()
