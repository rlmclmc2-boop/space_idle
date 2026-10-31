extends RefCounted

const Resources = preload("res://src/systems/resource_amounts.gd")
const CombatSetup = preload("res://src/combat_setup.gd")

var _run_state
var _api
var _parameters: Dictionary = {}
var _routes: Dictionary = {}
var _groups: Dictionary = {}
var _lineups: Dictionary = {}
var _enemies: Dictionary = {}
var _weapons: Dictionary = {}
var _references: Dictionary = {}
var _assignments: Dictionary = {}
var _early_budgets: Dictionary = {}
var _main_groups: Dictionary = {}
var _main_enemies: Dictionary = {}
var _enemy_weapon_definitions: Dictionary = {}
var _levels: Dictionary = {}
var _slot_rows: Array = []
var _qualities: Array = []
var _affixes: Dictionary = {}
var _affix_ranges: Dictionary = {}
var _tiers: Array = []
var _legends: Array = []
var _legend_parameters: Dictionary = {}
var _legacy_legend_ranges: Dictionary = {}
var _planets: Array = []
var _history: Dictionary = {}
var _manual: Dictionary = {}
var _idle: Dictionary = {}
var _auto: Dictionary = {"enabled": false, "route": "", "crew_id": ""}
var _warehouse: Array = []
var _overflow: Array = []
var _equipped: Array = []
var _favorites: Array = []
var _sealed: Dictionary = {}
var _presets: Array = []
var _receipts: Dictionary = {}
var _filter: Dictionary = {"version": 2, "enabled": false, "mode": "all", "action": "keep_matches", "conditions": []}
var _modules: Dictionary = {}
var _module_definitions: Dictionary = {}
var _forge_costs: Dictionary = {}
var _last_forge: Dictionary = {}
var _legend_seen: Dictionary = {}
var _legend_collection: Dictionary = {}
var _energy: Dictionary = {}
var _energy_progress: Dictionary = {}
var _energy_meter: Dictionary = {}
var _late_supply_work: float = 0.0
var _reward_rng := RandomNumberGenerator.new()
var _luck_rng := RandomNumberGenerator.new()
var _round_id: int = 1
var _next_run: int = 1
var _next_enemy_uid: int = 0
var _base_seed: int = 1
var _reforge_count: int = 0
var _unlocked_drones: Dictionary = {}
var _planet_claim_levels: Dictionary = {}

func save_state() -> Dictionary:
	return {"history": _history.duplicate(true), "manual": _manual.duplicate(true),
		"idle": _idle.duplicate(true), "auto": _auto.duplicate(true),
		"warehouse": _warehouse.duplicate(true), "overflow": _overflow.duplicate(true),
		"equipped": _equipped.duplicate(true), "favorites": _favorites.duplicate(true),
		"sealed": _sealed.duplicate(true), "presets": _presets.duplicate(true),
		"receipts": _receipts.duplicate(true), "filter": _filter.duplicate(true),
		"modules": _modules.duplicate(true), "last_forge": _last_forge.duplicate(true),
		"legend_seen": _legend_seen.duplicate(true), "legend_collection": _legend_collection.duplicate(true),
		"energy": _energy.duplicate(true), "energy_progress":_energy_progress.duplicate(true), "energy_meter":_energy_meter.duplicate(true), "late_supply_work": _late_supply_work,
		"reward_rng_state": _reward_rng.state, "luck_rng_state": _luck_rng.state,
		"round_id": _round_id, "next_run": _next_run, "next_enemy_uid": _next_enemy_uid,
		"base_seed": _base_seed, "reforge_count": _reforge_count, "unlocked_drones": _unlocked_drones.duplicate(true)}

func restore_state(state: Dictionary) -> Dictionary:
	for key in ["history", "manual", "idle", "auto", "sealed", "receipts", "filter", "modules",
		"last_forge", "legend_seen", "legend_collection", "unlocked_drones"]:
		if not state.get(key) is Dictionary: return {"ok": false, "reason": "InvalidHyperspaceState"}
	for key in ["warehouse", "overflow", "equipped", "favorites", "presets"]:
		if not state.get(key) is Array: return {"ok": false, "reason": "InvalidHyperspaceState"}
	for key in ["round_id", "next_run", "next_enemy_uid", "base_seed", "reforge_count", "reward_rng_state", "luck_rng_state"]:
		if not state.get(key) is int: return {"ok": false, "reason": "InvalidHyperspaceState"}
	if state.round_id < 1 or state.next_run < 1 or state.next_enemy_uid < 0 or state.reforge_count < 0 or state.base_seed != _base_seed:
		return {"ok": false, "reason": "InvalidHyperspaceSequence"}
	for key in ["late_supply_work"]:
		if not state.get(key) is float or not is_finite(state[key]) or state[key] < 0.0:
			return {"ok": false, "reason": "InvalidHyperspaceTimer"}
	for route in state.history:
		if not route is String or not _routes.has(route): return {"ok": false, "reason": "UnknownHyperspaceRoute"}
		var progress = state.history[route]
		if not progress is Dictionary or not progress.get("cleared") is int or progress.cleared < 0 or not progress.get("best") is Dictionary:
			return {"ok": false, "reason": "InvalidHyperspaceHistory"}
		for level in progress.best:
			if not level is int or level < 1 or level > progress.cleared or not progress.best[level] is float or not is_finite(progress.best[level]) or progress.best[level] <= 0.0:
				return {"ok": false, "reason": "InvalidHyperspaceHistory"}
	if not state.auto.get("route", "") is String or (not state.auto.route.is_empty() and not _routes.has(state.auto.route)):
		return {"ok": false, "reason": "UnknownHyperspaceRoute"}
	if not state.auto.get("enabled") is bool or not state.auto.get("crew_id") is String or (state.auto.enabled and (state.auto.route.is_empty() or state.auto.crew_id.is_empty())):
		return {"ok": false, "reason": "InvalidHyperspaceAuto"}
	if state.modules.keys() != _modules.keys(): return {"ok": false, "reason": "InvalidHyperspaceModules"}
	for key in state.modules:
		var progress = state.modules[key]
		if not progress is Dictionary or not progress.get("unlocked") is bool or not progress.get("level") is int or progress.level < 0 or not progress.get("exp") is float or not is_finite(progress.exp) or progress.exp < 0.0:
			return {"ok": false, "reason": "InvalidHyperspaceModules"}
	for receipt in [state.manual, state.idle]:
		if receipt.is_empty(): continue
		if not _valid_receipt(receipt, state.round_id, state.next_run) or not state.receipts.has(receipt.run_id) or state.receipts[receipt.run_id] != receipt:
			return {"ok": false, "reason": "InvalidHyperspaceReceipt"}
	for run_id in state.receipts:
		if not run_id is int or not _valid_receipt(state.receipts[run_id], state.round_id, state.next_run) or state.receipts[run_id].run_id != run_id:
			return {"ok": false, "reason": "InvalidHyperspaceReceipt"}
	var ids: Dictionary = {}
	for list in [state.warehouse, state.overflow]:
		for drone in list:
			if not _valid_drone(drone) or ids.has(drone.id):
				return {"ok": false, "reason": "InvalidHyperspaceDrone"}
			ids[drone.id] = true
	for id in state.equipped + state.favorites:
		if not id is String or not ids.has(id): return {"ok": false, "reason": "UnknownHyperspaceDrone"}
	for list in [state.equipped, state.favorites]:
		var seen: Dictionary = {}
		for id in list:
			if seen.has(id): return {"ok": false, "reason": "DuplicateHyperspaceDrone"}
			seen[id] = true
	for id in state.sealed:
		if not id is String or not ids.has(id) or not state.sealed[id] is int or state.sealed[id] < 0:
			return {"ok": false, "reason": "InvalidHyperspaceSeal"}
	for id in state.unlocked_drones:
		if not id is String or not state.unlocked_drones[id] is bool or not state.unlocked_drones[id]:
			return {"ok": false, "reason": "InvalidHyperspaceUnlock"}
	var restored_capacity: int = int(_parameters.warehouse_capacity) + state.reforge_count * int(_parameters.reforge_capacity_gain)
	if state.warehouse.size() > restored_capacity or state.overflow.size() > int(_parameters.overflow_capacity):
		return {"ok": false, "reason": "InvalidHyperspaceCapacity"}
	var energy: Dictionary = state.get("energy",{}) if state.get("energy") is Dictionary else _api.apply("from_decimal",[str(state.get("energy", "invalid"))]).get("value",{})
	var whole_energy: Dictionary = Resources.whole(energy,_api)
	if not whole_energy.ok: return whole_energy
	var cap: Dictionary = _resource_energy_cap()
	if not cap.ok: return cap
	var limit: Dictionary = _api.apply("compare",[whole_energy.value,cap.value])
	if not limit.ok: return limit
	if limit.scalar>0: return {"ok":false,"reason":"InvalidHyperspaceEnergy"}
	if not state.get("energy_progress",{}) is Dictionary or not state.get("energy_meter",{}) is Dictionary: return {"ok":false,"reason":"InvalidResourceProgress"}
	var progress: Dictionary = Resources.progress_map({"energy":state.energy_progress} if not state.get("energy_progress",{}).is_empty() else {},_api)
	if not progress.ok: return progress
	var meter: Dictionary = state.get("energy_meter",{})
	if not meter.is_empty():
		if not meter.get("elapsed") is float or not meter.get("origin") is float or not meter.get("late") is bool or not meter.get("total") is Dictionary or not is_finite(meter.elapsed) or not is_finite(meter.origin) or meter.elapsed<0.0 or meter.origin<0.0:
			return {"ok":false,"reason":"InvalidResourceMeter"}
		var end: Dictionary = _energy_integral(meter.origin+meter.elapsed,meter.late)
		var begin: Dictionary = _energy_integral(meter.origin,meter.late)
		if not end.ok: return end
		if not begin.ok: return begin
		var total: Dictionary = _api.apply("sub_nonnegative",[end.value,begin.value])
		if not total.ok: return total
		var check: Dictionary = _api.apply("compare",[total.value,meter.total])
		if not check.ok: return check
		if check.scalar!=0: return {"ok":false,"reason":"InvalidResourceMeter"}
	var last_forge: Dictionary = state.last_forge.duplicate(true)
	if not last_forge.is_empty():
		if not last_forge.get("result") is Dictionary or not last_forge.result.get("costs") is Dictionary: return {"ok":false,"reason":"InvalidForgeReceipt"}
		var normalized: Dictionary = _whole_resource_texts(last_forge.result.costs)
		if not normalized.ok: return normalized
		last_forge.result.costs = normalized.values
	var receipts: Dictionary = state.receipts.duplicate(true)
	for id in receipts:
		if receipts[id].status in ["CompletedPending","Claimed"]:
			var normalized: Dictionary = _whole_reward(receipts[id].reward)
			if not normalized.ok: return normalized
			receipts[id].reward = normalized.reward
	var manual: Dictionary = state.manual.duplicate(true)
	var idle: Dictionary = state.idle.duplicate(true)
	if not manual.is_empty() and receipts.has(manual.get("run_id")): manual = receipts[manual.run_id]
	if not idle.is_empty() and receipts.has(idle.get("run_id")): idle = receipts[idle.run_id]
	var filter_result: Dictionary = set_filter(state.filter)
	if not filter_result.ok: return filter_result
	_history = state.history.duplicate(true)
	_manual = manual
	_idle = idle
	_auto = state.auto.duplicate(true)
	_warehouse = state.warehouse.duplicate(true)
	_overflow = state.overflow.duplicate(true)
	_equipped = state.equipped.duplicate(true)
	_favorites = state.favorites.duplicate(true)
	_sealed = state.sealed.duplicate(true)
	_presets = state.presets.duplicate(true)
	_receipts = receipts
	_modules = state.modules.duplicate(true)
	_last_forge = last_forge
	_legend_seen = state.legend_seen.duplicate(true)
	_legend_collection = state.legend_collection.duplicate(true)
	_energy = whole_energy.value
	_energy_progress = state.get("energy_progress",{}).duplicate(true)
	_energy_meter = meter.duplicate(true)
	_late_supply_work = state.late_supply_work
	_reward_rng.state = state.reward_rng_state
	_luck_rng.state = state.luck_rng_state
	_round_id = state.round_id
	_next_run = state.next_run
	_next_enemy_uid = state.next_enemy_uid
	_reforge_count = state.reforge_count
	_unlocked_drones = state.unlocked_drones.duplicate(true)
	return {"ok": true}

