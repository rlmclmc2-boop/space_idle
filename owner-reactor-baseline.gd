extends RefCounted
var _run_state

signal choices_changed
signal presentation_changed(changes: PackedStringArray)

var _enabled: Array = []
var _available: bool = false
var _state: Dictionary
var _prepared_state: Dictionary = {}
var _parameters: Dictionary = {}
var _api
var _plan_preview_cache: Dictionary = {}
var _presentation_queued: bool = false
var _presentation_before: Dictionary = {}
var _purchase_preview_level: int = -1
var _purchase_preview_quotes: Dictionary = {}

func save_state() -> Dictionary:
	var state: Dictionary = _state.duplicate(true)
	state.erase("_capacity")
	state.erase("_enabled")
	return state

func restore_state(state: Dictionary) -> Dictionary:
	if not state.get("level") is int or int(state.level) < int(_parameters.reactorInitialLevel) or not state.get("free_charge") is float or not is_finite(state.free_charge) or state.free_charge < 0.0 or not state.get("allocations") is Dictionary:
		return {"ok": false, "reason": "InvalidReactorState"}
	var valid: PackedStringArray = str(_parameters.reactorModules).split(",")
	var zero: Dictionary = _api.apply("zero", []).value
	for module in state.allocations:
		if not module is String or module not in valid or not state.allocations[module] is Dictionary:
			return {"ok": false, "reason": "InvalidReactorAllocation"}
		var comparison: Dictionary = _api.apply("compare", [state.allocations[module], zero])
		if not comparison.get("ok", false) or int(comparison.scalar) < 0:
			return {"ok": false, "reason": "InvalidReactorAllocation"}
	_queue_presentation_change()
	_state = state.duplicate(true)
	_plan_preview_cache.clear()
	_prepared_state = {}
	return {"ok": true}

func _init(parameters: Dictionary, api, run_state) -> void:
	_run_state = run_state
	_enabled.make_read_only()
	for key in parameters:
		if str(key).begins_with("reactor"): _parameters[key] = parameters[key]
	_api = api
	_state = _initial(_parameters)

func panel_options() -> Array:
	var labels := {"weapons": "武器", "defence": "防御", "smelting": "冶炼", "condensation": "碎片凝结"}
	var enabled: Array = enabled_modules()
	var options: Array = []
	for id in str(_parameters.reactorModules).split(","):
		options.append({"id": id, "name": str(labels.get(id, id)), "enabled": id in enabled})
	return options

func refresh_availability(unlocked: Callable, notify: bool = true) -> bool:
	if not _run_state.is_running(): return false
	var available: bool = bool(unlocked.call("feature", "reactor"))
	var enabled: Array = []
	if available:
		for module in str(_parameters.reactorModules).split(","):
			if module != "condensation" or bool(unlocked.call("reactor_module", module)): enabled.append(module)
	if available != _available or enabled != _enabled:
		_queue_presentation_change()
		_available = available
		enabled.make_read_only()
		_enabled = enabled
		if notify: choices_changed.emit()
		return true
	return false

func publish_availability() -> void:
	choices_changed.emit()

func enabled_modules() -> Array:
	return _enabled

func modules_changed() -> bool:
	return _state.get("_enabled", []) != _enabled

# The candidate carries module-private state until native publication succeeds.
func prepare(inputs: Dictionary) -> Dictionary:
	if not _run_state.is_running(): return _run_state.rejection()
	var candidate = _evaluate(_state, _parameters, enabled_modules(), _api, inputs.capacity, inputs.free_charge)
	if not candidate.ok: return candidate
	_prepared_state = candidate.state
	var output := {"ok": true, "factors": candidate.factors}
	output.make_read_only()
	return output

func _adopt(next: Dictionary) -> void:
	_queue_presentation_change()
	_state = next
	_plan_preview_cache.clear()
	_prepared_state = {}

func accept() -> void:
	if not _run_state.is_running(): return
	if not _prepared_state.is_empty(): _adopt(_prepared_state)

func discard_prepared() -> void:
	_prepared_state = {}

