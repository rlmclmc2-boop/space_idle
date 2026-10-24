extends RefCounted
## Stage 1 disk protocol. Domain validators and recovery sessions arrive in stage 6.
## One serial writer; snapshots are copied before the worker sees them.

var directory: String
var config_hash: String
var _worker := Thread.new()
var _pending: Dictionary = {}
var _next_generation: int = 0
var saved_generation: int = 0
var saved_change: int = -1
var last_result: Dictionary = {}
var fault_boundary := "" # test-only disk boundary, never business logic
var _lock
var _available := false

func _init(path: String, hash_value: String) -> void:
	directory = path
	config_hash = hash_value
	DirAccess.make_dir_recursive_absolute(directory)
	_lock = ClassDB.instantiate("SpaceSaveLock")
	_available = _lock.acquire(directory.path_join("writer.lock"))
	if not _available:
		last_result = _failure("SaveDirectoryInUse")
		return
	var recovered := load_latest()
	if recovered.get("ok", false):
		_next_generation = int(recovered.envelope.generation)
		saved_generation = _next_generation
		saved_change = int(recovered.envelope.changeNumber)

func request(snapshot: Dictionary, change_number: int, session_id: String, utc: int) -> int:
	if not _available or change_number < 0 or _next_generation == 9223372036854775807:
		last_result = _failure("SaveRequestRejected")
		return -1
	_next_generation += 1
	_pending = {"formatVersion": 1, "sessionId": session_id,
		"changeNumber": str(change_number), "generation": str(_next_generation),
		"configHash": config_hash, "savedUtc": str(utc), "payload": snapshot.duplicate(true)}
	_start_pending()
	return _next_generation

func _start_pending() -> void:
	if _worker.is_started() or _pending.is_empty():
		return
	var snapshot := _pending
	_pending = {}
	var status := _worker.start(_write_snapshot.bind(snapshot, fault_boundary))
	if status != OK:
		last_result = _failure("WriterStart")

func poll() -> Dictionary:
	if _worker.is_started() and not _worker.is_alive():
		last_result = _worker.wait_to_finish()
		if last_result.ok:
			saved_generation = int(last_result.generation)
			saved_change = int(last_result.changeNumber)
	_start_pending()
	return last_result

func dirty(change_number: int) -> bool:
	return change_number != saved_change

func close() -> void:
	# Explicit lifecycle hook; caller owns shutdown timeout/UI policy.
	while _worker.is_started() or not _pending.is_empty():
		if _worker.is_started():
			last_result = _worker.wait_to_finish()
			if last_result.ok:
				saved_generation = int(last_result.generation)
				saved_change = int(last_result.changeNumber)
		_start_pending()
	_lock = null
	_available = false

func _failure(reason: String) -> Dictionary:
	return {"ok": false, "error": reason}

func _write_snapshot(envelope: Dictionary, fault: String) -> Dictionary:
	var io = ClassDB.instantiate("SpaceSaveIO")
	envelope.payloadHash = JSON.stringify(envelope.payload).sha256_text()
	var text := JSON.stringify(envelope)
	var file_name: String = "generation-" + envelope.generation + ".json"
	if fault == "snapshot_write":
		return _failure("InjectedSnapshotWrite")
	if io.write_atomic(directory.path_join(file_name), text.to_utf8_buffer()) != 0:
		return _failure("SnapshotWrite")
	if fault == "snapshot_readback" or FileAccess.get_file_as_string(directory.path_join(file_name)) != text:
		return _failure("SnapshotReadback")
	var pointer := {"generation": envelope.generation, "file": file_name, "checksum": text.sha256_text()}
	# A damaged active may have forced recovery through backup. Never replace
	# that last valid pointer with unchecked active bytes before committing.
	var previous := load_latest()
	if previous.get("ok", false):
		var old := JSON.stringify(previous.pointer)
		if fault == "backup_write" or io.write_atomic(directory.path_join("backup.json"), old.to_utf8_buffer()) != 0:
			return _failure("BackupWrite")
	if fault == "manifest_write":
		return _failure("InjectedManifestWrite")
	var pointer_text := JSON.stringify(pointer)
	var status: int = io.write_atomic(directory.path_join("active.json"), pointer_text.to_utf8_buffer())
	# A rename followed by a durability error has an uncertain outcome. Read back
	# before reporting it; never replay rewards or business mutations here.
	if status != 0 and FileAccess.get_file_as_string(directory.path_join("active.json")) != pointer_text:
		return _failure("ManifestWrite")
	return {"ok": true, "generation": envelope.generation, "changeNumber": envelope.changeNumber}

func _read_candidate(pointer_name: String) -> Dictionary:
	var path := directory.path_join(pointer_name)
	if not FileAccess.file_exists(path):
		return _failure("MissingPointer")
	var pointer = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not pointer is Dictionary or not pointer.get("file") is String or not pointer.get("generation") is String or not pointer.get("checksum") is String:
		return _failure("InvalidPointer")
	if not pointer.file.begins_with("generation-") or "/" in pointer.file or "\\" in pointer.file:
		return _failure("InvalidPointer")
	var text := FileAccess.get_file_as_string(directory.path_join(pointer.file))
	if text.sha256_text() != pointer.get("checksum", ""):
		return _failure("Checksum")
	var value = JSON.parse_string(text)
	if not value is Dictionary or value.get("formatVersion") != 1 or value.get("configHash") != config_hash or not value.get("payload") is Dictionary:
		return _failure("EnvelopeSchema")
	for field in ["generation", "changeNumber", "savedUtc"]:
		if not value.get(field) is String or not value[field].is_valid_int() or str(int(value[field])) != value[field]:
			return _failure("EnvelopeInteger")
	if value.generation != pointer.generation or int(value.generation) <= 0 or JSON.stringify(value.payload).sha256_text() != value.get("payloadHash", ""):
		return _failure("PayloadHash")
	return {"ok": true, "envelope": value, "pointer": pointer}

func load_latest() -> Dictionary:
	var active := _read_candidate("active.json")
	var backup := _read_candidate("backup.json")
	if not active.get("ok", false):
		return backup
	if backup.get("ok", false) and int(backup.envelope.generation) > int(active.envelope.generation):
		return backup
	return active
