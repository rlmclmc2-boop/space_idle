extends RefCounted
## Region work, RNG, opening rules and contribution ledgers have one owner.
signal status_changed(keys: Array)
signal availability_changed

var _definitions: Dictionary = {}
var _buildings: Dictionary = {}
var _rules: Dictionary = {}
var _regions: Dictionary = {}
var _available: Dictionary = {}
var _factors: Dictionary = {}
var _initial_error: String = ""
var _api

func _init(rows: Array, buildings: Array, rules: Array, api) -> void:
	for row in rows: _definitions[str(row.key)] = row
	for row in buildings: _buildings[str(row.key)] = row
	for row in rules: _rules[str(row.key)] = row.value
	_api = api
	var result = _initial(_definitions)
	if result.ok: _regions = result.regions
	else: _initial_error = str(result.reason)

func initialization_result() -> Dictionary:
	return {"ok": _initial_error.is_empty(), "reason": _initial_error}

func refresh_availability(enabled: bool, cleared_stages: Dictionary) -> void:
	var next: Dictionary = {}
	for key in _regions:
		var row: Dictionary = _definitions[key]
		next[key] = _regions[key].get("unlocked", false) or (enabled and row.unlock_type == "stage_cleared" and cleared_stages.has(int(row.unlock_value)))
		if next[key]: _regions[key].unlocked = true
	if next != _available:
		_available = next
		availability_changed.emit()

func is_available(key: String) -> bool:
	return _available.get(key, false)

func contributions(changes: Array = []) -> Dictionary:
	var output = _contributions(_regions, _buildings, _api, _factors, changes)
	if output.ok: _factors = output
	return output

func advance(counts: Dictionary, dt: float) -> Dictionary:
	var result = _advance(_regions, _definitions, _buildings, counts, _available, dt, float(_rules.income_interval))
	if not result.ok: return result
	if not result.displayed.is_empty(): status_changed.emit(result.displayed)
	if not result.changes.is_empty():
		result.contributions = contributions(result.changes)
		if not result.contributions.ok: return result.contributions
	return result

func income(region: String, production_rates: Dictionary, seconds: float) -> Dictionary:
	return _income(_factors, region, production_rates, seconds, _api)

func assignment_options() -> Array:
	var options: Array = []
	for key in _regions:
		if is_available(key): options.append({"label": "星系 · " + str(_definitions[key].name), "kind": "galaxy", "target": key})
	return options

func status_rows(keys: Array = []) -> Array:
	var rows: Array = []
	for key in (_regions.keys() if keys.is_empty() else keys):
		if not is_available(str(key)): continue
		var region: Dictionary = _regions[key]
		var phase: String = str({"exploring": "探索施工", "developing": "发展升级", "complete": "已完成"}[region.phase])
		var text: String = "%s · %s · 探索 %d/%d · 建筑 %d · 等级合计 %d · 升级中 %d" % [_definitions[key].name, phase, region.explored_count, region.nodes.size(), region.active_count, region.total_levels, region.upgrades.size()]
		if not str(region.active_node).is_empty():
			var work: Dictionary = region.nodes[str(region.active_node)]
			text += "\n%s · %s" % [_buildings[work.building].name, "剩余探索工作 %.1f" % float(work.explore_remaining) if not work.explored else "剩余施工 %.1f 秒" % float(work.construction_remaining)]
		rows.append({"id": str(key), "text": text})
	return rows

static func _generate(count: int) -> Array:
	var nodes: Array = []
	var positions: Dictionary = {Vector2i.ZERO: -1}
	var queue: Array[Vector2i] = [Vector2i.ZERO]
	var cursor: int = 0
	while nodes.size() < count:
		var parent: Vector2i = queue[cursor]
		cursor += 1
		var parent_id: int = int(positions[parent])
		var depth: int = 1 if parent_id == -1 else int(nodes[parent_id].depth) + 1
		for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			var cell: Vector2i = parent + direction
			if positions.has(cell) or nodes.size() >= count: continue
			var id: int = nodes.size()
			nodes.append({"id": id, "parent_id": parent_id, "depth": depth})
			positions[cell] = id
			queue.append(cell)
	return nodes

