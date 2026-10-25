extends RefCounted
var _reason: String = ""

func is_running() -> bool:
	return _reason.is_empty()

func fail(reason: String) -> void:
	if _reason.is_empty(): _reason = reason

func reason() -> String:
	return _reason

func rejection() -> Dictionary:
	return {"ok": false, "reason": "SessionUnavailable", "error": _reason}
