extends RefCounted
var _run_state
## Economy owns balances, drop ownership, timed production and income history.
signal display_changed

var _wallet: Dictionary = {}
var _drops: Dictionary = {}
var _markers: Dictionary = {}
var _cursor: Dictionary = {"registered_through": 0}
var _samples: Array = []
var _generator: Dictionary = {"elapsed": 0.0, "next_id": 0}
var _spec: PackedStringArray
var _rules: Dictionary
var _auto_reduce: float
var _api
var _income_dirty: bool = false
var _balance_dirty: bool = true
var _balance_text: String = ""

func _init(parameters: Dictionary, rules: Dictionary, api, run_state) -> void:
	_run_state = run_state
	_wallet.make_read_only()
	_spec = str(parameters.autoGenRes).replace("\uff0c", ",").split(",")
	_auto_reduce = float(parameters.autoCollectReduce)
	_rules = {"fragment_drop_auto_seconds": rules.fragment_drop_auto_seconds, "ordinary_drop_auto_seconds": rules.ordinary_drop_auto_seconds}
	_api = api

# A budget is a read-only snapshot; candidates duplicate its ledger and replace Amount values.
func budget() -> Dictionary:
	return _wallet

func accept_budget(next: Dictionary, notify: bool = true) -> bool:
	if not _run_state.is_running() or next == _wallet: return false
	_wallet = next.duplicate()
	_wallet.make_read_only()
	_balance_dirty = true
	if notify: display_changed.emit()
	return true

func publish_budget_change() -> void:
	display_changed.emit()

func affordable(costs: Dictionary, candidate = null) -> bool:
	return can_pay(costs, candidate).ok

func income_changed() -> bool:
	return _income_dirty

func acknowledge_income() -> void:
	if not _run_state.is_running(): return
	_income_dirty = false

func drop_markers() -> Array:
	var markers: Array = _markers.values()
	markers.make_read_only()
	return markers

func balances_text() -> String:
	if _balance_dirty:
		var balances: PackedStringArray = []
		for resource in _wallet:
			var text = _api.apply("to_display", [_wallet[resource]])
			balances.append(str(resource) + ": " + str(text.text))
		_balance_text = "   ".join(balances)
		_balance_dirty = false
	return _balance_text

func collect_at(point: Vector2, wall: float, game: float, factors: Dictionary) -> Dictionary:
	if not _run_state.is_running(): return _run_state.rejection()
	for id in _markers:
		var marker: Dictionary = _markers[id]
		if point.distance_to(Vector2(float(marker.x), float(marker.y))) <= 18.0:
			return collect_drop(str(id), false, wall, game, factors)
	return {"ok": false, "reason": "NoChange"}

func advance_timed(dt: float, active: bool, resource_ratio: Callable, origin: Vector2, target_y: float, wall: float, game: float, factors: Dictionary) -> Dictionary:
	if not _run_state.is_running(): return _run_state.rejection()
	if active:
		_generator.elapsed = float(_generator.elapsed) + dt
		var interval: float = float(_spec[0])
		while float(_generator.elapsed) + 1e-9 >= interval:
			var ratio: Dictionary = resource_ratio.call()
			if not ratio.ok: return ratio
			var remainder: float = maxf(0.0, float(_generator.elapsed) - interval)
			var spawned = _spawn_timed_drop(_spec[1], _spec[2], float(_spec[3]), ratio.value, origin, game - remainder, factors.refinery)
			if not spawned.ok: return spawned
			_generator.elapsed = remainder
	return _advance_timed_drops(target_y, wall, game, factors)

func can_pay(costs: Dictionary, candidate = null) -> Dictionary:
	var wallet: Dictionary = _wallet if candidate == null else candidate
	var amount_api = _api
	var zero = amount_api.apply("zero", [])
	for resource in costs:
		var balance: Dictionary = wallet.get(resource, zero.value)
		var compared = amount_api.apply("compare", [balance, costs[resource]])
		if not compared.ok:
			return compared
		if compared.scalar < 0:
			return {"ok": false, "reason": "InsufficientResources"}
	return {"ok": true}

