extends RefCounted
const CombatSetup = preload("res://src/combat_setup.gd")
signal progress_changed
signal ship_changed
signal status_changed

var _levels: Dictionary = {}
var _groups: Dictionary = {}
var _ships: Dictionary = {}
var _enemies: Dictionary = {}
var _enemy_weapons: Dictionary = {}
var _unlocks: Array
var _rules: Dictionary = {}
var _parameters: Dictionary = {}
var _selected_ship: String = ""
var _next_enemy_uid: int = 0
var _departure_remaining: float = 0.0
var _retreat_from: float = 0.0
var _retreat_to: float = 0.0
var _retreat_elapsed: float = 0.0
var _halted: bool = false
var _kernel
var _api
var _state: Dictionary = {"state": "menu", "stage": 1, "distance": 0.0,
	"point": 0, "points": [], "highest_reached": 1,
	"cleared_stages": {}, "origin": 0.0, "speed": 0.0, "wait": 0.0}
var _guard: Dictionary = {"enabled": false, "stage": 1, "point": 0, "distance": 0.0, "death_option": 0}

func _init(configuration: Dictionary, parameters: Dictionary, rules: Dictionary) -> void:
	for row in configuration.level.level: _levels[int(row.id)] = row
	for row in configuration.monGroup.monGroup: _groups[int(row.id)] = row
	for row in configuration.ship.ship: _ships[str(row.name)] = row
	for row in configuration.mon.mon: _enemies[int(row.id)] = row
	for row in configuration.enemy_weapon_base.enemy_weapon_base: _enemy_weapons[str(row.id)] = row
	_unlocks = configuration.unlock.unlock
	for key in ["departure_real_seconds", "death_retreat_duration", "clear_wait_seconds", "travel_max_seconds", "jewel_drop_rolls"]: _rules[key] = rules[key]
	for key in ["backRange", "jewelDrop"]: _parameters[key] = parameters[key]
	for row in configuration.ship.ship:
		if available("ship", str(row.name)):
			_selected_ship = str(row.name)
			break

func bind_native(kernel, api) -> void:
	_kernel = kernel
	_api = api

func halt() -> void:
	_halted = true

func selected_ship() -> String:
	return _selected_ship

func ship_keys() -> Array:
	return _ships.keys()

func ship_facts(id: String = "") -> Dictionary:
	var row: Dictionary = _ships[_selected_ship if id.is_empty() else id]
	return {"mounts": {"weapon": int(row.para_1), "defence": int(row.para_2)}, "drone_capacity": int(row.para_5)}

func ship_options() -> Array:
	var options: Array = []
	for key in _ships: options.append({"id": key, "name": str(_ships[key].des), "enabled": available("ship", key), "selected": key == _selected_ship})
	return options

func change_ship(id: String, refit: Callable) -> Dictionary:
	if id == _selected_ship: return {"ok": false, "reason": "NoChange"}
	if not _ships.has(id) or not available("ship", id): return {"ok": false, "reason": "ShipLocked"}
	return refit.call(id)

func accept_ship(id: String) -> void:
	if id == _selected_ship: return
	_selected_ship = id
	ship_changed.emit()

func progress_facts() -> Dictionary:
	return {"highest_reached": int(_state.highest_reached), "cleared_stages": _state.cleared_stages}

func resource_generation_active() -> bool:
	return _state.state in ["travel", "combat", "waiting", "guard_wait", "retreat"]

func planet_experience() -> Dictionary:
	return {"enabled": available("feature", "crew_level"), "ratio": _levels[int(_state.highest_reached)].planetExpRatio}

func departure_active() -> bool:
	return _departure_remaining > 0

func consume_departure(seconds: float) -> float:
	var accepted: float = seconds
	if _departure_remaining > 0:
		var used: float = minf(_departure_remaining, accepted)
		_departure_remaining -= used
		accepted -= used
		if _departure_remaining <= 0:
			_begin_travel()
			status_changed.emit()
	return accepted

func status_text() -> String:
	return "关卡 %s · %s · %.0f" % [_state.stage, _state.state, _state.distance]

func toggle_guard() -> Dictionary:
	return set_guard(not _guard.enabled, int(_guard.death_option))

func advance(dt: float, advance_native: Callable, start_wave: Callable) -> void:
	var before: Array = [_state.stage, _state.state, _state.distance]
	_advance(dt, advance_native, start_wave)
	if before != [_state.stage, _state.state, _state.distance]: status_changed.emit()

