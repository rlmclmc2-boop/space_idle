extends RefCounted
## Pure visual assignment. Gameplay capacity is supplied by BattleGame, never redefined here.
## Ascending active occupied slots fill hull sockets, then visual carriers. Slot identity survives repeats.
static func assign(entries: Array, active_capacity: int, hull_budget: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for slot in mini(entries.size(),maxi(active_capacity,0)):
		var key := str(entries[slot].get("key",""))
		if key.is_empty(): continue
		var ordinal := result.size()
		result.append({"slot":slot,"key":key,"carrier":"hull" if ordinal<hull_budget else "drone",
			"mount":ordinal if ordinal<hull_budget else ordinal-hull_budget})
	return result