func payment(costs: Dictionary, candidate = null) -> Dictionary:
	if not _run_state.is_running(): return _run_state.rejection()
	var wallet: Dictionary = _wallet if candidate == null else candidate
	if costs.is_empty(): return {"ok": true, "wallet": wallet}
	var amount_api = _api
	var affordable = can_pay(costs, candidate)
	if not affordable.ok:
		return affordable
	var next: Dictionary = wallet.duplicate()
	var zero = amount_api.apply("zero", [])
	for resource in costs:
		var balance: Dictionary = wallet.get(resource, zero.value)
		var remaining = amount_api.apply("sub_nonnegative", [balance, costs[resource]])
		if not remaining.ok:
			return remaining
		next[resource] = remaining.value
	return {"ok": true, "wallet": next}

func register_drops(rows: Array, now: float, refinery: Dictionary) -> Dictionary:
	if not _run_state.is_running(): return _run_state.rejection()
	var pending: Dictionary = _drops
	var cursor: Dictionary = _cursor
	var rules: Dictionary = _rules
	var amount_api = _api
	# Native emits monotonically increasing IDs through one synchronous result stream.
	# Keep only its registration frontier, plus the still-unclaimed drops themselves.
	var registered_through: int = int(cursor.registered_through)
	var next_frontier: int = registered_through
	var captured: Dictionary = {}
	for source in rows:
		var id: int = source.uid
		var key: String = "native:" + str(id)
		if id <= registered_through or pending.has(key) or captured.has(key):
			continue
		var row: Dictionary = source.duplicate(true)
		var quantity = amount_api.apply("from_decimal", [str(row.amount)])
		if not quantity.ok:
			return quantity
		var base = amount_api.apply("from_decimal", [str(row.get("production_base", row.amount))])
		if not base.ok:
			return base
		if str(row.id) in ["1", "2"]:
			quantity = amount_api.apply("mul", [quantity.value, refinery])
			if not quantity.ok:
				return quantity
			quantity = amount_api.apply("ceil", [quantity.value])
		row.domain = "native"
		row.income_source = "fragment_drop" if row.get("jewel", false) else "enemy_drop"
		row.amount = quantity.value
		row.production_base = base.value
		row.born_at = float(row.get("created_at", now))
		row.auto_at = float(row.born_at) + float(rules.fragment_drop_auto_seconds if row.get("jewel", false) else rules.ordinary_drop_auto_seconds)
		captured[key] = row
		next_frontier = maxi(next_frontier, id)
	for id in captured:
		pending[id] = captured[id]
		_markers[id] = {"x": captured[id].x, "y": captured[id].y, "resource": str(captured[id].id)}
		_markers[id].make_read_only()
	cursor.registered_through = next_frontier
	if not captured.is_empty(): display_changed.emit()
	return {"ok": true}

