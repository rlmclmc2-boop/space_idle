extends RefCounted

static func initial(parameters: Dictionary) -> Dictionary:
	return {"level": int(parameters.reactorInitialLevel), "allocations": {}, "free_charge": 0.0}

static func quote(state: Dictionary, count: int, parameters: Dictionary, api) -> Dictionary:
	if count < 1:
		return {"ok": false, "reason": "InvalidPurchaseCount"}
	var base = api.apply("from_decimal", [str(parameters.reactorUpgradeBase)])
	if not base.ok:
		return base
	# The level-L reactor buys its next level at base * growth^(L-1).
	var result = api.apply("sum_ceiled_geometric", [base.value, float(parameters.reactorUpgradeGrowth), str(int(state.level) - 1), str(count)])
	if not result.ok:
		return result
	return {"ok": true, "costs": {str(int(parameters.reactorUraniumId)): result.value}, "count": count, "extreme": result.extreme}

static func evaluate(state: Dictionary, parameters: Dictionary, enabled: Array, api, capacity_factor: Dictionary, free_bonus: float) -> Dictionary:
	var base = api.apply("from_decimal", [str(parameters.reactorEnergyBase)])
	var growth = api.apply("from_decimal", [str(parameters.reactorEnergyGrowth)])
	for result in [base, growth]:
		if not result.ok:
			return result
	growth = api.apply("pow", [growth.value, int(state.level) - 1])
	if not growth.ok:
		return growth
	var capacity = api.apply("mul", [base.value, growth.value])
	if not capacity.ok:
		return capacity
	capacity = api.apply("mul", [capacity.value, capacity_factor])
	if not capacity.ok:
		return capacity
	capacity = api.apply("floor", [capacity.value])
	if not capacity.ok:
		return capacity
	var zero = api.apply("zero", [])
	var one = api.apply("from_decimal", ["1"])
	var scale = api.apply("from_decimal", [str(parameters.reactorPercentScale)])
	var free = api.apply("from_decimal", [str(float(state.free_charge) + free_bonus)])
	free = api.apply("mul", [free.value, capacity.value])
	if not free.ok:
		return free
	var remaining: Dictionary = capacity.value
	var allocations: Dictionary = {}
	var factors: Dictionary = {}
	for module in str(parameters.reactorModules).split(","):
		var requested: Dictionary = state.allocations.get(module, zero.value) if module in enabled else zero.value
		var assigned = api.apply("min", [requested, remaining])
		if not assigned.ok:
			return assigned
		allocations[module] = assigned.value
		var left = api.apply("sub_nonnegative", [remaining, assigned.value])
		if not left.ok:
			return left
		remaining = left.value
		var charged = api.apply("add", [assigned.value, free.value if module in enabled else zero.value])
		if not charged.ok:
			return charged
		charged = api.apply("pow", [charged.value, float(parameters.reactorBoostExponent)])
		if not charged.ok:
			return charged
		charged = api.apply("div", [charged.value, scale.value])
		if not charged.ok:
			return charged
		charged = api.apply("add", [one.value, charged.value])
		if not charged.ok:
			return charged
		factors[module] = charged.value
	return {"ok": true, "capacity": capacity.value, "remaining": remaining, "allocations": allocations, "factors": factors}

static func allocate(state: Dictionary, module: String, requested: Dictionary, parameters: Dictionary, enabled: Array, api, capacity_factor: Dictionary, free_bonus: float) -> Dictionary:
	if module not in enabled:
		return {"ok": false, "reason": "ReactorModuleLocked"}
	var next: Dictionary = state.duplicate(true)
	var value = api.apply("floor", [requested])
	if not value.ok:
		return value
	next.allocations.erase(module)
	var current = evaluate(next, parameters, enabled, api, capacity_factor, free_bonus)
	if not current.ok:
		return current
	value = api.apply("min", [value.value, current.remaining])
	if not value.ok:
		return value
	next.allocations = current.allocations
	next.allocations[module] = value.value
	return {"ok": true, "state": next}

static func distribute(state: Dictionary, parameters: Dictionary, enabled: Array, api, capacity_factor: Dictionary, free_bonus: float) -> Dictionary:
	if enabled.is_empty():
		return {"ok": false, "reason": "ReactorModuleLocked"}
	var current = evaluate(state, parameters, enabled, api, capacity_factor, free_bonus)
	if not current.ok:
		return current
	var divisor = api.apply("from_decimal", [str(enabled.size())])
	var share = api.apply("div", [current.capacity, divisor.value])
	if not share.ok:
		return share
	share = api.apply("floor", [share.value])
	if not share.ok:
		return share
	var used = api.apply("mul", [share.value, divisor.value])
	var extra = api.apply("sub_nonnegative", [current.capacity, used.value])
	var one = api.apply("from_decimal", ["1"])
	var next: Dictionary = state.duplicate(true)
	next.allocations = {}
	for module in str(parameters.reactorModules).split(","):
		if module not in enabled:
			continue
		var balance: Dictionary = share.value
		if api.apply("compare", [extra.value, one.value]).scalar >= 0:
			var increment = api.apply("add", [balance, one.value])
			if not increment.ok:
				return increment
			balance = increment.value
			extra = api.apply("sub_nonnegative", [extra.value, one.value])
		next.allocations[module] = balance
	return {"ok": true, "state": next}
