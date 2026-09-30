extends RefCounted
# Synchronous safe writes, used only by timed/manual saves. No thread or queue.
var path := ProjectSettings.globalize_path("user://progress.json")

func write_progress(bytes: PackedByteArray) -> Error:
	return _write_payload(bytes).error

func _write_payload(bytes: PackedByteArray) -> Dictionary:
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE_READ)
	if file == null:return {"error":FileAccess.get_open_error()}
	var written := _store_buffer(file,bytes)
	file.flush()
	var error := file.get_error()
	if not written or error != OK:
		file.close()
		return {"error":ERR_FILE_CANT_WRITE}
	# Validate the flushed temporary file before touching the previous commit.
	file.seek(0)
	var verified := file.get_buffer(bytes.size())
	var complete := verified == bytes and file.get_length() == bytes.size() and file.get_error() == OK
	file.close()
	if not complete:return {"error":ERR_FILE_CANT_WRITE}
	return {"error":_commit_temp()}

func _store_buffer(file: FileAccess, bytes: PackedByteArray) -> bool:
	return file.store_buffer(bytes)

func _commit_temp() -> Error:
	# Godot's Windows rename removes an existing destination before moving.
	# Move only to absent destinations. Keep the previous file recoverable until
	# the new file is installed; load also accepts this backup after interruption.
	if FileAccess.file_exists(path):
		# A damaged primary must never replace a good recovery copy.
		if _read_progress_file(path) == null and _read_progress_file(path + ".bak") != null:
			var removed := DirAccess.remove_absolute(path)
			if removed != OK:return removed
		else:
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
	# Remove recovery state first. If deleting the main file fails, it stays live.
	for suffix in [".bak", ".tmp", ""]:
		if FileAccess.file_exists(path + suffix):
			var error := DirAccess.remove_absolute(path + suffix)
			if error != OK:return error
	return OK

static func read_progress(path: String) -> Variant:
	for suffix in ["", ".bak"]:
		var data = _read_progress_file(path + suffix)
		if data != null:return data
	return null

static func _read_progress_file(path: String) -> Variant:
	if not FileAccess.file_exists(path):return null
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:return null
	var data = parser.data
	if data is Dictionary:
		var version = data.get("version",0)
		if (version is int or version is float) and (version == 2 or version == 3):return data
	return null
