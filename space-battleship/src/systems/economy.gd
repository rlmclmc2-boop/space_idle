extends RefCounted
## These functions mutate the session's ledger only after Amount operations succeed.
## Death sampling and damage belong to the native kernel.

static func register_drops(pending: Dictionary, cursor: Dictionary, rows: Array, now: float, rules: Dictionary, amount_api) -> Dictionary:
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
	cursor.registered_through = next_frontier
	return {"ok": true}

static func collect_drop(pending: Dictionary, wallet: Dictionary, samples: Array, id: String, automatic: bool, auto_reduce: float, wall: float, game: float, amount_api) -> Dictionary:
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
	var zero = amount_api.apply("zero", [])
	result = amount_api.apply("add", [wallet.get(resource, zero.value), quantity])
	if not result.ok:
		return result
	# One completed collection: wallet, history and ownership change together.
	wallet[resource] = result.value
	samples.append({"resource": resource, "actual": quantity, "production_base": base,
		"wall": wall, "game": game, "source": row.income_source})
	while not samples.is_empty() and float(samples[0].wall) <= wall - 60.0 and float(samples[0].game) <= game - 60.0:
		samples.pop_front()
	pending.erase(id)
	return {"ok": true, "amount": quantity, "resource": resource}

static func collect_due(pending: Dictionary, wallet: Dictionary, samples: Array, auto_reduce: float, wall: float, game: float, amount_api, force: bool = false) -> Dictionary:
	# Stable birth order; collection never depends on Dictionary iteration order.
	var ids: Array = pending.keys()
	ids.sort_custom(func(a, b):
		var left: Dictionary = pending[a]
		var right: Dictionary = pending[b]
		if float(left.born_at) != float(right.born_at): return float(left.born_at) < float(right.born_at)
		if str(left.domain) != str(right.domain): return str(left.domain) < str(right.domain)
		return int(left.uid) < int(right.uid))
	for id in ids:
		if force or (not pending[id].get("moving", false) and float(pending[id].auto_at) <= game):
			var result = collect_drop(pending, wallet, samples, id, true, auto_reduce, wall, game, amount_api)
			if not result.ok:
				return result
	return {"ok": true}

static func spawn_timed_drop(pending: Dictionary, generator: Dictionary, resource: String,
		base_text: String, speed: float, resource_ratio: Dictionary, origin: Vector2,
		born_at: float, amount_api) -> Dictionary:
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
	var id: int = int(generator.next_id) + 1
	var key: String = "timed:" + str(id)
	pending[key] = {"domain": "timed", "uid": id, "id": resource,
		"amount": base.value, "production_base": base.value, "income_source": "timed_drop",
		"x": origin.x, "y": origin.y, "origin_y": origin.y, "born_at": born_at,
		"moving": true, "speed": speed}
	generator.next_id = id
	return {"ok": true}

static func advance_timed_drops(pending: Dictionary, wallet: Dictionary, samples: Array,
		target_y: float, auto_reduce: float, wall: float, game: float, amount_api) -> Dictionary:
	var ids: Array = pending.keys()
	ids.sort_custom(func(a, b): return int(pending[a].uid) < int(pending[b].uid))
	for key in ids:
		var row: Dictionary = pending[key]
		if not row.get("moving", false):
			continue
		row.y = minf(target_y, float(row.origin_y) + float(row.speed) * maxf(0.0, game - float(row.born_at)))
		if float(row.y) + 1e-9 >= target_y:
			row.y = target_y
			var result = collect_drop(pending, wallet, samples, str(key), true, auto_reduce, wall, game, amount_api)
			if not result.ok:
				return result
	return {"ok": true}