func collect_drop(id: String, automatic: bool, wall: float, game: float, income_factors: Dictionary = {}) -> Dictionary:
	if not _run_state.is_running(): return _run_state.rejection()
	var pending: Dictionary = _drops
	var wallet: Dictionary = _wallet
	var samples: Array = _samples
	var auto_reduce: float = _auto_reduce
	var amount_api = _api
	if not pending.has(id):
		return {"ok": false, "reason": "NoChange"}
	var row: Dictionary = pending[id]
	var resource: String = str(row.id)
	var quantity: Dictionary = row.amount
	var base: Dictionary = row.production_base
	var result: Dictionary
	if automatic and resource in ["1", "2"]:
		var loss_factor = amount_api.apply("from_decimal", [str(1.0 - auto_reduce)])
		if not loss_factor.ok:
			return loss_factor
		result = amount_api.apply("mul", [quantity, loss_factor.value])
		if not result.ok:
			return result
		result = amount_api.apply("ceil", [result.value])
		if not result.ok:
			return result
		quantity = result.value
		result = amount_api.apply("mul", [base, loss_factor.value])
		if not result.ok:
			return result
		result = amount_api.apply("ceil", [result.value])
		if not result.ok:
			return result
		base = result.value
	if resource == "jewel":
		for contribution in ["crew_fragments", "condensation", "galaxy_fragments"]:
			if not income_factors.has(contribution):
				continue
			result = amount_api.apply("mul", [quantity, income_factors[contribution]])
			if not result.ok:
				return result
			quantity = result.value
		# Ordinary fragments have no resource auto-collection loss.
		var factor = amount_api.apply("from_decimal", [str(row.get("jewelRatio", 1.0))])
		if not factor.ok:
			return factor
		result = amount_api.apply("mul", [quantity, factor.value])
		if not result.ok:
			return result
		var hundred = amount_api.apply("from_decimal", ["100"])
		var half = amount_api.apply("from_decimal", ["0.5"])
		result = amount_api.apply("mul", [result.value, hundred.value])
		if not result.ok:
			return result
		result = amount_api.apply("add", [result.value, half.value])
		if not result.ok:
			return result
		result = amount_api.apply("floor", [result.value])
		if not result.ok:
			return result
		result = amount_api.apply("div", [result.value, hundred.value])
		if not result.ok:
			return result
		quantity = result.value
	var effect: String = "iron" if resource == "1" else "uranium" if resource == "2" else "jewel" if resource == "jewel" else ""
	if income_factors.has(effect):
		result = amount_api.apply("mul", [quantity, income_factors[effect]])
		if not result.ok:
			return result
		quantity = result.value
		if resource != "jewel":
			result = amount_api.apply("ceil", [quantity])
			if not result.ok:
				return result
			quantity = result.value
	var zero = amount_api.apply("zero", [])
	result = amount_api.apply("add", [wallet.get(resource, zero.value), quantity])
	if not result.ok:
		return result
	# One completed collection: wallet, history and ownership change together.
	wallet = wallet.duplicate()
	wallet[resource] = result.value
	wallet.make_read_only()
	_wallet = wallet
	samples.append({"resource": resource, "actual": quantity, "production_base": base,
		"wall": wall, "game": game, "source": row.income_source})
	pending.erase(id)
	_markers.erase(id)
	_income_dirty = true
	_balance_dirty = true
	display_changed.emit()
	return {"ok": true, "amount": quantity, "resource": resource}

func collect_due(wall: float, game: float, force: bool = false, income_factors: Dictionary = {}) -> Dictionary:
	if not _run_state.is_running(): return _run_state.rejection()
	var pending: Dictionary = _drops
	# Stable birth order; collection never depends on Dictionary iteration order.
	var collected: bool = false
	var ids: Array = []
	for id in pending:
		if force or (not pending[id].get("moving", false) and float(pending[id].auto_at) <= game): ids.append(id)
	ids.sort_custom(func(a, b):
		var left: Dictionary = pending[a]
		var right: Dictionary = pending[b]
		if float(left.born_at) != float(right.born_at): return float(left.born_at) < float(right.born_at)
		if str(left.domain) != str(right.domain): return str(left.domain) < str(right.domain)
		return int(left.uid) < int(right.uid))
	for id in ids:
		var result = collect_drop(id, true, wall, game, income_factors)
		if not result.ok:
			return result
		collected = true
	return {"ok": true, "collected": collected}

func _spawn_timed_drop(resource: String, base_text: String, speed: float, resource_ratio: Dictionary, origin: Vector2, born_at: float, refinery: Dictionary) -> Dictionary:
	var pending: Dictionary = _drops
	var generator: Dictionary = _generator
	var amount_api = _api
	if int(generator.next_id) == 9223372036854775807:
		return {"ok": false, "reason": "TimedDropIdRangeExceeded"}
	var base = amount_api.apply("from_decimal", [base_text])
	if not base.ok:
		return base
	base = amount_api.apply("mul", [base.value, resource_ratio])
	if not base.ok:
		return base
	base = amount_api.apply("ceil", [base.value])
	if not base.ok:
		return base
	var quantity = amount_api.apply("mul", [base.value, refinery])
	if not quantity.ok:
		return quantity
	quantity = amount_api.apply("ceil", [quantity.value])
	if not quantity.ok:
		return quantity
	var id: int = int(generator.next_id) + 1
	var key: String = "timed:" + str(id)
	pending[key] = {"domain": "timed", "uid": id, "id": resource,
		"amount": quantity.value, "production_base": base.value, "income_source": "timed_drop",
		"x": origin.x, "y": origin.y, "origin_y": origin.y, "born_at": born_at,
		"moving": true, "speed": speed}
	generator.next_id = id
	_markers[key] = {"x": origin.x, "y": origin.y, "resource": resource}
	_markers[key].make_read_only()
	display_changed.emit()
	return {"ok": true}

