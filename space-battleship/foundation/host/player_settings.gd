extends RefCounted

const SaveFiles = preload("res://foundation/host/save_files.gd")
const MAX_INTERVAL: int = 86400

static func _path() -> String:
	var override: String = OS.get_environment("SPACE_IDLE_SETTINGS_PATH")
	return override if not override.is_empty() else ProjectSettings.globalize_path("user://settings.json")

static func load_interval() -> Dictionary:
	var path: String = _path()
	if not FileAccess.file_exists(path): return {"ok": true, "interval": 0, "auto_skip_tutorial": false}
	var stream: FileAccess = FileAccess.open(path, FileAccess.READ)
	if stream == null: return {"ok": false, "reason": "InvalidSettings"}
	if stream.get_length() > 4096:
		stream.close()
		return {"ok": false, "reason": "InvalidSettings"}
	var parser := JSON.new()
	var parsed: Error = parser.parse(stream.get_as_text())
	stream.close()
	if parsed != OK or not parser.data is Dictionary:
		return {"ok": false, "reason": "InvalidSettings"}
	var value: Dictionary = parser.data
	var interval = value.get("autosaveInterval")
	if value.get("formatVersion") != 1 or not (interval is int or interval is float) or not is_finite(float(interval)) or floorf(float(interval)) != float(interval) or interval < 0 or interval > MAX_INTERVAL:
		return {"ok": false, "reason": "InvalidSettings"}
	var skip = value.get("autoSkipTutorial", false)
	if not skip is bool: return {"ok": false, "reason": "InvalidSettings"}
	return {"ok": true, "interval": int(interval), "auto_skip_tutorial": skip}

static func save_interval(interval: int) -> Dictionary:
	if interval < 0 or interval > MAX_INTERVAL:
		return {"ok": false, "reason": "InvalidSettings"}
	var current: Dictionary = load_interval()
	return _publish(interval, bool(current.get("auto_skip_tutorial", false)))

static func save_auto_skip_tutorial(enabled: bool) -> Dictionary:
	var current: Dictionary = load_interval()
	if not current.ok: return current
	return _publish(int(current.interval), enabled)

static func _publish(interval: int, skip: bool) -> Dictionary:
	var path: String = _path()
	var directory: String = path.get_base_dir()
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		return {"ok": false, "reason": "SettingsWriteFailed"}
	var disk = ClassDB.instantiate("FoundationDisk")
	var payload: String = JSON.stringify({"formatVersion": 1, "autosaveInterval": interval,
		"autoSkipTutorial": skip})
	if not SaveFiles.publish_file(directory, path.get_file(), payload, disk):
		return {"ok": false, "reason": "SettingsWriteFailed"}
	return {"ok": true}
