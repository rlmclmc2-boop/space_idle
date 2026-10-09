extends RefCounted
## Read-only projection of one purchase, including its integer allocation growth.
const Growth := preload("res://scripts/reactor_allocation_growth.gd")

static func quote(game: BattleGame, count: int) -> Dictionary:
	var level := int(game.profile.reactorLevel)
	var capacity := game.reactor_capacity()
	var next_capacity := capacity if count <= 0 else maxi(0,int(floor(game.reactor_energy(level+count))))
	var allocation: Dictionary = Growth.expand(Array(game.reactor_modules()),game.profile.reactorAllocation,capacity,next_capacity)
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