func _submit(next: Dictionary, inputs: Dictionary, next_wallet, kind: String, publish: Callable) -> Dictionary:
	var candidate = _evaluate(next, _parameters, enabled_modules(), _api, inputs.capacity, inputs.free_charge)
	if not candidate.ok: return candidate
	_prepared_state = candidate.state
	var result: Dictionary = publish.call(candidate.factors, next_wallet, kind)
	if not result.ok: _prepared_state = {}
	return result

func purchase(count: int, automatic: bool, inputs: Dictionary, pay: Callable, publish: Callable) -> Dictionary:
	if not _run_state.is_running(): return _run_state.rejection()
	if not _available: return {"ok": false, "reason": "ReactorLocked"}
	var changed = _purchase(_state, count, automatic, _parameters, _api)
	if not changed.ok: return changed
	var paid: Dictionary = pay.call(changed.costs)
	if not paid.ok: return paid
	return _submit(changed.state, inputs, paid.wallet, "growth", publish)

func allocate_text(module: String, text: String, inputs: Dictionary, publish: Callable) -> Dictionary:
	if not _run_state.is_running(): return _run_state.rejection()
	var quantity = _api.apply("from_decimal", [text])
	if not quantity.ok: return quantity
	var changed = _allocate(_state, module, quantity.value, _parameters, enabled_modules(), _api, inputs.capacity)
	if not changed.ok: return changed
	return _submit(changed.state, inputs, null, "selection", publish)

func distribute(inputs: Dictionary, publish: Callable) -> Dictionary:
	if not _run_state.is_running(): return _run_state.rejection()
	var changed = _distribute(_state, _parameters, enabled_modules(), _api, inputs.capacity)
	if not changed.ok: return changed
	return _submit(changed.state, inputs, null, "selection", publish)

func refresh(inputs: Dictionary, publish: Callable) -> Dictionary:
	if not _run_state.is_running(): return _run_state.rejection()
	return _submit(_state, inputs, null, "growth", publish)

## Amount plans are read on detached state; this cache never enters saved state.
func allocation_plan_preview(draft: Dictionary, inputs: Dictionary) -> Dictionary:
	if not _available: return {"ok": false, "reason": "ReactorLocked"}
	var admitted: Dictionary = _plan_input_admission(inputs)
	if not admitted.ok: return admitted
	var signature := {"draft": draft.duplicate(true), "inputs": inputs.duplicate(true),
		"running": _run_state.is_running(), "level": _state.level, "allocations": _state.allocations.duplicate(true), "free": _state.free_charge, "enabled": _enabled.duplicate()}
	if _plan_preview_cache.get("signature") == signature: return _plan_preview_cache.result.duplicate(true)
	var planned: Dictionary = _allocation_plan(draft, inputs, false)
	if not planned.ok: return planned
	var actual: Dictionary = _accepted_plan_readings()
	if not actual.ok: return actual
	var target: Dictionary = _plan_readings(planned)
	if not target.ok: return target
	var result := {"ok": true, "can_apply": _run_state.is_running(), "reason": "" if _run_state.is_running() else "SessionUnavailable",
		"source": {"capacity": target.capacity, "enabled_ids": _enabled.duplicate()}, "current": actual, "target": target}
	_plan_preview_cache = {"signature": signature, "result": result}
	return result.duplicate(true)

func apply_allocation_plan(amount_texts: Dictionary, inputs: Dictionary, publish: Callable) -> Dictionary:
	if not _run_state.is_running(): return _run_state.rejection()
	if not _available: return {"ok": false, "reason": "ReactorLocked"}
	var admitted: Dictionary = _plan_input_admission(inputs)
	if not admitted.ok: return admitted
	var planned: Dictionary = _allocation_plan({"kind": "amounts", "amount_texts": amount_texts}, inputs, true)
	if not planned.ok: return planned
	var actual: Dictionary = _plan_readings(planned)
	if not actual.ok: return actual
	_prepared_state = planned.state
	var result: Dictionary = publish.call(planned.factors, null, "selection")
	if not result.ok:
		_prepared_state = {}
		return result
	var published: Dictionary = result.duplicate()
	published.actual = actual
	choices_changed.emit()
	return published