func _valid_receipt(receipt, round_id: int, next_run: int) -> bool:
	if not receipt is Dictionary or not receipt.get("run_id") is int or receipt.run_id < 1 or receipt.run_id >= next_run or receipt.get("round_id") != round_id:
		return false
	if receipt.get("status") not in ["Started", "CompletedPending", "Claimed", "Failed"] or receipt.get("mode") not in ["manual", "auto", "single"] or not receipt.get("route") is String or not _routes.has(receipt.route):
		return false
	if not receipt.get("level") is int or receipt.level < 1 or not receipt.get("work") is float or not is_finite(receipt.work) or receipt.work < 0.0 or not receipt.get("return_target") is Dictionary or not receipt.get("reward") is Dictionary:
		return false
	if receipt.mode == "manual":
		if not receipt.get("wave") is int or receipt.wave < 0 or receipt.wave > 10: return false
	else:
		if not receipt.get("duration") is float or not is_finite(receipt.duration) or receipt.duration <= 0.0 or receipt.work > receipt.duration: return false
	if receipt.status in ["CompletedPending", "Claimed"]:
		var reward: Dictionary = receipt.reward
		if not reward.get("drone") is Dictionary or not reward.get("materials") is Dictionary or not reward.get("ultimate_cores") is int or reward.ultimate_cores < 0 or not reward.get("hanging_rewards") is Dictionary:
			return false
		if not reward.drone.is_empty() and not _valid_drone(reward.drone): return false
	return true

func _valid_drone(drone) -> bool:
	if not drone is Dictionary or not drone.get("id") is String or drone.id.is_empty() or not drone.get("weapon") is String or not drone.get("planet_id") is String:
		return false
	if not _planet_claim_levels.has(_planet_key(drone.planet_id)) or not drone.get("level") is int or drone.level < 1 or not drone.get("hangings") is Array or not drone.get("affixes") is Array:
		return false
	if not drone.get("legendary") is bool or not drone.get("ultimate") is bool or not drone.get("hanging_slots") is int or drone.hanging_slots < 0 or not drone.get("forge_revision") is int or drone.forge_revision < 0 or not drone.get("forge_rng_state") is String or not drone.forge_rng_state.is_valid_int():
		return false
	for module_id in drone.hangings:
		if not module_id is String or not _module_definitions.has(module_id): return false
	for affix in drone.affixes:
		if not _valid_affix(affix): return false
	if not drone.get("ultimate_affix", {}) is Dictionary: return false
	if not drone.ultimate_affix.is_empty() and not _valid_affix(drone.ultimate_affix): return false
	if not drone.get("legendary_effect", {}) is Dictionary: return false
	if drone.legendary:
		var effect: Dictionary = drone.legendary_effect
		if not effect.get("effect_id") is String or not effect.get("parameters") is Dictionary:
			return false
		var definition: Dictionary = {}
		for row in _legends:
			if str(row.effect_id) == effect.effect_id: definition = row
		if definition.is_empty() or not _weapon_matches(definition.weapon, str(drone.weapon)):
			return false
		var rules: Array = _legend_parameters.get(str(effect.effect_id), [])
		if effect.parameters.size() != rules.size(): return false
		for row in rules:
			var key: String = str(row.parameter)
			var value = effect.parameters.get(key)
			if not (value is int or value is float) or not is_finite(float(value)):
				return false
			var current: bool = float(value) >= float(row.minimum) and float(value) <= float(row.maximum)
			var historical: Dictionary = _legacy_legend_ranges.get(str(effect.effect_id) + ":" + key, {})
			var old: bool = historical.has("minimum") and historical.has("maximum") and float(value) >= float(historical.minimum) and float(value) <= float(historical.maximum)
			if not current and not old: return false
	elif not drone.legendary_effect.is_empty(): return false
	return true

func _valid_affix(affix) -> bool:
	if not affix is Dictionary or not affix.get("key") is String or not affix.get("tier") is int or not affix.get("locked") is bool:
		return false
	var key: String = str(affix.key)
	if not _affixes.has(key) or not _affix_ranges.has(key) or not _affix_ranges[key].has(affix.tier): return false
	var value = affix.get("value")
	if not (value is int or value is float) or not is_finite(float(value)): return false
	var bounds: Dictionary = _affix_ranges[key][affix.tier]
	return float(value) >= float(bounds.minimum) and float(value) <= float(bounds.maximum)

func _planet_key(value: String) -> String:
	if value.ends_with(".0"):
		var integer: String = value.trim_suffix(".0")
		if integer.is_valid_int(): return integer
	return value

func _init(configuration: Dictionary, api, run_state, seed_value: int = 1) -> void:
	_run_state = run_state
	_api = api
	_base_seed = seed_value
	_reward_rng.seed = seed_value ^ 0x4859504552
	_luck_rng.seed = seed_value ^ 0x4c55434b
	for row in configuration.hyperspace_config["\u57fa\u7840\u53c2\u6570"]: _parameters[str(row.key)] = row.value
	_energy = _resource_energy_cap().value
	_energy_progress = {}
	_energy_meter = {}
	for row in configuration.hyperspace_config["\u8def\u7ebf"]: _routes[str(row.route_id)] = row
	_qualities = configuration.hyperspace_config["\u54c1\u8d28"].duplicate()
	_qualities.sort_custom(func(a, b): return int(a.order) < int(b.order))
	for row in configuration.hyperspace_config["\u8bcd\u7f00\u5b9a\u4e49"]: _affixes[str(row.affix_id)] = row
	for row in configuration.hyperspace_config["\u6302\u8bbe\u6210\u957f"]:
		_module_definitions[str(row.module_id)] = row
		_modules[str(row.module_id)] = {"unlocked": false, "level": 0, "exp": 0.0}
	for row in configuration.hyperspace_config["\u6539\u9020\u8d39\u7528"]:
		_forge_costs[str(row.operation)] = {"resource": str(row.resource), "amount": int(row.amount)}
	for row in configuration.hyperspace_config["\u8bcd\u7f00\u533a\u95f4"]:
		var id: String = str(row.affix_id)
		if not _affix_ranges.has(id): _affix_ranges[id] = {}
		_affix_ranges[id][int(row.tier)] = row
	_tiers = configuration.hyperspace_config["\u9636\u7ea7\u6743\u91cd"].duplicate()
	_tiers.sort_custom(func(a, b): return int(a.order) < int(b.order))
	_legends = configuration.hyperspace_config["\u4f20\u8bf4\u5b9a\u4e49"].duplicate()
	_legends.sort_custom(func(a, b): return int(a.order) < int(b.order))
	for row in configuration.hyperspace_config["\u4f20\u8bf4\u968f\u673a\u53c2\u6570"]:
		var id: String = str(row.effect_id)
		if not _legend_parameters.has(id): _legend_parameters[id] = []
		_legend_parameters[id].append(row)
	for id in _legend_parameters: _legend_parameters[id].sort_custom(func(a, b): return int(a.order) < int(b.order))
	for row in configuration.hyperspace_config["\u56fa\u5b9a\u89c4\u5219_\u517c\u5bb9\u8bf4\u660e"]:
		var parts: PackedStringArray = str(row.key).split("/")
		if parts.size() == 6 and parts[1] == "legendary_effects" and parts[3] == "stored_parameter_ranges" and parts[5] in ["0", "1"]:
			var key: String = parts[2] + ":" + parts[4]
			if not _legacy_legend_ranges.has(key): _legacy_legend_ranges[key] = {}
			_legacy_legend_ranges[key]["minimum" if parts[5] == "0" else "maximum"] = row.value
	_planets = configuration.planet.planet.duplicate()
	_planets.sort_custom(func(a, b): return int(a.reforgeStartLevel) < int(b.reforgeStartLevel))
	for row in configuration.unlock.unlock:
		if str(row.type) == "planet": _planet_claim_levels[str(row.target)] = int(row.level)
	var source: Dictionary = configuration.hyperspace_enemies
	for row in source["\u7f16\u961f"]: _groups[int(row.group_id)] = row
	for row in source["\u8def\u7ebf\u7f16\u6392"]:
		var route: String = str(row.route_id)
		if not _lineups.has(route): _lineups[route] = []
		_lineups[route].append(row)
	for route in _lineups: _lineups[route].sort_custom(func(a, b): return int(a.order) < int(b.order))
	for row in source["\u654c\u4eba"]: _enemies[int(row.enemy_id)] = row
	_slot_rows = source["\u7f16\u961f\u69fd\u4f4d"]
	for row in source["\u6b66\u5668\u5b89\u88c5"]:
		var id: int = int(row.enemy_id)
		if not _weapons.has(id): _weapons[id] = []
		_weapons[id].append(row)
	for id in _weapons: _weapons[id].sort_custom(func(a, b): return int(a.order) < int(b.order))
	for row in source["\u5956\u52b1\u53c2\u8003"]: _references[str(row.reference_id)] = row
	for row in source["\u6210\u5458\u5206\u914d"]:
		var id: int = int(row.group_id)
		if not _assignments.has(id): _assignments[id] = []
		_assignments[id].append(row)
	for row in source["\u65e9\u6bb5\u56de\u9000\u9884\u7b97"]:
		var key: String = str(row.reference_id) + ":" + str(row.reference_member_ordinal)
		if not _early_budgets.has(key): _early_budgets[key] = []
		_early_budgets[key].append(row)
	for row in configuration.monGroup.monGroup: _main_groups[int(row.id)] = row
	for row in configuration.mon.mon: _main_enemies[int(row.id)] = row
	for row in configuration.enemy_weapon_base.enemy_weapon_base: _enemy_weapon_definitions[str(row.id)] = row
	for row in configuration.level.level: _levels[int(row.id)] = row

