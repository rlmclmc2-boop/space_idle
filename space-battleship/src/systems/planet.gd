extends RefCounted
## Exploration/construction retain no personnel state; callers provide current crew views.
signal status_changed(ids: Array)
signal buildings_changed(ids: Array)
signal assignment_options_changed(ids: Array)
signal availability_changed

var _definitions: Dictionary = {}
var _buildings: Dictionary = {}
var _buffs: Array
var _state: Dictionary
var _gates: Dictionary = {}
var _available: Dictionary = {}
var _factors: Dictionary = {}
var _api

func _init(rows: Array, buildings: Array, buffs: Array, api) -> void:
	for row in rows: _definitions[str(int(row.id))] = row
	for row in buildings: _buildings[str(row.id)] = row
	_buffs = buffs
	_api = api
	_state = _initial(_definitions, _buildings)

func refresh_availability(unlocked: Callable) -> void:
	for id in _definitions: _gates[id] = bool(unlocked.call("planet", id))
	_refresh_available()

func _refresh_available() -> void:
	var next: Dictionary = {}
	for id in _definitions:
		next[id] = _gates.get(id, false) and (int(id) == 1 or _buff(_state, _buffs, "planet_unlock", "planet") >= int(id))
	if next != _available:
		_available = next
		availability_changed.emit()

func is_available(id: String) -> bool:
	return _available.get(id, false)

func assignment_capacity(kind: String, target: String) -> Dictionary:
	if kind == "planet_explore":
		return {"ok": true, "capacity": 1} if is_available(target) else {"ok": false, "reason": "PlanetLocked"}
	var parts: PackedStringArray = target.split(":")
	if parts.size() != 2 or not is_available(parts[0]) or not _state[parts[0]].buildings.has(parts[1]) or _state[parts[0]].buildings[parts[1]].state != "building":
		return {"ok": false, "reason": "PlanetBuildingUnavailable"}
	return {"ok": true, "capacity": int(_buildings[parts[1]].extra_crew)}

func set_explorer(id: String, assigned: bool) -> Dictionary:
	var result = _set_explorer(_state[id], _definitions[id], assigned)
	status_changed.emit([id])
	return result

func cancel(id: String) -> Dictionary:
	if not _state.has(id): return {"ok": false, "reason": "UnknownPlanet"}
	_cancel(_state[id])
	status_changed.emit([id])
	return {"ok": true}

func set_automatic(id: String, enabled: bool) -> Dictionary:
	if not is_available(id): return {"ok": false, "reason": "PlanetLocked"}
	return _set_automatic(_state[id], enabled)

func claim_build(id: String, building: String, publish: Callable) -> Dictionary:
	if not is_available(id): return {"ok": false, "reason": "PlanetLocked"}
	var claimed = _claim_build(_state[id], building)
	if not claimed.ok: return claimed
	buildings_changed.emit([id])
	var output = contributions({id: [building]})
	if not output.ok: return output
	_refresh_available()
	return publish.call(output)

func contributions(changes: Dictionary = {}) -> Dictionary:
	var output = _contributions(_state, _buildings, _buffs, _api, _factors, changes)
	if output.ok: _factors = output
	return output

func advance(explorers: Dictionary, builders: Dictionary, dt: float, experience_context: Callable) -> Dictionary:
	var result = _advance(_state, _definitions, _buildings, explorers, builders, dt)
	if not result.ok: return result
	if not result.progressed.is_empty(): status_changed.emit(result.progressed)
	if result.completed.is_empty(): return result
	var context: Dictionary = experience_context.call()
	var changes: Dictionary = {}
	for completion in result.completed:
		var id: String = str(completion.planet)
		changes[id] = []
		if completion.buildings_changed: buildings_changed.emit([id])
		if completion.assignments_changed: assignment_options_changed.emit([id])
		completion.award_experience = context.enabled
		if context.enabled:
			var earned = _experience_reward(_definitions[id], context.ratio, context.factor, _api)
			if not earned.ok: return earned
			completion.experience = earned.value
			completion.share_experience = _buff(_state, _buffs, "crew_exp_share", "all", id) > 0
	result.contributions = contributions(changes)
	if not result.contributions.ok: return result.contributions
	return result

func planet_options() -> Array:
	var rows: Array = []
	for id in _definitions:
		if is_available(id): rows.append({"id": id, "name": str(_definitions[id].name)})
	return rows

func assignment_options(ids: Array = [], building_only: bool = false) -> Array:
	var rows: Array = []
	for id in (_definitions.keys() if ids.is_empty() else ids):
		if not is_available(str(id)): continue
		var name: String = str(_definitions[id].name)
		if not building_only: rows.append({"label": "探索 · " + name, "kind": "planet_explore", "target": str(id)})
		for key in _state[id].buildings:
			if _state[id].buildings[key].state == "building" and int(_buildings[key].extra_crew) > 0:
				rows.append({"label": "施工 · " + name + " · " + str(_buildings[key].name), "kind": "planet_build", "target": str(id) + ":" + str(key)})
	return rows

