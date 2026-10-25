extends RefCounted
## Tasks retain progress, never personnel references. Crew views are ephemeral inputs.

static func applicable(row: Dictionary, planet_id: String) -> bool:
	if int(planet_id) < int(row.min_planet):
		return false
	var ids: PackedStringArray = str(row.planet_value).split(",")
	return row.planet_rule == "all" or (row.planet_rule == "only" and planet_id in ids) or (row.planet_rule == "exclude" and planet_id not in ids)

static func initial(definitions: Dictionary, buildings: Dictionary) -> Dictionary:
	var state: Dictionary = {}
	for id in definitions:
		var entries: Dictionary = {}
		for key in buildings:
			if applicable(buildings[key], str(id)):
				entries[key] = {"state": "locked", "work": 0}
		state[id] = {"exploration": 0, "running": false, "duration": 0.0, "elapsed": 0.0,
			"automatic": false, "conquered": false, "buildings": entries}
	return state

static func duration(progress: Dictionary, definition: Dictionary) -> float:
	var base: float = float(definition.baseTime)
	return maxf(float(definition.minTime), base * base / (base + float(progress.exploration)))

static func set_explorer(progress: Dictionary, definition: Dictionary, assigned: bool) -> Dictionary:
	if not assigned:
		cancel(progress)
		return {"ok": true}
	return start(progress, definition) if not progress.running else {"ok": true}

static func start(progress: Dictionary, definition: Dictionary) -> Dictionary:
	if progress.running:
		return {"ok": false, "reason": "PlanetAlreadyExploring"}
	progress.running = true
	progress.elapsed = 0.0
	progress.duration = duration(progress, definition)
	return {"ok": true}

static func cancel(progress: Dictionary) -> void:
	progress.running = false
	progress.elapsed = 0.0
	progress.duration = 0.0
	progress.automatic = false

static func set_automatic(progress: Dictionary, enabled: bool) -> Dictionary:
	if enabled and (not progress.buildings.has("station") or progress.buildings.station.state != "built"):
		return {"ok": false, "reason": "PlanetStationRequired"}
	# Disabling only changes continuation; the current exploration still completes.
	progress.automatic = enabled
	return {"ok": true}

static func claim_build(progress: Dictionary, building: String) -> Dictionary:
	if not progress.buildings.has(building) or progress.buildings[building].state != "ready":
		return {"ok": false, "reason": "PlanetBuildingNotReady"}
	progress.buildings[building].state = "built"
	return {"ok": true}

static func advance(state: Dictionary, definitions: Dictionary, buildings: Dictionary, explorers: Dictionary, builders: Dictionary, dt: float) -> Dictionary:
	var completed: Array = []
	var progressed: Array = []
	for id in state:
		var progress: Dictionary = state[id]
		var people: Array = explorers.get(id, [])
		if not progress.running or people.is_empty():
			continue
		progressed.append(id)
		progress.elapsed = minf(float(progress.duration), float(progress.elapsed) + dt)
		if float(progress.elapsed) + 1e-9 < float(progress.duration):
			continue
		if int(progress.exploration) == 9223372036854775807:
			return {"ok": false, "reason": "PlanetExplorationRangeExceeded"}
		var released: Array = []
		var buildings_changed: bool = false
		var assignments_changed: bool = false
		# Construction sees the pre-completion unlock state, so a threshold crossing
		# cannot also advance a newly unlocked building.
		for key in progress.buildings:
			var build: Dictionary = progress.buildings[key]
			var row: Dictionary = buildings[key]
			if build.state == "building" and builders.get(str(id) + ":" + str(key), []).size() >= int(row.extra_crew):
				buildings_changed = true
				build.work = int(build.work) + 1
				if int(build.work) >= int(row.build_explore):
					assignments_changed = true
					build.state = "ready"
					released.append(str(id) + ":" + str(key))
		progress.exploration = int(progress.exploration) + 1
		for key in progress.buildings:
			if progress.buildings[key].state == "locked" and int(progress.exploration) >= int(buildings[key].unlock_explore):
				buildings_changed = true
				assignments_changed = true
				progress.buildings[key].state = "building"
		var again: bool = progress.automatic and progress.buildings.station.state == "built"
		progress.running = again
		progress.elapsed = 0.0
		progress.duration = duration(progress, definitions[id]) if again else 0.0
		completed.append({"planet": id, "explorer": str(people[0]), "released": released, "again": again, "buildings_changed": buildings_changed, "assignments_changed": assignments_changed})
	return {"ok": true, "completed": completed, "progressed": progressed}

