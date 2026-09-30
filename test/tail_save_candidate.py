"""Install the unaccepted save candidate only in a test/work project copy."""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def install(game):
    game = game.resolve()
    assert game.is_relative_to((ROOT / "test/work").resolve())
    path = game / "scripts/game.gd"
    source = path.read_text(encoding="utf-8")
    assert "ordinary_save_async_enabled" not in source
    source = source.replace('var save_dirty := false', '''var save_dirty_generation := 0
var saved_dirty_generation := 0
var save_dirty := false:
	set(value):
		if value:save_dirty_generation += 1
		save_dirty = value''')
    source = source.replace("var frame_save_requested := false", 'var frame_save_requested := false\nvar frame_save_requires_sync := false\nvar ordinary_save_request := false\nvar ordinary_save_async_enabled := false\nvar progress_writer := preload("res://scripts/progress_writer.gd").new()')
    source = source.replace('if not FileAccess.file_exists(SAVE_PATH):\n\t\treturn\n\tvar raw = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))', 'var raw = progress_writer.read_progress(SAVE_PATH)')
    source = source.replace('func begin_frame_save_batch() -> void:\n', 'func begin_frame_save_batch() -> void:\n\tvar result: Dictionary = progress_writer.poll()\n\tif not result.is_empty():_accept_save_result(result)\n\tframe_save_requires_sync = false\n')
    source = source.replace('func end_frame_save_batch() -> void:\n\tframe_save_batch_active = false', 'func end_frame_save_batch() -> void:\n\tframe_save_batch_active = false\n\tvar synchronous := frame_save_requires_sync\n\tframe_save_requires_sync = false')
    source = source.replace('frame_save_requested = true\n\t\treturn', 'frame_save_requested = true\n\t\tif not ordinary_save_request:frame_save_requires_sync = true\n\t\treturn', 1)
    source = source.replace('frame_save_requested = false\n\t\tsave_progress()', '''frame_save_requested = false
        if ordinary_save_async_enabled and save_enabled and not synchronous:
            save_dirty = true
            saved_dirty_generation = save_dirty_generation
            var error: Error = progress_writer.enqueue(JSON.stringify(_build_save_data(), "\\t").to_utf8_buffer())
            if error != OK:event.emit("save_error", {})
        else:save_progress()'''.replace('    ', '\t'))
    source = source.replace('\tprofile.hightechOrder = hightech_slots()\n\tprofile.hightechSavedAt', '''	saved_dirty_generation = save_dirty_generation
	_accept_save_result(progress_writer.immediate(JSON.stringify(_build_save_data(), "\\t").to_utf8_buffer()))
	if not save_dirty and frame_save_batch_active:
		frame_save_requested = false
		frame_save_requires_sync = false

func request_ordinary_progress_save() -> void:
	# Explicit allowlist callers only. All other requests retain synchronous
	# frame-end commit; transactions and calls outside the frame stay immediate.
	var previous := ordinary_save_request
	ordinary_save_request = true
	save_progress()
	ordinary_save_request = previous

func _accept_save_result(result: Dictionary) -> void:
	if result.error != OK:
		save_dirty = true
		event.emit("save_error", {})
	elif result.revision == progress_writer.revision and saved_dirty_generation == save_dirty_generation:
		save_dirty = false

func finish_pending_saves() -> void:
	var result: Dictionary = progress_writer.finish()
	if not result.is_empty():_accept_save_result(result)

func _build_save_data() -> Dictionary:
	profile.hightechOrder = hightech_slots()
	profile.hightechSavedAt''')
    source = source.replace('''	var file := FileAccess.open(SAVE_PATH + ".tmp", FileAccess.WRITE)
	if file == null:
		event.emit("save_error", {})
		return
''', '')
    source = source.replace('''	file.store_string(JSON.stringify(saved, "\\t"))
	file.close()
	var err := DirAccess.rename_absolute(SAVE_PATH + ".tmp", SAVE_PATH)
	if err != OK:
		event.emit("save_error", {})
	else:
		save_dirty = false
		if frame_save_batch_active:frame_save_requested = false''', '\treturn saved')
    path.write_text(source, encoding="utf-8")
    # Ordinary resource receipts, gem pickups and the five-second checkpoint.
    # Level/death/warp/reforge, purchases, assignments and unknown callers use
    # the default synchronous path. A planet building status transition does too.
    source = path.read_text(encoding="utf-8")
    source = source.replace('hightech_save_elapsed = 0\n\t\tsave_progress()', 'hightech_save_elapsed = 0\n\t\trequest_ordinary_progress_save()', 1)
    start=source.index('func collect(')
    end=source.index('\nfunc settle_drops',start)
    body=source[start:end].replace('jewels_changed()', 'jewels_changed("", [], true)').replace('save_progress()', 'request_ordinary_progress_save()')
    source=source[:start]+body+source[end:]
    source=source.replace('func jewels_changed(slot := "", slots: Array = []) -> void:', 'func jewels_changed(slot := "", slots: Array = [], ordinary_progress := false) -> void:')
    start=source.index('func jewels_changed(')
    body=source[start:].replace('\tsave_progress()', '\tif ordinary_progress:request_ordinary_progress_save()\n\telse:save_progress()', 1)
    source=source[:start]+body
    start=source.index('func advance_planets(')
    end=source.index('\nfunc assign_crew',start)
    body=source[start:end].replace('\t\tplanet_buildings.complete(self,str(id))', '\t\tvar prior_building_status := _planet_building_statuses(progress)\n\t\tplanet_buildings.complete(self,str(id))')
    body=body.replace('\t\tsave_progress()', '\t\tif prior_building_status == _planet_building_statuses(progress):request_ordinary_progress_save()\n\t\telse:save_progress()')
    source=source[:start]+body+source[end:]
    source+='''
func _planet_building_statuses(progress: Dictionary) -> Array:
	var statuses: Array = []
	for key in progress.get("buildings", {}):statuses.append([key,progress.buildings[key].get("status", "")])
	return statuses
'''
    path.write_text(source,encoding="utf-8")
    path = game / "scripts/main.gd"
    source = path.read_text(encoding="utf-8")
    source = source.replace('\tgame = BattleGame.new(db, not automation_args.has("--capture"))', '\tgame = BattleGame.new(db, not automation_args.has("--capture"))\n\tgame.ordinary_save_async_enabled = true\n\tget_tree().auto_accept_quit = false')
    source = source.replace('func _notification(what: int) -> void:\n\tif game == null:\n\t\treturn', 'func _notification(what: int) -> void:\n\tif game == null:\n\t\tif what == NOTIFICATION_WM_CLOSE_REQUEST:_quit_after_save()\n\t\treturn')
    source = source.replace('elif what == NOTIFICATION_WM_CLOSE_REQUEST:\n\t\tgame.settle_drops()\n\t\tgame.save_progress()', 'elif what == NOTIFICATION_WM_CLOSE_REQUEST:\n\t\tif not game.save_enabled:\n\t\t\t_quit_after_save()\n\t\t\treturn\n\t\tgame.settle_drops()\n\t\tgame.save_progress()\n\t\tif not game.save_dirty:_quit_after_save()')
    source += '''
func _exit_tree() -> void:
	if game == null:return
	if game.save_enabled:game.finish_pending_saves()
	else:game.progress_writer.cancel_and_join()

func _quit_after_save() -> void:
	get_tree().quit()
'''
    path.write_text(source, encoding="utf-8")
    path = game / "scripts/config_panel.gd"
    source = path.read_text(encoding="utf-8")
    old = '''		if FileAccess.file_exists(BattleGame.SAVE_PATH):
			var error := DirAccess.remove_absolute(ProjectSettings.globalize_path(BattleGame.SAVE_PATH))
			if error != OK:
				status_label.text = UIText.t("debug.restart_game.text_01") + error_string(error)
				return'''
    new = '''		var error: Error = scene.game.progress_writer.clear_files()
		if error != OK:
			status_label.text = UIText.t("debug.restart_game.text_01") + error_string(error)
			return'''
    assert old in source
    source = source.replace(old, new)
    path.write_text(source, encoding="utf-8")
