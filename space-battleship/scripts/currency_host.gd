extends RefCounted
## Transient owner. Prepared data stays inside the host, never in returned tickets.
const Ledger = preload("res://scripts/currency_ledger.gd")
var _profile: Dictionary
var _generation := 0
var _prepared: Dictionary = {}

class Plan extends RefCounted:
	var status := "invalid"

class Receipt extends RefCounted:
	var status: String
	var resource_ids: Array
	func _init(state: String, ids: Array = []) -> void:
		status = state
		resource_ids = ids.duplicate()

func bind(profile: Dictionary) -> void:
	_profile = profile
	_generation += 1
	_prepared.clear()

func invalidate() -> void:
	_generation += 1
	_prepared.clear()

func _copy(value: Variant) -> Variant:
	return value.duplicate(true) if value is Dictionary or value is Array else value

func _same_value(a: Variant, b: Variant) -> bool:
	if typeof(a) != typeof(b):
		return false
	if a is Dictionary:
		if a.size() != b.size():
			return false
		for key in a:
			if not b.has(key) or not _same_value(a[key], b[key]):
				return false
		return true
	if a is Array:
		if a.size() != b.size():
			return false
		for index in a.size():
			if not _same_value(a[index], b[index]):
				return false
		return true
	return a == b

func prepare(profile: Dictionary, costs: Dictionary, dependencies: Dictionary, credit := false) -> Plan:
	var plan := Plan.new()
	if not is_same(profile, _profile) or not profile.get("resources") is Dictionary:
		plan.status = "wrong_owner"
		return plan
	var record := {"owner":profile,"generation":_generation,"dependencies":dependencies.duplicate(true),"before":{},"after":{},"ticket":weakref(plan)}
	for id in costs:
		if not id is String or not profile.resources.has(id):
			plan.status = "invalid_resource"
			return plan
		var balance: Ledger.Outcome = Ledger.decode(profile.resources[id])
		var cost: Ledger.Outcome = Ledger.decode(costs[id])
		if balance.status != "ok" or cost.status != "ok":
			plan.status = "invalid_value"
			return plan
		var result: Ledger.Outcome = Ledger.add(balance.value, cost.value) if credit else Ledger.subtract(balance.value, cost.value)
		if result.status != "ok":
			plan.status = result.status
			return plan
		record.before[id] = _copy(profile.resources[id])
		record.after[id] = Ledger.encode(result.value)
	for id in _prepared.keys():
		if _prepared[id].ticket.get_ref() == null:
			_prepared.erase(id)
	_prepared[plan.get_instance_id()] = record
	plan.status = "ready"
	return plan

func discard(plan: Plan) -> void:
	if plan != null:
		_prepared.erase(plan.get_instance_id())

func commit(plan: Plan, profile: Dictionary, dependencies: Dictionary) -> Receipt:
	if plan == null:
		return Receipt.new("invalid_plan")
	var id: int = plan.get_instance_id()
	if not _prepared.has(id):
		return Receipt.new("invalid_plan" if plan.status == "committed" else "stale")
	var record: Dictionary = _prepared[id]
	if not is_same(record.ticket.get_ref(), plan):
		return Receipt.new("invalid_plan")
	if not is_same(profile, _profile) or not is_same(profile, record.owner) or record.generation != _generation:
		return Receipt.new("stale")
	if not _same_value(dependencies, record.dependencies) or not profile.get("resources") is Dictionary:
		return Receipt.new("stale")
	for resource_id in record.before:
		if not profile.resources.has(resource_id) or not _same_value(profile.resources[resource_id], record.before[resource_id]):
			return Receipt.new("stale")
	var next: Dictionary = profile.resources.duplicate(true)
	for resource_id in record.after:
		next[resource_id] = record.after[resource_id].duplicate(true)
	plan.status = "committed"
	profile.resources = next
	_generation += 1
	_prepared.clear()
	return Receipt.new("committed", record.after.keys())