static func buff(state: Dictionary, rows: Array, kind: String, target: String, only_planet: String = "") -> float:
	var add: float = 0.0
	var multiply: float = 1.0
	var maximum: float = 0.0
	var has_add: bool = false
	var has_multiply: bool = false
	for row in rows:
		var id: String = str(int(row.planet_id))
		if not state.has(id) or not state[id].conquered or row.buff_type != kind or row.target != target or (not only_planet.is_empty() and id != only_planet):
			continue
		if row.stack == "add":
			has_add = true
			add += float(row.value)
		elif row.stack == "mul":
			has_multiply = true
			multiply *= float(row.value)
		elif row.stack == "max":
			maximum = maxf(maximum, float(row.value))
	return maxf((add if has_add else 1.0 if has_multiply else 0.0) * multiply, maximum)

static func contributions(state: Dictionary, buildings: Dictionary, rows: Array, api, previous: Dictionary = {}, changes: Dictionary = {}) -> Dictionary:
	var result: Dictionary = previous.duplicate()
	if not previous.is_empty(): result._sources = previous._sources.duplicate()
	var affected: Dictionary = {}
	var one: Dictionary = api.apply("from_decimal", ["1"]).value
	if result.is_empty():
		result = {"ok": true, "equipment": one, "refinery": one, "_sources": {"equipment": {}, "refinery": {}},
			"equipment_levels": int(buff(state, rows, "level_bonus", "equipment")),
			"enhancement_levels": int(buff(state, rows, "level_bonus", "enhancement")), "free_charge": buff(state, rows, "free_charge", "all")}
		for id in state:
			changes[id] = []
			for key in state[id].buildings:
				if buildings[key].type in ["equipment", "refinery"]: result._sources[buildings[key].type][str(id) + ":" + str(key)] = one
	for id in changes:
		var keys: Array = state[id].buildings.keys() if changes[id].is_empty() else changes[id]
		for key in keys:
			var row: Dictionary = buildings[key]
			if row.type not in ["equipment", "refinery"] or state[id].buildings[key].state != "built": continue
			var count = api.apply("from_decimal", [str(state[id].exploration)])
			var scale = api.apply("from_decimal", [str(row.config1)])
			count = api.apply("mul", [count.value, scale.value])
			if not count.ok: return count
			count = api.apply("add", [one, count.value])
			var value = api.apply("pow", [count.value, float(row.config2)])
			if not value.ok: return value
			var source: String = str(id) + ":" + str(key)
			if value.value == result._sources[row.type][source]: continue
			if not affected.has(row.type): result._sources[row.type] = result._sources[row.type].duplicate()
			result._sources[row.type][source] = value.value
			affected[row.type] = true
	for effect in affected:
		var value: Dictionary = one
		for factor in result._sources[effect].values():
			var multiplied = api.apply("mul", [value, factor])
			if not multiplied.ok: return multiplied
			value = multiplied.value
		result[effect] = value
	return result

static func experience_reward(definition: Dictionary, stage_ratio, galaxy_factor: Dictionary, api) -> Dictionary:
	var earned = api.apply("from_decimal", [str(definition.baseExp)])
	var ratio = api.apply("from_decimal", [str(stage_ratio)])
	for result in [earned, ratio]:
		if not result.ok: return result
	earned = api.apply("mul", [earned.value, ratio.value])
	if not earned.ok: return earned
	earned = api.apply("mul", [earned.value, galaxy_factor])
	if not earned.ok: return earned
	var half = api.apply("from_decimal", ["0.5"])
	earned = api.apply("add", [earned.value, half.value])
	if not earned.ok: return earned
	return api.apply("floor", [earned.value])
