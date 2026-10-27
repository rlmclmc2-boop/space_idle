extends RefCounted
const PlayerText = preload("res://src/ui/player_text.gd")
const Geometry = preload("res://scripts/ship_geometry_convention.gd")
const CombatSetup = preload("res://src/combat_setup.gd")
const Statistics = preload("res://src/systems/battle_statistics.gd")
var _kernel
var _presentation
var _api
var _run_state
var _statistics
var _geometry: Dictionary = {}
var _motion: Dictionary = {}
var _parameters: Dictionary
var _rules: Dictionary
var _configuration: Dictionary
var _models: Dictionary = {}
var _weapon_art: Dictionary = {}
var _weapon_art_meta: Dictionary = {}
var _weapon_poses: Dictionary = {}
var _visual_weapons: Array = []
var _enemy_visual_weapons: Array = []
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
var _prepared_player: Dictionary = {}
var configuration_commits: int = 0
var _events: Array = []
var _seed: int
var _initial_result: Dictionary

func _init(configuration: Dictionary, parameters: Dictionary, rules: Dictionary, ship_keys: Array, selected_ship: String, api, seed: int, run_state) -> void:
	_api = api
	_run_state = run_state
	_enemy_hulls.make_read_only()
	_parameters = parameters
	_rules = rules
	_seed = seed
	_ship_key = selected_ship
	for row in configuration.battle_geometry.battle_geometry: _geometry[str(row.id)] = row.value
	for row in configuration.weapon_motion.weapon_motion: _motion[str(row.id)] = row.value
	_geometry.make_read_only()
	_motion.make_read_only()
	_configuration = CombatSetup.legendary_configuration(configuration.hyperspace_config)
	_initial_result = _load_models(ship_keys)
	_initial_result.make_read_only()
	if not _initial_result.ok: return
	_kernel = ClassDB.instantiate("SpaceCombatKernel")
	_statistics = Statistics.new(api, run_state)

func _load_models(ship_keys: Array) -> Dictionary:
	var art_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/ship_weapon_visuals.json"))
	for key in art_data.weapons:
		var source: Texture2D = load(str(art_data.weapons[key].rotating_sprite))
		var crop := AtlasTexture.new()
		crop.atlas = source
		crop.region = Rect2(source.get_image().get_used_rect())
		_weapon_art[key] = crop
		var port: Array = art_data.weapons[key].muzzle[0]
		_weapon_art_meta[key] = {"source_size": source.get_size(), "crop": crop.region,
			"port": Vector2(float(port[0]), float(port[1]))}
	var model_keys: Array = ship_keys.duplicate()
	model_keys.append_array(["enemy_1", "enemy_2", "enemy_3", "enemy_4", "enemy_5", "enemy_6"])
	for key in model_keys:
		var art: Dictionary = art_data.ships[key]
		var texture := load(str(art.texture)) as Texture2D
		var image: Image = texture.get_image() if texture != null else null
		if image == null or image.is_empty():
			return {"ok": false, "reason": "MissingHullAsset:" + str(key)}
		var logical_path: String = str(art.get("geometry_texture", art.texture))
		var logical_texture := load(logical_path) as Texture2D if logical_path != str(art.texture) else texture
		var logical_image: Image = image if logical_path == str(art.texture) else logical_texture.get_image() if logical_texture != null else null
		if logical_image == null or logical_image.is_empty():
			return {"ok": false, "reason": "MissingGeometryAsset:" + str(key)}
		var model := {"texture": texture, "hull": Geometry.normalized_hull(image), "size": Vector2(image.get_size()),
			"geometry_height": float(logical_image.get_height())}
		var slot_map: Array = art.slot_map.duplicate()
		slot_map.make_read_only()
		var hardpoints: Array = []
		for source in art.hardpoints:
			var position: Array = source.pos.duplicate()
			position.make_read_only()
			var point := {"pos": position}
			point.make_read_only()
			hardpoints.append(point)
		hardpoints.make_read_only()
		model.art = {"display_scale": float(art.get("display_scale", 1.0)), "slot_map": slot_map,
			"hardpoints": hardpoints, "static_height": float(art.get("static_height", 0.0))}
		model.art.make_read_only()
		_models[key] = model
	return {"ok": true}

func initialization_result() -> Dictionary:
	return _initial_result

