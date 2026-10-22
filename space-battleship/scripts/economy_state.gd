extends RefCounted
## Owns every spendable balance: resources, fragments, chrono and exact materials. No signals or game access:
## callers finish the other business state before publishing a notification.
const N = preload("res://scripts/growth_number.gd")
const Integer = preload("res://scripts/reactor_integer.gd")
const IDS := ["1", "2", "jewel", "chrono"]
var _balances := {"1":0.0, "2":0.0, "jewel":0.0, "chrono":0.0}
const MATERIAL_LIMIT := 9000000000000000
var _materials: Dictionary = {}
var _cores := 0
var material_revision := 0
var revision := 0
var resource_revision := 0

static func _copy(value: Variant) -> Variant:
	return value.duplicate(true) if value is Dictionary else value

func balance(id: String) -> Variant:
	if id == "ultimate_cores":return _cores
	if _materials.has(id):return int(_materials[id])
	return _copy(_balances.get(id, 0.0))

func resources() -> Dictionary:
	return {"1":balance("1"), "2":balance("2")}

func reset(resources: Dictionary, config: Dictionary) -> void:
	var wallet := {"materials":{}, "ultimate_cores":0}
	for route in config.routes.values():wallet.materials[route.material] = 0
	install_material_wallet(wallet)
	_balances = {"1":_copy(resources["1"]), "2":_copy(resources["2"]), "jewel":0.0, "chrono":0.0}
	revision += 1
	resource_revision += 1

func material_wallet() -> Dictionary:
	return {"materials":_materials.duplicate(), "ultimate_cores":_cores}

static func exact_amount(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= 0 and value < MATERIAL_LIMIT and value == floorf(float(value))

static func valid_material_wallet(wallet: Dictionary, keys: Array = []) -> bool:
	if not wallet.get("materials") is Dictionary or not exact_amount(wallet.get("ultimate_cores")):return false
	if not keys.is_empty() and (wallet.materials.size() != keys.size() or not keys.all(func(key):return wallet.materials.has(key))):return false
	for amount in wallet.materials.values():
		if not exact_amount(amount):return false
	return true

static func material_can_pay(wallet: Dictionary, costs: Dictionary) -> bool:
	for id in costs:
		if not exact_amount(costs[id]):return false
		if id != "ultimate_cores" and not wallet.materials.has(id):return false
		var owned: int = int(wallet.ultimate_cores) if id == "ultimate_cores" else int(wallet.materials[id])
		if owned < int(costs[id]):return false
	return true

static func material_debit(wallet: Dictionary, costs: Dictionary) -> bool:
	if not material_can_pay(wallet, costs):return false
	for id in costs:
		if id == "ultimate_cores":wallet.ultimate_cores = int(wallet.ultimate_cores) - int(costs[id])
		else:wallet.materials[id] = int(wallet.materials[id]) - int(costs[id])
	return true

static func material_credit(wallet: Dictionary, gains: Dictionary) -> bool:
	for id in gains:
		if not exact_amount(gains[id]) or (id != "ultimate_cores" and not wallet.materials.has(id)):return false
		var owned: int = int(wallet.ultimate_cores) if id == "ultimate_cores" else int(wallet.materials[id])
		if int(gains[id]) >= MATERIAL_LIMIT - owned:return false
	for id in gains:
		if id == "ultimate_cores":wallet.ultimate_cores = int(wallet.ultimate_cores) + int(gains[id])
		else:wallet.materials[id] = int(wallet.materials[id]) + int(gains[id])
	return true

func install_material_wallet(wallet: Dictionary) -> bool:
	if not valid_material_wallet(wallet, _materials.keys()):return false
	var next: Dictionary = {}
	for id in wallet.materials:next[id] = int(wallet.materials[id])
	if next != _materials or int(wallet.ultimate_cores) != _cores:
		_materials = next
		_cores = int(wallet.ultimate_cores)
		material_revision += 1
		revision += 1
	return true

static func valid_snapshot(raw: Dictionary) -> bool:
	if not valid_material_wallet({"materials":raw.get("materials"), "ultimate_cores":raw.get("ultimateCores")}):return false
	if not raw.get("resources") is Dictionary or raw.resources.size() != 2:return false
	for id in ["1", "2"]:
		if not N.valid(raw.resources.get(id)):return false
	if not N.valid(raw.get("jewelFragments")):return false
	var chrono = raw.get("chronoParticles")
	return (chrono is int or chrono is float) and is_finite(float(chrono)) and chrono >= 0

func install_snapshot(raw: Dictionary) -> bool:
	if not valid_snapshot(raw):return false
	if not install_material_wallet({"materials":raw.materials, "ultimate_cores":raw.ultimateCores}):return false
	_balances = {"1":_copy(raw.resources["1"]), "2":_copy(raw.resources["2"]), "jewel":_copy(raw.jewelFragments), "chrono":float(raw.chronoParticles)}
	revision += 1
	resource_revision += 1
	return true

func save_data() -> Dictionary:
	var result := resources()
	for id in result:
		if result[id] is int and result[id] > 9007199254740991:result[id] = Integer.encode(result[id])
	return {"resources":result, "jewelFragments":balance("jewel"), "chronoParticles":balance("chrono"), "materials":_materials.duplicate(), "ultimateCores":_cores}

func credit(id: String, amount: Variant) -> bool:
	return credit_many({id:amount})

func credit_many(gains: Dictionary) -> bool:
	var next := _balances.duplicate(true)
	var wallet := material_wallet()
	var materials := {}
	for id in gains:
		if id not in IDS:materials[id] = gains[id];continue
		if not N.valid(gains[id]):return false
		next[id] = N.add(next[id], gains[id])
		if not N.valid(next[id]) or (id == "chrono" and next[id] is Dictionary):return false
	if not material_credit(wallet, materials):return false
	install_material_wallet(wallet)
	_balances = next
	if not gains.is_empty():revision += 1
	if gains.has("1") or gains.has("2"):resource_revision += 1
	return true

func credit_fragments(amount: Variant) -> bool:
	if not credit("jewel", amount):return false
	if not _balances.jewel is Dictionary:_balances.jewel = snappedf(float(_balances.jewel), 0.01)
	return true

func can_pay(costs: Dictionary) -> bool:
	var materials := {}
	for id in costs:
		if id not in IDS:materials[id] = costs[id];continue
		if not N.valid(costs[id]) or N.compare(_balances[id], costs[id]) < 0:return false
	return material_can_pay(material_wallet(), materials)

func debit(costs: Dictionary) -> bool:
	if not can_pay(costs):return false
	# Ordinary resources and integer materials are validated before either changes.
	var materials := {}
	for id in costs:
		if id not in IDS:materials[id] = costs[id]
		else:_balances[id] = N.subtract(_balances[id], costs[id])
	if not materials.is_empty():
		var wallet := material_wallet()
		material_debit(wallet, materials)
		install_material_wallet(wallet)
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
