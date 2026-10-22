extends RefCounted
## Owns ordinary resource, fragment and chrono balances. No signals or game access:
## callers finish the other business state before publishing a notification.
const N = preload("res://scripts/growth_number.gd")
const Integer = preload("res://scripts/reactor_integer.gd")
const IDS := ["1", "2", "jewel", "chrono"]
var _balances := {"1":0.0, "2":0.0, "jewel":0.0, "chrono":0.0}
var revision := 0
var resource_revision := 0

static func _copy(value: Variant) -> Variant:
	return value.duplicate(true) if value is Dictionary else value

func balance(id: String) -> Variant:
	return _copy(_balances.get(id, 0.0))

func resources() -> Dictionary:
	return {"1":balance("1"), "2":balance("2")}

static func valid_snapshot(raw: Dictionary) -> bool:
	if not raw.get("resources") is Dictionary or raw.resources.size() != 2:return false
	for id in ["1", "2"]:
		if not N.valid(raw.resources.get(id)):return false
	if not N.valid(raw.get("jewelFragments")):return false
	var chrono = raw.get("chronoParticles")
	return (chrono is int or chrono is float) and is_finite(float(chrono)) and chrono >= 0

func install_snapshot(raw: Dictionary) -> bool:
	if not valid_snapshot(raw):return false
	_balances = {"1":_copy(raw.resources["1"]), "2":_copy(raw.resources["2"]), "jewel":_copy(raw.jewelFragments), "chrono":float(raw.chronoParticles)}
	revision += 1
	resource_revision += 1
	return true

func save_data() -> Dictionary:
	var result := resources()
	for id in result:
		if result[id] is int and result[id] > 9007199254740991:result[id] = Integer.encode(result[id])
	return {"resources":result, "jewelFragments":balance("jewel"), "chronoParticles":balance("chrono")}

func credit(id: String, amount: Variant) -> bool:
	if id not in IDS or not N.valid(amount):return false
	var next = N.add(_balances[id], amount)
	if not N.valid(next) or (id == "chrono" and next is Dictionary):return false
	_balances[id] = _copy(next)
	revision += 1
	if id in ["1", "2"]:resource_revision += 1
	return true

func credit_fragments(amount: Variant) -> bool:
	if not credit("jewel", amount):return false
	if not _balances.jewel is Dictionary:_balances.jewel = snappedf(float(_balances.jewel), 0.01)
	return true

func can_pay(costs: Dictionary) -> bool:
	for id in costs:
		if id not in IDS or not N.valid(costs[id]) or N.compare(_balances[id], costs[id]) < 0:return false
	return true

func debit(costs: Dictionary) -> bool:
	if not can_pay(costs):return false
	# Validation precedes every write, including multi-resource research slices.
	for id in costs:_balances[id] = N.subtract(_balances[id], costs[id])
	if not costs.is_empty():revision += 1
	if costs.has("1") or costs.has("2"):resource_revision += 1
	return true

func accrue_chrono(amount: float, capacity: float) -> void:
	_balances.chrono = minf(capacity, float(_balances.chrono) + amount)
	revision += 1

func consume_chrono(seconds: float, per_second: float) -> float:
	if per_second <= 0:return seconds
	var covered := minf(seconds, float(_balances.chrono) / per_second)
	_balances.chrono = maxf(0.0, float(_balances.chrono) - covered * per_second)
	if covered > 0:revision += 1
	return covered

func reset_run_fragments() -> void:
	_balances.jewel = 0.0
	revision += 1

# These preserve the accepted main arithmetic until the bounded resource
# representation is migrated. Materials are deliberately not routed through it.
static func exact_budget(budget: Variant) -> bool:
	return (budget is Dictionary and budget.has("i")) or (budget is int and budget > 9007199254740991)

static func reactor_affordable(cost: Variant, budget: Variant) -> bool:
	if cost is float and not exact_budget(budget):return N.compare(cost, budget) <= 0
	var exact_balance = Integer.from_growth(budget)
	var exact_cost = Integer.from_growth(cost)
	if budget is Dictionary and budget.has("m") and exact_cost != null:
		return Integer.compare_legacy_growth_to_integer(budget, exact_cost) >= 0
	return Integer.compare(exact_balance, exact_cost) >= 0 if exact_balance != null and exact_cost != null else N.compare(budget, cost) >= 0

static func reactor_remainder(budget: Variant, cost: Variant) -> Variant:
	if cost is float and not exact_budget(budget):return N.subtract(budget, cost)
	var exact_cost = Integer.from_growth(cost)
	var exact_balance = Integer.from_growth(budget)
	if exact_cost != null and exact_balance == null and budget is Dictionary and budget.has("m"):
		exact_balance = Integer.nearby_legacy_integer(budget, exact_cost)
	if exact_balance != null and exact_cost != null:return Integer.subtract(exact_balance, exact_cost)
	return N.subtract(budget, cost)

func debit_reactor(id: String, cost: Variant) -> bool:
	if id not in ["1", "2"] or not N.valid(cost) or not reactor_affordable(cost, _balances[id]):return false
	_balances[id] = reactor_remainder(_balances[id], cost)
	revision += 1
	resource_revision += 1
	return true