func prepare_wave(enemy_override: Callable, geometry: Dictionary, motion: Dictionary) -> Dictionary:
	var point: int = int(_state.point)
	var stage: Dictionary = _levels[int(_state.stage)]
	var previous: Dictionary = _levels.get(int(_state.stage) - 1, {})
	var group: Dictionary = _groups[int(_state.points[point].id)]
	var jewel_rolls: int = int(_rules.jewel_drop_rolls) if available("feature", "jewels") else 0
	return CombatSetup.build_wave(group, stage, previous, point, _state.points.size(), _enemies, _enemy_weapons,
		enemy_override, geometry, motion, jewel_rolls, float(_parameters.jewelDrop), _next_enemy_uid, _api)

func accept_wave(update: Dictionary) -> void:
	_next_enemy_uid = int(update.next_uid)
	_state.state = "combat"
	status_changed.emit()

func available(kind: String, target: String) -> bool:
	for row in _unlocks:
		if str(row.type) != kind or str(row.target) != target:
			continue
		var gate: int = int(row.level)
		if gate == 0:
			return true
		return int(_state.highest_reached) > gate if row.mode == "reached" else _state.cleared_stages.has(gate)
	return false

func start_sortie(stage: int, clear_locks: Callable) -> Dictionary:
	if _kernel == null or _halted:
		return {"ok": false, "reason": "SessionUnavailable"}
	if not _levels.has(stage) or stage > int(_state.highest_reached):
		return {"ok": false, "reason": "StageLocked"}
	var hp = _api.apply("from_decimal", [str(_kernel.player_view().max_armour)])
	var zero = _api.apply("zero", [])
	if not hp.ok or _api.apply("compare", [hp.value, zero.value]).scalar <= 0:
		return {"ok": false, "reason": "NoArmour"}
	clear_locks.call()
	_kernel.clear_encounter("sortie")
	_kernel.finish_retreat()
	_set_stage(stage, 0.0)
	_state.point = 0
	_departure_remaining = float(_rules.departure_real_seconds)
	_state.state = "departing"
	status_changed.emit()
	return {"ok": true}

func set_guard(enabled: bool, death_option: int = 0) -> Dictionary:
	if death_option < 0 or death_option > 2:
		return {"ok": false, "reason": "InvalidGuardPolicy"}
	if enabled and _state.points.is_empty():
		return {"ok": false, "reason": "NoBattlePoint"}
	var was_enabled: bool = _guard.enabled
	_guard.enabled = enabled
	_guard.death_option = death_option
	if enabled and not was_enabled:
		_guard.stage = _state.stage
		_guard.point = _state.point
		_guard.distance = _state.distance
	return {"ok": true}

func _guard_matches() -> bool:
	return _guard.enabled and int(_guard.stage) == int(_state.stage) and int(_guard.point) == int(_state.point)

func _guard_interval() -> float:
	var point: int = int(_state.point)
	var previous: float = 0.0 if point == 0 else float(_state.points[point - 1].position)
	var gap: float = (float(_state.points[point].position) - previous) * float(_levels[int(_state.stage)].length)
	return minf(float(_rules.clear_wait_seconds), gap / float(_ships[_selected_ship].para_3))

func _target_distance() -> float:
	var point_distance: float = float(_state.points[int(_state.point)].position) * float(_levels[int(_state.stage)].length)
	if _guard_matches():
		point_distance = maxf(point_distance, float(_guard.distance))
	# A retreat beyond the preceding terminal point must still fight that point.
	return maxf(point_distance, float(_state.distance))

func _begin_travel() -> void:
	var target: float = _target_distance()
	_state.origin = _state.distance
	_state.speed = maxf(float(_ships[_selected_ship].para_3), (target - float(_state.origin)) / float(_rules.travel_max_seconds))
	_state.state = "travel"

func _set_stage(stage: int, distance: float) -> void:
	_state.stage = stage
	_state.distance = distance
	if stage > int(_state.highest_reached):
		_state.highest_reached = stage
		progress_changed.emit()
	var entries: PackedStringArray = str(_levels[stage].monGroup).replace("{", "").replace("}", "").replace("｛", "").replace("｝", "").replace("，", ",").split(",")
	_state.points = []
	for entry in entries:
		var fields: PackedStringArray = entry.split("|")
		_state.points.append({"id": int(fields[0]), "position": float(fields[1])})

func _global_position() -> float:
	var total: float = float(_state.distance)
	for stage in range(1, int(_state.stage)):
		total += float(_levels[stage].length)
	return total

func _place_global(position: float) -> void:
	var stage: int = 1
	while _levels.has(stage + 1) and position >= float(_levels[stage].length):
		position -= float(_levels[stage].length)
		stage += 1
	if stage != int(_state.stage):
		_set_stage(stage, position)
	else:
		_state.distance = position
	# Stage, distance and the next battle point form one position update. Shared
	# income may read this position during retreat, before retreat completes.
	var point: int = 0
	while point < _state.points.size() - 1 and float(_state.points[point].position) * float(_levels[int(_state.stage)].length) < float(_state.distance):
		point += 1
	_state.point = point

