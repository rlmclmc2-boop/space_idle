extends SceneTree

var checks := 0
var failures := 0
var observed: Array = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",label)

func observe(kind: String, _payload: Dictionary, game: BattleGame) -> void:
	if kind == "resources_changed":observed.append(game.portable_save_data())

func finish() -> void:
	print("Save boundaries: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func remember(data: Dictionary) -> void:
	var file := FileAccess.open("user://expected.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()

func _initialize() -> void:
	var area := ProjectSettings.globalize_path("res://../userdata").simplify_path().replace("\\", "/")
	check(OS.get_user_data_dir().replace("\\", "/").begins_with(area), "Uses isolated player data")
	var db := ShipDatabase.new()
	db.config.offlineMax = 0
	var phase := OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "write"
	if phase != "write":
		reopen(db, phase)
		return
	var game := BattleGame.new(db, true)
	check(game.save_enabled and game.progress_writer.owns_progress(), "Real native writer lock is held")
	game.profile.cleared = [1]
	game.rebuild_unlocks()
	game.economy.credit("2", 10000.0)
	game.economy.credit_fragments(123.45)
	var before = game.economy.balance("2")
	var quoted = game.reactor_upgrade_cost()
	var observer := observe.bind(game)
	game.event.connect(observer)
	check(game.upgrade_reactor(1), "Reactor purchase commits")
	game.event.disconnect(observer)
	check(observed.size() == 1 and observed[0].reactorLevel == 2 and observed[0].resources["2"] == before - quoted, "Notification and save snapshot see the complete purchase")
	check(not FileAccess.file_exists(BattleGame.SAVE_PATH), "Purchase does not write a partial save")
	check(game.set_reactor_allocation("weapons", 31), "Allocate reactor before save")
	var detached := game.economy.resources()
	detached["2"] = 0
	var detached_reactor := game.reactor.allocations()
	detached_reactor.weapons = 0
	check(game.economy.balance("2") == before - quoted and game.reactor.allocation("weapons") == 31, "Read views cannot mutate authoritative domains")
	check(not game.profile.has("resources") and not game.profile.has("reactorLevel") and not game.profile.has("reactorAllocation") and not game.profile.has("jewelFragments") and not game.profile.has("chronoParticles"), "Profile no longer owns migrated state")
	var rejected := game.portable_save_data()
	rejected.resources["2"] = -1
	var prior := game.portable_save_data()
	game.load_progress_data(rejected)
	check(game.economy.save_data().resources == prior.resources and game.reactor.level() == prior.reactorLevel, "Invalid load leaves both domains unchanged")
	game.hyperspace.last_error = ""
	game.save_progress()
	check(game.last_save_error == OK and not game.save_dirty, "Current committed snapshot writes successfully")
	var original := FileAccess.get_file_as_string(BattleGame.SAVE_PATH)
	var saved: Dictionary = JSON.parse_string(original)
	var transfer := preload("res://scripts/save_transfer.gd").new()
	check(transfer.prepare_data(saved, db).error == "", "Written current format passes pure validation")
	var sparse := saved.duplicate(true)
	sparse.erase("reactorAllocation")
	check(not transfer.prepare_data(sparse, db).error.is_empty(), "Incomplete current state is rejected")
	remember(saved)
	finish()

func reopen(db: ShipDatabase, phase: String) -> void:
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://expected.json"))
	# JSON numbers are doubles; this fixture's small integer allocations are exact.
	for key in saved.reactorAllocation:saved.reactorAllocation[key] = int(saved.reactorAllocation[key])
	var original := FileAccess.get_file_as_string(BattleGame.SAVE_PATH)
	var restored := BattleGame.new(db, true)
	check(restored.startup_error.is_empty() and restored.progress_writer.owns_progress(), "Fresh game reopens with real persistence enabled")
	if phase == "latest":
		check(restored.economy.resources() == saved.latest, "Second real process reopen selects latest commit")
		var damaged := FileAccess.open(BattleGame.SAVE_PATH, FileAccess.WRITE)
		damaged.store_string("{broken")
		damaged.close()
		finish()
		return
	if phase == "recovery":
		check(restored.economy.resources() == saved.resources, "Corrupt primary recovers complete backup")
		check(original == "{broken", "Recovery read preserves rejected primary bytes")
		restored.save_progress()
		check(restored.last_save_error == OK and FileAccess.get_file_as_string(BattleGame.SAVE_PATH + ".rejected") == "{broken", "Recovery write retains rejected bytes")
		finish()
		return
	check(restored.economy.resources() == saved.resources and restored.economy.balance("jewel") == saved.jewelFragments and restored.reactor.level() == saved.reactorLevel and restored.reactor.allocations() == saved.reactorAllocation, "Save/reopen preserves balances, reactor level and allocations")
	var unchanged := restored.portable_save_data()
	var bad := unchanged.duplicate(true)
	bad.reactorAllocation.weapons = -1
	restored.load_progress_data(bad)
	check(restored.reactor.allocations() == saved.reactorAllocation and restored.economy.resources() == saved.resources, "Invalid allocation cannot install resources first")
	restored.hyperspace.last_error = ""
	DirAccess.make_dir_absolute(BattleGame.SAVE_PATH + ".tmp")
	restored.economy.credit("1", 7)
	restored.save_progress()
	check(restored.last_save_error != OK and restored.save_dirty, "Failed write retains dirty state")
	check(FileAccess.get_file_as_string(BattleGame.SAVE_PATH) == original, "Failed write preserves the committed bytes")
	DirAccess.remove_absolute(BattleGame.SAVE_PATH + ".tmp")
	restored.save_progress()
	check(restored.last_save_error == OK and FileAccess.file_exists(BattleGame.SAVE_PATH + ".bak"), "Retry keeps the prior valid recovery copy")
	saved.latest = restored.economy.resources()
	remember(saved)
	finish()