static func _initial(definitions: Dictionary) -> Dictionary:
	var regions: Dictionary = {}
	for key in definitions:
		var definition: Dictionary = definitions[key]
		var count: int = int(definition.building_slot_count)
		if count <= 0 or float(definition.explore_work_total) <= 0.0:
			return {"ok": false, "reason": "InvalidGalaxyWorkDefinition"}
		var blueprint: Array = _generate(count)
		var nodes: Dictionary = {}
		var quota: float = float(definition.explore_work_total) / blueprint.size()
		var remaining: float = float(definition.explore_work_total)
		for source in blueprint:
			var id: String = str(int(source.id))
			var work: float = remaining if int(source.id) == blueprint.size() - 1 else quota
			remaining = maxf(0.0, remaining - work)
			nodes[id] = {"parent_id": int(source.parent_id), "depth": int(source.depth),
				"explored": false, "explore_remaining": work,
				"state": "empty", "building": "", "level": 0, "construction_remaining": 0.0, "upgrade_remaining": 0.0}
		var random := RandomNumberGenerator.new()
		random.seed = int(definition.slot_seed)
		regions[key] = {"unlocked": false, "phase": "exploring", "nodes": nodes, "active_node": "", "attempt_elapsed": 0.0,
			"income_elapsed": 0.0, "explored_count": 0, "active_count": 0, "total_levels": 0, "upgrades": [], "bag": [], "bag_round": 0, "special_pending": false, "rng_state": random.state}
	return {"ok": true, "regions": regions}

static func _reachable(region: Dictionary) -> Array:
	var choices: Array = []
	var depth: int = 9223372036854775807
	for id in region.nodes:
		var node: Dictionary = region.nodes[id]
		if node.state != "empty": continue
		var parent: int = int(node.parent_id)
		if parent != -1 and not region.nodes[str(parent)].explored: continue
		if int(node.depth) > depth: continue
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

static func _advance(regions: Dictionary, definitions: Dictionary, buildings: Dictionary, personnel: Dictionary, enabled: Dictionary, dt: float, income_interval: float) -> Dictionary:
	var changes: Array = []
	var displayed: Array = []
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
		var upgrading: Array = region.upgrades.duplicate()
		var display_changed: bool = false
		var had_active: bool = not str(region.active_node).is_empty()
		if had_active:
			display_changed = true
			var node: Dictionary = region.nodes[str(region.active_node)]
			if not node.explored:
				node.explore_remaining = maxf(0.0, float(node.explore_remaining) - dt * (float(row.explore_power_base) + float(row.explore_power_per_crew) * count))
				if float(node.explore_remaining) <= 1e-9:
					node.explore_remaining = 0.0
					region.explored_count += 1
					node.explored = true
					node.state = "constructing"
					node.construction_remaining = float(row.construction_time)
			else:
				node.construction_remaining = maxf(0.0, float(node.construction_remaining) - dt)
				if float(node.construction_remaining) <= 1e-9:
					node.construction_remaining = 0.0
					region.active_count += 1
					region.total_levels += 1
					node.level = 1
					node.state = "active"
					changes.append({"region": key, "node": str(region.active_node)})
					region.active_node = ""
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
					display_changed = true
		if int(region.explored_count) == region.nodes.size() and region.phase == "exploring": region.phase = "developing"
		if not upgrading.is_empty():
			var power: float = (float(row.upgrade_power_base) + float(row.upgrade_power_per_crew) * count) / upgrading.size()
			for id in upgrading:
				var node: Dictionary = region.nodes[id]
				node.upgrade_remaining = maxf(0.0, float(node.upgrade_remaining) - dt * power)
				if float(node.upgrade_remaining) <= 1e-9:
					node.upgrade_remaining = 0.0
					region.total_levels += 1
					region.upgrades.erase(id)
					display_changed = true
					node.level = int(node.level) + 1
					changes.append({"region": key, "node": str(id)})
		if region.phase == "developing" and region.upgrades.size() < int(row.concurrent_upgrade_count):
			var active_upgrades: int = region.upgrades.size()
			var candidates: Array = []
			var complete: bool = true
			for id in region.nodes:
				var node: Dictionary = region.nodes[id]
				if node.state != "active":
					complete = false
					continue
				if int(node.level) < int(buildings[node.building].max_lv): complete = false
				if float(node.upgrade_remaining) <= 0.0 and int(node.level) < int(buildings[node.building].max_lv): candidates.append(id)
			candidates.sort_custom(func(a, b): return int(a) < int(b))
			while active_upgrades < int(row.concurrent_upgrade_count) and not candidates.is_empty():
				var index: int = random.randi_range(0, candidates.size() - 1)
				var id: String = str(candidates[index])
				candidates.remove_at(index)
				region.nodes[id].upgrade_remaining = float(row["upgrade_cost_lv" + str(int(region.nodes[id].level) + 1)])
				active_upgrades += 1
				region.upgrades.append(id)
				display_changed = true
			if complete and region.phase != "complete":
				region.phase = "complete"
				display_changed = true
		if display_changed: displayed.append(key)
		region.rng_state = random.state
	return {"ok": true, "changes": changes, "payments": payments, "displayed": displayed}