func defence_capacity_available() -> bool:
	var player: Dictionary = _kernel.player_view()
	var armour = _api.apply("from_decimal", [str(player.max_armour)])
	var shield = _api.apply("from_decimal", [str(player.max_shield)])
	if not armour.ok or not shield.ok: return false
	var zero: Dictionary = _api.apply("zero", []).value
	return _api.apply("compare", [armour.value, zero]).scalar > 0 or _api.apply("compare", [shield.value, zero]).scalar > 0

func defence_depleted() -> bool:
	var player: Dictionary = _kernel.player_view()
	var armour = _api.apply("from_decimal", [str(player.armour)])
	var shield = _api.apply("from_decimal", [str(player.shield)])
	if not armour.ok or not shield.ok: return false
	var zero: Dictionary = _api.apply("zero", []).value
	return _api.apply("compare", [armour.value, zero]).scalar <= 0 and _api.apply("compare", [shield.value, zero]).scalar <= 0

func reset_for_sortie() -> void:
	_kernel.clear_encounter("sortie")
	_kernel.finish_retreat()

func recover_from_retreat() -> bool:
	_kernel.finish_retreat()
	return defence_capacity_available()

func finish_wave(final: bool) -> void:
	_kernel.finish_wave(final)

func begin_death_retreat() -> void:
	_kernel.begin_retreat()

func statistics():
	return _statistics

func view_size() -> Vector2i:
	return Vector2i(int(_geometry.view_width), int(_geometry.view_height))

func mount_inputs(ship_key: String) -> Dictionary:
	var art: Dictionary = _models[ship_key].art
	var model: Dictionary = _models[ship_key]
	var height: float = float(art.static_height) * float(_geometry.player_display_multiplier) * float(_parameters["playerVisualScale" + ship_key])
	var dimensions: Vector2 = model.size * (height / (model.size.y * _hull_bounds(model.hull).size.y))
	var inputs := {"art": art, "dimensions": dimensions, "geometry": _geometry, "motion": _motion}
	inputs.make_read_only()
	return inputs

func wave_inputs() -> Dictionary:
	var inputs := {"geometry": _geometry, "motion": _motion}
	inputs.make_read_only()
	return inputs

func resource_positions() -> Dictionary:
	return {"origin": Vector2(float(_geometry.player_x), float(_geometry.timed_drop_spawn_y)), "target_y": float(_geometry.player_y)}

func draw_player_hull(canvas: CanvasItem) -> void:
	if _player_hull.size() >= 3: _draw_hull_texture(canvas, _player_hull, _models[_ship_key])

func draw_enemy_hull(canvas: CanvasItem, index: int) -> void:
	if index < 0 or index >= _enemy_hulls.size(): return
	var hull: PackedVector2Array = _enemy_hulls[index]
	if hull.size() >= 3:
		var actors: Array = _kernel.enemy_views()
		_draw_hull_texture(canvas, hull, _models["enemy_" + str(int(actors[index].size))])

func draw_enemy_overlays(canvas: CanvasItem, font: Font) -> void:
	var enemies: Array = _kernel.enemy_views()
	for index in enemies.size():
		var actor: Dictionary = enemies[index]
		if actor.get("dead", false): continue
		draw_enemy_hull(canvas, index)
		canvas.draw_string(font, Vector2(float(actor.x) - 40, float(actor.y) + maxf(46.0, _hull_bounds(_enemy_hulls[index]).size.y * 0.5 + 16.0)), PlayerText.number(str(actor.hp)), HORIZONTAL_ALIGNMENT_CENTER, 80, 14, Color("f1d9dc"))

func hud_values() -> Dictionary:
	var history: Dictionary = _kernel.read_history()
	var player: Dictionary = _kernel.player_view()
	return {"attacks": history.attacks, "incoming": history.incoming,
		"armour": player.armour, "shield": player.shield,
		"max_armour": player.max_armour, "max_shield": player.max_shield,
		"armour_fraction": _hud_fraction(str(player.armour), str(player.max_armour)),
		"shield_fraction": _hud_fraction(str(player.shield), str(player.max_shield))}

func configure_presentation(retained: ShaderMaterial, contact_meshes: Array, contact_canvas: RID,
		contacts: ShaderMaterial, flight_canvas: RID, beams: Callable) -> void:
	_presentation = ClassDB.instantiate("SpaceCombatPresentation")
	_presentation.configure_retained_gpu(retained)
	_presentation.configure_contact_gpu(contact_meshes, contact_canvas, contacts)
	# The native surface keeps its zero-copy path, but only Battle supplies the kernel.
	_presentation.configure_surface(_kernel, flight_canvas, beams)

func release_presentation() -> void:
	_presentation = null