func _advance_timed_drops(target_y: float, wall: float, game: float, income_factors: Dictionary = {}) -> Dictionary:
	var pending: Dictionary = _drops
	var collected: bool = false
	var ids: Array = pending.keys()
	# Timed IDs are inserted monotonically; erasure preserves their insertion order.
	for key in ids:
		var row: Dictionary = pending[key]
		if not row.get("moving", false):
			continue
		var previous_y: float = float(row.y)
		row.y = minf(target_y, float(row.origin_y) + float(row.speed) * maxf(0.0, game - float(row.born_at)))
		if float(row.y) != previous_y:
			var marker: Dictionary = _markers[key].duplicate()
			marker.y = row.y
			marker.make_read_only()
			_markers[key] = marker
			display_changed.emit()
		if float(row.y) + 1e-9 >= target_y:
			row.y = target_y
			var result = collect_drop(str(key), true, wall, game, income_factors)
			if not result.ok:
				return result
			collected = true
	return {"ok": true, "collected": collected}

func prune_income(wall: float, game: float, window: float) -> void:
	if not _run_state.is_running(): return
	var samples: Array = _samples
	while not samples.is_empty() and float(samples[0].wall) <= wall - window and float(samples[0].game) <= game - window:
		samples.pop_front()

func income_rates(wall: float, game: float, window: float, kind: String) -> Dictionary:
	var samples: Array = _samples
	var api = _api
	if kind not in ["peak", "investment", "production"]:
		return {"ok": false, "reason": "UnknownIncomeQuery"}
	var zero: Dictionary = api.apply("zero", []).value
	var rates: Dictionary = {"1": zero, "2": zero}
	if kind != "production":
		rates.jewel = zero
	var field: String = "production_base" if kind == "production" else "actual"
	var clock: String = "wall" if kind == "peak" else "game"
	var now: float = wall if kind == "peak" else game
	for sample in samples:
		if not rates.has(sample.resource) or float(sample[clock]) <= now - window or float(sample[clock]) > now:
			continue
		if sample.source not in ["enemy_drop", "timed_drop", "fragment_drop"] and not (kind == "investment" and sample.source == "galaxy_yield"):
			continue
		var sum = api.apply("add", [rates[sample.resource], sample[field]])
		if not sum.ok:
			return sum
		rates[sample.resource] = sum.value
	var duration = api.apply("from_decimal", [str(window)])
	if not duration.ok:
		return duration
	for resource in rates:
		var rate = api.apply("div", [rates[resource], duration.value])
		if not rate.ok:
			return rate
		rates[resource] = rate.value
	return {"ok": true, "rates": rates}

func credit_yield(resource: String, quantity: Dictionary, wall: float, game: float, notify: bool = true) -> Dictionary:
	if not _run_state.is_running(): return _run_state.rejection()
	var wallet: Dictionary = _wallet
	var samples: Array = _samples
	var api = _api
	var zero: Dictionary = api.apply("zero", []).value
	if api.apply("compare", [quantity, zero]).scalar <= 0:
		return {"ok": true, "credited": false}
	var total = api.apply("add", [wallet.get(resource, zero), quantity])
	if not total.ok:
		return total
	wallet = wallet.duplicate()
	wallet[resource] = total.value
	wallet.make_read_only()
	_wallet = wallet
	_balance_dirty = true
	samples.append({"resource": resource, "actual": quantity, "production_base": zero,
		"wall": wall, "game": game, "source": "galaxy_yield"})
	if notify: display_changed.emit()
	return {"ok": true, "credited": true}
