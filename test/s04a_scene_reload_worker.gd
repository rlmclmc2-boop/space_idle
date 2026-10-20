extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var opened := change_scene_to_file("res://main.tscn")
	if opened != OK:
		print("S04A_RELOAD:", JSON.stringify({"passed":false,"open_error":opened}))
		quit(1)
		return
	for step in range(10):
		await process_frame
		if current_scene != null:break
	var old_scene = current_scene
	if old_scene == null or old_scene.game == null:
		print("S04A_RELOAD:", JSON.stringify({"passed":false,"initial_scene":false}))
		quit(1)
		return
	var old_game = old_scene.game
	var initial_owner: bool = old_game.progress_writer.owns_progress()
	old_game.save_progress()
	var initial_save: int = old_game.last_save_error
	var import_data: Dictionary = old_game.portable_save_data()
	import_data.resources["1"] = 4321.0
	if old_scene.save_import_confirmation == null:
		old_scene.save_import_confirmation = ConfirmationDialog.new()
		old_scene.add_child(old_scene.save_import_confirmation)
	old_scene.pending_import = import_data
	var old_scene_id: int = old_scene.get_instance_id()
	old_scene.confirm_save_import()
	old_game = null
	old_scene = null
	import_data.clear()
	for step in range(15):
		await process_frame
		if current_scene != null and current_scene.get_instance_id() != old_scene_id:break
	var new_scene = current_scene
	var reloaded: bool = new_scene != null and new_scene.get_instance_id() != old_scene_id
	var new_game = new_scene.game if reloaded else null
	var acquired: bool = new_game != null and new_game.progress_writer.owns_progress()
	var imported: bool = new_game != null and GrowthNumber.compare(new_game.profile.resources["1"],4321.0) == 0
	var save_error: int = -1
	var disk_value_correct := false
	if new_game != null:
		new_game.save_progress()
		save_error = new_game.last_save_error
		var disk = JSON.parse_string(FileAccess.get_file_as_string(BattleGame.SAVE_PATH))
		disk_value_correct = disk is Dictionary and GrowthNumber.compare(disk.get("resources",{}).get("1",0),4321.0) == 0
	var passed: bool = initial_owner and initial_save == OK and reloaded and acquired and imported and save_error == OK and disk_value_correct
	print("S04A_RELOAD:", JSON.stringify({"passed":passed,"initial_owner":initial_owner,"initial_save":initial_save,"reloaded":reloaded,"new_owner":acquired,"imported":imported,"new_save":save_error,"disk_value_correct":disk_value_correct}))
	quit(0 if passed else 1)
