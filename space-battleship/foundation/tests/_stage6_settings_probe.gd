extends SceneTree

const PlayerSettings = preload("res://foundation/host/player_settings.gd")

func _initialize() -> void:
	var loaded = GDExtensionManager.load_extension(OS.get_environment("SPACE_IDLE_NATIVE_EXTENSION"))
	if loaded != GDExtensionManager.LOAD_STATUS_OK and loaded != GDExtensionManager.LOAD_STATUS_ALREADY_LOADED:
		printerr("native extension unavailable")
		quit(1)
		return
	call_deferred("_run")

func _find_button(node: Node, label: String) -> Button:
	if node is Button and node.text == label: return node
	for child in node.get_children():
		var found := _find_button(child, label)
		if found != null: return found
	return null

func _find_line(node: Node, placeholder: String) -> LineEdit:
	if node is LineEdit and node.placeholder_text == placeholder: return node
	for child in node.get_children():
		var found := _find_line(child, placeholder)
		if found != null: return found
	return null

func _fail(reason: String) -> void:
	printerr(reason)
	quit(1)

func _run() -> void:
	var directory: String = OS.get_environment("SPACE_IDLE_SAVE_TEST_DIR")
	if directory.is_empty():
		_fail("missing test directory")
		return
	DirAccess.make_dir_recursive_absolute(directory)
	OS.set_environment("SPACE_IDLE_SETTINGS_PATH", directory.path_join("player-settings.json"))
	for bad in [
		{"formatVersion": 1, "autosaveInterval": 1, "damageMode": "unknown"},
		{"formatVersion": 1, "autosaveInterval": 1, "preferredPage": "unknown"},
		{"formatVersion": 1, "autosaveInterval": 1, "musicEnabled": 1},
		{"formatVersion": 1, "autosaveInterval": 1, "effectsEnabled": "false"}
	]:
		var stream: FileAccess = FileAccess.open(PlayerSettings._path(), FileAccess.WRITE)
		stream.store_string(JSON.stringify(bad))
		stream.close()
		if PlayerSettings.load_interval().ok:
			_fail("invalid setting accepted: " + str(bad))
			return
	var saved: Dictionary = PlayerSettings.reset()
	if not saved.ok:
		_fail("settings reset failed: " + str(saved))
		return
	var main = load("res://src/main.tscn").instantiate()
	root.add_child(main)
	if not main.startup_error.is_empty() or main._music_player == null or main._effects_player == null:
		_fail("settings consumers missing: " + main.startup_error)
		return
	var music: Button = _find_button(main, "音乐")
	var effects: Button = _find_button(main, "音效")
	var save_path: LineEdit = _find_line(main, "存档目录（完整路径）")
	if music == null or effects == null or save_path == null or main._damage_option == null:
		_fail("settings UI missing")
		return
	music.button_pressed = false
	effects.button_pressed = false
	main._damage_option.select(2)
	main._damage_option.item_selected.emit(2)
	main._set_page("growth")
	var state: Dictionary = PlayerSettings.load_interval()
	if state.music_enabled or state.effects_enabled or state.damage_mode != "off" or state.page != "growth" or not main._music_player.stream_paused or not main.growth_panel.visible:
		_fail("settings did not reach live consumers: " + str(state))
		return
	var settings_path: String = PlayerSettings._path()
	var blocker_path: String = directory.path_join("settings-path-blocker")
	var blocker: FileAccess = FileAccess.open(blocker_path, FileAccess.WRITE)
	blocker.store_string("file, not directory")
	blocker.close()
	OS.set_environment("SPACE_IDLE_SETTINGS_PATH", blocker_path.path_join("settings.json"))
	music.button_pressed = true
	if not main._music_player.stream_paused or main._music_enabled or music.button_pressed or main.growth_status.text != "个人设置未能写入文件，请检查目录权限。":
		_fail("failed settings publication changed the live control")
		return
	OS.set_environment("SPACE_IDLE_SETTINGS_PATH", settings_path)
	var first_dir: String = directory.path_join("keep")
	DirAccess.make_dir_recursive_absolute(first_dir)
	save_path.text = first_dir
	var before = main.session
	_find_button(main, "预览新游戏").pressed.emit()
	if main._pending_new_game.is_empty() or main.session != before:
		_fail("new game preview changed active session")
		return
	_find_button(main, "确认新游戏").pressed.emit()
	if main.session == before or PlayerSettings.load_interval().damage_mode != "off":
		_fail("new game did not preserve settings")
		return
	await process_frame
	var second_dir: String = directory.path_join("clear")
	DirAccess.make_dir_recursive_absolute(second_dir)
	save_path = _find_line(main, "存档目录（完整路径）")
	save_path.text = second_dir
	var clear: Button = _find_button(main, "新游戏同时重置个人设置")
	clear.button_pressed = true
	before = main.session
	_find_button(main, "预览新游戏").pressed.emit()
	if main._pending_new_game.is_empty() or main.session != before:
		_fail("clear preview changed active session")
		return
	_find_button(main, "确认新游戏").pressed.emit()
	state = PlayerSettings.load_interval()
	if main.session == before or not state.music_enabled or not state.effects_enabled or state.damage_mode != "all" or state.page != "battle" or main._music_player.stream_paused or main.growth_panel.visible:
		_fail("explicit clear did not restore defaults: " + str(state))
		return
	var closed: Dictionary = main.session.save_files.close(2000)
	if not closed.ok:
		_fail("new game save failed: " + str(closed))
		return
	print("STAGE6_SETTINGS_PROBE_OK")
	quit()
