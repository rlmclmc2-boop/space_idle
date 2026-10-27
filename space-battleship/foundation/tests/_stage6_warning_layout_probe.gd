extends SceneTree
const Main = preload("res://src/main.tscn")
const Hud = preload("res://src/ui/battle_hud.gd")
var main
func _initialize() -> void:
	call_deferred("_run")
func _check(condition: bool, reason: String) -> bool:
	if condition: return true
	printerr("WARNING_LAYOUT_FAILED " + reason)
	quit(1)
	return false
func _warning(label: String) -> bool:
	var warning: Label = main._save_warning
	var rect: Rect2 = warning.get_global_rect()
	var font: Font = warning.get_theme_font("font")
	var open: Button = main.growth_panel.get_parent().get_child(0)
	if not _check(warning.visible and rect.position.y >= 50 and rect.end.y < 80, label + " outside top warning strip " + str(rect)): return false
	for region in [Hud.DEFENCE_RECT, Hud.RESOURCES_RECT, Hud.STATISTICS_RECT, main._pause_button.get_global_rect(), open.get_global_rect()]:
		if not _check(not rect.intersects(region), label + " overlaps HUD/control " + str(region)): return false
	if not _check(font.get_height(14) <= rect.size.y and warning.clip_text and warning.max_lines_visible == 1, label + " unconstrained text height"): return false
	return true
func _run() -> void:
	var directory: String = OS.get_environment("SPACE_IDLE_SAVE_TEST_DIR")
	if not _check(not directory.is_empty(), "disposable directory required"): return
	DirAccess.make_dir_recursive_absolute(directory)
	OS.set_environment("SPACE_IDLE_SETTINGS_PATH", directory.path_join("settings.json"))
	main = Main.instantiate()
	root.add_child(main)
	main.set_process(false)
	if not _check(main.startup_error.is_empty(), "main startup " + main.startup_error): return
	main._refresh_save_warning()
	for frame in 2: await process_frame
	if not _check(not main._save_warning.visible, "normal state shows warning"): return
	# Presentation-only failure metadata; writer behavior is covered separately.
	main.session.save_files.last_failure = {"ok": false, "error": "DataWrite", "generation": "layout-only"}
	main._refresh_save_warning()
	for frame in 2: await process_frame
	if not _warning("save error") or not _check("保存失败" in main._save_warning.text, "save error hidden"): return
	main.session.save_files.last_failure = {}
	main.session.run_state.fail("WarningLayoutFixture")
	main._refresh_save_warning()
	for frame in 2: await process_frame
	if not _warning("stopped") or not _check("会话已停止" in main._save_warning.text, "stopped message hidden"): return
	main.session.save_files.last_failure = {"ok": false, "error": "DataWrite", "generation": "layout-only"}
	main._refresh_save_warning()
	for frame in 2: await process_frame
	if not _warning("stopped and save error") or not _check("保存未完成" in main._save_warning.text, "combined warning lost save status"): return
	print("STAGE6_NORMAL_STOPPED_SAVE_ERROR_WARNING_REGIONS_DISJOINT_OK rect=", main._save_warning.get_global_rect())
	main._stop_audio()
	main.session.save_files.close(2000)
	main.queue_free()
	for frame in 2: await process_frame
	main = null
	# Allow the backend to retire this short-lived layout fixture playback.
	await create_timer(0.05).timeout
	quit(0)
