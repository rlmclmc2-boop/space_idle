extends RefCounted
## Reactor rules/state. Contributions are supplied by the command owner; this
## domain never switches a combat backend, clears global caches or emits events.
const N = preload("res://scripts/growth_number.gd")
const Integer = preload("res://scripts/reactor_integer.gd")
var _level := 1
var _allocation: Dictionary = {}
var revision := 0
var _capacity_inputs: Array = []
var _capacity: Variant = 0

func level() -> int:return _level

func allocation(key: String) -> Variant:
	var value = _allocation.get(key, 0)
	return value.duplicate(true) if value is Dictionary else value

func allocations() -> Dictionary:return _allocation.duplicate(true)

func reset(config: Dictionary) -> void:
	_level = int(config.reactorInitialLevel)
	_allocation = {}
	for key in str(config.reactorModules).split(",", false):_allocation[key] = 0
	revision += 1

static func valid_snapshot(raw: Dictionary, config: Dictionary) -> bool:
	var value = raw.get("reactorLevel")
	if not (value is int or value is float) or not is_finite(float(value)) or value != floorf(float(value)) or value < int(config.reactorInitialLevel) or value >= 9223372036854775807.0:return false
	var allocation = raw.get("reactorAllocation")
	var modules := str(config.reactorModules).split(",", false)
	if not allocation is Dictionary or allocation.size() != modules.size():return false
	for key in modules:
		var amount = allocation.get(key)
		if Integer.valid(amount):continue
		if not (amount is float and is_finite(amount) and amount >= 0 and amount <= 9007199254740991 and amount == floorf(amount)):return false
	return true

func install_snapshot(raw: Dictionary, config: Dictionary) -> bool:
	if not valid_snapshot(raw, config):return false
	_level = int(raw.reactorLevel)
	_allocation = {}
	for key in str(config.reactorModules).split(",", false):_allocation[key] = Integer.command_floor(raw.reactorAllocation[key])
	revision += 1
	return true

func save_data() -> Dictionary:
	var saved := {}
	for key in _allocation:saved[key] = Integer.encode(_allocation[key])
	return {"reactorLevel":_level, "reactorAllocation":saved}

func energy(config: Dictionary, contributions: Array, at_level := -1) -> Variant:
	var actual := _level if at_level < 0 else at_level
	var base := float(config.reactorEnergyBase)
	var growth := float(config.reactorEnergyGrowth)
	var ordinary := base * pow(growth, actual - 1) * float(contributions[0]) * float(contributions[1]) * float(contributions[2])
	if is_finite(ordinary):return ordinary
	return N.multiply(N.multiply(N.multiply(N.multiply(base, N.power(growth, actual - 1)), contributions[0]), contributions[1]), contributions[2])

func capacity(config: Dictionary, contributions: Array) -> Variant:
	var signature: Array = [_level, float(config.reactorEnergyBase), float(config.reactorEnergyGrowth)] + contributions
	if signature != _capacity_inputs:
		var available = energy(config, contributions)
		if not available is Dictionary and is_finite(float(available)) and float(available) < 9223372036854775808.0:
			_capacity = maxi(0, int(floor(float(available))))
		else:
			_capacity = Integer.formula_floor([float(config.reactorEnergyBase)] + contributions, float(config.reactorEnergyGrowth), _level - 1)
		_capacity_inputs = signature
	return _capacity.duplicate(true) if _capacity is Dictionary else _capacity

func upgrade_cost(config: Dictionary, at_level := -1) -> Variant:
	var actual := _level if at_level < 0 else at_level
	var ordinary := float(config.reactorUpgradeBase) * pow(float(config.reactorUpgradeGrowth), actual - 1)
	return ceilf(ordinary) if is_finite(ordinary) else N.ceiling(N.multiply(float(config.reactorUpgradeBase),N.power(float(config.reactorUpgradeGrowth),actual-1)))

func allocated() -> Variant:
	var total: Variant = 0
	for key in _allocation:total = Integer.add(total, _allocation[key])
	return total

func effective_ratio(key: String, capacity: Variant, free_ratio: float) -> Variant:
	return N.add(N.ratio(N.from_integer(allocation(key)), N.from_integer(Integer.maximum(1, capacity))), free_ratio)