func unlocked(highest_reached: int) -> bool:
	return highest_reached >= int(_parameters.unlock_stage)

func routes() -> Array:
	var result: Array = []
	for id in _routes:
		var record: Dictionary = _history.get(id, {})
		var cleared: int = int(record.get("cleared", 0))
		var best = record.get("best", {}).get(cleared)
		result.append({"route": id, "weapon": _routes[id].weapon, "cleared": cleared,
			"best_time": float(best) if cleared > 0 and best != null and float(best) > 0.0 else null})
	return result

func material_ids() -> Array:
	var ids: Array = []
	for route in _routes.values(): ids.append(str(route.material))
	return ids

func manual_active() -> bool:
	return _manual.get("status") == "Started"

func manual_receipt() -> Dictionary:
	return _manual.duplicate(true)

func warehouse() -> Dictionary:
	return {"main": _warehouse.duplicate(true), "overflow": _overflow.duplicate(true),
		"equipped": _equipped.duplicate(), "favorites": _favorites.duplicate(),
		"sealed": _sealed.duplicate(), "presets": _presets.duplicate(true),
		"main_capacity": _warehouse_capacity(), "overflow_capacity": int(_parameters.overflow_capacity),
		"reforge_count": _reforge_count, "retention_capacity": int(_parameters.initial_retention_capacity) + _reforge_count * int(_parameters.retention_capacity_gain)}

func _warehouse_capacity() -> int:
	return int(_parameters.warehouse_capacity) + _reforge_count * int(_parameters.reforge_capacity_gain)

func organize() -> int:
	var moved: int = 0
	while _warehouse.size() < _warehouse_capacity() and not _overflow.is_empty():
		_warehouse.append(_overflow.pop_front())
		moved += 1
	return moved

func set_favorite(id: String, favorite: bool) -> Dictionary:
	if _find_drone(id).is_empty(): return {"ok": false, "reason": "DroneUnavailable"}
	if favorite and id not in _favorites: _favorites.append(id)
	elif not favorite: _favorites.erase(id)
	return {"ok": true}

func _protected(id: String) -> bool:
	if id in _equipped or id in _favorites or _sealed.has(id): return true
	for preset in _presets:
		if id in preset.drone_ids: return true
	return false

func prepare_dismantle(id: String) -> Dictionary:
	var drone: Dictionary = _find_drone(id)
	if drone.is_empty(): return {"ok": false, "reason": "DroneUnavailable"}
	if _protected(id): return {"ok": false, "reason": "ProtectedDrone"}
	return {"ok": true, "reward": _dismantle_reward(drone)}

func accept_dismantle(id: String, reward: Dictionary) -> void:
	for index in _warehouse.size():
		if str(_warehouse[index].id) == id:
			_warehouse.remove_at(index)
			break
	for index in _overflow.size():
		if str(_overflow[index].id) == id:
			_overflow.remove_at(index)
			break
	_credit_modules(reward.hanging_rewards)
	organize()

func _dismantle_reward(drone: Dictionary) -> Dictionary:
	var identity: String = "legendary" if drone.legendary else str(drone.origin_quality)
	var portions: int = 0
	for row in _qualities:
		if str(row.quality) == identity: portions = int(row.dismantle_amount)
	var material: String = ""
	for route in _routes.values():
		if str(route.weapon) == str(drone.weapon): material = str(route.material)
	var random := RandomNumberGenerator.new()
	random.state = int(drone.forge_rng_state)
	var keys: Array = _module_definitions.keys()
	keys.sort_custom(func(a, b): return int(_module_definitions[a].order) < int(_module_definitions[b].order))
	var hanging: Dictionary = {}
	for index in portions:
		var key: String = str(keys[random.randi_range(0, keys.size() - 1)])
		hanging[key] = int(hanging.get(key, 0)) + 1
	return {"drone": {}, "materials": {material: portions * int(_parameters.material_unit_scale)},
		"ultimate_cores": 0, "hanging_rewards": hanging}

func _credit_modules(drops: Dictionary) -> void:
	_modules = _modules_after_credit(drops)

func _modules_after_credit(drops: Dictionary) -> Dictionary:
	var next: Dictionary = _modules.duplicate(true)
	for key in drops:
		var progress: Dictionary = next[key]
		var copies: int = int(drops[key])
		if not progress.unlocked:
			progress.unlocked = true
			copies -= 1
		progress.exp += copies * float(_module_definitions[key].base_exp)
		var needed: float = _module_required_exp(str(key), int(progress.level))
		while progress.exp >= needed:
			progress.exp -= needed
			progress.level += 1
			needed = _module_required_exp(str(key), int(progress.level))
	return next

func filter_configuration() -> Dictionary:
	return _filter.duplicate(true)

func set_filter(candidate: Dictionary) -> Dictionary:
	var checked: Dictionary = _validate_filter(candidate)
	if not checked.ok: return checked
	_filter = candidate.duplicate(true)
	return {"ok": true}

func _validate_filter(candidate: Dictionary) -> Dictionary:
	if candidate.keys().size() != 5 or not candidate.has_all(["version", "enabled", "mode", "action", "conditions"]) or not candidate.version is int or candidate.version != 2:
		return {"ok": false, "reason": "InvalidFilter"}
	if not candidate.enabled is bool or candidate.mode not in ["all", "any"] or candidate.action not in ["keep_matches", "clear_matches"] or not candidate.conditions is Array:
		return {"ok": false, "reason": "InvalidFilter"}
	if candidate.conditions.size() > int(_parameters.maximum_filter_conditions) or (candidate.enabled and candidate.conditions.is_empty()):
		return {"ok": false, "reason": "InvalidFilter"}
	for condition in candidate.conditions:
		if not condition is Dictionary or not condition.has("field"): return {"ok": false, "reason": "InvalidFilter"}
		match str(condition.field):
			"weapon":
				if condition.keys().size() != 2 or condition.get("value") not in ["laser", "missile", "cannon", "longLaser"]: return {"ok": false, "reason": "InvalidFilter"}
			"quality":
				if condition.keys().size() != 2 or condition.get("value") not in ["white", "blue", "gold", "legendary", "ultimate"]: return {"ok": false, "reason": "InvalidFilter"}
			"minimum_level":
				if condition.keys().size() != 2 or not condition.get("value") is int or int(condition.value) < 0: return {"ok": false, "reason": "InvalidFilter"}
			"affix":
				if condition.keys().size() != 3 or not _affixes.has(str(condition.get("key", ""))) or not condition.get("tier") is int or int(condition.tier) < 1 or int(condition.tier) > 5: return {"ok": false, "reason": "InvalidFilter"}
			"legendary_effect":
				var known: bool = false
				for row in _legends:
					if str(row.effect_id) == str(condition.get("value", "")): known = true
				if condition.keys().size() != 2 or not known: return {"ok": false, "reason": "InvalidFilter"}
			_: return {"ok": false, "reason": "InvalidFilter"}
	return {"ok": true}

func export_filter() -> String:
	return "SPACE-FILTER-v2:" + Marshalls.utf8_to_base64(JSON.stringify(_filter, "", true))

func import_filter(value: String) -> Dictionary:
	var preview: Dictionary = preview_filter_import(value)
	if not preview.ok: return preview
	return set_filter(preview.candidate)

func preview_filter_import(value: String) -> Dictionary:
	if value.length() > int(_parameters.maximum_filter_string_length) or not value.begins_with("SPACE-FILTER-v2:"):
		return {"ok": false, "reason": "InvalidFilterShare"}
	var encoded: String = value.trim_prefix("SPACE-FILTER-v2:")
	if encoded.is_empty() or encoded.length() % 4 != 0: return {"ok": false, "reason": "InvalidFilterShare"}
	var pattern := RegEx.new()
	pattern.compile("^[A-Za-z0-9+/]*={0,2}$")
	if pattern.search(encoded) == null: return {"ok": false, "reason": "InvalidFilterShare"}
	var decoded: String = Marshalls.base64_to_utf8(encoded)
	if Marshalls.utf8_to_base64(decoded) != encoded: return {"ok": false, "reason": "InvalidFilterShare"}
	var parsed = JSON.parse_string(decoded)
	if parsed is Dictionary:
		if parsed.get("version") is float and float(parsed.version) == floorf(float(parsed.version)): parsed.version = int(parsed.version)
		if parsed.get("conditions") is Array:
			for condition in parsed.conditions:
				if not condition is Dictionary: continue
				for field in ["value", "tier"]:
					if condition.get(field) is float and float(condition[field]) == floorf(float(condition[field])): condition[field] = int(condition[field])
	if not parsed is Dictionary: return {"ok": false, "reason": "InvalidFilterShare"}
	var checked: Dictionary = _validate_filter(parsed)
	if not checked.ok: return checked
	return {"ok": true, "candidate": parsed.duplicate(true)}

