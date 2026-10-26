extends SceneTree

const Session = preload("res://src/game_session.gd")
const StateCodec = preload("res://foundation/host/state_codec.gd")
const SaveFiles = preload("res://foundation/host/save_files.gd")

func _initialize() -> void:
	var extension: String = OS.get_environment("SPACE_IDLE_NATIVE_EXTENSION")
	var loaded = GDExtensionManager.load_extension(extension)
	if loaded != GDExtensionManager.LOAD_STATUS_OK and loaded != GDExtensionManager.LOAD_STATUS_ALREADY_LOADED:
		printerr("extension: ", loaded)
		quit(1)
		return
	call_deferred("_run")

func _run() -> void:
	var directory: String = OS.get_environment("SPACE_IDLE_SAVE_TEST_DIR")
	if directory.is_empty():
		printerr("missing disposable directory")
		quit(1)
		return
	var original = Session.new()
	var ready: Dictionary = original.initialize("res://generated/config.json", 101)
	if not ready.ok:
		printerr("initialize: ", ready)
		quit(1)
		return
	ready = original.campaign_system.start_sortie(1, original.equipment.clear_switch_locks)
	if not ready.ok:
		printerr("sortie: ", ready)
		quit(1)
		return
	ready = original.configure_save_directory(directory)
	if ready.ok: ready = original.request_save()
	if not ready.ok:
		printerr("save: ", ready)
		quit(1)
		return
	ready = original.save_files.close(2000)
	if not ready.ok:
		printerr("close: ", ready)
		quit(1)
		return
	var restored: Dictionary = Session.load_candidate("res://generated/config.json", directory)
	if not restored.ok:
		printerr("load: ", restored)
		quit(1)
		return
	if restored.session.campaign_system.restore_checkpoint() != "departing":
		printerr("checkpoint changed")
		quit(1)
		return
	restored.session.save_files.close(2000)
	original._start_wave()
	if not original.run_state.is_running():
		printerr("wave start failed: ", original.run_state.reason())
		quit(1)
		return
	ready = original.request_save()
	if ready.ok: ready = original.save_files.close(2000)
	if not ready.ok:
		printerr("combat save: ", ready)
		quit(1)
		return
	restored = Session.load_candidate("res://generated/config.json", directory)
	if not restored.ok or restored.session.campaign_system.restore_checkpoint() != "combat":
		printerr("combat load: ", restored)
		quit(1)
		return
	var snapshot: Dictionary = original.save_payload()
	var decoded: Dictionary = StateCodec.unpack(snapshot.payload)
	var damaged: Dictionary = decoded.value
	damaged.modules.equipment.slots[0].equipment_id = "missing-equipment-id"
	var rejected = Session.new()
	var attempted: Dictionary = rejected.initialize("res://generated/config.json", damaged.seed, damaged.native, damaged)
	if attempted.ok or not original.run_state.is_running():
		printerr("semantic candidate rejection failed: ", attempted)
		quit(1)
		return
	var pointer: Dictionary = SaveFiles.read_pointer(directory, "active.json")
	var imported: Dictionary = Session.import_candidate("res://generated/config.json", directory,
		directory.path_join(pointer.pointer.file))
	if not imported.ok:
		printerr("import: ", imported)
		quit(1)
		return
	var offline: Dictionary = original.economy.credit_offline(100000, 12, "1")
	var cap: Dictionary = original.amount_api.apply("from_decimal", ["43200"])
	if not offline.ok or original.amount_api.apply("compare", [
		original.economy.budget().get("chrono", {}), cap.value]).scalar != 0:
		printerr("offline cap failed: ", offline)
		quit(1)
		return
	offline = original.economy.credit_offline(100000, 12, "1")
	if not offline.ok or offline.credited:
		printerr("offline capacity replayed: ", offline)
		quit(1)
		return
	printerr("STAGE6_SESSION_PROBE_OK")
	quit(0)