func advance_presentation() -> void:
	_presentation.advance_visuals()
	for event in _events:
		if int(event.kind) in [0, 1]:
			_presentation.record_contact(0 if event.get("hostile", false) else 1, event.position, event.direction,
				float(event.clock), int(event.kind) == 0, bool(event.critical), int(event.type))
	_presentation.prune_contacts(float(_kernel.presentation_clock()))

func draw_presentation_flights() -> void:
	var prepared = _presentation.prepare_flights(Vector2.ZERO)
	_presentation.draw_flights(prepared, Vector2.ZERO)

func draw_presentation_contacts() -> void:
	_presentation.draw_contacts(float(_kernel.presentation_clock()))

func presentation_clock() -> float:
	return float(_kernel.presentation_clock())

func consume_damage_receipts() -> Array:
	var receipts: Array = _events.filter(func(event): return int(event.kind) == 8)
	_events = _events.filter(func(event): return int(event.kind) != 8)
	return receipts

func presentation_active() -> bool:
	return _run_state.is_running()

func begin_frame() -> void:
	if not _run_state.is_running(): return
	_events = []

func prepare_player(mounted: Dictionary, upgrades: Dictionary, factors: Dictionary, reactor: Dictionary,
		ship: Dictionary, ship_key: String, mount: Dictionary, contributions, damage_types: Dictionary) -> Dictionary:
	if not _run_state.is_running(): return _run_state.rejection()
	_prepared_player = {}
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
		weapon.muzzle = Vector2(float(_geometry.player_x), float(_geometry.player_y))
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
	setup.ship_key = ship_key
	setup.player_art = mount.art
	setup.player_dimensions = mount.dimensions
	setup.equipped_drones = next_drones
	_prepared_player = setup
	return {"ok": true}

func _accept_player() -> void:
	var setup: Dictionary = _prepared_player
	_ship_key = setup.ship_key
	_player_art = setup.player_art
	_player_dimensions = setup.player_dimensions
	_player_geometry_height = float(_models[_ship_key].geometry_height)
	_equipped_drones = setup.equipped_drones
	_values = setup["values"]
	_visual_weapons = setup.descriptor.weapons.duplicate(true)
	_prepared_player = {}

func persistent_state() -> Dictionary:
	if not _run_state.is_running() or _kernel == null: return _run_state.rejection()
	return {"ok": true, "state": _kernel.persistent_state()}

func initialize_player(native_state: Dictionary = {}) -> Dictionary:
	if not _run_state.is_running(): return _run_state.rejection()
	if not native_state.is_empty():
		if not native_state.get("history_counts") is Dictionary or not native_state.get("next_ids") is Dictionary:
			return {"ok": false, "reason": "InvalidNativeState"}
		var history: Dictionary = native_state.history_counts
		var ids: Dictionary = native_state.next_ids
		for value in [history.get("attacks"), history.get("incoming"), ids.get("attack"), ids.get("drop"), native_state.get("rng_state")]:
			if not value is String or not str(value).is_valid_int(): return {"ok": false, "reason": "InvalidNativeState"}
		_prepared_player.descriptor.attack_counter = str(history.attacks).to_int()
		_prepared_player.descriptor.incoming_counter = str(history.incoming).to_int()
		_prepared_player.descriptor.projectile_serial = str(ids.attack).to_int()
		_prepared_player.descriptor.drop_uid = str(ids.drop).to_int()
		_prepared_player.descriptor.rng_state = str(native_state.rng_state).to_int()
	if not _kernel.initialize(_prepared_player.descriptor):
		_run_state.fail("NativeInitializationFailed")
		return {"ok": false, "reason": "NativeInitializationFailed"}
	if not native_state.is_empty() and not _kernel.restore_persistent_state(native_state):
		return {"ok": false, "reason": "InvalidNativeState"}
	_accept_player()
	_player_hull = Geometry.transform_hull(_models[_ship_key].hull, Vector2(float(_geometry.player_x), float(_geometry.player_y)), _player_dimensions, 0.0)
	_kernel.set_damage_stats_enabled(true)
	return _sync_geometry()

func commit_player(kind: String, geometry_changed: bool) -> Dictionary:
	if not _run_state.is_running(): return _run_state.rejection()
	var result: Dictionary = _kernel.set_player_configuration(_prepared_player.descriptor, kind)
	if not result.ok:
		if result.get("fault", false): _run_state.fail(str(result.reason))
		return result
	configuration_commits += 1
	_accept_player()
	if geometry_changed: return _sync_geometry()
	return result