func _filter_matches(drone: Dictionary) -> bool:
	if not _filter.enabled: return true
	for condition in _filter.conditions:
		var matched: bool = false
		match str(condition.field):
			"weapon": matched = drone.weapon == condition.value
			"quality": matched = drone.ultimate if condition.value == "ultimate" else drone.legendary if condition.value == "legendary" else (not drone.legendary and drone.origin_quality == condition.value)
			"minimum_level": matched = int(drone.level) >= int(condition.value)
			"affix":
				var affixes: Array = drone.affixes.duplicate()
				if drone.ultimate and not drone.ultimate_affix.is_empty(): affixes.append(drone.ultimate_affix)
				matched = affixes.any(func(a): return a.key == condition.key and int(a.tier) <= int(condition.tier))
			"legendary_effect": matched = drone.legendary and drone.legendary_effect.effect_id == condition.value
		if _filter.mode == "any" and matched: return true
		if _filter.mode == "all" and not matched: return false
	return _filter.mode == "all"

func module_growth() -> Dictionary:
	return _modules.duplicate(true)

func _module_required_exp(id: String, level: int) -> float:
	return float(_module_definitions[id].base_exp) * pow(1.0 + float(_module_definitions[id].exp_growth), level)

func _module_effect_factor(id: String, level: int) -> float:
	return pow(1.0 + float(_module_definitions[id].effect_growth), level)

# Growth keeps its existing float domain; nonfinite display values are unknown.
func module_details(highest_reached: int) -> Dictionary:
	var rows: Array = []
	var totals: Dictionary = module_contributions()
	for id in _modules:
		var progress: Dictionary = _modules[id]
		var needed: float = _module_required_exp(str(id), int(progress.level))
		var bonus: float = _module_effect_factor(str(id), int(progress.level)) - 1.0
		var valid: bool = is_finite(needed) and needed > 0.0
		var available: bool = progress.unlocked and highest_reached >= int(_module_definitions[id].unlock_stage)
		rows.append({"id": str(id), "unlocked": progress.unlocked, "level": progress.level,
			"exp": progress.exp, "required_exp": needed if valid else null,
			"progress_ratio": clampf(float(progress.exp) / needed, 0.0, 1.0) if valid else null,
			"growth_reason": "" if valid else "RequiredExperienceUnavailable",
			"per_copy_bonus": bonus if is_finite(bonus) else null,
			"per_copy_reason": "" if is_finite(bonus) else "ContributionUnavailable",
			"aggregate_contribution": totals.get(id, 0.0) if is_finite(float(totals.get(id, 0.0))) else null,
			"aggregate_reason": "" if is_finite(float(totals.get(id, 0.0))) else "ContributionUnavailable",
			"unlock_stage": int(_module_definitions[id].unlock_stage), "available": available,
			"reason": "" if available else "HangingUnavailable"})
	return {"ok": true, "rows": rows}

func dismantle_preview(id: String) -> Dictionary:
	var prepared: Dictionary = prepare_dismantle(id)
	if not prepared.ok: return prepared
	var copies: int = 0
	for count in prepared.reward.hanging_rewards.values(): copies += int(count)
	return {"ok": true, "id": id, "removed_ids": [id],
		"materials": prepared.reward.materials.duplicate(true), "ultimate_cores": prepared.reward.ultimate_cores,
		"hanging_copies": copies, "hanging_kinds": "pending_settlement"}

# Ranges describe raw stored values, including protected rows; no random result is awarded.
func forge_display_limits(id: String) -> Dictionary:
	var drone: Dictionary = _find_drone(id)
	if drone.is_empty(): return {"ok": false, "reason": "DroneUnavailable"}
	var blocked: String = "DroneUnavailable" if _sealed.has(id) else "UltimateLocked" if drone.ultimate else ""
	var rows: Array = []
	for index in drone.affixes.size():
		var affix: Dictionary = drone.affixes[index]
		var interval: Dictionary = _affix_ranges[str(affix.key)][int(affix.tier)]
		var reason: String = blocked if not blocked.is_empty() else "AffixLocked" if affix.locked else ""
		rows.append({"id": id, "forge_revision": int(drone.forge_revision), "kind": "affix",
			"index": index, "key": str(affix.key), "tier": int(affix.tier), "current": affix.value,
			"minimum": interval.minimum, "maximum": interval.maximum, "locked": bool(affix.locked),
			"modifiable": reason.is_empty(), "reason": reason})
	if drone.legendary:
		for row in _legend_parameters.get(str(drone.legendary_effect.effect_id), []):
			rows.append({"id": id, "forge_revision": int(drone.forge_revision), "kind": "legendary",
				"effect_id": str(drone.legendary_effect.effect_id), "parameter": str(row.parameter),
				"current": drone.legendary_effect.parameters[str(row.parameter)],
				"minimum": row.minimum, "maximum": row.maximum, "locked": not blocked.is_empty(),
				"modifiable": blocked.is_empty(), "reason": blocked})
	return {"ok": true, "id": id, "forge_revision": int(drone.forge_revision),
		"affix_limit": int(_quality_row(drone).get("affix_limit", 0)),
		"hanging_limit": maxi(int(_quality_row(drone).get("hanging_limit", 0)), int(drone.preserved_hanging_slots)),
		"hanging_slots": int(drone.hanging_slots), "preserved_hanging_slots": int(drone.preserved_hanging_slots),
		"modifiable": blocked.is_empty(), "reason": blocked, "reroll_ranges": rows}

func legend_collection() -> Dictionary:
	return {"seen": _legend_seen.duplicate(), "collection": _legend_collection.duplicate()}

func set_legend_collected(effect_id: String, collected: bool) -> Dictionary:
	if not _legend_seen.has(effect_id): return {"ok": false, "reason": "LegendNotSeen"}
	if collected: _legend_collection[effect_id] = true
	else: _legend_collection.erase(effect_id)
	return {"ok": true}

func module_contributions(ids = null, hanging_overrides: Dictionary = {}, module_states = null) -> Dictionary:
	var totals: Dictionary = {}
	var active: Array = _equipped if ids == null else ids
	var modules: Dictionary = _modules if module_states == null else module_states
	for id in active:
		var drone: Dictionary = _find_drone(str(id))
		if drone.is_empty() or _sealed.has(str(id)): continue
		var installed: Array = hanging_overrides.get(str(id), drone.hangings)
		for module_id in installed:
			var progress: Dictionary = modules.get(str(module_id), {})
			if not bool(progress.get("unlocked", false)): continue
			totals[str(module_id)] = float(totals.get(str(module_id), 0.0)) + _module_effect_factor(str(module_id), int(progress.level)) - 1.0
	return totals

func future_module_contributions(drops: Dictionary) -> Dictionary:
	return module_contributions(null, {}, _modules_after_credit(drops))

func prepare_hangings(id: String, module_ids: Array, highest_reached: int) -> Dictionary:
	var drone: Dictionary = _find_drone(id)
	if drone.is_empty() or _sealed.has(id): return {"ok": false, "reason": "DroneUnavailable"}
	if drone.ultimate: return {"ok": false, "reason": "UltimateLocked"}
	if module_ids.size() > int(drone.hanging_slots): return {"ok": false, "reason": "HangingCapacityExceeded"}
	var seen: Dictionary = {}
	for value in module_ids:
		var module_id: String = str(value)
		if seen.has(module_id) or not _modules.has(module_id) or not _modules[module_id].unlocked or highest_reached < int(_module_definitions[module_id].unlock_stage):
			return {"ok": false, "reason": "HangingUnavailable"}
		seen[module_id] = true
	return {"ok": true, "id": id, "hangings": module_ids.duplicate()}

func accept_hangings(id: String, module_ids: Array) -> void:
	_find_drone(id).hangings = module_ids.duplicate()

func save_preset(name: String) -> Dictionary:
	if name.strip_edges().is_empty(): return {"ok": false, "reason": "InvalidPresetName"}
	var entries: Array = []
	for id in _equipped:
		entries.append({"id": id, "hangings": _find_drone(str(id)).hangings.duplicate()})
	var preset: Dictionary = {"name": name, "drone_ids": _equipped.duplicate(), "entries": entries}
	for index in _presets.size():
		if str(_presets[index].name) == name:
			_presets[index] = preset
			return {"ok": true, "preset": preset.duplicate(true)}
	_presets.append(preset)
	return {"ok": true, "preset": preset.duplicate(true)}

func prepare_preset(name: String, capacity: int, highest_reached: int, weapon_source: Callable) -> Dictionary:
	for preset in _presets:
		if str(preset.name) != name: continue
		var prepared: Dictionary = prepare_loadout(preset.drone_ids, capacity, weapon_source)
		if not prepared.ok: return prepared
		for entry in preset.entries:
			var drone: Dictionary = _find_drone(str(entry.id))
			if drone.ultimate and entry.hangings == drone.hangings: continue
			var checked: Dictionary = prepare_hangings(str(entry.id), entry.hangings, highest_reached)
			if not checked.ok: return checked
		prepared.entries = preset.entries.duplicate(true)
		return prepared
	return {"ok": false, "reason": "UnknownPreset"}

func accept_preset(prepared: Dictionary) -> void:
	for entry in prepared.entries:
		if _find_drone(str(entry.id)).hangings != entry.hangings: accept_hangings(str(entry.id), entry.hangings)
	accept_loadout(prepared.ids)

func equipped_ids() -> Array:
	return _equipped.duplicate()

func weapon_level_bonus(drone: Dictionary) -> int:
	if drone.ultimate: return int(_parameters.ultimate_weapon_bonus)
	var origin: String = "blue" if drone.blue_source_bonus else "legendary" if drone.legendary else str(drone.origin_quality)
	for row in _qualities:
		if str(row.quality) == origin: return int(row.weapon_level_bonus)
	return 0

