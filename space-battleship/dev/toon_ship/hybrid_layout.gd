extends RefCounted
## Pure visual assignment. Gameplay capacity is supplied by BattleGame, never redefined here.
## Every active weapon uses its own physical hull socket. Slot identity survives refits.
static func assign(entries: Array, active_capacity: int, hull_budget: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	assert(active_capacity <= hull_budget, "Configured weapon slots exceed physical hull mounts")
	for slot in mini(entries.size(),maxi(active_capacity,0)):
		var key := str(entries[slot].get("key",""))
		if key.is_empty(): continue
		var ordinal := result.size()
		result.append({"slot":slot,"key":key,"carrier":"hull","mount":ordinal})
	return result
