extends RefCounted
## Region work and RNG belong to Session progress; personnel arrive as current counts.

static func initial(definitions: Dictionary, blueprints: Dictionary) -> Dictionary:
	var regions: Dictionary = {}
	for key in definitions:
		var definition: Dictionary = definitions[key]
		if not blueprints.has(key) or blueprints[key].size() != int(definition.building_slot_count):
			return {"ok": false, "reason": "GalaxyBlueprintRequired"}
		var nodes: Dictionary = {}
		for source in blueprints[key]:
			var id: String = str(int(source.id))
			if nodes.has(id) or int(source.depth) < 0:
				return {"ok": false, "reason": "InvalidGalaxyBlueprint"}
			nodes[id] = {"id": id, "depth": int(source.depth), "neighbors": source.neighbors.duplicate(),
				"explored": false, "explore_remaining": float(definition.explore_work_total) / blueprints[key].size(),
				"state": "empty", "building": "", "level": 0, "construction_remaining": 0.0, "upgrade_remaining": 0.0}
		for id in nodes:
			for neighbor in nodes[id].neighbors:
				if int(neighbor) != -1 and not nodes.has(str(int(neighbor))):
					return {"ok": false, "reason": "InvalidGalaxyBlueprint"}
		var random := RandomNumberGenerator.new()
		random.seed = int(definition.slot_seed)
		regions[key] = {"unlocked": false, "phase": "exploring", "nodes": nodes, "active_node": "", "attempt_elapsed": 0.0,
			"income_elapsed": 0.0, "bag": [], "bag_round": 0, "special_pending": false, "rng_state": random.state}
	return {"ok": true, "regions": regions}

static func _reachable(region: Dictionary) -> Array:
	var choices: Array = []
	var depth: int = 9223372036854775807
	for id in region.nodes:
		var node: Dictionary = region.nodes[id]
		if node.state != "empty": continue
		var reachable: bool = false
		for neighbor in node.neighbors:
			if int(neighbor) == -1 or region.nodes[str(int(neighbor))].explored:
				reachable = true
				break
		if not reachable or int(node.depth) > depth: continue
		if int(node.depth) < depth:
			choices.clear()
			depth = int(node.depth)
		choices.append(id)
	choices.sort_custom(func(a, b): return int(a) < int(b))
	return choices

static func _draw(region: Dictionary, buildings: Dictionary, key: String, cycle: int, random: RandomNumberGenerator) -> String:
	var normal: Array = []
	var special: Array = []
	for id in buildings:
		if buildings[id].galaxy_key != key: continue
		if buildings[id].group == "normal": normal.append(id)
		elif buildings[id].group == "special": special.append(id)
	if region.special_pending:
		region.special_pending = false
		return "" if special.is_empty() else str(special[random.randi_range(0, special.size() - 1)])
	if region.bag.is_empty():
		region.bag = normal.duplicate()
		for i in range(region.bag.size() - 1, 0, -1):
			var other: int = random.randi_range(0, i)
			var held = region.bag[i]
			region.bag[i] = region.bag[other]
			region.bag[other] = held
	if region.bag.is_empty(): return ""
	var selected: String = str(region.bag.pop_back())
	if region.bag.is_empty():
		region.bag_round = int(region.bag_round) + 1
		region.special_pending = int(region.bag_round) % cycle == 0
	return selected