func building_options(id: String) -> Array:
	var options: Array = []
	if not _state.has(id): return options
	var names := {"locked": "未解锁", "building": "施工中", "ready": "可领取", "built": "已建造"}
	for key in _state[id].buildings:
		var progress: Dictionary = _state[id].buildings[key]
		var row: Dictionary = _buildings[key]
		options.append({"id": key, "name": str(row.name) + " · " + str(names[progress.state]) + " %d/%d" % [int(progress.work), int(row.build_explore)]})
	return options

func status_rows(ids: Array = []) -> Array:
	var rows: Array = []
	for id in (_definitions.keys() if ids.is_empty() else ids):
		if not is_available(str(id)): continue
		var progress: Dictionary = _state[id]
		rows.append({"id": str(id), "text": "%s · 探索 %d · %s" % [_definitions[id].name, int(progress.exploration), "%.1f/%.1f 秒" % [float(progress.elapsed), float(progress.duration)] if progress.running else "未派遣"]})
	return rows

static func _applicable(row: Dictionary, planet_id: String) -> bool:
	if int(planet_id) < int(row.min_planet):
		return false
	var ids: PackedStringArray = str(row.planet_value).split(",")
	return row.planet_rule == "all" or (row.planet_rule == "only" and planet_id in ids) or (row.planet_rule == "exclude" and planet_id not in ids)

static func _initial(definitions: Dictionary, buildings: Dictionary) -> Dictionary:
	var state: Dictionary = {}
	for id in definitions:
		var entries: Dictionary = {}
		for key in buildings:
			if _applicable(buildings[key], str(id)):
				entries[key] = {"state": "locked", "work": 0}
		state[id] = {"exploration": 0, "running": false, "duration": 0.0, "elapsed": 0.0,
			"automatic": false, "conquered": false, "buildings": entries}
	return state

static func _duration(progress: Dictionary, definition: Dictionary) -> float:
	var base: float = float(definition.baseTime)
	return maxf(float(definition.minTime), base * base / (base + float(progress.exploration)))

static func _set_explorer(progress: Dictionary, definition: Dictionary, assigned: bool) -> Dictionary:
	if not assigned:
		_cancel(progress)
		return {"ok": true}
	return _start(progress, definition) if not progress.running else {"ok": true}

static func _start(progress: Dictionary, definition: Dictionary) -> Dictionary:
	if progress.running:
		return {"ok": false, "reason": "PlanetAlreadyExploring"}
	progress.running = true
	progress.elapsed = 0.0
	progress.duration = _duration(progress, definition)
	return {"ok": true}

static func _cancel(progress: Dictionary) -> void:
	progress.running = false
	progress.elapsed = 0.0
	progress.duration = 0.0
	progress.automatic = false

static func _set_automatic(progress: Dictionary, enabled: bool) -> Dictionary:
	if enabled and (not progress.buildings.has("station") or progress.buildings.station.state != "built"):
		return {"ok": false, "reason": "PlanetStationRequired"}
	# Disabling only changes continuation; the current exploration still completes.
	progress.automatic = enabled
	return {"ok": true}

static func _claim_build(progress: Dictionary, building: String) -> Dictionary:
	if not progress.buildings.has(building) or progress.buildings[building].state != "ready":
		return {"ok": false, "reason": "PlanetBuildingNotReady"}
	progress.buildings[building].state = "built"
	return {"ok": true}

static func _advance(state: Dictionary, definitions: Dictionary, buildings: Dictionary, explorers: Dictionary, builders: Dictionary, dt: float) -> Dictionary:
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
		progress.duration = _duration(progress, definitions[id]) if again else 0.0
		completed.append({"planet": id, "explorer": str(people[0]), "released": released, "again": again, "buildings_changed": buildings_changed, "assignments_changed": assignments_changed})
	return {"ok": true, "completed": completed, "progressed": progressed}

static func _buff(state: Dictionary, rows: Array, kind: String, target: String, only_planet: String = "") -> float:
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

static func _contributions(state: Dictionary, buildings: Dictionary, rows: Array, api, previous: Dictionary = {}, changes: Dictionary = {}) -> Dictionary:
	var result: Dictionary = previous.duplicate()
	if not previous.is_empty(): result._sources = previous._sources.duplicate()
	var affected: Dictionary = {}
	var one: Dictionary = api.apply("from_decimal", ["1"]).value
	if result.is_empty():
		result = {"ok": true, "equipment": one, "refinery": one, "_sources": {"equipment": {}, "refinery": {}},
			"equipment_levels": int(_buff(state, rows, "level_bonus", "equipment")),
			"enhancement_levels": int(_buff(state, rows, "level_bonus", "enhancement")), "free_charge": _buff(state, rows, "free_charge", "all")}
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

static func _experience_reward(definition: Dictionary, stage_ratio, galaxy_factor: Dictionary, api) -> Dictionary:
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