func _plan_input_admission(inputs: Dictionary) -> Dictionary:
	if not bool(inputs.get("ok", true)): return inputs.duplicate(true)
	if not inputs.get("capacity") is Dictionary or not (inputs.get("free_charge") is float or inputs.get("free_charge") is int):
		return {"ok": false, "reason": "InvalidReactorInputs"}
	if not is_finite(float(inputs.free_charge)): return {"ok": false, "reason": "InvalidReactorInputs"}
	return {"ok": true}

func _allocation_plan(draft: Dictionary, inputs: Dictionary, strict_integer: bool) -> Dictionary:
	var next: Dictionary = _state.duplicate(true)
	next.erase("_distribute")
	var capacity: Dictionary = _capacity(next, _parameters, _api, inputs.capacity)
	if not capacity.ok: return capacity
	var kind: String = str(draft.get("kind", ""))
	if kind == "equal":
		var distributed: Dictionary = _distribute(next, _parameters, _enabled, _api, inputs.capacity)
		if not distributed.ok: return distributed
		next = distributed.state
	else:
		var mapping = draft.get("shares_bp" if kind == "shares" else "amount_texts")
		if kind not in ["shares", "amounts"] or not mapping is Dictionary:
			return {"ok": false, "reason": "InvalidReactorPlan"}
		if mapping.size() != _enabled.size(): return {"ok": false, "reason": "ReactorModuleSetChanged"}
		for id in mapping:
			if id not in _enabled: return {"ok": false, "reason": "ReactorModuleSetChanged", "module": id}
		var targets: Dictionary = {}
		var total: Dictionary = _api.apply("zero", []).value
		var total_bp: int = 0
		for id in _enabled:
			var quantity: Dictionary
			if kind == "shares":
				if not mapping[id] is int or mapping[id] < 0 or mapping[id] > 10000:
					return {"ok": false, "reason": "InvalidReactorShare", "module": id}
				total_bp += int(mapping[id])
				if total_bp > 10000: return {"ok": false, "reason": "ReactorPlanOverCapacity"}
				var ratio: Dictionary = _api.apply("div", [_api.apply("from_decimal", [str(mapping[id])]).value, _api.apply("from_decimal", ["10000"]).value])
				if not ratio.ok: return ratio
				quantity = _api.apply("mul", [capacity.value, ratio.value])
			else:
				if not mapping[id] is String: return {"ok": false, "reason": "InvalidReactorAmount", "module": id}
				quantity = _api.apply("from_decimal", [mapping[id]])
			if not quantity.ok: return {"ok": false, "reason": "InvalidReactorAmount", "module": id, "error": quantity.get("error", "")}
			var rounded: Dictionary = _api.apply("floor", [quantity.value])
			if not rounded.ok: return rounded
			if strict_integer and _api.apply("compare", [rounded.value, quantity.value]).scalar != 0:
				return {"ok": false, "reason": "InvalidReactorAmount", "module": id}
			targets[id] = rounded.value
			var added: Dictionary = _api.apply("add", [total, rounded.value])
			if not added.ok: return added
			total = added.value
		if _api.apply("compare", [total, capacity.value]).scalar > 0: return {"ok": false, "reason": "ReactorPlanOverCapacity"}
		next.allocations = targets
	var result: Dictionary = _evaluate(next, _parameters, _enabled, _api, inputs.capacity, inputs.free_charge)
	if not result.ok: return result
	# _evaluate's legacy clipping is never allowed to change a confirmed plan.
	for id in _enabled:
		if _api.apply("compare", [next.allocations[id], result.state.allocations[id]]).scalar != 0:
			return {"ok": false, "reason": "ReactorPlanOverCapacity"}
	return result

func _accepted_plan_readings() -> Dictionary:
	if not _state.has("_capacity") or not _state.has("_factors") or not _state.has("_enabled"):
		return {"ok": true, "capacity": null, "allocated": null, "remaining": null, "modules": [], "reason": "ReactorSnapshotUnavailable"}
	var used: Dictionary = _api.apply("zero", []).value
	for id in _state._enabled:
		var total: Dictionary = _api.apply("add", [used, _state._factors[id].assigned])
		if not total.ok: return total
		used = total.value
	var remaining: Dictionary = _api.apply("sub_nonnegative", [_state._capacity.value, used])
	if not remaining.ok: return remaining
	return _plan_readings({"capacity": _state._capacity.value, "remaining": remaining.value, "state": _state})

