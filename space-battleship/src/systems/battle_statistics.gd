extends RefCounted
signal changed
var _totals: Dictionary = {}
var _api
var _dirty: bool = true
var _text: String = ""

func _init(api) -> void:
	_api = api

# Preserve the existing per-native-advance Amount aggregation order.
func record(rows: Array) -> Dictionary:
	for source in rows:
		var key: String = str(source.source)
		var previous: Dictionary = _totals.get(key, {"shield": _api.apply("zero", []).value, "health": _api.apply("zero", []).value})
		for field in ["shield", "health"]:
			var value = _api.apply("from_decimal", [str(source[field])])
			if not value.ok:
				return value
			var total = _api.apply("add", [previous[field], value.value])
			if not total.ok:
				return total
			previous[field] = total.value
		_totals[key] = previous
	if not rows.is_empty():
		_dirty = true
		changed.emit()
	return {"ok": true}

func display_text() -> String:
	if _dirty:
		var statistics: PackedStringArray = []
		for source in _totals:
			var entry: Dictionary = _totals[source]
			var total = _api.apply("add", [entry.shield, entry.health])
			var text = _api.apply("to_display", [total.value])
			statistics.append(str(source) + " " + str(text.text))
		_text = "  ".join(statistics)
		_dirty = false
	return _text
