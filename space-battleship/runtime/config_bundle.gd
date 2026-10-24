extends RefCounted
## Session owns one immutable bundle identity. Queries return detached copies.
var semantic_hash: String
var schema_version: int
var _data: Dictionary

static func open_active(path: String) -> Dictionary:
	var pointer = JSON.parse_string(FileAccess.get_file_as_string(path.path_join("active-manifest.json")))
	if not pointer is Dictionary or not pointer.get("bundle") is String:
		return {"ok": false, "error": "ConfigPointer"}
	if not pointer.bundle.begins_with("versions/") or ".." in pointer.bundle or "\\" in pointer.bundle:
		return {"ok": false, "error": "ConfigPointer"}
	var text := FileAccess.get_file_as_string(path.path_join(pointer.bundle))
	if text.sha256_text() != pointer.get("checksum", ""):
		return {"ok": false, "error": "ConfigChecksum"}
	var data = JSON.parse_string(text)
	if not data is Dictionary or data.get("schemaVersion") != 1 or data.get("semanticHash") != pointer.get("semanticHash"):
		return {"ok": false, "error": "ConfigSchema"}
	var bundle = load("res://runtime/config_bundle.gd").new()
	bundle._data = data
	bundle.semantic_hash = data.semanticHash
	bundle.schema_version = int(data.schemaVersion)
	return {"ok": true, "bundle": bundle}

func rows(table: String) -> Array:
	return _data.tables.get(table, []).duplicate(true)

func lookup(table: String, primary: Array) -> Dictionary:
	var index = _data.indices.get(table, {}).get(JSON.stringify(primary), null)
	return {} if index == null else _data.tables[table][int(index)].duplicate(true)
