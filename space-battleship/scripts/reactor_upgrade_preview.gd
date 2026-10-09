extends RefCounted
## Read-only projection of one purchase, including its integer allocation growth.
const Growth := preload("res://scripts/reactor_allocation_growth.gd")

static func active_allocation(game: BattleGame,drone_totals: Dictionary = {}) -> Dictionary:
	# The parent-owned core supplies the effective view; older cores retain their
	# ordinary allocation behavior until that interface is merged.
	return game.call("reactor_active_allocation",drone_totals) if game.has_method("reactor_active_allocation") else game.profile.reactorAllocation.duplicate()

const I=preload("res://scripts/reactor_integer.gd")
const N=preload("res://scripts/growth_number.gd")
static func quote(game: BattleGame, count: int) -> Dictionary:
	var level := int(game.profile.reactorLevel)
	var capacity = game.reactor_capacity()
	var next_capacity = capacity if count <= 0 else game.reactor_capacity_at(level+count)
	if next_capacity==null:next_capacity=capacity
	var active:=active_allocation(game)
	var free_ratio := game.charge_free_ratio() if game.reactor_unlocked() else 0.0
	var key := [count,level,capacity,next_capacity,active,free_ratio,Array(game.reactor_available_modules()),game.db.config.reactorUpgradeBase,game.db.config.reactorUpgradeGrowth,game.db.config.reactorBoostExponent,game.db.config.reactorPercentScale]
	for cached in game.reactor_quote_cache:
		if cached.key==key:return cached.quote.duplicate(true)
	var allocation: Dictionary = Growth.expand(Array(game.reactor_modules()),active,capacity,next_capacity)
	var cost = 0.0
	for offset in maxi(0,count):cost=N.add(cost,game.reactor_upgrade_cost(level+offset))
	var effects := {}
	for module in game.reactor_available_modules():
		var current = game.reactor_multiplier(module)
		var energy = N.add(I.as_growth(allocation.get(module,0)),N.multiply(I.as_growth(next_capacity),free_ratio))
		var next = N.add(1.0,N.divide(N.power(energy,float(game.db.config.reactorBoostExponent)),float(game.db.config.reactorPercentScale)))
		effects[module] = {"current":current,"next":next,"gain":(N.ratio(next,current)-1.0)*100.0}
	var result := {"count":maxi(0,count),"cost":cost,"capacity":capacity,"next_capacity":next_capacity,"allocation":allocation,"effects":effects}
	if game.reactor_quote_cache.size()>=8:game.reactor_quote_cache.pop_front()
	game.reactor_quote_cache.append({"key":key,"quote":result})
	return result.duplicate(true)
