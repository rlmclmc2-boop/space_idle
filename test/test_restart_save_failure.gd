extends SceneTree

var failures := 0

func check(ok: bool, label: String) -> void:
	print(label, ": ", "PASS" if ok else "FAIL")
	if not ok:
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	change_scene_to_file("res://main.tscn")
	await scene_changed
	current_scene.show_qa_tools()
	var panel = root.get_node("QATools")
	current_scene.game.paused = true
	current_scene.game.save_progress()
	var saved := FileAccess.get_file_as_string(BattleGame.SAVE_PATH)
	var scene_id := current_scene.get_instance_id()
	current_scene.game.profile.resources["1"] = 4321
	for obstruction in [BattleGame.SAVE_PATH + ".tmp", BattleGame.SAVE_PATH]:
		if obstruction == BattleGame.SAVE_PATH:
			DirAccess.remove_absolute(obstruction)
		DirAccess.make_dir_absolute(obstruction)
		panel.restart_button.pressed.emit()
		check(not panel.restarting, "Save failure cancels reload: " + obstruction)
		# Let deferred scene reload run, if incorrectly scheduled.
		await process_frame
		await process_frame
		check(current_scene.get_instance_id() == scene_id, "Failure preserves current scene")
		check(current_scene.game.profile.resources["1"] == 4321, "Failure preserves unsaved progress")
		check(current_scene.is_processing() and current_scene.game.save_enabled, "Failure keeps game and saving enabled")
		check(not panel.restart_button.disabled and panel.status_label.text.contains("保存进度失败"), "Failure is visible and retry remains available")
		if obstruction.ends_with(".tmp"):
			check(FileAccess.get_file_as_string(BattleGame.SAVE_PATH) == saved, "Open failure preserves saved bytes")
			if DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				panel.get_texture().get_image().save_png("res://.runtime/restart-save-failure.png")
		DirAccess.remove_absolute(obstruction)
	panel.restart_button.pressed.emit()
	var deadline := Time.get_ticks_msec() + 10000
	while panel.restarting and Time.get_ticks_msec() < deadline:
		await process_frame
	check(not panel.restarting and current_scene.get_instance_id() != scene_id, "Retry reloads scene")
	check(current_scene.game.profile.resources["1"] == 4321, "Retry persists latest progress")
	print("Restart save failure: ", failures, " failures")
	quit(1 if failures else 0)
