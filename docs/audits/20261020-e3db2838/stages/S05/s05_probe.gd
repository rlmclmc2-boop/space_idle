extends SceneTree

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1 or args[0] not in ["new", "reopen"]:
		push_error("Expected new or reopen")
		quit(2)
		return
	var db := ShipDatabase.new()
	if not db.data.get("ai_tech_tree") is Dictionary or db.data.ai_tech_tree.is_empty() or not db.data.get("equipment_evolution") is Dictionary or db.data.equipment_evolution.is_empty():
		push_error("Database required configuration missing")
		quit(3)
		return
	var rewards := preload("res://scripts/hyperspace_reward_binding.gd").new()
	if not rewards.load_contract():
		push_error("Reward contract missing: " + rewards.last_error)
		quit(4)
		return
	var save_path := ProjectSettings.globalize_path("user://progress.json")
	if args[0] == "new" and FileAccess.file_exists(save_path):
		push_error("Expected fresh isolated user directory")
		quit(5)
		return
	var game := BattleGame.new(db, true)
	if not game.startup_error.is_empty() or not game.save_enabled:
		push_error("Player initialization failed: " + game.startup_error)
		quit(6)
		return
	if args[0] == "new":
		game.profile.resources["1"] = 4321
		game.save_progress()
		if game.last_save_error != OK or not FileAccess.file_exists(save_path):
			push_error("Real save_progress failed")
			quit(7)
			return
		print("S05_NEW_SAVE_OK data=15 resources.1=4321")
	else:
		if int(game.profile.resources.get("1", -1)) != 4321:
			push_error("Reopen lost saved resource")
			quit(8)
			return
		print("S05_REOPEN_OK resources.1=4321")
	quit(0)