func prepare_loadout(ids: Array, capacity: int, weapon_source: Callable, replacements: Dictionary = {}) -> Dictionary:
	if ids.size() > capacity or ids.size() > int(_parameters.maximum_equipped):
		return {"ok": false, "reason": "DroneCapacityExceeded"}
	var seen: Dictionary = {}
	var legendary: int = 0
	var ultimate: int = 0
	var cannon_drones: int = 0
	var higgs: bool = false
	var contributions: Array = []
	for id_value in ids:
		var id: String = str(id_value)
		var drone: Dictionary = replacements.get(id, _find_drone(id))
		if seen.has(id) or drone.is_empty() or _sealed.has(id) or not _warehouse.any(func(item): return item.id == id):
			return {"ok": false, "reason": "DroneUnavailable"}
		seen[id] = true
		if drone.legendary: legendary += 1
		if drone.ultimate: ultimate += 1
		if str(drone.weapon) == "cannon": cannon_drones += 1
		if drone.legendary and str(drone.legendary_effect.get("effect_id", "")) == "higgs_cannon": higgs = true
		var source: Dictionary = weapon_source.call(drone)
		if not source.ok: return source
		var stats: Dictionary = {"id": id, "generation": int(drone.get("weapon_generation", 1)),
			"quality": "ultimate" if drone.ultimate else "legendary" if drone.legendary else str(drone.origin_quality),
			"weapon": source.weapon}
		if drone.legendary:
			stats.legendary_effect = str(drone.legendary_effect.effect_id)
			stats.legendary_parameters = drone.legendary_effect.parameters.duplicate()
		var totals: Dictionary = {}
		var affixes: Array = drone.affixes.duplicate()
		if drone.ultimate and not drone.ultimate_affix.is_empty(): affixes.append(drone.ultimate_affix)
		for affix in affixes:
			var key: String = str(affix.key)
			var value: float = float(affix.value)
			if bool(_affixes[key].amplified): value *= pow(1.0 + float(_parameters.amplification_rate), int(drone.level) - int(_parameters.amplification_start_level))
			totals[key] = float(totals.get(key, 0.0)) + value
		var mapping: Dictionary = {"global_damage": "global_weapon_bonus", "global_defence": "global_defence_bonus",
			"damage_laser": "laser_damage_bonus", "damage_cannon": "cannon_damage_bonus",
			"damage_missile": "missile_damage_bonus", "damage_longLaser": "long_laser_damage_bonus",
			"global_critical_damage": "critical_damage_bonus", "critical_chance": "critical_rate_bonus",
			"repeat_chance": "repeat_probability_bonus", "attack_speed": "attack_speed_bonus",
			"chain_count": "chain_count_bonus", "shield_capacity": "shield_capacity_bonus",
			"armour_capacity": "armour_capacity_bonus"}
		for key in totals:
			stats[str(mapping[key])] = str(totals[key]) if key in ["global_damage", "global_defence"] else totals[key]
		contributions.append(stats)
	if legendary > int(_parameters.maximum_legendary) or ultimate > int(_parameters.maximum_ultimate):
		return {"ok": false, "reason": "DroneQualityLimit"}
	if higgs and cannon_drones > 1:
		return {"ok": false, "reason": "HiggsCannonLimit"}
	return {"ok": true, "ids": ids.duplicate(), "contributions": contributions}

func accept_loadout(ids: Array) -> void:
	_equipped = ids.duplicate()

func _find_drone(id: String) -> Dictionary:
	for drone in _warehouse:
		if str(drone.id) == id: return drone
	for drone in _overflow:
		if str(drone.id) == id: return drone
	return {}

func preview_forge(id: String, operation: String, args: Dictionary = {}, highest_reached: int = 0) -> Dictionary:
	var drone: Dictionary = _find_drone(id)
	if drone.is_empty() or _sealed.has(id): return {"ok": false, "reason": "DroneUnavailable"}
	if drone.ultimate and operation not in ["restore_ultimate"]: return {"ok": false, "reason": "UltimateLocked"}
	if not _forge_costs.has(operation) and operation != "modernize" and operation != "disable_omen":
		return {"ok": false, "reason": "UnknownForgeOperation"}
	var candidate: Dictionary = drone.duplicate(true)
	var random := RandomNumberGenerator.new()
	random.state = int(drone.forge_rng_state)
	var multiplier: int = 1
	var guarantee_points: Array = []
	var affix_limit: int = _quality_row(candidate).get("affix_limit", 0)
	var hanging_limit: int = maxi(int(_quality_row(candidate).get("hanging_limit", 0)), int(candidate.preserved_hanging_slots))
	var unlocked: Array = []
	for index in candidate.affixes.size():
		if not candidate.affixes[index].locked: unlocked.append(index)
	match operation:
		"add_affix":
			if candidate.affixes.size() >= affix_limit: return {"ok": false, "reason": "AffixCapacityExceeded"}
			candidate.affixes.append(_draw_affix_with(random, str(candidate.weapon)))
		"replace_affix":
			if unlocked.is_empty(): return {"ok": false, "reason": "NoUnlockedAffix"}
			var candidates: Array = unlocked
			if candidate.omen:
				var worst_tier: int = -1
				for index in unlocked:
					worst_tier = maxi(worst_tier, int(candidate.affixes[index].tier))
				candidates = unlocked.filter(func(index): return int(candidate.affixes[index].tier) == worst_tier)
			var slot: int = int(candidates[random.randi_range(0, candidates.size() - 1)])
			var target: String = str(args.get("target_affix", ""))
			if not target.is_empty() and not _affixes.has(target): return {"ok": false, "reason": "UnknownAffix"}
			var found: bool = false
			for attempt in int(_parameters.maximum_forecast_attempts):
				candidate.affixes[slot] = _draw_affix_with(random, str(candidate.weapon))
				multiplier = attempt + 1
				if target.is_empty() or str(candidate.affixes[slot].key) == target:
					found = true
					break
			if not found: return {"ok": false, "reason": "ForecastLimit"}
		"add_hanging_slot":
			if int(candidate.hanging_slots) >= hanging_limit: return {"ok": false, "reason": "HangingCapacityExceeded"}
			candidate.hanging_slots += 1
		"lock_affix":
			if unlocked.is_empty(): return {"ok": false, "reason": "NoUnlockedAffix"}
			candidate.affixes[int(unlocked[random.randi_range(0, unlocked.size() - 1)])].locked = true
			multiplier = int(pow(int(_parameters.lock_cost_multiplier), candidate.affixes.size() - unlocked.size()))
		"promote_affix":
			unlocked = unlocked.filter(func(index): return int(candidate.affixes[index].tier) > 1)
			if unlocked.is_empty(): return {"ok": false, "reason": "NoPromotableAffix"}
			var slot: int = int(unlocked[random.randi_range(0, unlocked.size() - 1)])
			var drawn: Dictionary = _draw_affix_with(random, str(candidate.weapon))
			if int(drawn.tier) < int(candidate.affixes[slot].tier):
				candidate.affixes[slot].tier = int(candidate.affixes[slot].tier) - 1
				var range_row: Dictionary = _affix_ranges[str(candidate.affixes[slot].key)][int(candidate.affixes[slot].tier)]
				candidate.affixes[slot].value = _quantized(range_row.minimum, range_row.maximum, random)
		"reroll_values":
			if unlocked.is_empty() and not candidate.legendary: return {"ok": false, "reason": "NoUnlockedAffix"}
			var guaranteed: bool = bool(args.get("guaranteed", false))
			for index in unlocked:
				var affix: Dictionary = candidate.affixes[index]
				var range_row: Dictionary = _affix_ranges[str(affix.key)][int(affix.tier)]
				if guaranteed:
					affix.value = float(range_row.maximum)
					guarantee_points.append(floori((float(range_row.maximum) - float(range_row.minimum)) / float(_parameters.value_precision) + 1e-7) + 1)
				else: affix.value = _quantized(range_row.minimum, range_row.maximum, random)
			if candidate.legendary:
				for row in _legend_parameters.get(str(candidate.legendary_effect.effect_id), []):
					if guaranteed:
						candidate.legendary_effect.parameters[str(row.parameter)] = float(row.maximum)
						guarantee_points.append(floori((float(row.maximum) - float(row.minimum)) / float(_parameters.value_precision) + 1e-7) + 1)
					else: candidate.legendary_effect.parameters[str(row.parameter)] = _quantized(row.minimum, row.maximum, random)
		"enable_omen":
			if candidate.omen: return {"ok": false, "reason": "OmenAlreadyEnabled"}
			candidate.omen = true
		"disable_omen":
			if not candidate.omen: return {"ok": false, "reason": "NoChange"}
			candidate.omen = false
		"legendary":
			if candidate.legendary: return {"ok": false, "reason": "AlreadyLegendary"}
			var target: String = str(args.get("target_effect", ""))
			if not target.is_empty() and (target not in _legend_collection or target not in _legend_seen):
				return {"ok": false, "reason": "LegendNotCollected"}
			var found: bool = false
			for attempt in int(_parameters.maximum_forecast_attempts):
				candidate.legendary_effect = _draw_legend_with(random, str(candidate.weapon))
				multiplier = attempt + 1
				if target.is_empty() or str(candidate.legendary_effect.effect_id) == target:
					found = true
					break
			if not found: return {"ok": false, "reason": "ForecastLimit"}
			candidate.legendary = true
			candidate.preserved_hanging_slots = int(candidate.hanging_slots)
		"ultimate":
			if candidate.ultimate: return {"ok": false, "reason": "AlreadyUltimate"}
			candidate.ultimate = true
			if candidate.ultimate_affix.is_empty(): candidate.ultimate_affix = _draw_affix_with(random, str(candidate.weapon))
		"restore_ultimate":
			if not candidate.ultimate: return {"ok": false, "reason": "NotUltimate"}
			candidate.ultimate = false
		"modernize":
			var target: int = 0
			var best: Dictionary = _history.get(_route_for_weapon(str(candidate.weapon)), {}).get("best", {})
			for recorded_level in best:
				var level: int = int(recorded_level)
				if level <= highest_reached: target = maxi(target, level)
			if target <= int(candidate.level) or (args.has("target_level") and int(args.target_level) != target):
				return {"ok": false, "reason": "ModernizationLevelUnavailable"}
			candidate.level = target
		_: return {"ok": false, "reason": "UnknownForgeOperation"}
	candidate.forge_revision = int(candidate.forge_revision) + 1
	candidate.forge_rng_state = str(random.state)
	var costs: Dictionary = {}
	if _forge_costs.has(operation):
		var row: Dictionary = _forge_costs[operation]
		if guarantee_points.is_empty():
			var amount: Dictionary = _api.apply("from_decimal",[str(row.amount)])
			for factor in [str(multiplier),"1" if str(row.resource)=="ultimate_cores" else str(_parameters.material_unit_scale)]:
				if not amount.ok: return amount
				var scale: Dictionary = _api.apply("from_decimal",[factor])
				if not scale.ok: return scale
				amount = _api.apply("mul",[amount.value,scale.value])
			if not amount.ok: return amount
			costs[str(row.resource)] = _api.apply("to_display",[amount.value]).text
		else:
			var quantity: Dictionary = _api.apply("from_decimal", [str(row.amount)])
			for factor in [str(_parameters.material_unit_scale),str(_parameters.reroll_guarantee_multiplier)]:
				if not quantity.ok: return quantity
				var scale: Dictionary = _api.apply("from_decimal",[factor])
				if not scale.ok: return scale
				quantity = _api.apply("mul",[quantity.value,scale.value])
			if not quantity.ok: return quantity
			for points in guarantee_points:
				var factor: Dictionary = _api.apply("from_decimal", [str(points)])
				if not factor.ok: return factor
				quantity = _api.apply("mul", [quantity.value, factor.value])
				if not quantity.ok: return quantity
			var exact: Dictionary = _api.apply("to_display", [quantity.value])
			if not exact.ok: return exact
			costs[str(row.resource)] = exact.text
	elif operation == "modernize":
		var weight: float = 0.0
		for affix in candidate.affixes:
			for tier in _tiers:
				if int(tier.tier) == int(affix.tier): weight += float(tier.modernization_weight)
		var units: Dictionary = _api.apply("from_decimal",[str(1.0 + float(int(candidate.level)-int(_parameters.material_reward_start_level))/float(_parameters.modernization_level_step))])
		for factor in [str(float(_parameters.modernization_base_coefficient)+weight),str(_parameters.modernization_legendary_multiplier if candidate.legendary else 1)]:
			if not units.ok: return units
			var scale: Dictionary = _api.apply("from_decimal",[factor])
			if not scale.ok: return scale
			units = _api.apply("mul",[units.value,scale.value])
		if not units.ok: return units
		units = _api.apply("add",[units.value,_api.apply("from_decimal",["0.5"]).value])
		if not units.ok: return units
		units = _api.apply("floor",[units.value])
		for factor in [str(_parameters.modernization_cost_base),str(_parameters.material_unit_scale)]:
			if not units.ok: return units
			units = _api.apply("mul",[units.value,_api.apply("from_decimal",[factor]).value])
		if not units.ok: return units
		costs[str(_routes[_route_for_weapon(str(candidate.weapon))].material)] = _api.apply("to_display",[units.value]).text
	var normalized: Dictionary = _whole_resource_texts(costs)
	if not normalized.ok: return normalized
	return {"ok": true, "drone": candidate, "costs": normalized.values, "draws": multiplier}

