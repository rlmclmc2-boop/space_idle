extends SceneTree

const Transfer := preload("res://scripts/save_transfer.gd")
var game: BattleGame

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var db := ShipDatabase.new()
	game = BattleGame.new(db, true)
	var can_write := game.progress_writer.owns_progress()
	var initial := game.last_save_error
	game.save_progress()
	var save_error := game.last_save_error
	var transfer := Transfer.new()
	var import_error: int = -1
	var clear_error: int = -1
	var recovery_error: int = -1
	if not can_write:
		import_error = transfer.commit_import(game, game.portable_save_data()).error
		clear_error = game.progress_writer.clear_files()
		recovery_error = game.progress_writer.finish_loaded_recovery(BattleGame.SAVE_PATH, {"status":"loaded","source":".import-prev","import_active":false})
	print("S04A_GAME:", JSON.stringify({"path":game.progress_writer.path,"owns":can_write,"enabled":game.save_enabled,"initial":initial,"save":save_error,"import":import_error,"clear":clear_error,"recovery":recovery_error,"startup":game.startup_error}))
	if args.size() > 0 and args[0] == "hold":
		await create_timer(60.0).timeout
	quit(0)
