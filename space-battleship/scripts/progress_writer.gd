extends RefCounted
# Only this object writes progress. The main thread owns queue/revision state;
# the worker receives an already serialized byte snapshot and returns a result.
var worker: Thread
var pending := PackedByteArray()
var pending_revision := 0
var active_revision := 0
var revision := 0
var committed_revision := 0
# Resolve on the main thread. Absolute READ paths also avoid editor-only
# per-component case checks when validating the temporary file on Windows.
var path := ProjectSettings.globalize_path("user://progress.json")

func enqueue(bytes: PackedByteArray) -> Error:
	revision += 1
	pending = bytes
	pending_revision = revision
	if worker == null:return _start_pending()
	return OK

func _start_pending() -> Error:
	if pending.is_empty():return OK
	var bytes := pending
	active_revision = pending_revision
	pending = PackedByteArray()
	worker = Thread.new()
	var error := worker.start(_write_payload.bind(bytes))
	if error != OK:
		worker = null
		pending = bytes
		pending_revision = active_revision
	return error

func poll() -> Dictionary:
	if worker == null or worker.is_alive():return {}
	var result := _join_worker()
	if result.error == OK:committed_revision = active_revision
	result.revision = active_revision
	var start_error := _start_pending()
	if start_error != OK:result.error = start_error
	return result

func immediate(bytes: PackedByteArray) -> Dictionary:
	# The current snapshot supersedes queued snapshots. Join the sole older writer
	# before committing, so no older completion can overwrite this transaction.
	if worker != null:
		_join_worker()
	pending = PackedByteArray()
	revision += 1
	var result := _write_payload(bytes)
	result.revision = revision
	if result.error == OK:committed_revision = revision
	return result

func finish() -> Dictionary:
	var result := {}
	while worker != null or not pending.is_empty():
		if worker == null:
			var error := _start_pending()
			if error != OK:return {"error":error,"revision":revision}
		var completed := _join_worker()
		completed.revision = active_revision
		if completed.error == OK:committed_revision = active_revision
		result = completed
	return result

func cancel_and_join() -> void:
	pending = PackedByteArray()
	if worker != null:
		_join_worker()

func _join_worker() -> Dictionary:
	var result: Dictionary = worker.wait_to_finish()
	worker = null
	return result

func _write_payload(bytes: PackedByteArray) -> Dictionary:
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:return {"error":FileAccess.get_open_error()}
	var written := file.store_buffer(bytes)
	file.flush()
	var error := file.get_error()
	file.close()
	if not written or error != OK:return {"error":ERR_FILE_CANT_WRITE}
	# A close-time failure must not install truncated bytes. Read back only the
	# private temporary file; the old committed file remains untouched.
	if FileAccess.get_file_as_bytes(path + ".tmp") != bytes:return {"error":ERR_FILE_CANT_WRITE}
	return {"error":_commit_temp()}

func _commit_temp() -> Error:
	# Godot's Windows rename removes an existing destination before moving.
	# Move only to absent destinations. Keep the previous file recoverable until
	# the new file is installed; load also accepts this backup after interruption.
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(path + ".bak"):
			var removed := DirAccess.remove_absolute(path + ".bak")
			if removed != OK:return removed
		var moved := _rename(path, path + ".bak")
		if moved != OK:return moved
	var error := _rename(path + ".tmp", path)
	if error != OK and FileAccess.file_exists(path + ".bak"):
		_rename(path + ".bak", path)
	return error

func _rename(from: String, to: String) -> Error:
	return DirAccess.rename_absolute(from, to)

func clear_files() -> Error:
	cancel_and_join()
	# Remove recovery state first. If deleting the main file fails, it stays live.
	for suffix in [".bak", ".tmp", ""]:
		if FileAccess.file_exists(path + suffix):
			var error := DirAccess.remove_absolute(path + suffix)
			if error != OK:return error
	return OK

static func read_progress(path: String) -> Variant:
	for suffix in ["", ".bak"]:
		if not FileAccess.file_exists(path + suffix):continue
		var data = JSON.parse_string(FileAccess.get_file_as_string(path + suffix))
		if data is Dictionary and int(data.get("version",0)) in [2,3]:return data
	return null
