extends SceneTree

# Run only with APPDATA/LOCALAPPDATA redirected to the launcher verification
# directory. Never point this probe at a player's ordinary user directory.
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1 or not args[0] in ["seed", "check"]:
		push_error("Expected -- seed or -- check")
		quit(2)
		return
	var path := ProjectSettings.globalize_path("user://progress.json")
	print("ISOLATED_PROGRESS_PATH=", path)
	var db := ShipDatabase.new()
	if args[0] == "seed":
		if FileAccess.file_exists(path):
			push_error("Refusing to replace an existing progress file")
			quit(3)
			return
		var game := BattleGame.new(db, false)
		game.profile.resources["1"] = 4321
		var data := game.portable_save_data()
		var transfer := preload("res://scripts/save_transfer.gd").new()
		var prepared: Dictionary = transfer.prepare_data(data, db)
		if not str(prepared.get("error", "")).is_empty() or str(prepared.get("quality", "")) != "complete":
			push_error("Synthetic save did not satisfy the complete current-writer contract")
			quit(4)
			return
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			push_error("Could not create isolated progress file")
			quit(5)
			return
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
		print("ISOLATED_SEED_COMPLETE resources.1=4321")
	else:
		if not FileAccess.file_exists(path):
			push_error("Isolated progress file is missing")
			quit(6)
			return
		var game := BattleGame.new(db, true)
		if not game.startup_error.is_empty() or not game.save_enabled or int(game.profile.resources.get("1", -1)) != 4321:
			push_error("Isolated full save did not load unchanged")
			quit(7)
			return
		print("ISOLATED_LOAD_OK resources.1=4321 startup_error=empty save_enabled=true")
	quit(0)