func filter_values(values: Dictionary) -> void:
	if not _run_state.is_running(): return
	for group in ["weapons", "defences"]:
		for id in values[group].keys():
			if values[group][id] == _values[group].get(id): values[group].erase(id)

func commit_values(values: Dictionary, kind: String, iron: String, upgrades: Dictionary) -> Dictionary:
	if not _run_state.is_running(): return _run_state.rejection()
	if values.weapons.is_empty() and values.defences.is_empty() and iron.is_empty() and upgrades.is_empty(): return {"ok": true, "defence_changed": false}
	var result: Dictionary = _kernel.set_player_values(values.weapons, values.defences, kind, iron, upgrades)
	if not result.ok:
		if result.get("fault", false): _run_state.fail(str(result.reason))
		return result
	var next_values: Dictionary = _values
	var values_changed: bool = false
	for group in ["weapons", "defences"]:
		var next_group: Dictionary = _values[group]
		var group_changed: bool = false
		for id in values[group]:
			if not values[group][id].has("base"): continue
			if not group_changed:
				next_group = next_group.duplicate()
				group_changed = true
			var row: Dictionary = values[group][id].duplicate()
			row.erase("external")
			row.make_read_only()
			next_group[id] = row
		if group_changed:
			if not values_changed:
				next_values = _values.duplicate()
				values_changed = true
			next_group.make_read_only()
			next_values[group] = next_group
	if values_changed:
		next_values.make_read_only()
		_values = next_values
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
	for event in result.events: event.make_read_only()
	_events.append_array(result.events)
	result.ok = true
	return result

func start_wave(setup: Dictionary) -> Dictionary:
	if not _run_state.is_running(): return _run_state.rejection()
	if not _kernel.start_wave(setup.wave):
		_run_state.fail("NativeWaveRejected")
		return {"ok": false, "reason": "NativeWaveRejected"}
	_enemy_visual_weapons = setup.wave.weapons.duplicate(true)
	return _sync_geometry()

func validate_drones(contributions: Array, capacity: int) -> Dictionary:
	if contributions.size() > capacity: return {"ok": false, "reason": "DroneCapacityExceeded"}
	for contribution in contributions:
		if not contribution is Dictionary or not contribution.get("id") is String or str(contribution.id).is_empty() or not contribution.has("generation") or not contribution.get("weapon") is Dictionary or not contribution.weapon.get("entry") is Dictionary:
			return {"ok": false, "reason": "InvalidDroneContribution"}
	return {"ok": true}

func append_drone_growth(values: Dictionary, contributions: Array, external_factors: Array) -> void:
	for drone in contributions:
		var weapon: Dictionary = drone.weapon
		var entry: Dictionary = weapon.entry
		var external: Array = external_factors.duplicate()
		external.append_array(weapon.get("external_factors", []))
		values.weapons["drone:" + str(drone.id)] = {"key": str(entry.key),
			"generation": int(drone.generation), "base": str(weapon.damage),
			"paid_level": int(entry.paid_level), "effective_level": int(entry.effective_level),
			"external": external}

func accept_drone_growth(contributions: Array) -> void:
	_equipped_drones = contributions.duplicate(true)

func matches_drone_contributions(contributions: Array) -> bool:
	return _equipped_drones == contributions

func _sync_geometry() -> Dictionary:
	var actors: Array = _kernel.enemy_views()
	var packet = Geometry.battle_geometry(actors, _models, _ship_key, _player_art,
		_player_dimensions, _player_geometry_height, _geometry, _parameters)
	_enemy_hulls = packet.hulls
	_enemy_hulls.make_read_only()
	_player_hull = packet.player_hull
	_weapon_poses = {}
	_player_muzzles = {}
	_enemy_muzzles = {}
	for weapon in _visual_weapons:
		var id: String = str(weapon.entry.id)
		if weapon.entry.has("drone_id"):
			_player_muzzles[id] = weapon.muzzle
			continue
		var pose: Dictionary = _weapon_pose(str(weapon.entry.key), weapon.muzzle, -PI * 0.5, 30.0)
		_weapon_poses[id] = pose
		_player_muzzles[id] = pose.muzzle
	for weapon in _enemy_visual_weapons:
		var source: int = int(weapon.source)
		if source >= actors.size(): continue
		var actor: Dictionary = actors[source]
		var body: Dictionary = packet.poses[source]
		var art: Dictionary = _models["enemy_" + str(int(actor.size))].art
		var pivot: Vector2 = Geometry.mount_position(art, int(weapon.slot) % art.slot_map.size(), body.origin, body.dimensions, body.angle)
		var pose: Dictionary = _weapon_pose(str(weapon.entry.key), pivot, PI * 0.5 + float(body.angle), 24.0)
		var id: String = "enemy:" + str(actor.uid) + ":" + str(int(weapon.slot))
		pose.source = source
		_weapon_poses[id] = pose
		_enemy_muzzles[id] = pose.muzzle
	var muzzles: Dictionary = _player_muzzles.duplicate()
	muzzles.merge(_enemy_muzzles)
	# The same source-keyed ports feed numerical and retained/screen births.
	_kernel.input_geometry(packet.points, muzzles)
	_kernel.input_ballistic_geometry(packet.hulls, packet.points, muzzles, packet.stationary)
	_kernel.input_player_point(packet.player_point)
	if not _kernel.input_player_hull(packet.player_hull):
		_run_state.fail("InvalidPlayerGeometry")
		return {"ok": false, "fault": true, "reason": "InvalidPlayerGeometry"}
	return {"ok": true}

