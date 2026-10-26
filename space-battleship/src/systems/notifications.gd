extends RefCounted

signal changed

const TOPICS := ["unlock", "research", "hyperspace"]
var _entries: Dictionary = {}

func save_state() -> Dictionary:
	return {"entries": _entries.duplicate(true)}

func restore_state(state: Dictionary) -> Dictionary:
	if not state.get("entries") is Dictionary:
		return {"ok": false, "reason": "InvalidNotificationState"}
	for key in state.entries:
		if not key is String or not state.entries[key] is Dictionary:
			return {"ok": false, "reason": "InvalidNotification"}
		var row: Dictionary = state.entries[key]
		if not row.get("topic") in TOPICS or not row.get("id") is String or row.id.is_empty() or key != str(row.topic) + ":" + row.id or not row.get("seen") is bool or not row.get("read") is bool:
			return {"ok": false, "reason": "InvalidNotification"}
	_entries = state.entries.duplicate(true)
	return {"ok": true}

func record(topic: String, id: String) -> Dictionary:
	if topic not in TOPICS or id.is_empty(): return {"ok": false, "reason": "InvalidNotification"}
	var key: String = topic + ":" + id
	if _entries.has(key): return {"ok": true, "created": false}
	_entries[key] = {"topic": topic, "id": id, "seen": false, "read": false}
	changed.emit()
	return {"ok": true, "created": true}

func mark_seen(key: String) -> Dictionary:
	if not _entries.has(key): return {"ok": false, "reason": "UnknownNotification"}
	_entries[key].seen = true
	changed.emit()
	return {"ok": true}

func mark_read(key: String) -> Dictionary:
	if not _entries.has(key): return {"ok": false, "reason": "UnknownNotification"}
	_entries[key].read = true
	changed.emit()
	return {"ok": true}

func entries() -> Array:
	var output: Array = []
	for key in _entries:
		var row: Dictionary = _entries[key].duplicate()
		row.key = key
		output.append(row)
	return output

func unread(topic: String = "") -> int:
	var count: int = 0
	for row in _entries.values():
		if (topic.is_empty() or row.topic == topic) and not row.read: count += 1
	return count
