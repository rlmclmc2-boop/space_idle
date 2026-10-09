extends RefCounted
## Read-only projection of one purchase, including its integer allocation growth.
const Growth := preload("res://scripts/reactor_allocation_growth.gd")

static func active_allocation(game: BattleGame,drone_totals: Dictionary = {}) -> Dictionary:
	# The parent-owned core supplies the effective view; older cores retain their
	# ordinary allocation behavior until that interface is merged.
	return game.call("reactor_active_allocation",drone_totals) if game.has_method("reactor_active_allocation") else game.profile.reactorAllocation.duplicate()

static func quote(game: BattleGame, count: int) -> Dictionary:
	var level := int(game.profile.reactorLevel)
	var capacity := game.reactor_capacity()
	var next_capacity := capacity if count <= 0 else preload("res://scripts/reactor_growth.gd").capacity(game.reactor_energy(level+count))
	var allocation: Dictionary = Growth.expand(Array(game.reactor_modules()),active_allocation(game),capacity,next_capacity)
	var cost := 0.0
	for offset in maxi(0,count):cost += game.reactor_upgrade_cost(level+offset)
	var effects := {}
	var free_ratio := game.charge_free_ratio() if game.reactor_unlocked() else 0.0
	for key in game.reactor_available_modules():
		var current := game.reactor_multiplier(key)
		var energy := float(allocation.get(key,0))+float(next_capacity)*free_ratio
		var next := 1.0+pow(energy,float(game.db.config.reactorBoostExponent))/float(game.db.config.reactorPercentScale) if energy>0.0 else 1.0
		effects[key] = {"current":current,"next":next,"gain":(next/current-1.0)*100.0}
	return {"count":maxi(0,count),"cost":cost,"capacity":capacity,"next_capacity":next_capacity,"allocation":allocation,"effects":effects}