func accept_forge(id: String, candidate: Dictionary, operation_id: String, fingerprint: String, result: Dictionary) -> void:
	for collection in [_warehouse, _overflow]:
		for index in collection.size():
			if str(collection[index].id) == id: collection[index] = candidate.duplicate(true)
	if candidate.legendary:
		var effect: String = str(candidate.legendary_effect.effect_id)
		_legend_seen[effect] = true
	_last_forge = {"operation_id": operation_id, "fingerprint": fingerprint, "result": result.duplicate(true)}

func forge_repeat(operation_id: String, fingerprint: String) -> Dictionary:
	if operation_id.is_empty() or str(_last_forge.get("operation_id", "")) != operation_id: return {}
	if str(_last_forge.fingerprint) != fingerprint: return {"ok": false, "reason": "OperationIdConflict"}
	return _last_forge.result.duplicate(true)

func _quality_row(drone: Dictionary) -> Dictionary:
	var quality: String = "legendary" if drone.legendary else str(drone.origin_quality)
	for row in _qualities:
		if str(row.quality) == quality: return row
	return {}

func _route_for_weapon(weapon: String) -> String:
	for route in _routes:
		if str(_routes[route].weapon) == weapon: return str(route)
	return ""

func _draw_affix_with(random: RandomNumberGenerator, weapon: String) -> Dictionary:
	return _draw_affix(weapon, random)

func _draw_legend_with(random: RandomNumberGenerator, weapon: String) -> Dictionary:
	return _draw_legend(weapon, random)

func online_status() -> Dictionary:
	var energy: Dictionary = Resources.integer_text(_energy,_api)
	return {"idle": _idle.duplicate(true), "auto": _auto.duplicate(true), "energy": energy.text if energy.ok else "", "energy_text": energy.text if energy.ok else "", "energy_amount":_energy.duplicate(true)}

func prepare_idle(route: String, automatic: bool, crew_id: String, crew_level: int, permanent_luck: float,
		return_target: Dictionary = {}) -> Dictionary:
	if not _routes.has(route): return {"ok": false, "reason": "UnknownRoute"}
	if _auto.enabled and not automatic: return {"ok": false, "reason": "AutoRunning"}
	if str(_idle.get("status", "")) in ["Started", "CompletedPending"]:
		return {"ok": false, "reason": "OnlineChallengePending"}
	var record: Dictionary = _history.get(route, {})
	var level: int = int(record.get("cleared", 0))
	if level < 1 or not record.get("best", {}).has(level): return {"ok": false, "reason": "NoBestTime"}
	if float(record.best[level]) <= 0: return {"ok": false, "reason": "NoBestTime"}
	if automatic and crew_id.is_empty(): return {"ok": false, "reason": "CrewRequired"}
	var best: float = float(record.best[level])
	var duration: float = maxf(float(_parameters.minimum_duration), best * 20.0 / (20.0 + crew_level) if automatic else best)
	return {"ok": true, "receipt": {"round_id": _round_id, "run_id": _next_run, "mode": "auto" if automatic else "single",
		"route": route, "level": level, "status": "Started", "work": 0.0, "duration": duration,
		"crew_id": crew_id if automatic else "", "crew_level": crew_level if automatic else 0,
		"luck": permanent_luck + (crew_level if automatic else 0), "luck_state": str(_luck_rng.state),
		"return_target": return_target.duplicate(true), "reward": {}}}

func accept_idle(receipt: Dictionary, automatic: bool) -> void:
	_idle = receipt
	_receipts[int(receipt.run_id)] = _idle
	_luck_rng.randi()
	_next_run += 1
	if automatic:
		_auto = {"enabled": true, "route": str(receipt.route), "crew_id": str(receipt.crew_id)}

func prepare_auto_continuation(crew_level: int, permanent_luck: float) -> Dictionary:
	if not _auto.enabled or _idle.get("status") != "Claimed": return {"ok": false, "reason": "AutoContinuationUnavailable"}
	if _warehouse.size() >= _warehouse_capacity() and _overflow.size() >= int(_parameters.overflow_capacity):
		return {"ok": false, "reason": "WarehouseFull"}
	return prepare_idle(str(_auto.route), true, str(_auto.crew_id), crew_level, permanent_luck)

func stop_auto() -> Dictionary:
	if not _auto.enabled: return {"ok": false, "reason": "AutoNotRunning"}
	if _idle.get("status") == "CompletedPending": return {"ok": false, "reason": "RewardPending"}
	var crew_id: String = str(_auto.crew_id)
	var route: String = str(_auto.route)
	if _idle.get("status") == "Started": _idle.status = "Failed"
	_auto.enabled = false
	return {"ok": true, "crew_id": crew_id, "route": route}

func advance_online(dt: float, cleared_stages: Dictionary) -> void:
	var late_supply: bool = cleared_stages.has(int(_parameters.late_supply_unlock_stage))
	var before: float = _late_supply_work
	if late_supply: _late_supply_work = minf(float(_parameters.late_supply_ramp_seconds), before + dt)
	var generated: Dictionary = _advance_energy(dt,late_supply,before)
	if not generated.ok:
		_run_state.fail(str(generated.get("reason",generated.get("error","EnergyGenerationFailed"))))
		return
	if _idle.get("status") == "Started":
		_idle.work = minf(float(_idle.duration), float(_idle.work) + dt)
		if float(_idle.work) + 1e-9 >= float(_idle.duration):
			_idle.reward = _generate_reward(_idle)
			_idle.status = "CompletedPending"

func prepare_manual(route: String, highest_reached: int, return_target: Dictionary, permanent_luck: float = 0.0) -> Dictionary:
	if not _run_state.is_running(): return _run_state.rejection()
	if not unlocked(highest_reached): return {"ok": false, "reason": "HyperspaceLocked"}
	if str(_manual.get("status", "")) in ["Started", "CompletedPending"]:
		return {"ok": false, "reason": "ManualChallengePending"}
	if not _routes.has(route): return {"ok": false, "reason": "UnknownRoute"}
	var level: int = int(_history.get(route, {}).get("cleared", 0)) + 1
	if not _levels.has(level): return {"ok": false, "reason": "HyperspaceLevelUnavailable"}
	if _lineups[route].size() != 10: return {"ok": false, "reason": "HyperspaceLineupUnavailable"}
	return {"ok": true, "receipt": {"round_id": _round_id, "run_id": _next_run,
		"mode": "manual", "route": route, "level": level, "status": "Started",
		"work": 0.0, "luck": permanent_luck, "luck_state": str(_luck_rng.state),
		"return_target": return_target.duplicate(true), "reward": {}}}

func accept_manual(receipt: Dictionary) -> void:
	_manual = receipt
	_manual.wave = 0
	_receipts[int(receipt.run_id)] = _manual
	_luck_rng.randi()
	_next_run += 1

func advance_manual(dt: float) -> void:
	if manual_active(): _manual.work += dt