func _plan_readings(evaluated: Dictionary) -> Dictionary:
	var zero: Dictionary = _api.apply("zero", [])
	if not zero.ok: return zero
	var capacity_check: Dictionary = _api.apply("compare", [evaluated.capacity, zero.value])
	if not capacity_check.ok: return capacity_check
	var empty_capacity: bool = int(capacity_check.scalar) == 0
	var allocated: Dictionary = zero.value
	var total_effective: Dictionary = zero.value
	var rows: Array = []
	for id in evaluated.state._enabled:
		var cached: Dictionary = evaluated.state._factors[id]
		var added: Dictionary = _api.apply("add", [allocated, cached.assigned])
		if not added.ok: return added
		allocated = added.value
		var effective: Dictionary = _api.apply("add", [cached.assigned, cached.free])
		if not effective.ok: return effective
		added = _api.apply("add", [total_effective, effective.value])
		if not added.ok: return added
		total_effective = added.value
		var free_check: Dictionary = _api.apply("compare", [cached.free, zero.value])
		if not free_check.ok: return free_check
		if empty_capacity:
			var effective_check: Dictionary = _api.apply("compare", [effective.value, zero.value])
			if not effective_check.ok: return effective_check
			if int(effective_check.scalar) != 0: return {"ok": false, "reason": "ReactorSnapshotUnavailable"}
		var ratio: Dictionary = _presentation_ratio(cached.assigned, evaluated.capacity, empty_capacity)
		if not ratio.ok: return ratio
		var load: Dictionary = _presentation_ratio(effective.value, evaluated.capacity, empty_capacity)
		if not load.ok: return load
		var row := {"id": id, "enabled": true, "ratio": ratio.scalar, "load": load.scalar,
			"has_free": int(free_check.scalar) > 0}
		var values := {"manual": cached.assigned, "free": cached.free, "effective": effective.value, "factor": cached.value}
		for field in values:
			var text: Dictionary = _api.apply("to_display", [values[field]])
			if not text.ok: return text
			row[field] = text.text
		rows.append(row)
	var core_load: Dictionary = _presentation_ratio(total_effective, evaluated.capacity, empty_capacity)
	if not core_load.ok: return core_load
	var result := {"ok": true, "modules": rows, "load": core_load.scalar}
	var amounts := {"capacity": evaluated.capacity, "allocated": allocated, "remaining": evaluated.remaining}
	for field in amounts:
		var text: Dictionary = _api.apply("to_display", [amounts[field]])
		if not text.ok: return text
		result[field] = text.text
	return result

func _presentation_ratio(value: Dictionary, capacity: Dictionary, empty_capacity: bool) -> Dictionary:
	if empty_capacity: return {"ok": true, "scalar": 0.0}
	var result: Dictionary = _api.apply("to_ratio", [value, capacity])
	if not result.ok: return result
	if not is_finite(float(result.scalar)): return {"ok": false, "reason": "ReactorSnapshotUnavailable"}
	return result

# Current is accepted, never re-evaluated using newer inputs or a pending plan.
func presentation_model() -> Dictionary:
	if not _available: return {"ok": false, "reason": "ReactorLocked"}
	if _state.get("_enabled", []) != _enabled: return {"ok": false, "reason": "ReactorSnapshotUnavailable"}
	var actual: Dictionary = _accepted_plan_readings()
	if not actual.ok: return actual
	if actual.capacity == null: return {"ok": false, "reason": "ReactorSnapshotUnavailable"}
	actual.level = int(_state.level)
	actual.can_allocate = _run_state.is_running()
	actual.reason = "" if actual.can_allocate else "SessionUnavailable"
	return actual

