extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	print(label, ": ", "PASS" if value else "FAIL")
	if not value:
		failures += 1

func reset_profile_matches(game: BattleGame) -> bool:
	var reference := BattleGame.new(game.db,false)
	var expected := reference.profile.duplicate(true)
	# Saving and building the UI add metadata absent from fresh_profile().
	# Check its reset values explicitly; wall-clock timestamps are not progress.
	expected.hightechSavedAt = game.profile.hightechSavedAt
	expected.chronoSavedAt = float(game.profile.hightechSavedAt)
	expected.resourceSamples = []
	expected.hightechDrops = []
	expected.hightechOrder = reference.hightech_slots()
	return game.profile == expected

func run() -> void:
	change_scene_to_file("res://main.tscn")
	await scene_changed
	current_scene.show_qa_tools()
	var panel = root.get_node("QATools")
	var original_id: int = panel.get_instance_id()
	var settings_before := FileAccess.get_file_as_string("user://qa_settings.cfg")
	current_scene.game.profile.resources["1"] = 999999
	current_scene.game.first_equipment_entry("armour").level = 5
	current_scene.game.profile.cleared = [1]
	current_scene.game.profile.bossSeen = [1]
	current_scene.game.save_progress()
	panel.delete_save_button.pressed.emit()
	await scene_changed
	await process_frame
	check(reset_profile_matches(current_scene.game), "All progress resets to configured defaults")
	check(current_scene.game.stage == 1 and not current_scene.game.paused, "Restarts at first stage")
	check(root.get_node("QATools").get_instance_id() == original_id, "Same QA window survives")
	check(FileAccess.get_file_as_string("user://qa_settings.cfg") == settings_before, "QA settings preserved")
	var disk = JSON.parse_string(FileAccess.get_file_as_string(BattleGame.SAVE_PATH))
	check(disk.resources["1"] == current_scene.game.profile.resources["1"] and disk.cleared.is_empty(), "Old save not resurrected")
	current_scene.game.profile.resources["1"] = 123
	current_scene.game.save_progress()
	panel.restart_button.pressed.emit()
	await scene_changed
	await process_frame
	check(current_scene.game.profile.resources["1"] == 123, "New game still saves and ordinary restart preserves it")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(BattleGame.SAVE_PATH))
	panel.delete_save_button.pressed.emit()
	await scene_changed
	await process_frame
	check(reset_profile_matches(current_scene.game), "Reset also works without existing save")
	await RenderingServer.frame_post_draw
	panel.get_texture().get_image().save_png("res://preview-delete-save.png")
	print("DELETE SAVE: ", failures, " failures")
	quit(0 if failures == 0 else 1)
