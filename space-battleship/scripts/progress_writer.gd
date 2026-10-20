extends RefCounted
# Synchronous safe writes, used only by timed/manual saves. No thread or queue.
var path := ProjectSettings.globalize_path("user://progress.json")
var validation_db: ShipDatabase

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
	var displaced := ""
	if FileAccess.file_exists(path):
		# A damaged primary must never replace a good recovery copy.
		if _read_progress_file(path, validation_db) == null and _read_progress_file(path + ".bak", validation_db) != null:
			# Retain the rejected bytes, including when installing the new file fails.
			displaced = path + ".rejected"
			if FileAccess.file_exists(displaced) or DirAccess.dir_exists_absolute(displaced):return ERR_ALREADY_EXISTS
			var moved := _rename(path, displaced)
			if moved != OK:return moved
		else:
			if FileAccess.file_exists(path + ".bak"):
				var removed := DirAccess.remove_absolute(path + ".bak")
				if removed != OK:return removed
			var moved := _rename(path, path + ".bak")
			if moved != OK:return moved
	var error := _rename(path + ".tmp", path)
	if error != OK:
		if not displaced.is_empty():
			_rename(displaced, path)
		elif FileAccess.file_exists(path + ".bak"):
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

static func _import_owner_running(pid: int) -> bool:
	if pid==OS.get_process_id():return true
	# Godot's process tracker only knows this process and its children.
	if OS.get_name()=="Linux":return DirAccess.dir_exists_absolute("/proc/"+str(pid))
	var output: Array=[]
	if OS.get_name()=="Windows":
		var error:=OS.execute("tasklist",["/FI","PID eq "+str(pid),"/FO","CSV","/NH"],output,true)
		return error!=0 or output.any(func(line):return str(line).contains('","'+str(pid)+'",'))
	var error:=OS.execute("/bin/ps",["-p",str(pid),"-o","pid="],output,true)
	return _import_owner_ps_result(error,output)

static func _import_owner_ps_result(error: int, output: Array) -> bool:
	# POSIX ps: exit 1 with no output means no matching PID. Diagnostics or an
	# execution failure leave ownership unknown, so retain the transaction.
	return error!=1 or output.any(func(line):return not str(line).strip_edges().is_empty())

static func read_progress(path: String, db: ShipDatabase = null) -> Variant:
	var result := read_progress_result(path, db)
	return result.data if result.status == "loaded" else null

static func read_progress_result(path: String, db: ShipDatabase = null) -> Dictionary:
	# Interrupted import installation keeps the previous committed primary here.
	# Never read .import-new: it is uncommitted, even if it parses successfully.
	# Selection is read-only: failed recovery must preserve every on-disk clue.
	var marker := path+".import-active"
	var active := false
	if FileAccess.file_exists(marker):
		var owner = JSON.parse_string(FileAccess.get_file_as_string(marker))
		# Conservatively retain unrecognized ownership; our marker is atomically written.
		var pid = owner.get("pid") if owner is Dictionary else null
		active = true
		if (pid is float or pid is int) and is_finite(float(pid)) and pid==floorf(float(pid)) and pid>0 and pid<9.22e18:
			active = _import_owner_running(int(pid))
	var found := FileAccess.file_exists(marker) or FileAccess.file_exists(path+".import-new")
	var rejected := []
	for suffix in ["", ".import-prev", ".bak"]:
		if not FileAccess.file_exists(path+suffix):continue
		found = true
		var checked := _check_progress_file(path + suffix, db)
		if checked.error.is_empty():
			return {"status":"loaded", "source":suffix, "data":checked.data, "rejected":rejected, "import_active":active}
		rejected.append({"source":suffix, "error":checked.error})
	return {"status":"invalid" if found else "absent", "source":"", "data":null, "rejected":rejected, "import_active":active}

static func finish_loaded_recovery(path: String, result: Dictionary) -> Error:
	# Only a successfully applied save may retire an abandoned import transaction.
	if result.status != "loaded" or result.import_active:return OK
	var previous := path + ".import-prev"
	if result.source == ".import-prev":
		if FileAccess.file_exists(path):
			var rejected := path + ".rejected"
			if FileAccess.file_exists(rejected) or DirAccess.dir_exists_absolute(rejected):return ERR_ALREADY_EXISTS
			var moved := DirAccess.rename_absolute(path,rejected)
			if moved != OK:return moved
			moved = DirAccess.rename_absolute(previous,path)
			if moved != OK:
				DirAccess.rename_absolute(rejected,path)
				return moved
		else:
			var moved := DirAccess.rename_absolute(previous,path)
			if moved != OK:return moved
	elif result.source == "":
		if FileAccess.file_exists(previous):
			var removed := DirAccess.remove_absolute(previous)
			if removed != OK:return removed
	else:
		return OK # Backup recovery keeps all primary/import evidence available.
	for suffix in [".import-new", ".import-active"]:
		if FileAccess.file_exists(path+suffix):
			var removed := DirAccess.remove_absolute(path+suffix)
			if removed != OK:return removed
	return OK

static func _check_progress_file(path: String, db: ShipDatabase = null) -> Dictionary:
	if not FileAccess.file_exists(path):return {"error":"absent"}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK or not parser.data is Dictionary:return {"error":"format"}
	var data = parser.data
	var database := db if db != null else ShipDatabase.new()
	# Runtime load uses the same shape, semantic and legacy migration rules as import.
	return load("res://scripts/save_transfer.gd").new().prepare_data(data, database)

static func _read_progress_file(path: String, db: ShipDatabase = null) -> Variant:
	var checked := _check_progress_file(path, db)
	return checked.data if checked.error.is_empty() else null
