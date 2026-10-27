extends SceneTree
const SaveFiles = preload("res://foundation/host/save_files.gd")
const PlayerSettings = preload("res://foundation/host/player_settings.gd")
const Main = preload("res://src/main.tscn")

func _initialize() -> void:
	var loaded = GDExtensionManager.load_extension(OS.get_environment("SPACE_IDLE_NATIVE_EXTENSION"))
	if loaded not in [GDExtensionManager.LOAD_STATUS_OK, GDExtensionManager.LOAD_STATUS_ALREADY_LOADED]:
		quit(1)
		return
	call_deferred("_run")

func _fail(reason: String) -> void:
	printerr(reason)
	quit(1)

func _run() -> void:
	var directory: String = OS.get_environment("SPACE_IDLE_SAVE_TEST_DIR")
	if directory.is_empty():
		_fail("missing disposable directory")
		return
	DirAccess.make_dir_recursive_absolute(directory)
	OS.set_environment("SPACE_IDLE_SETTINGS_PATH", directory.path_join("settings.json"))
	var main = Main.instantiate()
	root.add_child(main)
	main.set_process(false)
	if not main.startup_error.is_empty() or main.session.save_files == null or main._autosave_interval != 60.0:
		_fail("fresh startup has no save protection: " + main.startup_error)
		return
	var store: String = main.session.save_files._directory
	if store != directory.path_join("saves") or not main.session.save_files.close(2000).ok or not SaveFiles.read_pointer(store, "active.json").ok:
		_fail("initial snapshot did not reach actual file")
		return
	for key in main._feature_panels:
		if main._feature_panels[key].visible:
			_fail("locked feature visible on fresh profile: " + key)
			return
	if "unlock:" in main._guidance_label.text or "equipment:" in main._guidance_label.text or "复合装甲" not in main._guidance_label.text:
		_fail("guidance exposed internal IDs: " + main._guidance_label.text)
		return
	if "departing" in main.session.campaign_system.status_text():
		_fail("campaign state not localized")
		return
	var amount = main.session.amount_api.apply("from_decimal", ["12"]).value
	main.session.economy.credit_yield("1", amount, 0.0, 0.0, false)
	main.session.economy.credit_yield("chrono", amount, 0.0, 0.0, false)
	if "铁：" not in main.session.economy.balances_text() or "时空微粒：" not in main.session.economy.balances_text() or "chrono:" in main.session.economy.balances_text():
		_fail("wallet exposed resource IDs")
		return
	print("STARTUP_INITIAL_FILE_NAMES_LOCKED_PANELS_OK")
	# Exercise actual progress publication, not a separate UI unlock predicate.
	main.session.campaign_system._grants["hightech:超时空炼铁炉"] = true
	var progress: Dictionary = main.session._publish_progress()
	if not progress.ok:
		_fail("progress fixture rejected")
		return
	main.session._notify_progress(progress.notices)
	main.session.campaign_system.publish_progress_change()
	main._process(0.0)
	main.growth_panel.visible = true
	main._tabs.current_tab = main._pages.growth.index
	var panel = main._feature_panels.research
	if not panel.visible or main._feature_panels.enhancement.visible or main._feature_panels.hyperspace.visible:
		_fail("feature visibility did not follow real progress")
		return
	await process_frame
	await process_frame
	# Check container geometry at the actual 572x960 game viewport.
	if main.growth_panel.size.x > 548.1 or panel.size.x > main.growth_panel.size.x:
		_fail("growth/research horizontal overflow: " + str(main.growth_panel.size) + " / " + str(panel.size))
		return
	for child in panel.get_children():
		if child is Label and child.text.contains("AI 工厂岗位"):
			if child.autowrap_mode == TextServer.AUTOWRAP_OFF or child.size.x > panel.size.x or child.get_line_count() < 2:
				_fail("research help does not wrap within viewport")
				return
	main.session.research.set_automatic(true, 0.25)
	main.session.research.set_investment_text("1", "123")
	# Paused game still autosaves on wall time, and no game time is advanced.
	main.session.set_pause("user", true)
	var game_before: float = main.session.game_time
	main._next_autosave_wall = main.session.wall_time
	main._process(0.0)
	if not main.session.save_files.close(2000).ok or main.session.game_time != game_before:
		_fail("paused wall-clock autosave failed")
		return
	var saved_id: String = main.session._session_id
	print("STARTUP_PROGRESS_WRAP_PAUSED_AUTOSAVE_OK size=", main.growth_panel.size, " research=", panel.size)
	main.queue_free()
	await process_frame
	var resumed = Main.instantiate()
	root.add_child(resumed)
	resumed.set_process(false)
	if not resumed.startup_error.is_empty() or resumed.session._session_id != saved_id or not resumed.session.research.save_state().auto_invest or resumed.session.research.save_state().ratio != 0.25:
		_fail("normal startup did not resume saved session")
		return
	resumed.growth_panel.visible = true
	if not resumed._feature_panels.research.visible or resumed._feature_panels.enhancement.visible:
		_fail("restored feature visibility incorrect")
		return
	resumed.session.save_files.close(2000)
	resumed.queue_free()
	await process_frame
	var primary_path: String = store.path_join("active.json")
	var damaged: FileAccess = FileAccess.open(primary_path, FileAccess.WRITE)
	damaged.store_string("broken pointer")
	damaged.close()
	var protected = Main.instantiate()
	root.add_child(protected)
	protected.set_process(false)
	protected._process(0.0)
	if protected.session.save_files != null or not protected.session.pause_reasons.has("recovery") or protected._startup_save_error.is_empty() or FileAccess.get_file_as_string(primary_path) != "broken pointer" or protected._configure_save(store).ok:
		_fail("damaged primary was silently overwritten or not blocked")
		return
	var recovered: Dictionary = protected._load_saved(store, true)
	if not recovered.ok or not protected.session.save_files.close(2000).ok:
		_fail("explicit backup recovery failed")
		return
	# Preserve an explicit zero interval instead of silently re-enabling it.
	PlayerSettings.save_interval(0)
	protected.queue_free()
	await process_frame
	var disabled = Main.instantiate()
	root.add_child(disabled)
	disabled.set_process(false)
	if disabled._autosave_interval != 0.0 or disabled.session.save_files == null:
		_fail("explicit autosave preference was not preserved")
		return
	disabled.session.save_files.close(2000)
	print("STARTUP_RESUME_CORRUPTION_RECOVERY_EXPLICIT_OFF_OK")
	# An ended DataWrite failure must not prevent explicit migration to a
	# writable store; reproduce with an actual destination directory collision.
	var failed_store: String = directory.path_join("failed-store")
	DirAccess.make_dir_recursive_absolute(failed_store.path_join("slot-0.json"))
	if not disabled.session.configure_save_directory(failed_store).ok or not disabled.session.request_save().ok:
		_fail("could not start real failed-writer fixture")
		return
	var failed: Dictionary = disabled.session.save_files.close(2000)
	if failed.get("ok", true) or failed.get("error") != "DataWrite" or disabled.session.save_files.busy():
		_fail("expected ended DataWrite failure: " + str(failed))
		return
	var migrated_store: String = directory.path_join("migrated-store")
	DirAccess.make_dir_recursive_absolute(migrated_store)
	if not disabled._configure_save(migrated_store).ok or disabled.session.save_files._directory != migrated_store or not disabled.session.request_save().ok or not disabled.session.save_files.close(2000).ok or not SaveFiles.read_pointer(migrated_store, "active.json").ok:
		_fail("explicit directory migration was blocked by historical write failure")
		return
	print("REAL_DATA_WRITE_FAILURE_DIRECTORY_MIGRATION_OK")
	disabled.queue_free()
	await process_frame
	# Both corrupt pointers and slot bytes must survive an explicit new game.
	var original: Dictionary = {}
	for filename in ["active.json", "previous.json", "slot-0.json", "slot-1.json"]:
		var corrupt: FileAccess = FileAccess.open(store.path_join(filename), FileAccess.WRITE)
		original[filename] = "recoverable original bytes " + filename
		corrupt.store_string(original[filename])
		corrupt.close()
	PlayerSettings.save_change("save_directory", store)
	var recovery = Main.instantiate()
	root.add_child(recovery)
	recovery.set_process(false)
	var active_before = recovery.session
	var preview: Dictionary = recovery._preview_new_game(store, true)
	if not preview.ok or recovery.session != active_before or not preview.message.contains("原样保留"):
		_fail("corrupt-store new-game preview failed: " + str(preview))
		return
	var target: String = recovery._pending_new_game.target_directory
	# Fail the real first candidate write; it must not replace the live game.
	DirAccess.make_dir_recursive_absolute(target.path_join("slot-0.json"))
	var denied: Dictionary = recovery._confirm_new_game(store, true)
	if denied.get("ok", true) or denied.get("error") != "DataWrite" or recovery.session != active_before:
		_fail("failed candidate write replaced current game: " + str(denied))
		return
	if DirAccess.remove_absolute(target.path_join("slot-0.json")) != OK:
		_fail("could not clear disposable write-collision fixture")
		return
	var confirmed: Dictionary = recovery._confirm_new_game(store, true)
	if not confirmed.ok or recovery.session == active_before or recovery.session.save_files._directory != target or not recovery.session.save_files.close(2000).ok:
		_fail("confirmed corrupt-store new game failed: " + str(confirmed))
		return
	var published: Dictionary = SaveFiles.read_pointer(target, "active.json")
	if not published.ok or published.envelope.sessionId != recovery.session._session_id or PlayerSettings.load_interval().save_directory != target:
		_fail("new game was not on disk in the configured recovery store")
		return
	for filename in original:
		if FileAccess.get_file_as_string(store.path_join(filename)) != original[filename]:
			_fail("new game modified original corrupt file: " + filename)
			return
	var recovered_id: String = recovery.session._session_id
	recovery.queue_free()
	await process_frame
	var restarted = Main.instantiate()
	root.add_child(restarted)
	restarted.set_process(false)
	if not restarted.startup_error.is_empty() or restarted.session._session_id != recovered_id or restarted.session.save_files._directory != target:
		_fail("normal startup did not resume confirmed new game")
		return
	restarted.session.save_files.close(2000)
	restarted.queue_free()
	await process_frame
	print("CORRUPT_STORE_NEW_GAME_PUBLISHED_ORIGINALS_PRESERVED_RESTART_OK")
	print("STAGE6_STARTUP_PROBE_OK")
	quit(0)
