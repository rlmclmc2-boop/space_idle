extends RefCounted
const Geometry = preload("res://scripts/ship_geometry_convention.gd")
const CombatSetup = preload("res://src/combat_setup.gd")
const Statistics = preload("res://src/systems/battle_statistics.gd")
var _kernel
var _api
var _run_state
var _statistics
var _geometry: Dictionary = {}
var _motion: Dictionary = {}
var _parameters: Dictionary
var _rules: Dictionary
var _configuration: Dictionary
var _models: Dictionary = {}
var _ship_key: String
var _player_art: Dictionary
var _player_dimensions: Vector2
var _player_geometry_height: float
var _player_hull: PackedVector2Array
var _player_muzzles: Dictionary = {}
var _enemy_muzzles: Dictionary = {}
var _enemy_hulls: Array = []
var _equipped_drones: Array = []
var _values: Dictionary = {}
var _events: Array = []
var _seed: int
var _initial_result: Dictionary

func _init(configuration: Dictionary, parameters: Dictionary, rules: Dictionary, ship_keys: Array, selected_ship: String, api, seed: int, run_state) -> void:
	_api = api
	_run_state = run_state
	_parameters = parameters
	_rules = rules
	_seed = seed
	_ship_key = selected_ship
	for row in configuration.battle_geometry.battle_geometry: _geometry[str(row.id)] = row.value
	for row in configuration.weapon_motion.weapon_motion: _motion[str(row.id)] = row.value
	_configuration = CombatSetup.legendary_configuration(configuration.hyperspace_config)
	_initial_result = _load_models(ship_keys)
	if not _initial_result.ok: return
	_kernel = ClassDB.instantiate("SpaceCombatKernel")
	_statistics = Statistics.new(api, run_state)

func _load_models(ship_keys: Array) -> Dictionary:
	var art_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/ship_weapon_visuals.json"))
	_player_art = art_data.ships[_ship_key]
	var model_keys: Array = ship_keys.duplicate()
	model_keys.append_array(["enemy_1", "enemy_2", "enemy_3", "enemy_4", "enemy_5", "enemy_6"])
	for key in model_keys:
		var art: Dictionary = art_data.ships[key]
		var image := Image.load_from_file(str(art.texture))
		if image == null or image.is_empty():
			return {"ok": false, "reason": "MissingHullAsset:" + str(key)}
		var logical_path: String = str(art.get("geometry_texture", art.texture))
		var logical_image := image if logical_path == str(art.texture) else Image.load_from_file(logical_path)
		if logical_image == null or logical_image.is_empty():
			return {"ok": false, "reason": "MissingGeometryAsset:" + str(key)}
		_models[key] = {"hull": Geometry.normalized_hull(image), "size": Vector2(image.get_size()), "art": art,
			"geometry_height": float(logical_image.get_height())}
	_player_geometry_height = float(_models[_ship_key].geometry_height)
	_player_dimensions = _models[_ship_key].size * float(_player_art.display_scale) * float(_geometry.player_display_multiplier) * float(_parameters["playerVisualScale" + _ship_key])
	_player_hull = Geometry.transform_hull(_models[_ship_key].hull, Vector2(float(_geometry.player_x), float(_geometry.player_y)), _player_dimensions, 0.0)
	return {"ok": true}

func initialization_result() -> Dictionary:
	return _initial_result

# Native ownership is shared only with the campaign lifecycle and battle renderer.
func native_owner():
	return _kernel

func statistics():
	return _statistics

func view_size() -> Vector2i:
	return Vector2i(int(_geometry.view_width), int(_geometry.view_height))

func mount_inputs(ship_key: String) -> Dictionary:
	var art: Dictionary = _models[ship_key].art
	var dimensions: Vector2 = _models[ship_key].size * float(art.display_scale) * float(_geometry.player_display_multiplier) * float(_parameters["playerVisualScale" + ship_key])
	return {"art": art, "dimensions": dimensions, "geometry": _geometry, "motion": _motion}