func prepare_wave(latest_cleared: int, enemy_override: Callable, geometry: Dictionary, motion: Dictionary,
		jewel_probability: float) -> Dictionary:
	if not manual_active(): return {"ok": false, "reason": "NoManualChallenge"}
	var group_id: int = int(_lineups[str(_manual.route)][int(_manual.wave)].group_id)
	var group: Dictionary = _groups[group_id]
	var slots: Array = []
	var positions: Array = []
	var definitions: Dictionary = {}
	var budget_by_slot: Dictionary = {}
	var jewel_rolls: Dictionary = {}
	var rows: Array = _assignments.get(group_id, [])
	for row in rows:
		var slot: int = int(row.slot_index)
		var enemy_id: int = -1
		for candidate in _lineup_slots(group_id):
			if int(candidate.slot_index) == slot: enemy_id = int(candidate.enemy_id)
		if enemy_id < 0: return {"ok": false, "reason": "HyperspaceMemberMissing"}
		while slots.size() <= slot:
			slots.append(null)
			positions.append([0.0, 0.0])
		var instance_id: int = group_id * 100 + slot
		slots[slot] = instance_id
		var source: Dictionary = _enemies[enemy_id]
		var equipment: PackedStringArray = []
		for weapon in _weapons.get(enemy_id, []): equipment.append(str(weapon.weapon_id) + "|1")
		definitions[instance_id] = {"id": instance_id, "size": int(source.size), "health": source.health,
			"armourType": int(source.armour_type), "shield": source.shield, "shieldType": int(source.shield_type),
			"shieldRecovery": source.shield_recovery, "shieldDelay": source.shield_delay,
			"dmgMultiple": source.damage_multiplier, "equipment": "{" + ",".join(equipment) + "}",
			"res": "", "reactiveReduction": 0}
		budget_by_slot[slot] = []
		jewel_rolls[slot] = 0
	var reference: Dictionary = _references[str(group.reward_reference_id)]
	var source_blocks: Array = _source_budget_blocks(reference, latest_cleared)
	if source_blocks.is_empty(): return {"ok": false, "reason": "HyperspaceBudgetUnavailable"}
	var used: Dictionary = {}
	for row in rows:
		if row.reference_member_ordinal == null: continue
		var ordinal: int = int(row.reference_member_ordinal)
		if used.has(ordinal): return {"ok": false, "reason": "HyperspaceBudgetDuplicate"}
		used[ordinal] = true
		var slot: int = int(row.slot_index)
		budget_by_slot[slot].append_array(source_blocks[ordinal])
		jewel_rolls[slot] += 1
	if used.size() != source_blocks.size(): return {"ok": false, "reason": "HyperspaceBudgetUnassigned"}
	for slot in slots.size():
		if slots[slot] == null: continue
		var drops: PackedStringArray = []
		for drop in budget_by_slot[slot]: drops.append(str(drop.resource_id) + "," + str(drop.amount) + "," + str(drop.chance))
		definitions[int(slots[slot])].res = "{" + ";".join(drops) + "}" if not drops.is_empty() else ""
	for candidate in _lineup_slots(group_id): positions[int(candidate.slot_index)] = [candidate.x, candidate.y]
	var descriptor: Dictionary = {"mon": JSON.stringify(slots), "combatTier": group.tier,
		"formation_positions": positions, "jewel_rolls_by_slot": jewel_rolls}
	var selected: Dictionary = _levels[int(_manual.level)].duplicate()
	var resource: Dictionary = _levels[latest_cleared]
	selected.resRatio = resource.resRatio
	selected.jewelRatio = resource.jewelRatio
	var built: Dictionary = CombatSetup.build_wave(descriptor, selected, selected, int(_manual.wave), 10,
		definitions, _enemy_weapon_definitions, enemy_override, geometry, motion, 0, jewel_probability, _next_enemy_uid, _api, true)
	if built.ok: built.group_id = group_id
	return built

func accept_wave(setup: Dictionary) -> void:
	_next_enemy_uid = int(setup.next_uid)

func wave_cleared() -> bool:
	if not manual_active(): return false
	_manual.wave += 1
	return int(_manual.wave) >= 10

func finish_manual(success: bool) -> Dictionary:
	if not manual_active(): return {"ok": false, "reason": "NoManualChallenge"}
	if success:
		_manual.reward = _generate_reward(_manual)
		_manual.status = "CompletedPending"
		var route: String = str(_manual.route)
		var level: int = int(_manual.level)
		if not _history.has(route): _history[route] = {"cleared": 0, "best": {}}
		_history[route].cleared = level
		var old: float = float(_history[route].best.get(level, INF))
		_history[route].best[level] = minf(old, float(_manual.work))
	else:
		_manual.status = "Failed"
	return {"ok": true, "receipt": _manual.duplicate(true)}

func prepare_claim(run_id: int) -> Dictionary:
	var receipt: Dictionary = _receipts.get(run_id, {})
	if int(receipt.get("run_id", -1)) != run_id or int(receipt.get("round_id", -1)) != _round_id:
		return {"ok": false, "reason": "UnknownRun"}
	if receipt.status == "Claimed": return {"ok": true, "already_claimed": true, "reward": receipt.reward.duplicate(true)}
	if receipt.status != "CompletedPending": return {"ok": false, "reason": "RewardNotReady"}
	var reward: Dictionary = receipt.reward
	if not reward.drone.is_empty() and _warehouse.size() >= _warehouse_capacity() and _overflow.size() >= int(_parameters.overflow_capacity):
		return {"ok": false, "reason": "WarehouseFull"}
	return {"ok": true, "already_claimed": false, "reward": reward.duplicate(true)}

func accept_claim(run_id: int) -> void:
	var receipt: Dictionary = _receipts.get(run_id, {})
	if int(receipt.get("run_id", -1)) != run_id or receipt.status != "CompletedPending": return
	var drone: Dictionary = receipt.reward.drone
	if not drone.is_empty():
		if _warehouse.size() < _warehouse_capacity(): _warehouse.append(drone.duplicate(true))
		else: _overflow.append(drone.duplicate(true))
		_unlocked_drones[str(drone.id)] = true
		if drone.legendary: _legend_seen[str(drone.legendary_effect.effect_id)] = true
	_credit_modules(receipt.reward.hanging_rewards)
	receipt.status = "Claimed"

func prepare_reforge(ids: Array) -> Dictionary:
	if _manual.get("status") in ["Started", "CompletedPending"] or _idle.get("status") == "CompletedPending":
		return {"ok": false, "reason": "ChallengePending"}
	var capacity: int = int(_parameters.initial_retention_capacity) + (_reforge_count + 1) * int(_parameters.retention_capacity_gain)
	if ids.size() > capacity: return {"ok": false, "reason": "RetentionCapacityExceeded"}
	var seen: Dictionary = {}
	var retained: Array = []
	for value in ids:
		var id: String = str(value)
		var drone: Dictionary = _find_drone(id)
		if seen.has(id) or drone.is_empty(): return {"ok": false, "reason": "DroneUnavailable"}
		seen[id] = true
		retained.append(drone.duplicate(true))
	return {"ok": true, "retained": retained}

func accept_reforge(retained: Array) -> Dictionary:
	var old_auto: Dictionary = _auto.duplicate()
	_reforge_count += 1
	_round_id += 1
	_next_run = 1
	_next_enemy_uid = 0
	_energy = _resource_energy_cap().value
	_energy_progress = {}
	_energy_meter = {}
	_late_supply_work = 0.0
	_reward_rng.seed = _base_seed ^ 0x4859504552 ^ _round_id
	_luck_rng.seed = _base_seed ^ 0x4c55434b ^ _round_id
	_manual = {}
	_idle = {}
	_receipts = {}
	_auto = {"enabled": false, "route": "", "crew_id": ""}
	_warehouse = retained.duplicate(true)
	_overflow = []
	_equipped = []
	_presets = []
	_last_forge = {}
	_filter = {"version": 2, "enabled": false, "mode": "all", "action": "keep_matches", "conditions": []}
	_legend_seen = {}
	_legend_collection = {}
	for key in _modules: _modules[key] = {"unlocked": false, "level": 0, "exp": 0.0}
	var next_favorites: Array = []
	_sealed = {}
	for drone in _warehouse:
		var id: String = str(drone.id)
		drone.hangings = []
		if id in _favorites: next_favorites.append(id)
		_sealed[id] = int(_planet_claim_levels.get(_planet_key(str(drone.planet_id)), 0))
	_favorites = next_favorites
	return {"ok": true, "released_crew": str(old_auto.get("crew_id", "")), "route": str(old_auto.get("route", ""))}

func release_sealed(id: String, cleared_stages: Array) -> Dictionary:
	if not _sealed.has(id): return {"ok": false, "reason": "DroneNotSealed"}
	if int(_sealed[id]) not in cleared_stages: return {"ok": false, "reason": "ClaimStageLocked"}
	_sealed.erase(id)
	return {"ok": true}

func _generate_reward(receipt: Dictionary) -> Dictionary:
	var reward: Dictionary = {"drone": {}, "materials": {}, "ultimate_cores": 0, "hanging_rewards": {}}
	var route: Dictionary = _routes[str(receipt.route)]
	var base: int = int(_parameters.material_base_reward) + maxi(0, int(receipt.level) - int(_parameters.material_reward_start_level)) / int(_parameters.material_reward_level_step)
	var ramp: float = 1.0 + (float(_parameters.late_material_reward_multiplier) - 1.0) * _late_supply_work / float(_parameters.late_supply_ramp_seconds)
	var quantity: Dictionary = _api.apply("from_decimal",[str(base)])
	for factor in [str(_parameters.material_unit_scale),str(ramp),str(1.0 + float(module_contributions().get("hyperspace_charge",0.0)))]:
		if not quantity.ok: break
		var multiplier: Dictionary = _api.apply("from_decimal",[factor])
		if not multiplier.ok:
			quantity = multiplier
			break
		quantity = _api.apply("mul",[quantity.value,multiplier.value])
	if quantity.ok: quantity = _api.apply("floor",[quantity.value])
	if not quantity.ok:
		_run_state.fail(str(quantity.get("error","MaterialRewardFailed")))
		return reward
	reward.materials[str(route.material)] = _api.apply("to_display",[quantity.value]).text
	if _reward_rng.randf() < float(_parameters.ultimate_core_probability):
		reward.ultimate_cores = 1
		return reward
	var total: float = 0.0
	for row in _qualities:
		if str(row.quality) != "ultimate_core": total += float(row.weight)
	var draw: float = _reward_rng.randf() * total
	var quality: Dictionary = {}
	for row in _qualities:
		if str(row.quality) == "ultimate_core": continue
		draw -= float(row.weight)
		quality = row
		if draw < 0: break
	var planet_id: String = str(int(_planets[0].id))
	for planet in _planets:
		if int(receipt.level) >= int(planet.reforgeStartLevel): planet_id = str(int(planet.id))
	var drone: Dictionary = {"id": "space:%d:%d" % [_round_id, int(receipt.run_id)],
		"origin_quality": str(quality.quality), "weapon": str(route.weapon), "level": int(receipt.level),
		"planet_id": planet_id, "legendary": str(quality.quality) == "legendary", "ultimate": false,
		"blue_source_bonus": str(quality.quality) == "blue", "affixes": [], "hangings": [],
		"hanging_slots": _slot_count(int(quality.hanging_limit), float(_parameters.hanging_initial_probability)),
		"preserved_hanging_slots": 0, "legendary_effect": {}, "ultimate_affix": {}, "omen": false,
		"forge_revision": 0, "weapon_generation": 1, "forge_rng_state": str(_reward_rng.state)}
	for index in _slot_count(int(quality.affix_limit), float(_parameters.affix_initial_probability)):
		drone.affixes.append(_draw_affix(str(route.weapon)))
	if drone.legendary: drone.legendary_effect = _draw_legend(str(route.weapon))
	var receipt_luck := RandomNumberGenerator.new()
	receipt_luck.state = int(receipt.luck_state)
	for affix in drone.affixes: _apply_luck(affix, float(receipt.get("luck", 0.0)), receipt_luck)
	var keep: bool = _filter_matches(drone) if _filter.action == "keep_matches" else not _filter_matches(drone)
	if _filter.enabled and not keep:
		var reclaimed: Dictionary = _dismantle_reward(drone)
		var merged: Dictionary = _api.apply("add",[_api.apply("from_decimal",[str(reward.materials[str(route.material)])]).value,_api.apply("from_decimal",[str(reclaimed.materials[str(route.material)])]).value])
		if not merged.ok:
			_run_state.fail(str(merged.get("error","MaterialRewardFailed")))
			return reward
		reward.materials[str(route.material)] = _api.apply("to_display",[merged.value]).text
		reward.hanging_rewards = reclaimed.hanging_rewards
	else:
		reward.drone = drone
	return reward

