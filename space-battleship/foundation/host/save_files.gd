extends RefCounted
## One background writer. This foundation stores opaque immutable payloads;
## domain/entity validation and full session restore belong to later stages.
var _directory: String
var _config_hash: String
var _worker: Thread
var _pending: Dictionary = {}
var _generation: int = 0
var saved_change: String = ""
var last_result: Dictionary = {}
var fault_boundary: String = ""

func _init(directory: String, config_hash: String) -> void:
	_directory = directory
	_config_hash = config_hash
	DirAccess.make_dir_recursive_absolute(directory)
	var previous := load_latest()
	if previous.ok:
		_generation = str(previous.envelope.generation).to_int()
		saved_change = previous.envelope.changeNumber

static func integer_text(value) -> bool:
	return value is String and value.is_valid_int() and value.to_int() >= 0 and str(value.to_int()) == value

static func read_pointer(directory: String, config_hash: String, pointer_file: String) -> Dictionary:
	if not FileAccess.file_exists(directory.path_join(pointer_file)): return {"ok": false}
	var pointer = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join(pointer_file)))
	if not pointer is Dictionary or not pointer.get("file") in ["slot-0.json", "slot-1.json"] or not integer_text(pointer.get("generation")): return {"ok": false}
	var raw := FileAccess.get_file_as_string(directory.path_join(pointer.file))
	if raw.sha256_text() != pointer.get("checksum"): return {"ok": false}
	var envelope = JSON.parse_string(raw)
	if not envelope is Dictionary or envelope.get("formatVersion") != 1 or envelope.get("configHash") != config_hash:
		return {"ok": false}
	for field in ["changeNumber", "generation", "savedUtc"]:
		if not integer_text(envelope.get(field)): return {"ok": false}
	if envelope.generation != pointer.generation or not envelope.get("sessionId") is String or envelope.sessionId.is_empty() or not envelope.get("payload") is Dictionary: return {"ok": false}
	if JSON.stringify(envelope.payload).sha256_text() != envelope.get("payloadHash"): return {"ok": false}
	return {"ok": true, "envelope": envelope, "pointer": pointer}

static func read_store(directory: String, config_hash: String) -> Dictionary:
	var current := read_pointer(directory, config_hash, "active.json")
	if current.ok: return current
	var backup := read_pointer(directory, config_hash, "previous.json")
	if backup.ok: return backup
	return {"ok": false, "error": "InvalidSaveStore" if FileAccess.file_exists(directory.path_join("active.json")) or FileAccess.file_exists(directory.path_join("previous.json")) else "MissingSave"}

func load_latest() -> Dictionary:
	return read_store(_directory, _config_hash)

func request(payload: Dictionary, change_number: String, session_id: String, utc: String) -> Dictionary:
	if not integer_text(change_number) or not integer_text(utc) or session_id.is_empty() or _generation == 9223372036854775807:
		return {"ok": false, "error": "InvalidSaveRequest"}
	var store := load_latest()
	if not store.ok and store.error != "MissingSave": return store
	_generation += 1
	# Capture and serialize before the worker starts; it never sees live payloads.
	var payload_text := JSON.stringify(payload.duplicate(true))
	var snapshot = JSON.parse_string(payload_text)
	if not snapshot is Dictionary: return {"ok": false, "error": "InvalidSavePayload"}
	var envelope := {"formatVersion": 1, "sessionId": session_id, "changeNumber": change_number,
		"generation": str(_generation), "configHash": _config_hash, "savedUtc": utc,
		"payloadHash": JSON.stringify(snapshot).sha256_text(), "payload": snapshot}
	_pending = {"directory": _directory, "config": _config_hash, "envelope": JSON.stringify(envelope),
		"generation": str(_generation), "change": change_number, "fault": fault_boundary}
	poll()
	return {"ok": true, "generation": str(_generation)}

func poll() -> void:
	if _worker != null and not _worker.is_alive():
		last_result = _worker.wait_to_finish()
		_worker = null
		if last_result.ok: saved_change = last_result.change
	if _worker == null and not _pending.is_empty():
		var captured := _pending.duplicate(true)
		_pending = {}
		_worker = Thread.new()
		var code := _worker.start(write_snapshot.bind(captured))
		if code != OK:
			last_result = {"ok": false, "error": "WriterStart"}
			_worker = null

func busy() -> bool:
	return _worker != null or not _pending.is_empty()

func dirty(current_change: String) -> bool:
	return current_change != saved_change

func close() -> Dictionary:
	# Caller may poll within its own bounded shutdown budget. No blocking join
	# on a live worker and no claim that pending writes have already succeeded.
	poll()
	return {"ok": not busy(), "error": "WriterBusy" if busy() else ""}

static func publish_file(directory: String, name: String, content: String, disk) -> bool:
	var temporary := directory.path_join(name + ".tmp")
	var stream := FileAccess.open(temporary, FileAccess.WRITE)
	if stream == null: return false
	stream.store_string(content)
	stream.flush()
	stream.close()
	if FileAccess.get_file_as_string(temporary) != content: return false
	return disk.replace(temporary, directory.path_join(name))

static func write_snapshot(job: Dictionary) -> Dictionary:
	var directory: String = job.directory
	var disk = ClassDB.instantiate("FoundationDisk")
	var old := read_store(directory, job.config)
	if not old.ok and old.error != "MissingSave": return {"ok": false, "error": old.error}
	var filename := "slot-1.json" if old.ok and old.pointer.file == "slot-0.json" else "slot-0.json"
	if job.fault == "data_write" or not publish_file(directory, filename, job.envelope, disk): return {"ok": false, "error": "DataWrite"}
	var pointer := {"file": filename, "generation": job.generation, "checksum": job.envelope.sha256_text()}
	if job.fault == "data_verify": return {"ok": false, "error": "DataVerify"}
	# Validate the complete envelope before replacing either publication pointer.
	var probe_name: String = "probe-" + job.generation + ".json"
	if not publish_file(directory, probe_name, JSON.stringify(pointer), disk): return {"ok": false, "error": "DataVerify"}
	var verified := read_pointer(directory, job.config, probe_name)
	DirAccess.remove_absolute(directory.path_join(probe_name))
	if not verified.ok: return {"ok": false, "error": "DataVerify"}
	if old.ok:
		if job.fault == "backup_replace" or not publish_file(directory, "previous.json", JSON.stringify(old.pointer), disk): return {"ok": false, "error": "BackupWrite"}
	if job.fault == "manifest_replace" or not publish_file(directory, "active.json", JSON.stringify(pointer), disk): return {"ok": false, "error": "ManifestWrite"}
	return {"ok": true, "generation": job.generation, "change": job.change}