func _draw_hull_texture(canvas: CanvasItem, hull: PackedVector2Array, model: Dictionary) -> void:
	var uv := PackedVector2Array()
	for point in model.hull: uv.append(point + Vector2(0.5, 0.5))
	canvas.draw_polygon(hull, PackedColorArray([Color.WHITE]), uv, model.texture)

func _weapon_pose(key: String, pivot: Vector2, angle: float, pixels: float) -> Dictionary:
	var texture: Texture2D = _weapon_art[key]
	var scale: float = pixels / maxf(texture.get_width(), texture.get_height())
	var dimensions: Vector2 = texture.get_size() * scale
	var meta: Dictionary = _weapon_art_meta[key]
	var local_port: Vector2 = ((meta.port + Vector2(0.5, 0.5)) * meta.source_size - meta.crop.position - meta.crop.size * 0.5) * scale
	return {"key": key, "pivot": pivot, "angle": angle, "dimensions": dimensions,
		"muzzle": pivot + local_port.rotated(angle), "local_port": local_port}

func draw_weapon_art(canvas: CanvasItem) -> void:
	var actors: Array = _kernel.enemy_views()
	for id in _weapon_poses:
		var pose: Dictionary = _weapon_poses[id]
		if pose.has("source") and actors[int(pose.source)].get("dead", false): continue
		canvas.draw_set_transform(pose.pivot, float(pose.angle))
		canvas.draw_texture_rect(_weapon_art[pose.key], Rect2(-pose.dimensions * 0.5, pose.dimensions), false)
	canvas.draw_set_transform(Vector2.ZERO)

func enemy_intelligence() -> Array:
	var rows: Array = []
	for actor in _kernel.enemy_views():
		if actor.get("dead", false): continue
		rows.append({"name": str(actor.get("intelName", actor.get("des", "敌舰"))) if actor.get("intelName") != null else str(actor.get("des", "敌舰")),
			"armour": str(actor.hp), "shield": str(actor.get("shield", "0")),
			"armour_type": int(actor.get("armourType", 0)), "shield_type": int(actor.get("shieldType", 0)),
			"mechanics": str(actor.get("intelMechanics", "")) if actor.get("intelMechanics") != null else "",
			"tier": str(actor.get("combat_tier", "normal")), "texture": _models["enemy_" + str(int(actor.size))].texture})
	return rows

func attribute_details() -> Dictionary:
	return _kernel.attribute_details()

# Authoritative silhouette bounds used by assembly and drawing alike.
static func _hull_bounds(hull: PackedVector2Array) -> Rect2:
	if hull.is_empty(): return Rect2()
	var bounds := Rect2(hull[0], Vector2.ZERO)
	for point in hull: bounds = bounds.expand(point)
	return bounds

func _hud_fraction(current: String, maximum: String) -> float:
	var value: Dictionary = _api.apply("from_decimal", [current])
	var capacity: Dictionary = _api.apply("from_decimal", [maximum])
	if not value.ok or not capacity.ok: return 0.0
	var zero: Dictionary = _api.apply("zero", []).value
	if _api.apply("compare", [capacity.value, zero]).scalar <= 0: return 0.0
	var ratio: Dictionary = _api.apply("to_ratio", [value.value, capacity.value])
	return clampf(float(ratio.scalar), 0.0, 1.0) if ratio.ok else 0.0
