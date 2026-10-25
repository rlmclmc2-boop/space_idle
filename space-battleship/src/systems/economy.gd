extends RefCounted
## These functions mutate the session's ledger only after Amount operations succeed.
## Death sampling and damage belong to the native kernel.

static func payment(wallet: Dictionary, costs: Dictionary, amount_api) -> Dictionary:
	var next: Dictionary = wallet.duplicate(true)
	var zero = amount_api.apply("zero", [])
	for resource in costs:
		var balance: Dictionary = wallet.get(resource, zero.value)
		var compared = amount_api.apply("compare", [balance, costs[resource]])
		if not compared.ok:
			return compared
		if compared.scalar < 0:
			return {"ok": false, "reason": "InsufficientResources"}
		var remaining = amount_api.apply("sub_nonnegative", [balance, costs[resource]])
		if not remaining.ok:
			return remaining
		next[resource] = remaining.value
	return {"ok": true, "wallet": next}

static func register_drops(pending: Dictionary, cursor: Dictionary, rows: Array, now: float, rules: Dictionary, amount_api, refinery: Dictionary) -> Dictionary:
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
	cursor.registered_through = next_frontier
	return {"ok": true}

static func collect_drop(pending: Dictionary, wallet: Dictionary, samples: Array, id: String, automatic: bool, auto_reduce: float, wall: float, game: float, amount_api, income_factors: Dictionary = {}) -> Dictionary:
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
	wallet[resource] = result.value
	samples.append({"resource": resource, "actual": quantity, "production_base": base,
		"wall": wall, "game": game, "source": row.income_source})
	pending.erase(id)
	return {"ok": true, "amount": quantity, "resource": resource}

static func collect_due(pending: Dictionary, wallet: Dictionary, samples: Array, auto_reduce: float, wall: float, game: float, amount_api, force: bool = false, income_factors: Dictionary = {}) -> Dictionary:
	# Stable birth order; collection never depends on Dictionary iteration order.
	var collected: bool = false
	var ids: Array = pending.keys()
	ids.sort_custom(func(a, b):
		var left: Dictionary = pending[a]
		var right: Dictionary = pending[b]
		if float(left.born_at) != float(right.born_at): return float(left.born_at) < float(right.born_at)
		if str(left.domain) != str(right.domain): return str(left.domain) < str(right.domain)
		return int(left.uid) < int(right.uid))
	for id in ids:
		if force or (not pending[id].get("moving", false) and float(pending[id].auto_at) <= game):
			var result = collect_drop(pending, wallet, samples, id, true, auto_reduce, wall, game, amount_api, income_factors)
			if not result.ok:
				return result
			collected = true
	return {"ok": true, "collected": collected}

static func spawn_timed_drop(pending: Dictionary, generator: Dictionary, resource: String,
		base_text: String, speed: float, resource_ratio: Dictionary, origin: Vector2,
		born_at: float, amount_api, refinery: Dictionary) -> Dictionary:
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
	return {"ok": true}

static func advance_timed_drops(pending: Dictionary, wallet: Dictionary, samples: Array,
		target_y: float, auto_reduce: float, wall: float, game: float, amount_api, income_factors: Dictionary = {}) -> Dictionary:
	var collected: bool = false
	var ids: Array = pending.keys()
	ids.sort_custom(func(a, b): return int(pending[a].uid) < int(pending[b].uid))
	for key in ids:
		var row: Dictionary = pending[key]
		if not row.get("moving", false):
			continue
		row.y = minf(target_y, float(row.origin_y) + float(row.speed) * maxf(0.0, game - float(row.born_at)))
		if float(row.y) + 1e-9 >= target_y:
			row.y = target_y
			var result = collect_drop(pending, wallet, samples, str(key), true, auto_reduce, wall, game, amount_api, income_factors)
			if not result.ok:
				return result
			collected = true
	return {"ok": true, "collected": collected}

static func prune_income(samples: Array, wall: float, game: float, window: float) -> void:
	while not samples.is_empty() and float(samples[0].wall) <= wall - window and float(samples[0].game) <= game - window:
		samples.pop_front()

static func income_rates(samples: Array, wall: float, game: float, window: float, kind: String, api) -> Dictionary:
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

static func credit_yield(wallet: Dictionary, samples: Array, resource: String, quantity: Dictionary, wall: float, game: float, api) -> Dictionary:
	var zero: Dictionary = api.apply("zero", []).value
	var total = api.apply("add", [wallet.get(resource, zero), quantity])
	if not total.ok:
		return total
	wallet[resource] = total.value
	samples.append({"resource": resource, "actual": quantity, "production_base": zero,
		"wall": wall, "game": game, "source": "galaxy_yield"})
	return {"ok": true}
