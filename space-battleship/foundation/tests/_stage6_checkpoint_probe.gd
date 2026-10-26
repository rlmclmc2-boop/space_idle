extends SceneTree

const Session = preload("res://src/game_session.gd")
const SaveFiles = preload("res://foundation/host/save_files.gd")

func _initialize() -> void:
	var loaded = GDExtensionManager.load_extension(OS.get_environment("SPACE_IDLE_NATIVE_EXTENSION"))
	if loaded != GDExtensionManager.LOAD_STATUS_OK and loaded != GDExtensionManager.LOAD_STATUS_ALREADY_LOADED:
		printerr("extension: ", loaded)
		quit(1)
		return
	call_deferred("_run")

func _full_defence(session) -> bool:
	var player: Dictionary = session.battle._kernel.player_view()
	return str(player.armour) == str(player.max_armour) and str(player.shield) == str(player.max_shield)

func _run() -> void:
	var directory: String = OS.get_environment("SPACE_IDLE_SAVE_TEST_DIR")
	if directory.is_empty():
		printerr("missing disposable directory")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(directory)
	var session = Session.new()
	var ready: Dictionary = session.initialize("res://generated/config.json", 140)
	if ready.ok: ready = session.campaign_system.accept_reforge(session.campaign_system.save_state(), 8)
	if ready.ok: ready = session.campaign_system.start_sortie(8, session.equipment.clear_switch_locks)
	if not ready.ok:
		printerr("combat fixture: ", ready)
		quit(1)
		return
	session._start_wave()
	if not session.run_state.is_running() or session.campaign_system.restore_checkpoint() != "combat":
		printerr("combat wave failed")
		quit(1)
		return
	var damaged: bool = false
	var in_flight: bool = false
	for step in 1200:
		if not session._advance_kernel(0.05): break
		if session.campaign_system.restore_checkpoint() == "combat" and not _full_defence(session):
			damaged = true
		if damaged and session.campaign_system.restore_checkpoint() == "combat" and int(session.battle._kernel.active_flight_count()) > 0:
			in_flight = true
			break
	if not damaged or not in_flight:
		printerr("combat never reached a damaged live flight checkpoint: ", session.campaign_system.restore_checkpoint(), " ", session.battle._kernel.player_view())
		quit(1)
		return
	var native_before: Dictionary = session.battle.persistent_state().state
	var actor_before: int = int(session.campaign_system.save_state().next_enemy_uid)
	ready = session.configure_save_directory(directory)
	if ready.ok: ready = session.request_save()
	if ready.ok: ready = session.save_files.close(2000)
	if not ready.ok:
		printerr("damaged combat save: ", ready)
		quit(1)
		return
	var loaded: Dictionary = Session.load_candidate("res://generated/config.json", directory)
	if not loaded.ok or loaded.session.campaign_system.restore_checkpoint() != "combat" or not _full_defence(loaded.session) or int(loaded.session.battle._kernel.active_flight_count()) != 0:
		printerr("damaged combat load: ", loaded)
		quit(1)
		return
	var native_after: Dictionary = loaded.session.battle.persistent_state().state
	if native_after.history_counts != native_before.history_counts or int(native_after.next_ids.attack) < int(native_before.next_ids.attack) or int(loaded.session.campaign_system.save_state().next_enemy_uid) <= actor_before:
		printerr("combat history or actor watermark regressed")
		quit(1)
		return
	loaded.session.save_files.close(2000)
	var pointer: Dictionary = SaveFiles.read_pointer(directory, "active.json")
	var import_directory: String = directory.path_join("import")
	DirAccess.make_dir_recursive_absolute(import_directory)
	var imported: Dictionary = Session.import_candidate("res://generated/config.json", import_directory,
		directory.path_join(pointer.pointer.file))
	if not imported.ok or imported.session.campaign_system.restore_checkpoint() != "combat" or not _full_defence(imported.session) or int(imported.session.battle._kernel.active_flight_count()) != 0:
		printerr("damaged combat import: ", imported)
		quit(1)
		return
	imported.session.save_files.close(2000)
	for step in 2400:
		if not session._advance_kernel(0.05) or session.campaign_system.restore_checkpoint() != "combat": break
	if session.campaign_system.restore_checkpoint() != "retreat":
		printerr("damaged combat never entered retreat: ", session.campaign_system.restore_checkpoint())
		quit(1)
		return
	var retreat_directory: String = directory.path_join("retreat")
	DirAccess.make_dir_recursive_absolute(retreat_directory)
	ready = session.configure_save_directory(retreat_directory)
	if ready.ok: ready = session.request_save()
	if ready.ok: ready = session.save_files.close(2000)
	var resumed_retreat: Dictionary = Session.load_candidate("res://generated/config.json", retreat_directory)
	if not ready.ok or not resumed_retreat.ok or resumed_retreat.session.campaign_system.restore_checkpoint() != "retreat" or not _full_defence(resumed_retreat.session) or int(resumed_retreat.session.battle._kernel.active_flight_count()) != 0:
		printerr("retreat checkpoint failed: ", ready, " ", resumed_retreat)
		quit(1)
		return
	resumed_retreat.session.save_files.close(2000)
	var loot_directory: String = directory.path_join("pending-drop")
	DirAccess.make_dir_recursive_absolute(loot_directory)
	var loot = Session.new()
	ready = loot.initialize("res://generated/config.json", 141)
	if ready.ok: ready = loot.campaign_system.start_sortie(1, loot.equipment.clear_switch_locks)
	if not ready.ok:
		printerr("pending drop fixture: ", ready)
		quit(1)
		return
	loot._start_wave()
	for step in 2400:
		if not loot._advance_kernel(0.05): break
		if not loot.economy.save_state().drops.is_empty(): break
	if not loot.run_state.is_running() or loot.economy.save_state().drops.is_empty():
		printerr("native wave produced no pending drop: ", loot.campaign_system.restore_checkpoint(), " ", loot.battle.persistent_state())
		quit(1)
		return
	var drop_id: String = str(loot.economy.save_state().drops.keys()[0])
	if loot.campaign_system.restore_checkpoint() != "travel":
		printerr("pending drop fixture not in travel: ", loot.campaign_system.restore_checkpoint())
		quit(1)
		return
	ready = loot.configure_save_directory(loot_directory)
	if ready.ok: ready = loot.request_save()
	if ready.ok: ready = loot.save_files.close(2000)
	var reloaded_loot: Dictionary = Session.load_candidate("res://generated/config.json", loot_directory)
	if not ready.ok or not reloaded_loot.ok or not reloaded_loot.session.economy.save_state().drops.has(drop_id) or reloaded_loot.session.campaign_system.restore_checkpoint() != "travel" or int(reloaded_loot.session.battle._kernel.active_flight_count()) != 0:
		printerr("pending drop did not survive restore: ", ready, " ", reloaded_loot)
		quit(1)
		return
	var drop_pointer: Dictionary = SaveFiles.read_pointer(loot_directory, "active.json")
	var drop_import_dir: String = loot_directory.path_join("import")
	DirAccess.make_dir_recursive_absolute(drop_import_dir)
	var imported_loot: Dictionary = Session.import_candidate("res://generated/config.json", drop_import_dir,
		loot_directory.path_join(drop_pointer.pointer.file))
	if not imported_loot.ok or not imported_loot.session.economy.save_state().drops.has(drop_id) or imported_loot.session.campaign_system.restore_checkpoint() != "travel":
		printerr("pending DropId import failed: ", imported_loot)
		quit(1)
		return
	imported_loot.session.save_files.close(2000)
	ready = reloaded_loot.session.economy.collect_drop(drop_id, false, reloaded_loot.session.wall_time,
		reloaded_loot.session.game_time, {})
	if not ready.ok or reloaded_loot.session.economy.collect_drop(drop_id, false,
		reloaded_loot.session.wall_time, reloaded_loot.session.game_time, {}).ok:
		printerr("pending DropId credited more than once: ", ready)
		quit(1)
		return
	ready = reloaded_loot.session.request_save()
	if ready.ok: ready = reloaded_loot.session.save_files.close(2000)
	var settled: Dictionary = Session.load_candidate("res://generated/config.json", loot_directory)
	if not ready.ok or not settled.ok or settled.session.economy.save_state().drops.has(drop_id):
		printerr("claimed DropId returned after save: ", ready, " ", settled)
		quit(1)
		return
	ready = settled.session.campaign_system.start_sortie(1, settled.session.equipment.clear_switch_locks)
	if not ready.ok:
		printerr("new wave after restore failed: ", ready)
		quit(1)
		return
	settled.session._start_wave()
	for step in 2400:
		if not settled.session._advance_kernel(0.05): break
		if not settled.session.economy.save_state().drops.is_empty(): break
	var next_drops: Dictionary = settled.session.economy.save_state().drops
	if next_drops.is_empty() or int(str(next_drops.keys()[0]).trim_prefix("native:")) <= int(drop_id.trim_prefix("native:")):
		printerr("new wave reused DropId: ", drop_id, " ", next_drops.keys())
		quit(1)
		return
	settled.session.save_files.close(2000)
	print("STAGE6_CHECKPOINT_PROBE_OK")
	quit(0)