static func _contributions(regions: Dictionary, buildings: Dictionary, api, previous: Dictionary = {}, changes: Array = []) -> Dictionary:
	var result: Dictionary = previous.duplicate()
	if not previous.is_empty():
		result._sources = previous._sources.duplicate()
		result._regional = previous._regional.duplicate()
		result["values"] = previous["values"].duplicate()
	var one: Dictionary = api.apply("from_decimal", ["1"]).value
	var zero: Dictionary = api.apply("zero", []).value
	var affected: Dictionary = {}
	if result.is_empty():
		result = {"ok": true, "values": {}, "_sources": {}, "_regional": {}}
		for effect in ["crew_exp", "equipment_value", "charge_max", "gem_fragment", "iron_auto_ratio", "uranium_auto_ratio"]:
			result._sources[effect] = {}
			result._regional[effect] = {}
			for key in regions:
				result._sources[effect][key] = {}
				result._regional[effect][key] = zero
			if effect not in ["iron_auto_ratio", "uranium_auto_ratio"]: result["values"][effect] = one
	for change in changes:
		var node: Dictionary = regions[change.region].nodes[change.node]
		var row: Dictionary = buildings[node.building]
		var effect: String = str(row.effect_type)
		var base = api.apply("from_decimal", [str(row.base_effect)])
		var level = api.apply("from_decimal", [str(node.level)])
		var value = api.apply("mul", [base.value, level.value])
		if not value.ok: return value
		if not affected.has(effect):
			affected[effect] = {}
			result._sources[effect] = result._sources[effect].duplicate()
			result._regional[effect] = result._regional[effect].duplicate()
		if not affected[effect].has(change.region): result._sources[effect][change.region] = result._sources[effect][change.region].duplicate()
		result._sources[effect][change.region][change.node] = value.value
		affected[effect][change.region] = true
	result.growth_changed = false
	for effect in affected:
		for region in affected[effect]:
			var sources: Dictionary = result._sources[effect][region]
			var ids: Array = sources.keys()
			ids.sort_custom(func(a, b): return int(a) < int(b))
			var sum: Dictionary = zero
			for id in ids:
				var added = api.apply("add", [sum, sources[id]])
				if not added.ok: return added
				sum = added.value
			result._regional[effect][region] = sum
		if effect in ["iron_auto_ratio", "uranium_auto_ratio"]: continue
		var total: Dictionary = one
		for sum in result._regional[effect].values():
			var factor = api.apply("add", [one, sum])
			var value = api.apply("mul", [total, factor.value])
			if not value.ok: return value
			total = value.value
		result.growth_changed = result.growth_changed or total != result["values"][effect]
		result["values"][effect] = total
	return result

static func _income(contributions: Dictionary, region: String, production_rates: Dictionary, seconds: float, api) -> Dictionary:
	var duration = api.apply("from_decimal", [str(seconds)])
	if not duration.ok: return duration
	var amounts: Dictionary = {}
	for pair in [["1", "iron_auto_ratio"], ["2", "uranium_auto_ratio"]]:
		var quantity = api.apply("mul", [production_rates[pair[0]], contributions._regional[pair[1]][region]])
		if not quantity.ok: return quantity
		quantity = api.apply("mul", [quantity.value, duration.value])
		if not quantity.ok: return quantity
		amounts[pair[0]] = quantity.value
	return {"ok": true, "amounts": amounts}
