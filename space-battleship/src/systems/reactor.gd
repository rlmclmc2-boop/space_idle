extends RefCounted

signal choices_changed

var _state: Dictionary
var _parameters: Dictionary = {}
var _api

func _init(parameters: Dictionary, api) -> void:
	for key in parameters:
		if str(key).begins_with("reactor"): _parameters[key] = parameters[key]
	_api = api
	_state = _initial(_parameters)

func panel_options(inputs: Dictionary) -> Array:
	var labels := {"weapons": "武器", "defence": "防御", "smelting": "冶炼", "condensation": "碎片凝结"}
	var enabled: Array = enabled_modules(inputs)
	var options: Array = []
	for id in str(_parameters.reactorModules).split(","):
		options.append({"id": id, "name": str(labels.get(id, id)), "enabled": id in enabled})
	return options

func enabled_modules(inputs: Dictionary) -> Array:
	var enabled: Array = []
	if inputs.available:
		for module in str(_parameters.reactorModules).split(","):
			if module != "condensation" or inputs.condensation: enabled.append(module)
	return enabled

func modules_changed(inputs: Dictionary) -> bool:
	return _state.get("_enabled", []) != enabled_modules(inputs)

# The candidate carries module-private state until native publication succeeds.
func prepare(inputs: Dictionary) -> Dictionary:
	return _evaluate(_state, _parameters, enabled_modules(inputs), _api, inputs.capacity, inputs.free_charge)

func _adopt(next: Dictionary) -> void:
	var changed: bool = _state.get("_enabled", []) != next.get("_enabled", [])
	_state = next
	if changed: choices_changed.emit()

func accept(candidate: Dictionary) -> void:
	if candidate.has("state"): _adopt(candidate.state)

func _submit(next: Dictionary, inputs: Dictionary, costs: Dictionary, kind: String, publish: Callable) -> Dictionary:
	var candidate = _evaluate(next, _parameters, enabled_modules(inputs), _api, inputs.capacity, inputs.free_charge)
	if not candidate.ok: return candidate
	var result: Dictionary = publish.call(candidate.factors, costs, kind)
	if result.ok: _adopt(candidate.state)
	return result

func purchase(count: int, automatic: bool, inputs: Dictionary, publish: Callable) -> Dictionary:
	if not inputs.available: return {"ok": false, "reason": "ReactorLocked"}
	var changed = _purchase(_state, count, automatic, _parameters, _api)
	if not changed.ok: return changed
	return _submit(changed.state, inputs, changed.costs, "growth", publish)

func allocate_text(module: String, text: String, inputs: Dictionary, publish: Callable) -> Dictionary:
	var quantity = _api.apply("from_decimal", [text])
	if not quantity.ok: return quantity
	var changed = _allocate(_state, module, quantity.value, _parameters, enabled_modules(inputs), _api, inputs.capacity)
	if not changed.ok: return changed
	return _submit(changed.state, inputs, {}, "selection", publish)

func distribute(inputs: Dictionary, publish: Callable) -> Dictionary:
	var changed = _distribute(_state, _parameters, enabled_modules(inputs), _api, inputs.capacity)
	if not changed.ok: return changed
	return _submit(changed.state, inputs, {}, "selection", publish)

func refresh(inputs: Dictionary, publish: Callable) -> Dictionary:
	return _submit(_state, inputs, {}, "growth", publish)

static func _initial(parameters: Dictionary) -> Dictionary:
	return {"level": int(parameters.reactorInitialLevel), "allocations": {}, "free_charge": 0.0}

static func _quote(state: Dictionary, count: int, parameters: Dictionary, api) -> Dictionary:
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

static func _capacity(state: Dictionary, parameters: Dictionary, api, capacity_factor: Dictionary) -> Dictionary:
	var cached: Dictionary = state.get("_capacity", {})
	if cached.get("level") == state.level and cached.get("factor") == capacity_factor:
		return {"ok": true, "value": cached.value}
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
	state._capacity = {"level": state.level, "factor": capacity_factor, "value": capacity.value}
	return capacity

static func _evaluate(state: Dictionary, parameters: Dictionary, enabled: Array, api, capacity_factor: Dictionary, free_bonus: float) -> Dictionary:
	if state.get("_distribute", false):
		var distributed = _distribute(state, parameters, enabled, api, capacity_factor)
		if not distributed.ok: return distributed
		state = distributed.state
		state.erase("_distribute")
	var capacity = _capacity(state, parameters, api, capacity_factor)
	if not capacity.ok: return capacity
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
	var cached: Dictionary = state.get("_factors", {})
	var next_cache: Dictionary = {}
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
		var free_charge: Dictionary = free.value if module in enabled else zero.value
		var previous: Dictionary = cached.get(module, {})
		if previous.get("assigned") == assigned.value and previous.get("free") == free_charge:
			factors[module] = previous.value
			next_cache[module] = previous
			continue
		var charged = api.apply("add", [assigned.value, free_charge])
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
		next_cache[module] = {"assigned": assigned.value, "free": free_charge, "value": charged.value}
	var next: Dictionary = state.duplicate()
	next.allocations = allocations
	next._factors = next_cache
	next._enabled = enabled.duplicate()
	return {"ok": true, "state": next, "capacity": capacity.value, "remaining": remaining, "factors": factors}

static func _allocate(state: Dictionary, module: String, requested: Dictionary, parameters: Dictionary, enabled: Array, api, capacity_factor: Dictionary) -> Dictionary:
	if module not in enabled:
		return {"ok": false, "reason": "ReactorModuleLocked"}
	var value = api.apply("floor", [requested])
	if not value.ok: return value
	var capacity = _capacity(state, parameters, api, capacity_factor)
	if not capacity.ok: return capacity
	var remaining: Dictionary = capacity.value
	var zero: Dictionary = api.apply("zero", []).value
	var allocations: Dictionary = {}
	for key in str(parameters.reactorModules).split(","):
		var assigned = api.apply("min", [state.allocations.get(key, zero) if key != module and key in enabled else zero, remaining])
		if not assigned.ok: return assigned
		allocations[key] = assigned.value
		var left = api.apply("sub_nonnegative", [remaining, assigned.value])
		if not left.ok: return left
		remaining = left.value
	value = api.apply("min", [value.value, remaining])
	if not value.ok: return value
	var next: Dictionary = state.duplicate(true)
	next.allocations = allocations
	next.allocations[module] = value.value
	return {"ok": true, "state": next}

static func _distribute(state: Dictionary, parameters: Dictionary, enabled: Array, api, capacity_factor: Dictionary) -> Dictionary:
	if enabled.is_empty():
		return {"ok": false, "reason": "ReactorModuleLocked"}
	var current = _capacity(state, parameters, api, capacity_factor)
	if not current.ok:
		return current
	var divisor = api.apply("from_decimal", [str(enabled.size())])
	var share = api.apply("div", [current.value, divisor.value])
	if not share.ok:
		return share
	share = api.apply("floor", [share.value])
	if not share.ok:
		return share
	var used = api.apply("mul", [share.value, divisor.value])
	var extra = api.apply("sub_nonnegative", [current.value, used.value])
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

static func _purchase(state: Dictionary, count: int, automatic: bool, parameters: Dictionary, api) -> Dictionary:
	var quoted = _quote(state, count, parameters, api)
	if not quoted.ok: return quoted
	if int(state.level) > 9223372036854775807 - count:
		return {"ok": false, "reason": "ReactorLevelRangeExceeded"}
	var next: Dictionary = state.duplicate(true)
	next.level = int(next.level) + count
	if automatic: next._distribute = true
	return {"ok": true, "state": next, "costs": quoted.costs}