# Fixed-count prices depend on accepted level, never the current budget.
func purchase_preview(can_pay: Callable, count: int = 1) -> Dictionary:
	if not _run_state.is_running(): return _run_state.rejection()
	if not _available: return {"ok": false, "reason": "ReactorLocked"}
	if _purchase_preview_level != int(_state.level):
		_purchase_preview_quotes.clear()
		_purchase_preview_level = int(_state.level)
	var quote: Dictionary = _purchase_preview_quotes.get(count, {})
	if quote.is_empty():
		var changed: Dictionary = _purchase(_state.duplicate(true), count, false, _parameters, _api)
		if not changed.ok: return changed
		var display: Dictionary = _purchase_cost_texts(changed.costs)
		if not display.ok: return display
		quote = {"costs": changed.costs.duplicate(true), "texts": display.texts}
		# Cache the two fixed UI modes only; MAX keeps only local search state.
		if count in [1, 10]: _purchase_preview_quotes[count] = quote
	var affordable: Dictionary = can_pay.call(quote.costs.duplicate(true))
	if not affordable.ok and affordable.get("reason", "") != "InsufficientResources": return affordable
	return {"ok": true, "count": count, "costs": quote.texts.duplicate(true),
		"cost_resource_ids": PackedStringArray(quote.costs.keys()),
		"can_purchase": bool(affordable.ok), "reason": affordable.get("reason", affordable.get("error", ""))}

func purchase_max_preview(can_pay: Callable) -> Dictionary:
	var quote: Dictionary = _maximum_purchase_quote(can_pay)
	if not quote.ok: return quote
	var display: Dictionary = _purchase_cost_texts(quote.costs)
	if not display.ok: return display
	return {"ok": true, "count": quote.count, "costs": display.texts,
		"cost_resource_ids": quote.cost_resource_ids, "can_purchase": quote.count > 0,
		"reason": "" if quote.count > 0 else "InsufficientResources"}

func purchase_max(inputs: Dictionary, can_pay: Callable, pay: Callable, publish: Callable) -> Dictionary:
	var quote: Dictionary = _maximum_purchase_quote(can_pay)
	if not quote.ok: return quote
	if quote.count == 0: return {"ok": false, "reason": "InsufficientResources"}
	# Format before publication: a display error cannot turn a completed purchase into failure.
	var display: Dictionary = _purchase_cost_texts(quote.costs)
	if not display.ok: return display
	var result: Dictionary = purchase(int(quote.count), false, inputs, pay, publish)
	if not result.ok: return result
	var receipt: Dictionary = result.duplicate(true)
	receipt.count = quote.count
	receipt.costs = display.texts
	return receipt

func _purchase_cost_texts(costs: Dictionary) -> Dictionary:
	var texts: Dictionary = {}
	for resource in costs:
		var text: Dictionary = _api.apply("to_display", [costs[resource]])
		if not text.ok: return text
		texts[resource] = text.text
	return {"ok": true, "texts": texts}

func _maximum_purchase_quote(can_pay: Callable) -> Dictionary:
	if not _run_state.is_running(): return _run_state.rejection()
	if not _available: return {"ok": false, "reason": "ReactorLocked"}
	var limit: int = 9223372036854775807 - int(_state.level)
	if limit <= 0: return {"ok": false, "reason": "ReactorLevelRangeExceeded"}
	var low: int = 0
	var high: int = 1
	var accepted: Dictionary = {}
	var resource_ids := PackedStringArray()
	while true:
		var quote: Dictionary = _purchase(_state.duplicate(true), high, false, _parameters, _api)
		if not quote.ok: return quote
		resource_ids = PackedStringArray(quote.costs.keys())
		var affordable: Dictionary = can_pay.call(quote.costs.duplicate(true))
		if not affordable.ok:
			if affordable.get("reason", "") != "InsufficientResources": return affordable
			break
		low = high
		accepted = quote
		if high == limit: return {"ok": false, "reason": "ReactorLevelRangeExceeded"}
		high = limit if high > (limit >> 1) else high * 2
	while low + 1 < high:
		@warning_ignore("integer_division")
		var middle: int = low + (high - low) / 2
		var quote: Dictionary = _purchase(_state.duplicate(true), middle, false, _parameters, _api)
		if not quote.ok: return quote
		var affordable: Dictionary = can_pay.call(quote.costs.duplicate(true))
		if affordable.ok:
			low = middle
			accepted = quote
		elif affordable.get("reason", "") == "InsufficientResources": high = middle
		else: return affordable
	# low was accepted and high=low+1 was rejected, both using original Amount costs.
	return {"ok": true, "count": low, "costs": accepted.costs.duplicate(true) if low > 0 else {},
		"cost_resource_ids": resource_ids}

