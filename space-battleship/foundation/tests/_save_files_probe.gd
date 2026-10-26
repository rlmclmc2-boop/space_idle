extends SceneTree

const SaveFiles = preload("res://foundation/host/save_files.gd")

class RejectManifest extends RefCounted:
	var delegate
	func _init() -> void:
		delegate = ClassDB.instantiate("FoundationDisk")
	func replace(source: String, destination: String) -> bool:
		if destination.ends_with("active.json"): return false
		return delegate.replace(source, destination)

func _initialize() -> void:
	var loaded = GDExtensionManager.load_extension(OS.get_environment("SPACE_IDLE_NATIVE_EXTENSION"))
	if loaded != GDExtensionManager.LOAD_STATUS_OK and loaded != GDExtensionManager.LOAD_STATUS_ALREADY_LOADED:
		printerr("extension: ", loaded)
		quit(1)
		return
	call_deferred("_run_probe")

func _run_probe() -> void:
	var session = preload("res://src/game_session.gd").new()
	var initialized: Dictionary = session.initialize("res://generated/config.json", 29)
	if not initialized.ok:
		printerr("session initialization: ", initialized)
		quit(1)
		return
	var native = session.battle._kernel
	var original: Dictionary = native.persistent_state()
	if session.battle.persistent_state().get("state") != original:
		printerr("Battle persistent boundary")
		quit(1)
		return
	if not native.restore_persistent_state(original) or native.persistent_state() != original:
		printerr("native persistent roundtrip")
		quit(1)
		return
	var corrupted: Dictionary = original.duplicate(true)
	corrupted.history_counts.attacks = "1.5"
	if native.restore_persistent_state(corrupted) or native.persistent_state() != original:
		printerr("native rejected candidate mutated state")
		quit(1)
		return
	var resume_state: Dictionary = original.duplicate(true)
	resume_state.history_counts.attacks = "101"
	resume_state.history_counts.incoming = "202"
	resume_state.next_ids.encounter = "10"
	resume_state.next_ids.attack = "300"
	resume_state.next_ids.emitter = "400"
	resume_state.next_ids.drop = "500"
	var resumed = preload("res://src/game_session.gd").new()
	if not resumed.initialize("res://generated/config.json", 31, resume_state).ok or resumed.battle.persistent_state().state != resume_state:
		printerr("new candidate native restore")
		quit(1)
		return
	var directory: String = OS.get_environment("SPACE_IDLE_SAVE_TEST_DIR")
	if directory.is_empty():
		printerr("missing disposable test directory")
		quit(1)
		return
	var files = SaveFiles.new(directory)
	var hash: String = "a".repeat(64)
	var first: Dictionary = files.request({"wallet": {"iron": {"m": "1", "e": "30"}}}, "1", "test-session", "1", hash)
	if not first.ok or not files.close(2000).ok or files.dirty("1"):
		printerr("first publication: ", first, " ", files.last_result)
		quit(1)
		return
	var second: Dictionary = files.request({"wallet": {"iron": {"m": "2", "e": "30"}}}, "2", "test-session", "2", hash)
	if not second.ok or not files.close(2000).ok:
		printerr("second publication: ", second, " ", files.last_result)
		quit(1)
		return
	var loaded_save: Dictionary = files.load_latest()
	if not loaded_save.ok or loaded_save.envelope.changeNumber != "2" or loaded_save.envelope.configHash != hash:
		printerr("load latest: ", loaded_save)
		quit(1)
		return
	var payload: Dictionary = {"wallet": {"iron": {"m": "3", "e": "30"}}}
	var envelope: Dictionary = {"formatVersion": 1, "sessionId": "test-session", "changeNumber": "3",
		"generation": "3", "savedUtc": "3", "configHash": hash,
		"payloadHash": JSON.stringify(payload).sha256_text(), "payload": payload}
	var rejected: Dictionary = SaveFiles.write_snapshot({"directory": directory, "envelope": JSON.stringify(envelope),
		"generation": "3", "change": "3"}, RejectManifest.new())
	if rejected.ok or rejected.error != "ManifestWrite" or files.load_latest().envelope.changeNumber != "2":
		printerr("failed manifest changed active save: ", rejected)
		quit(1)
		return
	if not files.dirty("3"):
		printerr("newer change should remain dirty")
		quit(1)
		return
	var active_path: String = directory.path_join("active.json")
	var active: String = FileAccess.get_file_as_string(active_path)
	var stream := FileAccess.open(active_path, FileAccess.WRITE)
	stream.store_string("{}")
	stream.close()
	var recovered: Dictionary = files.load_latest()
	if not recovered.ok or recovered.envelope.changeNumber != "2":
		printerr("backup recovery: ", recovered)
		quit(1)
		return
	stream = FileAccess.open(active_path, FileAccess.WRITE)
	stream.store_string(active)
	stream.close()
	if files.request({}, "4", "test-session", "3", "invalid").ok:
		printerr("invalid config hash admitted")
		quit(1)
		return
	print("SAVE_FILES_PROBE_OK")
	quit(0)