static func advance(regions: Dictionary, definitions: Dictionary, buildings: Dictionary, personnel: Dictionary, enabled: Dictionary, dt: float, income_interval: float) -> Dictionary:
	var changed: bool = false
	var payments: Array = []
	for key in regions:
		if not enabled.get(key, false): continue
		var region: Dictionary = regions[key]
		var row: Dictionary = definitions[key]
		region.income_elapsed = float(region.income_elapsed) + dt
		if float(region.income_elapsed) + 1e-9 >= income_interval:
			region.income_elapsed = maxf(0.0, float(region.income_elapsed) - income_interval)
			payments.append({"galaxy": key, "seconds": income_interval})
		var count: int = int(personnel.get(key, 0))
		if count <= 0: continue
		var random := RandomNumberGenerator.new()
		random.state = int(region.rng_state)
		var upgrading: Array = []
		for id in region.nodes:
			if float(region.nodes[id].upgrade_remaining) > 0.0: upgrading.append(id)
		var had_active: bool = not str(region.active_node).is_empty()
		if had_active:
			var node: Dictionary = region.nodes[str(region.active_node)]
			if not node.explored:
				node.explore_remaining = maxf(0.0, float(node.explore_remaining) - dt * (float(row.explore_power_base) + float(row.explore_power_per_crew) * count))
				if float(node.explore_remaining) <= 1e-9:
					node.explore_remaining = 0.0
					node.explored = true
					node.state = "constructing"
					node.construction_remaining = float(row.construction_time)
			else:
				node.construction_remaining = maxf(0.0, float(node.construction_remaining) - dt)
				if float(node.construction_remaining) <= 1e-9:
					node.construction_remaining = 0.0
					node.level = 1
					node.state = "active"
					region.active_node = ""
					changed = true
		elif region.phase == "exploring":
			region.attempt_elapsed = float(region.attempt_elapsed) + dt
			if float(region.attempt_elapsed) + 1e-9 >= float(row.build_interval):
				region.attempt_elapsed = 0.0
				var candidates: Array = _reachable(region)
				if not candidates.is_empty():
					var id: String = str(candidates[random.randi_range(0, candidates.size() - 1)])
					var building: String = _draw(region, buildings, key, int(row.special_cycle), random)
					if building.is_empty(): return {"ok": false, "reason": "GalaxyBuildingPoolEmpty"}
					region.nodes[id].state = "exploring"
					region.nodes[id].building = building
					region.active_node = id
		var all_explored: bool = true
		for id in region.nodes:
			if not region.nodes[id].explored: all_explored = false
		if all_explored and region.phase == "exploring": region.phase = "developing"
		if not upgrading.is_empty():
			var power: float = (float(row.upgrade_power_base) + float(row.upgrade_power_per_crew) * count) / upgrading.size()
			for id in upgrading:
				var node: Dictionary = region.nodes[id]
				node.upgrade_remaining = maxf(0.0, float(node.upgrade_remaining) - dt * power)
				if float(node.upgrade_remaining) <= 1e-9:
					node.upgrade_remaining = 0.0
					node.level = int(node.level) + 1
					changed = true
		if region.phase == "developing":
			var active_upgrades: int = 0
			var candidates: Array = []
			var complete: bool = true
			for id in region.nodes:
				var node: Dictionary = region.nodes[id]
				if node.state != "active":
					complete = false
					continue
				if int(node.level) < int(buildings[node.building].max_lv): complete = false
				if float(node.upgrade_remaining) > 0.0: active_upgrades += 1
				elif int(node.level) < int(buildings[node.building].max_lv): candidates.append(id)
			candidates.sort_custom(func(a, b): return int(a) < int(b))
			while active_upgrades < int(row.concurrent_upgrade_count) and not candidates.is_empty():
				var index: int = random.randi_range(0, candidates.size() - 1)
				var id: String = str(candidates[index])
				candidates.remove_at(index)
				region.nodes[id].upgrade_remaining = float(row["upgrade_cost_lv" + str(int(region.nodes[id].level) + 1)])
				active_upgrades += 1
			if complete: region.phase = "complete"
		region.rng_state = random.state
	return {"ok": true, "changed": changed, "payments": payments}

static func factors(regions: Dictionary, buildings: Dictionary, api) -> Dictionary:
	var one: Dictionary = api.apply("from_decimal", ["1"]).value
	var zero: Dictionary = api.apply("zero", []).value
	var values: Dictionary = {"crew_exp": one, "equipment_value": one, "charge_max": one, "gem_fragment": one, "iron_auto_ratio": zero, "uranium_auto_ratio": zero}
	for key in regions:
		var sums: Dictionary = {}
		for node in regions[key].nodes.values():
			if node.state != "active": continue
			var row: Dictionary = buildings[node.building]
			var base = api.apply("from_decimal", [str(row.base_effect)])
			var level = api.apply("from_decimal", [str(node.level)])
			var effect = api.apply("mul", [base.value, level.value])
			if not effect.ok: return effect
			var sum = api.apply("add", [sums.get(row.effect_type, zero), effect.value])
			if not sum.ok: return sum
			sums[row.effect_type] = sum.value
		for effect in values:
			var result: Dictionary
			if effect in ["iron_auto_ratio", "uranium_auto_ratio"]:
				result = api.apply("add", [values[effect], sums.get(effect, zero)])
			else:
				var factor = api.apply("add", [one, sums.get(effect, zero)])
				result = api.apply("mul", [values[effect], factor.value])
			if not result.ok: return result
			values[effect] = result.value
	return {"ok": true, "values": values}