func timed_resource_ratio() -> Dictionary:
	var stage: Dictionary = _levels[int(_state.stage)]
	var previous: Dictionary = _levels.get(int(_state.stage) - 1, {})
	return CombatSetup.ratio(stage, previous, "resRatio", int(_state.point), _state.points.size(), _api)

func _advance(dt: float, advance_native: Callable, start_wave: Callable) -> void:
	match str(_state.state):
		"travel":
			var target: float = _target_distance()
			var time_to_point: float = maxf(0.0, target - float(_state.distance)) / float(_state.speed)
			var travel_time: float = minf(dt, time_to_point)
			_state.distance = minf(target, float(_state.distance) + float(_state.speed) * travel_time)
			if not advance_native.call(travel_time):
				return
			if _state.state == "retreat":
				advance_native.call(dt - travel_time)
				return
			if time_to_point <= dt:
				start_wave.call()
				if not _halted:
					advance_native.call(dt - travel_time)
		"combat":
			advance_native.call(dt)
		"waiting":
			if not advance_native.call(dt):
				return
			_state.wait = maxf(0.0, float(_state.wait) - dt)
			if _state.state != "waiting":
				return
			if _state.wait <= 0 and _guard_matches():
				start_wave.call()
			elif _state.wait <= 0:
				var next: int = int(_state.stage) + 1
				if _levels.has(next):
					_set_stage(next, 0.0)
					_state.point = 0
					_begin_travel()
				else:
					_state.state = "menu"
		"guard_wait":
			if not advance_native.call(dt) or _state.state != "guard_wait":
				return
			_state.wait = maxf(0.0, float(_state.wait) - dt)
			if _state.wait <= 0:
				if _guard_matches():
					start_wave.call()
				else:
					_state.point = int(_state.point) + 1
					_begin_travel()
		"retreat":
			advance_native.call(dt)
			_retreat_elapsed += dt
			var duration: float = clampf(float(_rules.death_retreat_duration), 0.001, 3.0)
			_place_global(lerpf(_retreat_from, _retreat_to, minf(1.0, _retreat_elapsed / duration)))
			if _retreat_elapsed >= duration:
				_kernel.finish_retreat()
				var point: int = int(_state.point)
				if _guard.enabled and int(_guard.death_option) == 2:
					_guard.stage = _state.stage
					_guard.point = point
					_guard.distance = _state.distance
				var hp = _api.apply("from_decimal", [str(_kernel.player_view().max_armour)])
				var zero = _api.apply("zero", [])
				if _api.apply("compare", [hp.value, zero.value]).scalar <= 0:
					_state.state = "menu"
					_state.reason = "NoArmour"
				else:
					_begin_travel()
		_:
			advance_native.call(dt)

func observe_battle(result: Dictionary, clear_locks: Callable, settle_collection: Callable) -> bool:
	if result.player_dead and _state.state != "retreat":
		_begin_death_retreat(clear_locks)
	elif result.wave_cleared:
		clear_locks.call()
		_kernel.finish_wave(bool(result.final_cleared))
		if result.final_cleared:
			if not bool(settle_collection.call()): return false
			if not _state.cleared_stages.has(int(_state.stage)):
				_state.cleared_stages[int(_state.stage)] = true
				progress_changed.emit()
			_state.state = "waiting"
			_state.wait = _guard_interval() if _guard_matches() else float(_rules.clear_wait_seconds)
		elif _guard_matches():
			_state.state = "guard_wait"
			_state.wait = _guard_interval()
		else:
			_state.point = int(_state.point) + 1
			_begin_travel()
	return true

func _begin_death_retreat(clear_locks: Callable) -> void:
	_retreat_from = _global_position()
	_retreat_to = maxf(0.0, _retreat_from - float(_parameters.backRange))
	_retreat_elapsed = 0.0
	if int(_guard.death_option) == 0:
		_guard.enabled = false
	clear_locks.call()
	_kernel.begin_retreat()
	_state.state = "retreat"
	status_changed.emit()

func retreat_if_dead(clear_locks: Callable) -> void:
	var armour = _api.apply("from_decimal", [str(_kernel.player_view().armour)])
	if armour.ok and _api.apply("compare", [armour.value, _api.apply("zero", []).value]).scalar <= 0 and _state.state not in ["menu", "retreat", "departing"]:
		_begin_death_retreat(clear_locks)