func multiplier(key: String, capacity: Variant, free_ratio: float, config: Dictionary) -> Variant:
	var manual = allocation(key)
	if not manual is Dictionary and not capacity is Dictionary:
		var ordinary := float(manual) + float(capacity) * free_ratio
		var boost := pow(ordinary, float(config.reactorBoostExponent)) if ordinary > 0 else 0.0
		var bonus := 1.0 + boost / float(config.reactorPercentScale)
		if is_finite(bonus):return bonus
	var assigned = N.add(N.from_integer(manual), N.multiply(N.from_integer(capacity), free_ratio))
	return N.add(1.0, N.divide(N.power(assigned, float(config.reactorBoostExponent)), float(config.reactorPercentScale))) if N.compare(assigned, 0) > 0 else 1.0

# Below binary64's integral precision boundary each single-level ceil remains
# meaningful. Above it, the geometric tail has no representable fractional unit.
func purchase_cost(amount: int, config: Dictionary) -> Variant:
	if amount<=0:return 0.0
	var total:Variant=0.0
	var offset:=0
	while offset<amount:
		var cost:Variant=upgrade_cost(config,_level+offset)
		if N.compare(cost,9007199254740992.0)>=0:
			return N.add(total,N.multiply(cost,geometric_sum(float(config.reactorUpgradeGrowth),amount-offset)))
		total=N.add(total,cost);offset+=1
	return total

static func geometric_sum(growth:float,count:int)->Variant:
	# Sum 1+g+...+g^(count-1) by doubling, without a cancellation-prone g^n-1
	# or a loop proportional to a potentially huge MAX purchase count.
	var total:Variant=0.0;var factor:Variant=1.0
	var block_sum:Variant=1.0;var block_factor:Variant=growth
	while count>0:
		if count%2==1:total=N.add(total,N.multiply(factor,block_sum));factor=N.multiply(factor,block_factor)
		count/=2
		if count>0:block_sum=N.multiply(block_sum,N.add(1.0,block_factor));block_factor=N.multiply(block_factor,block_factor)
	return total

func purchase_quote(amount: int, budget: Variant, config: Dictionary) -> Dictionary:
	if amount <= 0 or _level > 9223372036854775807 - amount or not N.valid(budget):return {}
	var cost:Variant=purchase_cost(amount,config)
	if not N.valid(cost) or N.compare(cost,0)<=0 or N.compare(cost,budget)>0:return {}
	return {"revision":revision,"before":_level,"amount":amount,"cost":cost}

func max_upgrades(budget: Variant, config: Dictionary) -> int:
	if not N.valid(budget):return 0
	var room:int=9223372036854775807-_level
	if room==0:return 0
	var low:=0;var high:=1
	while not purchase_quote(high,budget,config).is_empty():
		low=high
		if high==room:return high
		high=room if high>room/2 else high*2
	while high-low>1:
		var middle:int=low+(high-low)/2
		if purchase_quote(middle,budget,config).is_empty():high=middle
		else:low=middle
	return low

func purchase_matches(quote: Dictionary) -> bool:
	return not quote.is_empty() and quote.revision == revision and quote.before == _level

func commit_purchase(quote: Dictionary) -> void:
	_level += int(quote.amount)
	revision += 1

func allocation_proposal(key: String, requested: Variant, capacity: Variant) -> Dictionary:
	if not _allocation.has(key):return {}
	var amount = Integer.command_floor(requested)
	if amount == null:return {}
	var current = allocation(key)
	var allowed = Integer.subtract(capacity, Integer.subtract(allocated(), current))
	var next = Integer.minimum(amount, allowed)
	if Integer.compare(next, current) == 0:return {}
	var result := allocations()
	result[key] = next
	return result

func equal_allocation(modules: PackedStringArray, capacity: Variant) -> Dictionary:
	if modules.is_empty():return {}
	var division := Integer.div_small(capacity, modules.size())
	var result := allocations()
	for index in modules.size():result[modules[index]] = Integer.add(division[0], 1 if index < int(division[1]) else 0)
	return {} if result == _allocation else result

func commit_allocation(next: Dictionary) -> void:
	_allocation = next.duplicate(true)
	revision += 1

func reconcile_capacity(capacity: Variant) -> void:
	var remaining = capacity
	var next := allocations()
	for key in next:
		next[key] = Integer.minimum(next[key], remaining)
		remaining = Integer.subtract(remaining, next[key])
	if next != _allocation:commit_allocation(next)
