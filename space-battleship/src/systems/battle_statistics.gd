extends RefCounted
const PlayerText = preload("res://src/ui/player_text.gd")
var _run_state
signal changed
var _totals: Dictionary = {}
var _api
var _dirty: bool = true
var _text: String = ""
var _rows: Array = []
var _source_names: Dictionary = {}
var _drone_count: int = 0

func _init(api, run_state) -> void:
	_run_state = run_state
	_api = api

# Preserve the existing per-native-advance Amount aggregation order.
func record(rows: Array) -> Dictionary:
	if not _run_state.is_running(): return _run_state.rejection()
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


func _source_name(source: String) -> String:
	if _source_names.has(source): return str(_source_names[source])
	var name: String = "其他伤害"
	if source.begins_with("module:") and source.trim_prefix("module:").is_valid_int():
		name = "武器%d" % (source.trim_prefix("module:").to_int() + 1)
	elif source.begins_with("drone:"):
		_drone_count += 1
		name = "无人机%d" % _drone_count
	_source_names[source] = name
	return name

func _display_amount(value: Dictionary) -> String:
	return PlayerText.number(str(_api.apply("to_display", [value]).text))

func _refresh_display() -> void:
	if not _dirty: return
	_rows = []
	var grand: Dictionary = _api.apply("zero", []).value
	var leader: String = ""
	var leader_total: Dictionary = grand
	for source in _totals:
		var entry: Dictionary = _totals[source]
		var total: Dictionary = _api.apply("add", [entry.shield, entry.health]).value
		grand = _api.apply("add", [grand, total]).value
		var name: String = _source_name(str(source))
		_rows.append({"name": name, "total": _display_amount(total),
			"shield": _display_amount(entry.shield), "armour": _display_amount(entry.health)})
		if leader.is_empty() or _api.apply("compare", [total, leader_total]).scalar > 0:
			leader = name
			leader_total = total
	_text = "累计伤害 " + _display_amount(grand) + (" · 主力 " + leader if not leader.is_empty() else "")
	_dirty = false

func display_text() -> String:
	_refresh_display()
	return _text if not _totals.is_empty() else ""

func display_rows() -> Array:
	_refresh_display()
	return _rows.duplicate(true)