func wave_inputs() -> Dictionary:
	return {"geometry": _geometry, "motion": _motion}

func resource_positions() -> Dictionary:
	return {"origin": Vector2(float(_geometry.player_x), float(_geometry.timed_drop_spawn_y)), "target_y": float(_geometry.player_y)}

func player_hull() -> PackedVector2Array:
	return _player_hull

func enemy_hulls() -> Array:
	return _enemy_hulls

func events() -> Array:
	return _events

func presentation_active() -> bool:
	return _run_state.is_running()

func begin_frame() -> void:
	if not _run_state.is_running(): return
	_events = []

func prepare_player(mounted: Dictionary, upgrades: Dictionary, factors: Dictionary, reactor: Dictionary,
		ship: Dictionary, ship_key: String, contributions, damage_types: Dictionary) -> Dictionary:
	if not _run_state.is_running(): return _run_state.rejection()
	var source: Array = _equipped_drones if contributions == null else contributions
	var next_drones: Array = source.slice(0, int(ship.drone_capacity)).duplicate(true)
	var drone_weapons: Array = []
	for index in next_drones.size():
		var contribution: Dictionary = next_drones[index]
		var weapon: Dictionary = contribution.weapon.duplicate(true)
		weapon.entry.id = "drone:" + str(contribution.id)
		weapon.entry.drone_id = str(contribution.id)
		weapon.entry.generation = int(contribution.generation)
		weapon.slot = int(ship.mounts.weapon) + index
		drone_weapons.append(weapon)
	var setup = CombatSetup.build_player(mounted, _geometry, _rules, float(_parameters.dmgReduce), _motion, upgrades, factors, drone_weapons, _seed)
	if not setup.ok: return setup
	var iron = _api.apply("to_display", [reactor.smelting])
	if not iron.ok: return iron
	setup.descriptor.iron_drop_factor = iron.text
	setup.descriptor.equipped_drones = next_drones.duplicate(true)
	setup.descriptor.merge(_configuration)
	setup.descriptor.drone_capacity = int(ship.drone_capacity)
	setup.descriptor.rail_trail_width = float(_motion.rail_trail_width)
	setup.descriptor.higgs_minimum_width = float(_rules.higgs_minimum_width)
	setup.descriptor.merge(damage_types)
	var mount: Dictionary = mount_inputs(ship_key)
	setup.ship_key = ship_key
	setup.player_art = mount.art
	setup.player_dimensions = mount.dimensions
	setup.equipped_drones = next_drones
	return setup

func _accept_player(setup: Dictionary) -> void:
	_ship_key = setup.ship_key
	_player_art = setup.player_art
	_player_dimensions = setup.player_dimensions
	_player_geometry_height = float(_models[_ship_key].geometry_height)
	_equipped_drones = setup.equipped_drones
	_values = setup["values"]
	_player_muzzles = {}
	for row in setup.descriptor.weapons: _player_muzzles[str(row.entry.id)] = row.muzzle
	_player_hull = Geometry.transform_hull(_models[_ship_key].hull, Vector2(float(_geometry.player_x), float(_geometry.player_y)), _player_dimensions, 0.0)

func initialize_player(setup: Dictionary) -> Dictionary:
	if not _run_state.is_running(): return _run_state.rejection()
	if not _kernel.initialize(setup.descriptor):
		_run_state.fail("NativeInitializationFailed")
		return {"ok": false, "reason": "NativeInitializationFailed"}
	_accept_player(setup)
	_kernel.set_damage_stats_enabled(true)
	return {"ok": true}

func commit_player(setup: Dictionary, kind: String, geometry_changed: bool) -> Dictionary:
	if not _run_state.is_running(): return _run_state.rejection()
	var result: Dictionary = _kernel.set_player_configuration(setup.descriptor, kind)
	if not result.ok:
		if result.get("fault", false): _run_state.fail(str(result.reason))
		return result
	_accept_player(setup)
	if geometry_changed: return _sync_geometry()
	return result

