extends RefCounted

const EVENTS := ["equip", "upgrade", "pickup", "retreat", "clear"]
var _completed: Dictionary = {}
var _seen: Dictionary = {}

func save_state() -> Dictionary:
	return {"completed": _completed.duplicate(), "seen": _seen.duplicate()}

func restore_state(state: Dictionary) -> Dictionary:
	if not state.get("completed") is Dictionary or not state.get("seen") is Dictionary:
		return {"ok": false, "reason": "InvalidTutorialState"}
	for group in [state.completed, state.seen]:
		for key in group:
			if not key is String or key not in EVENTS or group[key] != true:
				return {"ok": false, "reason": "InvalidTutorialState"}
	for key in state.seen:
		if not state.completed.has(key): return {"ok": false, "reason": "InvalidTutorialState"}
	_completed = state.completed.duplicate()
	_seen = state.seen.duplicate()
	return {"ok": true}

func record(event: String) -> bool:
	if event not in EVENTS or _completed.has(event): return false
	_completed[event] = true
	return true

func next_prompt() -> String:
	for event in EVENTS:
		if _completed.has(event) and not _seen.has(event): return event
	return ""

func mark_seen(event: String) -> Dictionary:
	if event != next_prompt(): return {"ok": false, "reason": "TutorialPromptMismatch"}
	_seen[event] = true
	return {"ok": true}

func completed(event: String) -> bool:
	return _completed.has(event)
