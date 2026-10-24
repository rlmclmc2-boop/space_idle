extends RefCounted
## These functions mutate the session's ledger only after Amount operations succeed.
## Death sampling and damage belong to the native kernel.

static func register_drops(pending: Dictionary, claimed: Dictionary, rows: Array, now: float, rules: Dictionary, amount_api) -> Dictionary:
	var captured: Dictionary = {}
	for source in rows:
		var id: int = source.uid
		if pending.has(id) or claimed.has(id):
			continue
		var row: Dictionary = source.duplicate(true)
		var quantity = amount_api.apply("from_decimal", [str(row.amount)])
		if not quantity.ok:
			return quantity
		var base = amount_api.apply("from_decimal", [str(row.get("production_base", row.amount))])
		if not base.ok:
			return base
		row.amount = quantity.value
		row.production_base = base.value
		row.born_at = float(row.get("created_at", now))
		row.auto_at = float(row.born_at) + float(rules.fragment_drop_auto_seconds if row.get("jewel", false) else rules.ordinary_drop_auto_seconds)
		captured[id] = row
	for id in captured:
		pending[id] = captured[id]
	return {"ok": true}

static func collect_drop(pending: Dictionary, claimed: Dictionary, wallet: Dictionary, samples: Array, id: int, automatic: bool, auto_reduce: float, wall: float, game: float, amount_api) -> Dictionary:
	if claimed.has(id) or not pending.has(id):
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
		"wall": wall, "game": game, "source": "fragment_drop" if resource == "jewel" else "enemy_drop"})
	while not samples.is_empty() and float(samples[0].wall) <= wall - 60.0 and float(samples[0].game) <= game - 60.0:
		samples.pop_front()
	claimed[id] = true
	pending.erase(id)
	return {"ok": true, "amount": quantity, "resource": resource}

static func collect_due(pending: Dictionary, claimed: Dictionary, wallet: Dictionary, samples: Array, auto_reduce: float, wall: float, game: float, amount_api, force: bool = false) -> Dictionary:
	# Stable birth order; collection never depends on Dictionary iteration order.
	var ids: Array = pending.keys()
	ids.sort()
	for id in ids:
		if force or float(pending[id].auto_at) <= game:
			var result = collect_drop(pending, claimed, wallet, samples, id, true, auto_reduce, wall, game, amount_api)
			if not result.ok:
				return result
	return {"ok": true}