func filter_values(values: Dictionary) -> void:
	if not _run_state.is_running(): return
	for group in ["weapons", "defences"]:
		for id in values[group].keys():
			if values[group][id] == _values[group].get(id): values[group].erase(id)

func commit_values(values: Dictionary, kind: String, iron: String, upgrades: Dictionary) -> Dictionary:
	if not _run_state.is_running(): return _run_state.rejection()
	if values.weapons.is_empty() and values.defences.is_empty() and iron.is_empty() and upgrades.is_empty(): return {"ok": true}
	var result: Dictionary = _kernel.set_player_values(values.weapons, values.defences, kind, iron, upgrades)
	if not result.ok:
		if result.get("fault", false): _run_state.fail(str(result.reason))
		return result
	for group in ["weapons", "defences"]:
		for id in values[group]:
			if not values[group][id].has("base"): continue
			var row: Dictionary = values[group][id].duplicate()
			row.erase("external")
			_values[group][id] = row
	return result

func advance(dt: float) -> Dictionary:
	if not _run_state.is_running(): return _run_state.rejection()
	if not _kernel.advance(dt):
		var reason: String = str(_kernel.take_results().get("error", ""))
		if reason.is_empty(): reason = "NativeAdvanceRejected"
		_run_state.fail(reason)
		return {"ok": false, "error": reason}
	var result: Dictionary = _kernel.take_results()
	if not str(result.error).is_empty():
		_run_state.fail(str(result.error))
		result.ok = false
		return result
	var recorded = _statistics.record(_kernel.take_damage_stats())
	if not recorded.ok:
		_run_state.fail(str(recorded.error))
		return recorded
	_events.append_array(result.events)
	result.ok = true
	return result

func start_wave(setup: Dictionary) -> Dictionary:
	if not _run_state.is_running(): return _run_state.rejection()
	if not _kernel.start_wave(setup.wave):
		_run_state.fail("NativeWaveRejected")
		return {"ok": false, "reason": "NativeWaveRejected"}
	_enemy_muzzles = setup.muzzles
	return _sync_geometry()

func validate_drones(contributions: Array, capacity: int) -> Dictionary:
	if contributions.size() > capacity: return {"ok": false, "reason": "DroneCapacityExceeded"}
	for contribution in contributions:
		if not contribution is Dictionary or not contribution.get("id") is String or str(contribution.id).is_empty() or not contribution.has("generation") or not contribution.get("weapon") is Dictionary or not contribution.weapon.get("entry") is Dictionary:
			return {"ok": false, "reason": "InvalidDroneContribution"}
	return {"ok": true}

func apply_drone_external(values: Dictionary, external_factors: Array) -> void:
	if not _run_state.is_running(): return
	for drone in _equipped_drones:
		var entry: Dictionary = drone.weapon.entry
		var external: Array = external_factors.duplicate()
		external.append_array(drone.weapon.get("external_factors", []))
		values.weapons["drone:" + str(drone.id)] = {"key": entry.key, "generation": int(drone.generation), "external": external}

func _sync_geometry() -> Dictionary:
	var packet = Geometry.battle_geometry(_kernel.enemy_views(), _models, _ship_key, _player_art,
		_player_dimensions, _player_geometry_height, _player_muzzles, _enemy_muzzles, _geometry, _parameters)
	_enemy_hulls = packet.hulls
	_kernel.input_geometry(packet.points, packet.muzzles)
	_kernel.input_ballistic_geometry(packet.hulls, packet.points, packet.muzzles, packet.stationary)
	_kernel.input_player_point(packet.player_point)
	_player_hull = packet.player_hull
	if not _kernel.input_player_hull(packet.player_hull):
		_run_state.fail("InvalidPlayerGeometry")
		return {"ok": false, "fault": true, "reason": "InvalidPlayerGeometry"}
	return {"ok": true}
