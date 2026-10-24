extends RefCounted

var semantic_hash: String
var _document: Dictionary

static func open(directory: String) -> Dictionary:
	var pointer = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("active.json")))
	if not pointer is Dictionary or not pointer.get("bundle") is String:
		return {"ok": false, "error": "ConfigPointer"}
	if not pointer.bundle.begins_with("versions/") or ".." in pointer.bundle or "\\" in pointer.bundle:
		return {"ok": false, "error": "ConfigPointer"}
	var raw := FileAccess.get_file_as_string(directory.path_join(pointer.bundle))
	if raw.sha256_text() != pointer.get("checksum"):
		return {"ok": false, "error": "ConfigChecksum"}
	var parsed = JSON.parse_string(raw)
	if not parsed is Dictionary or parsed.get("schemaVersion") != 1 or parsed.get("semanticHash") != pointer.get("semanticHash"):
		return {"ok": false, "error": "ConfigVersion"}
	var instance = load("res://host/config_bundle.gd").new()
	instance._document = parsed
	instance.semantic_hash = parsed.semanticHash
	return {"ok": true, "bundle": instance}

func rows(table: String) -> Array:
	return _document.tables.get(table, []).duplicate(true)

func lookup(table: String, primary: Array) -> Dictionary:
	var ordinal = _document.indices.get(table, {}).get(JSON.stringify(primary))
	return {} if ordinal == null else _document.tables[table][int(ordinal)].duplicate(true)

func origin(table: String, primary: Array, field: String) -> Dictionary:
	return _document.provenance.get(table, {}).get(JSON.stringify(primary), {}).get(field, {}).duplicate(true)