# Capture before replacing state: deferred delivery must not lose the first change.
func _queue_presentation_change() -> void:
	if _presentation_queued: return
	_presentation_before = _presentation_facts()
	_presentation_queued = true
	call_deferred("_emit_presentation_change")

func _presentation_facts() -> Dictionary:
	var rows: Dictionary = {}
	for id in _state.get("_enabled", []):
		var cached: Dictionary = _state.get("_factors", {}).get(id, {})
		rows[id] = {"assigned": cached.get("assigned", {}), "free": cached.get("free", {}), "value": cached.get("value", {})}
	return {"level": _state.level, "available": _available, "enabled": _enabled.duplicate(),
		"accepted_ids": _state.get("_enabled", []).duplicate(), "rows": rows.duplicate(true),
		"capacity": _state.get("_capacity", {}).get("value", {}).duplicate(true),
		"ready": _state.has("_capacity") and _state.has("_factors") and _state.has("_enabled") and _state._enabled == _enabled}

func _amount_changed(before: Dictionary, after: Dictionary) -> Dictionary:
	if before == after: return {"ok": true, "changed": false}
	if before.is_empty() or after.is_empty(): return {"ok": true, "changed": true}
	var comparison: Dictionary = _api.apply("compare", [before, after])
	if not comparison.ok: return comparison
	return {"ok": true, "changed": int(comparison.scalar) != 0}

func _presentation_changes(before: Dictionary, after: Dictionary) -> Dictionary:
	var changes := PackedStringArray()
	if before.level != after.level: changes.append("level")
	if before.available != after.available or before.enabled != after.enabled or before.accepted_ids != after.accepted_ids:
		changes.append("availability")
	if before.ready != after.ready: changes.append("readiness")
	var capacity: Dictionary = _amount_changed(before.capacity, after.capacity)
	if not capacity.ok: return capacity
	if capacity.changed: changes.append("capacity")
	var ids: Array = before.rows.keys()
	for id in after.rows:
		if id not in ids: ids.append(id)
	var tags := {"assigned": "allocation", "free": "free", "value": "effect"}
	for field in tags:
		var tag: String = tags[field]
		for id in ids:
			var value: Dictionary = _amount_changed(before.rows.get(id, {}).get(field, {}), after.rows.get(id, {}).get(field, {}))
			if not value.ok: return value
			if value.changed:
				changes.append(tag)
				break
	return {"ok": true, "changes": changes}

func _emit_presentation_change() -> void:
	var before: Dictionary = _presentation_before
	_presentation_before = {}
	_presentation_queued = false
	var result: Dictionary = _presentation_changes(before, _presentation_facts())
	if result.ok and not result.changes.is_empty(): presentation_changed.emit(result.changes)

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
	state = state.duplicate()
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
	if not free.ok: return free
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
	next._enabled = enabled
	factors.make_read_only()
	return {"ok": true, "state": next, "capacity": capacity.value, "remaining": remaining, "factors": factors}

static func _allocate(state: Dictionary, module: String, requested: Dictionary, parameters: Dictionary, enabled: Array, api, capacity_factor: Dictionary) -> Dictionary:
	state = state.duplicate()
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
	var next: Dictionary = state.duplicate()
	next.allocations = allocations
	next.allocations[module] = value.value
	return {"ok": true, "state": next}

static func _distribute(state: Dictionary, parameters: Dictionary, enabled: Array, api, capacity_factor: Dictionary) -> Dictionary:
	state = state.duplicate()
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
	var next: Dictionary = state.duplicate()
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
	var next: Dictionary = state.duplicate()
	next.level = int(next.level) + count
	if automatic: next._distribute = true
	return {"ok": true, "state": next, "costs": quoted.costs}