func _slot_count(limit: int, first_chance: float) -> int:
	var result: int = 0
	var chance: float = first_chance
	for index in limit:
		if _reward_rng.randf() < chance: result += 1
		chance *= float(_parameters.additional_probability_factor)
	return result

func _draw_affix(weapon: String, random: RandomNumberGenerator = null) -> Dictionary:
	var stream: RandomNumberGenerator = _reward_rng if random == null else random
	var total: float = 0.0
	for row in _tiers: total += float(row.draw_weight)
	var draw: float = stream.randf() * total
	var tier: int = 5
	for row in _tiers:
		draw -= float(row.draw_weight)
		tier = int(row.tier)
		if draw < 0: break
	var pool: Array = []
	for id in _affixes:
		if _weapon_matches(_affixes[id].weapon, weapon) and _affix_ranges[id].has(tier): pool.append(id)
	pool.sort()
	var key: String = str(pool[stream.randi_range(0, pool.size() - 1)])
	return {"key": key, "tier": tier, "value": _quantized(_affix_ranges[key][tier].minimum, _affix_ranges[key][tier].maximum, stream), "locked": false}

func _draw_legend(weapon: String, random: RandomNumberGenerator = null) -> Dictionary:
	var stream: RandomNumberGenerator = _reward_rng if random == null else random
	var pool: Array = []
	for row in _legends:
		if _weapon_matches(row.weapon, weapon): pool.append(row)
	var picked: Dictionary = pool[stream.randi_range(0, pool.size() - 1)]
	var parameters: Dictionary = {}
	for row in _legend_parameters.get(str(picked.effect_id), []):
		parameters[str(row.parameter)] = _quantized(row.minimum, row.maximum, stream)
	return {"effect_id": str(picked.effect_id), "parameters": parameters}

func _weapon_matches(required, weapon: String) -> bool:
	return required == null or str(required).is_empty() or str(required) == weapon

func _quantized(low: float, high: float, random = null) -> float:
	var precision: float = float(_parameters.value_precision)
	var stream = _reward_rng if random == null else random
	return snappedf(float(stream.randi_range(ceili(low / precision - 1e-7), floori(high / precision + 1e-7))) * precision, precision)

func _apply_luck(affix: Dictionary, luck: float, random: RandomNumberGenerator) -> void:
	var attempts: int = floori(luck / 100.0)
	if random.randf() < fposmod(luck, 100.0) / 100.0: attempts += 1
	for index in attempts:
		var total: float = 0.0
		for row in _tiers: total += float(row.draw_weight)
		var draw: float = random.randf() * total
		for row in _tiers:
			draw -= float(row.draw_weight)
			if draw < 0:
				if int(row.tier) < int(affix.tier):
					affix.tier = int(row.tier)
					affix.value = _quantized(_affix_ranges[str(affix.key)][int(affix.tier)].minimum, _affix_ranges[str(affix.key)][int(affix.tier)].maximum, random)
				break

func _lineup_slots(group_id: int) -> Array:
	# Slot coordinates are part of the authored encounter, not derived from mainline formations.
	var result: Array = []
	for row in _slot_rows:
		if int(row.group_id) == group_id: result.append(row)
	return result

func _source_budget_blocks(reference: Dictionary, latest_cleared: int) -> Array:
	var blocks: Array = []
	var first_key: String = str(reference.reference_id) + ":0"
	if latest_cleared <= 5 and _early_budgets.has(first_key):
		for ordinal in int(reference.reference_member_count):
			var key: String = str(reference.reference_id) + ":" + str(ordinal)
			if not _early_budgets.has(key): return []
			blocks.append(_early_budgets[key])
	else:
		var group_id: int = int(reference.source_design_group_id if latest_cleared <= 5 else reference.late_reference_group_id)
		if not _main_groups.has(group_id): return []
		var group: Dictionary = _main_groups[group_id]
		var members: Array = JSON.parse_string(str(group.mon).replace("｛", "[").replace("｝", "]").replace("{", "[").replace("}", "]").replace("，", ","))
		var pattern := RegEx.new()
		pattern.compile("[｛{]([^｝}]+)[｝}]")
		for enemy_id in members:
			if enemy_id == null: continue
			var drops: Array = []
			for match_row in pattern.search_all(str(_main_enemies[int(enemy_id)].res)):
				for text in match_row.get_string(1).replace("；", ";").split(";", false):
					var fields: PackedStringArray = text.replace("，", ",").split(",")
					drops.append({"resource_id": int(fields[0]), "amount": fields[1], "chance": float(fields[2])})
			blocks.append(drops)
	return blocks if blocks.size() == int(reference.reference_member_count) else []

func player_catalog() -> Dictionary:
	var qualities: Array = []
	var legends: Array = []
	var weapons: Array = []
	for row in _qualities:
		if str(row.quality) != "ultimate_core": qualities.append(str(row.quality))
	if "ultimate" not in qualities: qualities.append("ultimate")
	for row in _legends: legends.append(str(row.effect_id))
	for row in _routes.values():
		if str(row.weapon) not in weapons: weapons.append(str(row.weapon))
	return {"weapons": weapons, "qualities": qualities, "affixes": _affixes.keys(), "legends": legends}

func _whole_resource_texts(values: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for id in values:
		if not Resources.valid_id(id): return {"ok":false,"reason":"InvalidResourceId"}
		var value: Dictionary = values[id] if values[id] is Dictionary else _api.apply("from_decimal",[str(values[id])]).get("value",{})
		var checked: Dictionary = Resources.whole(value,_api)
		if not checked.ok: return checked
		var text: Dictionary = _api.apply("to_display",[checked.value])
		if not text.ok: return text
		result[id] = text.text
	return {"ok":true,"values":result}

func _whole_reward(reward: Dictionary) -> Dictionary:
	var checked: Dictionary = _whole_resource_texts(reward.materials)
	if not checked.ok: return checked
	var result: Dictionary = reward.duplicate(true)
	result.materials = checked.values
	return {"ok":true,"reward":result}

func _resource_energy_cap() -> Dictionary:
	var value: Dictionary = _api.apply("from_decimal",[str(_parameters.energy_cap)])
	if not value.ok: return value
	return Resources.whole(value.value,_api)

func _energy_integral(seconds: float, late: bool) -> Dictionary:
	var base: Dictionary = _api.apply("from_decimal",[str(_parameters.energy_rate)])
	if not base.ok: return base
	if not late: return _api.apply("mul",[base.value,_api.apply("from_decimal",[str(seconds)]).value])
	var head: Dictionary = _api.apply("from_decimal",[str(minf(seconds,float(_parameters.late_supply_ramp_seconds)))])
	var tail: Dictionary = _api.apply("from_decimal",[str(maxf(0.0,seconds-float(_parameters.late_supply_ramp_seconds)))])
	var multiplier: Dictionary = _api.apply("from_decimal",[str(_parameters.late_energy_rate_multiplier)])
	for item in [head,tail,multiplier]:
		if not item.ok: return item
	var slope: Dictionary = _api.apply("mul",[base.value,_api.apply("from_decimal",[str(float(_parameters.late_energy_rate_multiplier)-1.0)]).value])
	if not slope.ok: return slope
	slope = _api.apply("div",[slope.value,_api.apply("from_decimal",[str(_parameters.late_supply_ramp_seconds)]).value])
	if not slope.ok: return slope
	var curve: Dictionary = _api.apply("mul",[slope.value,head.value])
	if not curve.ok: return curve
	curve = _api.apply("mul",[curve.value,head.value])
	if not curve.ok: return curve
	curve = _api.apply("div",[curve.value,_api.apply("from_decimal",["2"]).value])
	if not curve.ok: return curve
	var initial: Dictionary = _api.apply("mul",[base.value,head.value])
	var final: Dictionary = _api.apply("mul",[base.value,multiplier.value])
	if not initial.ok: return initial
	if not final.ok: return final
	final = _api.apply("mul",[final.value,tail.value])
	if not final.ok: return final
	var total: Dictionary = _api.apply("add",[initial.value,curve.value])
	if not total.ok: return total
	return _api.apply("add",[total.value,final.value])

func _advance_energy(dt: float, late: bool, origin: float) -> Dictionary:
	if not is_finite(dt) or dt<0.0: return {"ok":false,"reason":"InvalidResourceInterval"}
	var cap: Dictionary = _resource_energy_cap()
	if not cap.ok: return cap
	var meter: Dictionary = _energy_meter.duplicate(true)
	if meter.is_empty() or meter.late!=late:
		meter = {"elapsed":0.0,"origin":origin if late else 0.0,"late":late,"total":_api.apply("zero",[]).value}
	meter.elapsed += dt
	var end: Dictionary = _energy_integral(meter.origin+meter.elapsed,late)
	var start: Dictionary = _energy_integral(meter.origin,late)
	if not end.ok: return end
	if not start.ok: return start
	var total: Dictionary = _api.apply("sub_nonnegative",[end.value,start.value])
	if not total.ok: return total
	var delta: Dictionary = _api.apply("sub_nonnegative",[total.value,meter.total])
	if not delta.ok: return delta
	var zero: Dictionary = _api.apply("zero",[]).value
	var settled: Dictionary = Resources.settle(delta.value,_energy_progress if not _energy_progress.is_empty() else zero,_api)
	if not settled.ok: return settled
	var sum: Dictionary = _api.apply("add",[_energy,settled.amount])
	if not sum.ok: return sum
	var bounded: Dictionary = _api.apply("min",[sum.value,cap.value])
	if not bounded.ok: return bounded
	var full: Dictionary = _api.apply("compare",[bounded.value,cap.value])
	if not full.ok: return full
	_energy = bounded.value
	meter.total = total.value
	_energy_progress = settled.progress if full.scalar<0 else {}
	_energy_meter = meter if full.scalar<0 else {}
	return {"ok":true}
