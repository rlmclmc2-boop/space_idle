extends RefCounted

const SaveFiles = preload("res://foundation/host/save_files.gd")
const MAX_INTERVAL: int = 86400
const DAMAGE_MODES: Array[String] = ["all", "critical", "off"]
const PAGES: Array[String] = ["battle", "growth"]

static func _path() -> String:
	var override: String = OS.get_environment("SPACE_IDLE_SETTINGS_PATH")
	return override if not override.is_empty() else ProjectSettings.globalize_path("user://settings.json")

static func defaults() -> Dictionary:
	return {"ok": true, "interval": 0, "auto_skip_tutorial": false,
		"music_enabled": true, "effects_enabled": true, "damage_mode": "all", "page": "battle"}

static func load_interval() -> Dictionary:
	var path: String = _path()
	if not FileAccess.file_exists(path): return defaults()
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
	var result: Dictionary = defaults()
	result.interval = int(interval)
	var fields := {"autoSkipTutorial": "auto_skip_tutorial", "musicEnabled": "music_enabled", "effectsEnabled": "effects_enabled"}
	for key in fields:
		var flag = value.get(key, result[fields[key]])
		if not flag is bool: return {"ok": false, "reason": "InvalidSettings"}
		result[fields[key]] = flag
	var mode = value.get("damageMode", "all")
	var page = value.get("preferredPage", "battle")
	if not mode is String or not DAMAGE_MODES.has(mode) or not page is String or not PAGES.has(page):
		return {"ok": false, "reason": "InvalidSettings"}
	result.damage_mode = mode
	result.page = page
	return result

static func save_interval(interval: int) -> Dictionary:
	var current: Dictionary = load_interval()
	if not current.ok: current = defaults()
	current.interval = interval
	return _publish(current)

static func save_auto_skip_tutorial(enabled: bool) -> Dictionary:
	return save_change("auto_skip_tutorial", enabled)

static func save_change(key: String, value: Variant) -> Dictionary:
	var current: Dictionary = load_interval()
	if not current.ok: return current
	if not current.has(key): return {"ok": false, "reason": "InvalidSettings"}
	current[key] = value
	return _publish(current)

static func reset() -> Dictionary:
	return _publish(defaults())

static func _publish(settings: Dictionary) -> Dictionary:
	var interval = settings.get("interval")
	var mode = settings.get("damage_mode")
	var page = settings.get("page")
	if not interval is int or interval < 0 or interval > MAX_INTERVAL or not mode is String or not DAMAGE_MODES.has(mode) or not page is String or not PAGES.has(page):
		return {"ok": false, "reason": "InvalidSettings"}
	for key in ["auto_skip_tutorial", "music_enabled", "effects_enabled"]:
		if not settings.get(key) is bool: return {"ok": false, "reason": "InvalidSettings"}
	var path: String = _path()
	var directory: String = path.get_base_dir()
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		return {"ok": false, "reason": "SettingsWriteFailed"}
	var disk = ClassDB.instantiate("FoundationDisk")
	var payload: String = JSON.stringify({"formatVersion": 1, "autosaveInterval": interval,
		"autoSkipTutorial": settings.auto_skip_tutorial, "musicEnabled": settings.music_enabled,
		"effectsEnabled": settings.effects_enabled, "damageMode": mode, "preferredPage": page})
	if not SaveFiles.publish_file(directory, path.get_file(), payload, disk):
		return {"ok": false, "reason": "SettingsWriteFailed"}
	return {"ok": true}
