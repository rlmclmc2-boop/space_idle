extends SceneTree

# Run against an isolated project and user directory with a visible Godot renderer.
const VIEW = preload("res://scripts/ai_tech_view_model.gd")

var checks := 0
var failures := 0
var evidence := ""

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", label)
	else:
		print("PASS ", label)

func _initialize() -> void:
	call_deferred("run")

func frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw

func capture(name: String) -> void:
	var path := evidence.path_join(name + ".png")
	var error := root.get_texture().get_image().save_png(path)
	check(error == OK, "capture " + name)

func run() -> void:
	evidence = OS.get_environment("AI_TECH_GUI_EVIDENCE")
	if evidence.is_empty():
		printerr("AI_TECH_GUI_EVIDENCE is required")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(evidence)
	DisplayServer.window_set_size(Vector2i(1720, 1280))
	var scene := load("res://main.tscn") as PackedScene
	var main = scene.instantiate()
	root.add_child(main)
	await frame()
	check(main.game != null and main.game.startup_error.is_empty(), "real game starts")
	check(is_instance_valid(main.hightech_page), "real main builds technology page")
	if main.game == null or not is_instance_valid(main.hightech_page):
		quit(1)
		return
	main.game.paused = true
	main.select_system(1)
	await frame()
	await frame()
	var page: Control = main.hightech_page
	check(main.equipment_tabs.current_tab == 1 and page.is_visible_in_tree(), "technology tab opens")
	check(page.status_text.text == str(VIEW.snapshot(main.game).status_text), "idle prompt uses game snapshot")
	page.set_drawer_open(true)
	await frame()
	capture("00-choose-research")
	page.row_nodes["weapon_accuracy"].action.pressed.emit()
	await frame()
	check(str(main.game.profile.aiTechActive) == "weapon_accuracy", "drawer action selects real research")
	page.set_drawer_open(false)
	main.game.advance_hightech(10.0)
	page.invalidate()
	await frame()
	var progress := float(main.game.profile.aiTechProgress.weapon_accuracy)
	check(progress > 0.0 and page.progress_text.text != "0%", "real progress reaches page")
	capture("01-research-progress")
	main.game.profile.resources["1"] = 100.0
	main.game.profile.resources["2"] = 0.0
	page.iron_edit.text = "10"
	page.iron_edit.text_submitted.emit("10")
	page.uranium_edit.text = "10"
	page.uranium_edit.text_submitted.emit("10")
	main.game.advance_hightech(1.0)
	page.invalidate()
	await frame()
	var shortage: Dictionary = main.game.tech_tree_snapshot()
	check(int(main.game.profile.aiTechInput["1"]) == 10 and int(main.game.profile.aiTechInput["2"]) == 10, "both page investments reach model")
	check(bool(shortage.inputs["2"].shortage) and not bool(shortage.inputs["1"].shortage), "uranium shortage leaves iron acceleration")
	check(float(main.game.profile.resources["1"]) == 90.0 and float(main.game.profile.resources["2"]) == 0.0, "only affordable investment is paid")
	capture("02-uranium-shortage")
	main.game.profile.resources["2"] = 100.0
	main.game.advance_hightech(1.0)
	page.invalidate()
	await frame()
	var recovered: Dictionary = main.game.tech_tree_snapshot()
	check(not bool(recovered.inputs["2"].shortage) and float(main.game.profile.resources["2"]) == 90.0, "uranium investment resumes after recovery")
	capture("03-investment-recovered")
	var before_tab := float(main.game.profile.aiTechProgress.weapon_accuracy)
	main.select_system(0)
	await frame()
	main.select_system(1)
	await frame()
	check(page.is_visible_in_tree() and absf(float(main.game.profile.aiTechProgress.weapon_accuracy) - before_tab) < 0.01, "returning to tab retains real research")
	check(page.progress_text.text != "0%", "returning to tab refreshes progress")
	capture("04-tab-return")
	var saved_progress := float(main.game.profile.aiTechProgress.weapon_accuracy)
	main.game.save_progress()
	check(main.game.last_save_error == OK and FileAccess.file_exists("user://progress.json"), "manual save writes isolated progress")
	main.queue_free()
	await process_frame
	var restored = scene.instantiate()
	root.add_child(restored)
	restored.game.paused = true
	await frame()
	for dialog in root.find_children("*", "AcceptDialog", true, false):
		if dialog.visible: dialog.hide()
	check(restored.game.startup_error.is_empty() and str(restored.game.profile.aiTechActive) == "weapon_accuracy", "real game reload restores selection")
	check(int(restored.game.profile.aiTechInput["1"]) == 10 and int(restored.game.profile.aiTechInput["2"]) == 10, "real game reload restores investments")
	check(absf(float(restored.game.profile.aiTechProgress.weapon_accuracy) - saved_progress) < 0.01, "real game reload restores progress without offline research")
	restored.select_system(1)
	await frame()
	check(restored.hightech_page.progress_text.text != "0%", "reloaded page shows saved progress")
	capture("05-save-reload")
	print("AI_TECH_GUI_CHECKS=", checks, " FAILURES=", failures)
	quit(1 if failures else 0)
