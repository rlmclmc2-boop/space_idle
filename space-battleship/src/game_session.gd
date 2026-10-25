extends RefCounted
const CombatSetup = preload("res://src/combat_setup.gd")
const Equipment = preload("res://src/systems/equipment.gd")
const Enhancement = preload("res://src/systems/enhancement.gd")
const Reactor = preload("res://src/systems/reactor.gd")
const Research = preload("res://src/systems/research.gd")
const Economy = preload("res://src/systems/economy.gd")
const Crew = preload("res://src/systems/crew.gd")
const Planet = preload("res://src/systems/planet.gd")
const Galaxy = preload("res://src/systems/galaxy.gd")
const Geometry = preload("res://scripts/ship_geometry_convention.gd")
const STEP: float = 1.0 / 60.0
const FRAME_STEPS: int = 64

var kernel
var amount_api
var configuration: Dictionary = {}
var parameters: Dictionary = {}
var rules: Dictionary = {}
var geometry: Dictionary = {}
var evolution: Dictionary = {}
var enhancement: Dictionary = {}
var enhancement_progress: Dictionary = Enhancement.initial()
var reactor_progress: Dictionary = {}
var research_progress: Dictionary = Research.initial()
var research_definitions: Dictionary = {}
var crew_definitions: Dictionary = {}
var crew_rules: Dictionary = {}
var crew_jobs: Dictionary = {}
var crew_progress: Dictionary = {}
var planet_definitions: Dictionary = {}
var planet_buildings: Dictionary = {}
var planet_buffs: Array = []
var planet_progress: Dictionary = {}
var galaxy_definitions: Dictionary = {}
var galaxy_buildings: Dictionary = {}
var galaxy_rules: Dictionary = {}
var galaxy_progress: Dictionary = {}
var galaxy_crew_experience: Dictionary = {}
var research_speed: Dictionary = {}
var equipped_drones: Array = []
var legendary_definitions: Dictionary = {}
var legendary_constants: Dictionary = {}
var legendary_ranges: Dictionary = {}
var drone_limits: Dictionary = {}
var combat_config_dirty: bool = false
var damage_statistics: Dictionary = {}
var income_factors: Dictionary = {}
var motion: Dictionary = {}
var equipment_definitions: Dictionary = {}
var enemy_weapon_definitions: Dictionary = {}
var enemy_definitions: Dictionary = {}
var group_definitions: Dictionary = {}
var level_definitions: Dictionary = {}
var ship_definitions: Dictionary = {}
var models: Dictionary = {}
var player_art: Dictionary = {}
var player_dimensions := Vector2.ZERO
var player_geometry_height: float = 0.0
var player_muzzles: Dictionary = {}
var enemy_hulls: Array = []
var selected_ship: String = ""
var slots: Array = []
var seed_value: int = 1
var next_enemy_uid: int = 0
var campaign: Dictionary = {"state": "menu", "stage": 1, "distance": 0.0,
	"point": 0, "points": [], "highest_reached": 1, "lifetime_highest_reached": 1,
	"cleared_stages": {}, "origin": 0.0, "speed": 0.0, "wait": 0.0}
var wallet: Dictionary = {}
var drops: Dictionary = {}
var drop_cursor: Dictionary = {"registered_through": 0}
var timed_resource_spec: PackedStringArray = []
var timed_resources: Dictionary = {"elapsed": 0.0, "next_id": 0}
var income_samples: Array = []
var income_dirty: bool = false
var pause_reasons: Dictionary = {}
var pending_seconds: float = 0.0
var wall_time: float = 0.0
var game_time: float = 0.0
var departure_remaining: float = 0.0
var last_error: String = ""
var last_events: Array = []
var retreat_from: float = 0.0
var retreat_to: float = 0.0
var retreat_elapsed: float = 0.0
var guard: Dictionary = {"enabled": false, "stage": 1, "point": 0, "distance": 0.0, "death_option": 0}

func initialize(path: String, combat_seed: int) -> Dictionary:
	if kernel != null:
		return {"ok": false, "reason": "AlreadyInitialized"}
	if not ClassDB.class_exists("SpaceCombatKernel") or not ClassDB.class_exists("FoundationAmount"):
		return _fail("NativeExtensionRequired")
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return _fail("ConfigurationReadFailed")
	configuration = parsed
	seed_value = combat_seed
	for row in configuration.config.config:
		parameters[str(row.name)] = row.para_1
	timed_resource_spec = str(parameters.autoGenRes).replace("\uff0c", ",").split(",")
	for row in configuration.game_rules.game_rules:
		rules[str(row.id)] = row.value
	for row in configuration.battle_geometry.battle_geometry:
		geometry[str(row.id)] = row.value
	for row in configuration.equipment_evolution.equipment_evolution:
		evolution[str(row.key)] = row.value
	for row in configuration.enhance_config.enhance_config:
		enhancement[str(row.id)] = row.value
	for row in configuration.hyperspace_config["\u4f20\u8bf4\u5b9a\u4e49"]:
		legendary_definitions[str(row.effect_id)] = row
	for row in configuration.hyperspace_config["\u4f20\u8bf4\u968f\u673a\u53c2\u6570"]:
		if not legendary_ranges.has(str(row.effect_id)):
			legendary_ranges[str(row.effect_id)] = {}
		legendary_ranges[str(row.effect_id)][str(row.parameter)] = {"minimum": row.minimum, "maximum": row.maximum}
	var legacy_bounds: Dictionary = {}
	for row in configuration.hyperspace_config["\u56fa\u5b9a\u89c4\u5219_\u517c\u5bb9\u8bf4\u660e"]:
		legacy_bounds[str(row.key)] = row.value
	var old_key: String = "/legendary_effects/drone_master/stored_parameter_ranges/maximum_reduction/"
	if legacy_bounds.has(old_key + "0") and legacy_bounds.has(old_key + "1"):
		legendary_ranges.drone_master.maximum_reduction.compatibility_minimum = legacy_bounds[old_key + "0"]
		legendary_ranges.drone_master.maximum_reduction.compatibility_maximum = legacy_bounds[old_key + "1"]
	for row in configuration.hyperspace_config["\u4f20\u8bf4\u5e38\u91cf"]:
		if not legendary_constants.has(str(row.effect_id)):
			legendary_constants[str(row.effect_id)] = {}
		legendary_constants[str(row.effect_id)][str(row.constant_path)] = row.value
	for row in configuration.hyperspace_config["\u57fa\u7840\u53c2\u6570"]:
		drone_limits[str(row.key)] = row.value
	for row in configuration.ai_tech_tree.ai_tech_tree:
		research_definitions[str(row.id)] = row
	for row in configuration.crew.crew:
		crew_definitions[str(row.id)] = row
	for row in configuration.crew_config.crew_config:
		crew_rules[str(row.id)] = row.value
	for row in configuration.crew_assignment.crew_assignment:
		crew_jobs[str(row.id)] = row
	for row in configuration.planet.planet:
		planet_definitions[str(int(row.id))] = row
	for row in configuration.planet_build.planet_build:
		planet_buildings[str(row.id)] = row
	planet_buffs = configuration.planet_buff.planet_buff
	for row in configuration.galaxy.galaxy:
		galaxy_definitions[str(row.key)] = row
	for row in configuration.galaxy_build.galaxy_build:
		galaxy_buildings[str(row.key)] = row
	for row in configuration.galaxy_config.galaxy_config:
		galaxy_rules[str(row.key)] = row.value
	for row in configuration.weapon_motion.weapon_motion:
		motion[str(row.id)] = row.value
	for row in configuration.equipment.equipment:
		equipment_definitions[str(row.name)] = row
	for row in configuration.enemy_weapon_base.enemy_weapon_base:
		enemy_weapon_definitions[str(row.id)] = row
	for row in configuration.mon.mon:
		enemy_definitions[int(row.id)] = row
	for row in configuration.monGroup.monGroup:
		group_definitions[int(row.id)] = row
	for row in configuration.level.level:
		level_definitions[int(row.id)] = row
	for row in configuration.ship.ship:
		ship_definitions[str(row.name)] = row
	for row in configuration.ship.ship:
		if unlocked("ship", str(row.name)):
			selected_ship = str(row.name)
			break
	if selected_ship.is_empty():
		return _fail("InitialShipUnavailable")
	var art_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/ship_weapon_visuals.json"))
	player_art = art_data.ships[selected_ship]
	var model_keys: Array = ship_definitions.keys()
	model_keys.append_array(["enemy_1", "enemy_2", "enemy_3", "enemy_4", "enemy_5", "enemy_6"])
	for key in model_keys:
		var art: Dictionary = art_data.ships[key]
		var image := Image.load_from_file(str(art.texture))
		if image == null or image.is_empty():
			return _fail("MissingHullAsset:" + str(key))
		var logical_image := Image.load_from_file(str(art.get("geometry_texture", art.texture)))
		if logical_image == null or logical_image.is_empty():
			return _fail("MissingGeometryAsset:" + str(key))
		models[key] = {"hull": Geometry.normalized_hull(image), "size": Vector2(image.get_size()), "art": art,
			"geometry_height": float(logical_image.get_height())}
	var geometry_image := Image.load_from_file(str(player_art.get("geometry_texture", player_art.texture)))
	if geometry_image == null or geometry_image.is_empty():
		return _fail("MissingGeometryAsset")
	player_geometry_height = float(geometry_image.get_height())
	player_dimensions = models[selected_ship].size * float(player_art.display_scale) * float(geometry.player_display_multiplier) * float(parameters["playerVisualScale" + selected_ship])
	var starts: PackedStringArray = str(parameters.startEquip).split(",")
	var starting_weapons: Array = []
	var starting_defences: Array = []
	for candidate in starts:
		if not unlocked("equipment", candidate):
			continue
		if CombatSetup.KINDS.has(candidate):
			starting_weapons.append(candidate)
		elif candidate in ["armour", "shield"]:
			starting_defences.append(candidate)
	var ship: Dictionary = ship_definitions[selected_ship]
	for index in int(ship.para_1):
		slots.append({"id": "weapon:" + str(index), "category": "weapon", "index": index,
			"equipment_id": starting_weapons[index] if index < starting_weapons.size() else "",
			"paid_level": 1, "extra_levels": 0, "generation": 1, "switch_ready_at": 0.0})
	for index in int(ship.para_2):
		slots.append({"id": "defence:" + str(index), "category": "defence", "index": index,
			"equipment_id": starting_defences[index] if index < starting_defences.size() else "",
			"paid_level": 1, "extra_levels": 0, "generation": 1, "switch_ready_at": 0.0})
	research_progress.ratio = float(rules.research_default_ratio)
	amount_api = ClassDB.instantiate("FoundationAmount")
	crew_progress = Crew.initial(crew_definitions, amount_api)
	planet_progress = Planet.initial(planet_definitions, planet_buildings)
	var galaxies = Galaxy.initial(galaxy_definitions)
	if not galaxies.ok:
		return _fail(str(galaxies.reason))
	galaxy_progress = galaxies.regions
	kernel = ClassDB.instantiate("SpaceCombatKernel")
	reactor_progress = Reactor.initial(parameters)
	var setup = _growth_setup(slots, enhancement_progress, reactor_progress, research_progress)
	if not setup.ok:
		return _fail(str(setup.get("error", setup.get("reason", "EquipmentAssemblyFailed"))))
	for row in setup.descriptor.weapons:
		player_muzzles[str(row.entry.id)] = row.muzzle
	reactor_progress = setup.reactor_state
	income_factors = setup.income_factors
	research_speed = setup.research_speed
	galaxy_crew_experience = setup.galaxy_crew_experience
	if not kernel.initialize(setup.descriptor):
		return _fail("NativeInitializationFailed")
	kernel.set_damage_stats_enabled(true)
	return {"ok": true}

func unlocked(kind: String, target: String) -> bool:
	for row in configuration.unlock.unlock:
		if str(row.type) != kind or str(row.target) != target:
			continue
		var gate: int = int(row.level)
		if gate == 0:
			return true
		return int(campaign.highest_reached) > gate if row.mode == "reached" else campaign.cleared_stages.has(gate)
	return false

func start_sortie(stage: int) -> Dictionary:
	if kernel == null or not last_error.is_empty():
		return {"ok": false, "reason": "SessionUnavailable"}
	if not level_definitions.has(stage) or stage > int(campaign.highest_reached):
		return {"ok": false, "reason": "StageLocked"}
	var hp = amount_api.apply("from_decimal", [str(kernel.player_view().max_armour)])
	var zero = amount_api.apply("zero", [])
	if not hp.ok or amount_api.apply("compare", [hp.value, zero.value]).scalar <= 0:
		return {"ok": false, "reason": "NoArmour"}
	_clear_switch_locks()
	kernel.clear_encounter("sortie")
	kernel.finish_retreat()
	_set_stage(stage, 0.0)
	campaign.point = 0
	departure_remaining = float(rules.departure_real_seconds)
	campaign.state = "departing"
	return {"ok": true}

func set_pause(reason: String, held: bool) -> void:
	if held:
		pause_reasons[reason] = true
	else:
		pause_reasons.erase(reason)

func frame(real_dt: float, _focused: bool) -> void:
	last_events = []
	if kernel == null or not last_error.is_empty() or not is_finite(real_dt) or real_dt < 0:
		return
	wall_time += real_dt
	if not pause_reasons.is_empty():
		return
	var accepted: float = real_dt
	if departure_remaining > 0:
		var used: float = minf(departure_remaining, accepted)
		departure_remaining -= used
		accepted -= used
		if departure_remaining <= 0:
			_begin_travel()
		else:
			return
	pending_seconds += accepted
	var steps: int = 0
	while pending_seconds >= STEP and steps < FRAME_STEPS and departure_remaining <= 0 and pause_reasons.is_empty() and last_error.is_empty():
		_step(STEP)
		pending_seconds -= STEP
		steps += 1

func _step(dt: float) -> void:
	game_time += dt
	if not _advance_planets(dt) or not _advance_galaxies(dt) or not _advance_crew_jobs(dt):
		return
	if not _advance_timed_resources(dt):
		return
	var researched = Research.advance(research_progress, wallet, research_definitions, _research_gates(), dt, rules, amount_api, research_speed)
	if not researched.ok:
		_fail(str(researched.get("error", researched.get("reason", "ResearchFailed"))))
		return
	research_progress = researched.state
	wallet = researched.wallet
	if not Crew.assigned(crew_progress, "system_job", "hightech_scientists").is_empty():
		var continuation = Research.select_shortest(research_progress, research_definitions, _research_gates(), amount_api)
		if not continuation.ok:
			_fail(str(continuation.get("error", continuation.get("reason", "ResearchContinuationFailed"))))
			return
	combat_config_dirty = combat_config_dirty or researched.completed
	if researched.completed:
		# Publish completion effects before collection; income-window/automatic
		# investment refresh still happens once, after this step's collections.
		var changed = _commit_growth(slots, enhancement_progress, reactor_progress, research_progress, wallet, "growth")
		if not changed.ok:
			_fail(str(changed.get("error", changed.get("reason", "ResearchGrowthUpdateFailed"))))
			return
	var settled = Economy.collect_due(drops, wallet, income_samples,
		float(parameters.autoCollectReduce), wall_time, game_time, amount_api, false, income_factors)
	if not settled.ok:
		_fail(str(settled.get("error", "CollectionFailed")))
		return
	income_dirty = income_dirty or settled.collected
	if not _refresh_growth():
		return
	match str(campaign.state):
		"travel":
			var target: float = _target_distance()
			var time_to_point: float = maxf(0.0, target - float(campaign.distance)) / float(campaign.speed)
			var travel_time: float = minf(dt, time_to_point)
			campaign.distance = minf(target, float(campaign.distance) + float(campaign.speed) * travel_time)
			if not _advance_kernel(travel_time):
				return
			if campaign.state == "retreat":
				_advance_kernel(dt - travel_time)
				return
			if time_to_point <= dt:
				_start_wave()
				if last_error.is_empty():
					_advance_kernel(dt - travel_time)
		"combat":
			_advance_kernel(dt)
		"waiting":
			if not _advance_kernel(dt):
				return
			campaign.wait = maxf(0.0, float(campaign.wait) - dt)
			if campaign.state != "waiting":
				return
			if campaign.wait <= 0 and _guard_matches():
				_start_wave()
			elif campaign.wait <= 0:
				var next: int = int(campaign.stage) + 1
				if level_definitions.has(next):
					_set_stage(next, 0.0)
					campaign.point = 0
					_begin_travel()
				else:
					campaign.state = "menu"
		"guard_wait":
			if not _advance_kernel(dt) or campaign.state != "guard_wait":
				return
			campaign.wait = maxf(0.0, float(campaign.wait) - dt)
			if campaign.wait <= 0:
				if _guard_matches():
					_start_wave()
				else:
					campaign.point = int(campaign.point) + 1
					_begin_travel()
		"retreat":
			_advance_kernel(dt)
			retreat_elapsed += dt
			var duration: float = clampf(float(rules.death_retreat_duration), 0.001, 3.0)
			_place_global(lerpf(retreat_from, retreat_to, minf(1.0, retreat_elapsed / duration)))
			if retreat_elapsed >= duration:
				kernel.finish_retreat()
				var point: int = int(campaign.point)
				if guard.enabled and int(guard.death_option) == 2:
					guard.stage = campaign.stage
					guard.point = point
					guard.distance = campaign.distance
				var hp = amount_api.apply("from_decimal", [str(kernel.player_view().max_armour)])
				var zero = amount_api.apply("zero", [])
				if amount_api.apply("compare", [hp.value, zero.value]).scalar <= 0:
					campaign.state = "menu"
					campaign.reason = "NoArmour"
				else:
					_begin_travel()
		_:
			_advance_kernel(dt)

func _advance_kernel(dt: float) -> bool:
	if dt <= 0:
		return true
	if not kernel.advance(dt):
		var reason: String = str(kernel.take_results().get("error", ""))
		_fail(reason if not reason.is_empty() else "NativeAdvanceRejected")
		return false
	var result: Dictionary = kernel.take_results()
	for source in kernel.take_damage_stats():
		var key: String = str(source.source)
		var previous: Dictionary = damage_statistics.get(key, {"shield": amount_api.apply("zero", []).value, "health": amount_api.apply("zero", []).value})
		for field in ["shield", "health"]:
			var value = amount_api.apply("from_decimal", [str(source[field])])
			if not value.ok:
				_fail(str(value.error))
				return false
			var total = amount_api.apply("add", [previous[field], value.value])
			if not total.ok:
				_fail(str(total.error))
				return false
			previous[field] = total.value
		damage_statistics[key] = previous
	last_events.append_array(result.events)
	var registered = Economy.register_drops(drops, drop_cursor, result.drops, game_time, rules, amount_api, income_factors.refinery)
	if not registered.ok:
		_fail(str(registered.get("error", "DropRegistrationFailed")))
		return false
	if not str(result.error).is_empty():
		_fail(str(result.error))
		return false
	if result.player_dead and campaign.state != "retreat":
		_begin_death_retreat()
	elif result.wave_cleared:
		_clear_switch_locks()
		kernel.finish_wave(bool(result.final_cleared))
		if result.final_cleared:
			var settled = Economy.collect_due(drops, wallet, income_samples,
				float(parameters.autoCollectReduce), wall_time, game_time, amount_api, true, income_factors)
			if not settled.ok:
				_fail(str(settled.get("error", "FinalCollectionFailed")))
				return false
			income_dirty = income_dirty or settled.collected
			if not _refresh_growth():
				return false
			campaign.cleared_stages[int(campaign.stage)] = true
			campaign.state = "waiting"
			campaign.wait = _guard_interval() if _guard_matches() else float(rules.clear_wait_seconds)
		elif _guard_matches():
			campaign.state = "guard_wait"
			campaign.wait = _guard_interval()
		else:
			campaign.point = int(campaign.point) + 1
			_begin_travel()
	return true

func _start_wave() -> void:
	var point: int = int(campaign.point)
	var stage: Dictionary = level_definitions[int(campaign.stage)]
	var previous_stage: Dictionary = level_definitions.get(int(campaign.stage) - 1, {})
	var group: Dictionary = group_definitions[int(campaign.points[point].id)]
	var jewel_rolls: int = int(rules.jewel_drop_rolls) if unlocked("feature", "jewels") else 0
	var setup = CombatSetup.build_wave(group, stage, previous_stage, point, campaign.points.size(),
		enemy_definitions, enemy_weapon_definitions, equipment_definitions, geometry, motion,
		jewel_rolls, float(parameters.jewelDrop), next_enemy_uid, amount_api)
	if not setup.ok:
		_fail(str(setup.get("error", setup.get("reason", "WaveAssemblyFailed"))))
		return
	if not kernel.start_wave(setup.wave):
		_fail("NativeWaveRejected")
		return
	next_enemy_uid = int(setup.next_uid)
	campaign.state = "combat"
	_sync_geometry()

func _sync_geometry() -> void:
	var hulls: Array = []
	var points := PackedVector2Array()
	var stationary := PackedByteArray()
	var actors: Array = kernel.enemy_views()
	for actor in actors:
		var point := Vector2(float(actor.x), float(actor.y))
		var model: Dictionary = models["enemy_" + str(int(actor.size))]
		var random := RandomNumberGenerator.new()
		random.seed = int(actor.uid) * 7919 + int(actor.slot) * 104729
		random.randf()
		random.randf_range(-1.0, 1.0)
		var variance_range: Array = JSON.parse_string(str(geometry.enemy_scale_variance))
		var variance: float = random.randf_range(float(variance_range[0]), float(variance_range[1]))
		var angle: float = deg_to_rad(random.randf_range(-float(geometry.enemy_rotation_variance), float(geometry.enemy_rotation_variance)))
		var width: float = Geometry.enemy_width(int(actor.size), bool(actor.wave_final),
			int(actor.formation_count), float(player_art.display_scale) * float(geometry.player_display_multiplier),
			player_geometry_height, float(parameters["enemyVisualScaleSize" + str(int(actor.size))]), variance, geometry)
		var hull: PackedVector2Array = Geometry.transform_hull(model.hull, point, Vector2(width, width * float(geometry.enemy_model_height_ratio)) * float(actor.hull_scale), angle)
		hulls.append(hull)
		points.append(point)
		stationary.append(1)
	var muzzles: Dictionary = player_muzzles.duplicate()
	for actor in actors:
		var entries: PackedStringArray = str(actor.equipment).replace("｛", "").replace("｝", "").replace("{", "").replace("}", "").replace("，", ",").split(",")
		var mount: int = 0
		for entry in entries:
			for _mount in int(entry.split("|")[1]):
				muzzles["enemy:" + str(actor.uid) + ":" + str(mount)] = Vector2(float(actor.x), float(actor.y))
				mount += 1
	enemy_hulls = hulls
	kernel.input_geometry(points, muzzles)
	kernel.input_ballistic_geometry(hulls, points, muzzles, stationary)
	var player_point := Vector2(float(geometry.player_x), float(geometry.player_y))
	kernel.input_player_point(player_point)
	var player_hull: PackedVector2Array = Geometry.transform_hull(models[selected_ship].hull, player_point, player_dimensions, 0.0)
	if not kernel.input_player_hull(player_hull):
		_fail("InvalidPlayerGeometry")

func collect_drop(id: String) -> Dictionary:
	var result = Economy.collect_drop(drops, wallet, income_samples, id, false,
		float(parameters.autoCollectReduce), wall_time, game_time, amount_api, income_factors)
	if result.ok:
		income_dirty = true
		if not _refresh_growth():
			return {"ok": false, "reason": last_error}
	return result

func set_guard(enabled: bool, death_option: int = 0) -> Dictionary:
	if death_option < 0 or death_option > 2:
		return {"ok": false, "reason": "InvalidGuardPolicy"}
	if enabled and campaign.points.is_empty():
		return {"ok": false, "reason": "NoBattlePoint"}
	var was_enabled: bool = guard.enabled
	guard.enabled = enabled
	guard.death_option = death_option
	if enabled and not was_enabled:
		guard.stage = campaign.stage
		guard.point = campaign.point
		guard.distance = campaign.distance
	return {"ok": true}

func _guard_matches() -> bool:
	return guard.enabled and int(guard.stage) == int(campaign.stage) and int(guard.point) == int(campaign.point)

func _guard_interval() -> float:
	var point: int = int(campaign.point)
	var previous: float = 0.0 if point == 0 else float(campaign.points[point - 1].position)
	var gap: float = (float(campaign.points[point].position) - previous) * float(level_definitions[int(campaign.stage)].length)
	return minf(float(rules.clear_wait_seconds), gap / float(ship_definitions[selected_ship].para_3))

func _target_distance() -> float:
	var point_distance: float = float(campaign.points[int(campaign.point)].position) * float(level_definitions[int(campaign.stage)].length)
	if _guard_matches():
		point_distance = maxf(point_distance, float(guard.distance))
	# A retreat beyond the preceding terminal point must still fight that point.
	return maxf(point_distance, float(campaign.distance))

func _begin_travel() -> void:
	var target: float = _target_distance()
	campaign.origin = campaign.distance
	campaign.speed = maxf(float(ship_definitions[selected_ship].para_3), (target - float(campaign.origin)) / float(rules.travel_max_seconds))
	campaign.state = "travel"

func _set_stage(stage: int, distance: float) -> void:
	campaign.stage = stage
	campaign.distance = distance
	campaign.highest_reached = maxi(int(campaign.highest_reached), stage)
	campaign.lifetime_highest_reached = maxi(int(campaign.lifetime_highest_reached), stage)
	var entries: PackedStringArray = str(level_definitions[stage].monGroup).replace("{", "").replace("}", "").replace("｛", "").replace("｝", "").replace("，", ",").split(",")
	campaign.points = []
	for entry in entries:
		var fields: PackedStringArray = entry.split("|")
		campaign.points.append({"id": int(fields[0]), "position": float(fields[1])})

func _global_position() -> float:
	var total: float = float(campaign.distance)
	for stage in range(1, int(campaign.stage)):
		total += float(level_definitions[stage].length)
	return total

func _place_global(position: float) -> void:
	var stage: int = 1
	while level_definitions.has(stage + 1) and position >= float(level_definitions[stage].length):
		position -= float(level_definitions[stage].length)
		stage += 1
	if stage != int(campaign.stage):
		_set_stage(stage, position)
	else:
		campaign.distance = position
	# Stage, distance and the next battle point form one position update. Shared
	# income may read this position during retreat, before retreat completes.
	var point: int = 0
	while point < campaign.points.size() - 1 and float(campaign.points[point].position) * float(level_definitions[int(campaign.stage)].length) < float(campaign.distance):
		point += 1
	campaign.point = point

func _fail(reason: String) -> Dictionary:
	last_error = reason
	pause_reasons.error = true
	return {"ok": false, "reason": reason}

func _advance_timed_resources(dt: float) -> bool:
	if campaign.state in ["travel", "combat", "waiting", "guard_wait", "retreat"]:
		timed_resources.elapsed = float(timed_resources.elapsed) + dt
		var interval: float = float(timed_resource_spec[0])
		while float(timed_resources.elapsed) + 1e-9 >= interval:
			var stage: Dictionary = level_definitions[int(campaign.stage)]
			var previous: Dictionary = level_definitions.get(int(campaign.stage) - 1, {})
			var ratio = CombatSetup.ratio(stage, previous, "resRatio", int(campaign.point), campaign.points.size(), amount_api)
			if not ratio.ok:
				_fail(str(ratio.get("error", "TimedResourceRatioFailed")))
				return false
			var remainder: float = maxf(0.0, float(timed_resources.elapsed) - interval)
			var spawned = Economy.spawn_timed_drop(drops, timed_resources, timed_resource_spec[1],
				timed_resource_spec[2], float(timed_resource_spec[3]), ratio.value,
				Vector2(float(geometry.player_x), float(geometry.timed_drop_spawn_y)), game_time - remainder, amount_api, income_factors.refinery)
			if not spawned.ok:
				_fail(str(spawned.get("error", spawned.get("reason", "TimedResourceSpawnFailed"))))
				return false
			timed_resources.elapsed = remainder
	var moved = Economy.advance_timed_drops(drops, wallet, income_samples, float(geometry.player_y),
		float(parameters.autoCollectReduce), wall_time, game_time, amount_api, income_factors)
	if not moved.ok:
		_fail(str(moved.get("error", "TimedResourceCollectionFailed")))
		return false
	income_dirty = income_dirty or moved.collected
	return true

func _reactor_modules() -> Array:
	var enabled: Array = []
	if unlocked("feature", "reactor"):
		for module in str(parameters.reactorModules).split(","):
			if module != "condensation" or unlocked("reactor_module", module):
				enabled.append(module)
	return enabled

func _research_gates() -> Dictionary:
	var gates: Dictionary = {}
	for key in research_definitions:
		var row: Dictionary = research_definitions[key]
		gates[key] = (row.legacy_unlock == null or unlocked("hightech", str(row.legacy_unlock))) and (row.unlock == null or unlocked("feature", "jewels"))
	return gates

func _growth_setup(next_slots: Array, next_enhancement: Dictionary, next_reactor: Dictionary, next_research: Dictionary, next_ship: String = "", contributions = null) -> Dictionary:
	var ship_key: String = selected_ship if next_ship.is_empty() else next_ship
	var ship: Dictionary = ship_definitions[ship_key]
	var art: Dictionary = models[ship_key].art
	var dimensions: Vector2 = models[ship_key].size * float(art.display_scale) * float(geometry.player_display_multiplier) * float(parameters["playerVisualScale" + ship_key])
	var world = _world_contributions()
	if not world.ok:
		return world
	var enabled_slots: Array = []
	for slot in next_slots:
		if int(slot.index) < int(ship.para_1 if slot.category == "weapon" else ship.para_2):
			var effective: Dictionary = slot.duplicate(true)
			if int(effective.extra_levels) > 9223372036854775807 - int(world.equipment_levels):
				return {"ok": false, "reason": "EquipmentLevelRangeExceeded"}
			effective.extra_levels = int(effective.extra_levels) + int(world.equipment_levels)
			enabled_slots.append(effective)
	var source_drones: Array = equipped_drones if contributions == null else contributions
	var next_drones: Array = source_drones.slice(0, int(ship.para_5)).duplicate(true)
	var reactor = Reactor.evaluate(next_reactor, parameters, _reactor_modules(), amount_api, world.capacity, world.free_charge)
	if not reactor.ok:
		return reactor
	var ai_weapon = Research.factor(next_research, research_definitions, "weapon_damage", rules, amount_api)
	var ai_defence = Research.factor(next_research, research_definitions, "equipment_durability", rules, amount_api)
	for result in [ai_weapon, ai_defence]:
		if not result.ok:
			return result
	var factors := {"ai_weapon": ai_weapon.value, "ai_defence": ai_defence.value,
		"reactor_weapon": reactor.factors.weapons, "reactor_defence": reactor.factors.defence, "external": world.external}
	var effective_enhancement: Dictionary = next_enhancement.duplicate(true)
	if int(effective_enhancement.extra_levels) > 9223372036854775807 - int(world.enhancement_levels):
		return {"ok": false, "reason": "EnhancementLevelRangeExceeded"}
	effective_enhancement.extra_levels = int(effective_enhancement.extra_levels) + int(world.enhancement_levels)
	var effects: Dictionary = Enhancement.describe(effective_enhancement, enhancement, unlocked("feature", "jewels"))
	var drone_weapons: Array = []
	for index in next_drones.size():
		var contribution: Dictionary = next_drones[index]
		var weapon_row: Dictionary = contribution.weapon.duplicate(true)
		weapon_row.entry.id = "drone:" + str(contribution.id)
		weapon_row.entry.drone_id = str(contribution.id)
		weapon_row.entry.generation = int(contribution.generation)
		weapon_row.slot = int(ship.para_1) + index
		drone_weapons.append(weapon_row)
	var setup = CombatSetup.build_player(enabled_slots, equipment_definitions, evolution, amount_api,
		art, dimensions, geometry, rules, float(parameters.dmgReduce), motion, enhancement, effects, factors, drone_weapons, seed_value)
	if not setup.ok:
		return setup
	setup.income_factors = {"condensation": reactor.factors.condensation, "refinery": world.refinery, "crew_fragments": world.fragments, "galaxy_fragments": world.galaxy_fragments}
	setup.research_speed = world.research
	setup.galaxy_crew_experience = world.crew_experience
	for resource_effect in [["iron", "iron_income"], ["uranium", "uranium_income"], ["jewel", "fragment_income"]]:
		var value = Research.factor(next_research, research_definitions, resource_effect[1], rules, amount_api)
		if not value.ok:
			return value
		setup.income_factors[resource_effect[0]] = value.value
	var iron_text = amount_api.apply("to_display", [reactor.factors.smelting])
	if not iron_text.ok:
		return iron_text
	setup.descriptor.iron_drop_factor = iron_text.text
	setup.reactor_state = next_reactor.duplicate(true)
	setup.reactor_state.allocations = reactor.allocations
	setup.descriptor.equipped_drones = next_drones.duplicate(true)
	setup.descriptor.legendary_definitions = legendary_definitions
	setup.descriptor.legendary_constants = legendary_constants
	setup.descriptor.legendary_ranges = legendary_ranges
	setup.descriptor.drone_limits = drone_limits
	setup.descriptor.drone_capacity = int(ship.para_5)
	setup.descriptor.rail_trail_width = float(motion.rail_trail_width)
	setup.descriptor.higgs_minimum_width = float(rules.higgs_minimum_width)
	setup.descriptor.strange_damage_type = int(equipment_definitions.cannon.dmgtype)
	setup.descriptor.wild_damage_type = int(equipment_definitions.missile.dmgtype)
	setup.ship_key = ship_key
	setup.player_art = art
	setup.player_dimensions = dimensions
	setup.equipped_drones = next_drones
	return setup

func _commit_growth(next_slots: Array, next_enhancement: Dictionary, next_reactor: Dictionary,
		next_research: Dictionary, next_wallet: Dictionary, change_kind: String, next_ship: String = "", contributions = null) -> Dictionary:
	var setup = _growth_setup(next_slots, next_enhancement, next_reactor, next_research, next_ship, contributions)
	if not setup.ok:
		return setup
	# No page callbacks or asynchronous work can interleave this commit.
	var committed: Dictionary = kernel.set_player_configuration(setup.descriptor, change_kind)
	if not committed.ok:
		if committed.fault:
			return _fail(str(committed.reason))
		return committed
	slots = next_slots
	selected_ship = setup.ship_key
	player_art = setup.player_art
	player_dimensions = setup.player_dimensions
	player_geometry_height = float(models[selected_ship].geometry_height)
	equipped_drones = setup.equipped_drones
	enhancement_progress = next_enhancement
	reactor_progress = setup.reactor_state
	income_factors = setup.income_factors
	research_speed = setup.research_speed
	galaxy_crew_experience = setup.galaxy_crew_experience
	research_progress = next_research
	wallet = next_wallet
	player_muzzles = {}
	for row in setup.descriptor.weapons:
		player_muzzles[str(row.entry.id)] = row.muzzle
	_sync_geometry()
	combat_config_dirty = false
	var armour = amount_api.apply("from_decimal", [str(kernel.player_view().armour)])
	if armour.ok and amount_api.apply("compare", [armour.value, amount_api.apply("zero", []).value]).scalar <= 0 and campaign.state not in ["menu", "retreat", "departing"]:
		_begin_death_retreat()
	return {"ok": true}

func _refresh_growth() -> bool:
	Economy.prune_income(income_samples, wall_time, game_time, float(rules.research_income_window))
	var automatic_due: bool = research_progress.auto_invest and float(research_progress.refresh_elapsed) >= float(rules.research_income_window) and not Crew.assigned(crew_progress, "system_job", "hightech_scientists").is_empty()
	var peaks: Dictionary = {}
	var investment: Dictionary = {}
	if income_dirty:
		var query = Economy.income_rates(income_samples, wall_time, game_time, float(rules.research_income_window), "peak", amount_api)
		if not query.ok:
			_fail(str(query.get("error", "IncomeQueryFailed")))
			return false
		peaks = query.rates
	if automatic_due:
		var query = Economy.income_rates(income_samples, wall_time, game_time, float(rules.research_income_window), "investment", amount_api)
		if not query.ok:
			_fail(str(query.get("error", "IncomeQueryFailed")))
			return false
		investment = query.rates
	var refreshed = Research.refresh_income(research_progress, peaks, investment, rules, amount_api, income_dirty, automatic_due)
	if not refreshed.ok:
		_fail(str(refreshed.get("error", "ResearchIncomeFailed")))
		return false
	combat_config_dirty = combat_config_dirty or refreshed.state.peaks != research_progress.peaks
	research_progress = refreshed.state
	income_dirty = false
	if combat_config_dirty:
		var changed = _commit_growth(slots, enhancement_progress, reactor_progress, research_progress, wallet, "growth")
		if not changed.ok:
			_fail(str(changed.get("error", changed.get("reason", "GrowthUpdateFailed"))))
			return false
	return true

func buy_levels(slot_id: String, count: int) -> Dictionary:
	var index: int = -1
	for candidate in slots.size():
		if slots[candidate].id == slot_id:
			index = candidate
	if index < 0:
		return {"ok": false, "reason": "UnknownSlot"}
	var slot: Dictionary = slots[index]
	var row: Dictionary = equipment_definitions.laser if slot.category == "weapon" else equipment_definitions.armour
	var quote = Equipment.quote_levels(row, int(slot.paid_level), count, evolution, int(campaign.highest_reached) >= int(rules.hyperspace_unlock_reached), amount_api)
	if not quote.ok:
		return quote
	var paid = Economy.payment(wallet, quote.costs, amount_api)
	if not paid.ok:
		return paid
	var next: Array = slots.duplicate(true)
	next[index].paid_level = int(slot.paid_level) + count
	return _commit_growth(next, enhancement_progress, reactor_progress, research_progress, paid.wallet, "upgrade")

func buy_reactor(count: int = 1) -> Dictionary:
	if not unlocked("feature", "reactor"):
		return {"ok": false, "reason": "ReactorLocked"}
	var quote = Reactor.quote(reactor_progress, count, parameters, amount_api)
	if not quote.ok:
		return quote
	if int(reactor_progress.level) > 9223372036854775807 - count:
		return {"ok": false, "reason": "ReactorLevelRangeExceeded"}
	var paid = Economy.payment(wallet, quote.costs, amount_api)
	if not paid.ok:
		return paid
	var next: Dictionary = reactor_progress.duplicate(true)
	next.level = int(next.level) + count
	return _commit_growth(slots, enhancement_progress, next, research_progress, paid.wallet, "growth")

func buy_enhancement(count: int = 1) -> Dictionary:
	if not unlocked("feature", "jewels"):
		return {"ok": false, "reason": "EnhancementLocked"}
	if count < 1 or int(enhancement_progress.level) > 9223372036854775807 - count:
		return {"ok": false, "reason": "EnhancementLevelRangeExceeded"}
	var quote = Enhancement.quote(enhancement_progress, count, enhancement, amount_api)
	if not quote.ok:
		return quote
	var paid = Economy.payment(wallet, quote.costs, amount_api)
	if not paid.ok:
		var low: int = 0
		var high: int = count
		while low < high:
			@warning_ignore("integer_division")
			var middle: int = low + (high - low) / 2 + 1
			var candidate = Enhancement.quote(enhancement_progress, middle, enhancement, amount_api)
			if candidate.ok and Economy.payment(wallet, candidate.costs, amount_api).ok:
				low = middle
			else:
				high = middle - 1
		if low == 0:
			return {"ok": false, "reason": "NoChange"}
		count = low
		quote = Enhancement.quote(enhancement_progress, count, enhancement, amount_api)
		paid = Economy.payment(wallet, quote.costs, amount_api)
	var next: Dictionary = enhancement_progress.duplicate(true)
	next.level = int(next.level) + count
	return _commit_growth(slots, next, reactor_progress, research_progress, paid.wallet, "growth")

func set_enhancement_order(category: String, order: Array) -> Dictionary:
	var changed = Enhancement.reorder(enhancement_progress, category, order)
	if not changed.ok:
		return changed
	return _commit_growth(slots, changed.state, reactor_progress, research_progress, wallet, "selection")

func set_enhancement_branch(effect: String, node: int, choice: String) -> Dictionary:
	var changed = Enhancement.choose(enhancement_progress, effect, node, choice, enhancement, unlocked("feature", "jewels"))
	if not changed.ok:
		return changed
	return _commit_growth(slots, changed.state, reactor_progress, research_progress, wallet, "selection")

func allocate_reactor(module: String, quantity: Dictionary) -> Dictionary:
	var world = _world_contributions()
	if not world.ok:
		return world
	var changed = Reactor.allocate(reactor_progress, module, quantity, parameters, _reactor_modules(), amount_api, world.capacity, world.free_charge)
	if not changed.ok:
		return changed
	return _commit_growth(slots, enhancement_progress, changed.state, research_progress, wallet, "selection")

func distribute_reactor() -> Dictionary:
	var world = _world_contributions()
	if not world.ok:
		return world
	var changed = Reactor.distribute(reactor_progress, parameters, _reactor_modules(), amount_api, world.capacity, world.free_charge)
	if not changed.ok:
		return changed
	return _commit_growth(slots, enhancement_progress, changed.state, research_progress, wallet, "selection")

func select_research(id: String) -> Dictionary:
	if not research_definitions.has(id) or not Research.available(research_definitions[id], research_progress.levels, _research_gates()):
		return {"ok": false, "reason": "ResearchLocked"}
	research_progress.current = id
	return {"ok": true}

func set_research_investment(resource: String, quantity: Dictionary) -> Dictionary:
	if resource not in ["1", "2"]:
		return {"ok": false, "reason": "InvalidResearchResource"}
	var value = amount_api.apply("floor", [quantity])
	if not value.ok:
		return value
	research_progress.investment[resource] = value.value
	return {"ok": true}

func set_research_automatic_investment(enabled: bool, ratio: float) -> Dictionary:
	if not is_finite(ratio) or ratio < float(rules.research_minimum_ratio) or ratio > 1.0:
		return {"ok": false, "reason": "InvalidResearchRatio"}
	research_progress.auto_invest = enabled
	research_progress.ratio = ratio
	return {"ok": true}

func equip_slot(slot_id: String, equipment_id: String) -> Dictionary:
	var index: int = -1
	for candidate in slots.size():
		if slots[candidate].id == slot_id:
			index = candidate
	if index < 0:
		return {"ok": false, "reason": "UnknownSlot"}
	var slot: Dictionary = slots[index]
	if equipment_id == str(slot.equipment_id):
		return {"ok": false, "reason": "NoChange"}
	if game_time < float(slot.switch_ready_at):
		return {"ok": false, "reason": "EquipmentSwitchLocked"}
	if not equipment_id.is_empty():
		if not equipment_definitions.has(equipment_id) or not unlocked("equipment", equipment_id):
			return {"ok": false, "reason": "EquipmentLocked"}
		if (slot.category == "weapon" and not CombatSetup.KINDS.has(equipment_id)) or (slot.category == "defence" and equipment_id not in ["armour", "shield"]):
			return {"ok": false, "reason": "EquipmentCategoryMismatch"}
	if int(slot.generation) == 9223372036854775807:
		return {"ok": false, "reason": "ModuleGenerationRangeExceeded"}
	var next: Array = slots.duplicate(true)
	next[index].equipment_id = equipment_id
	next[index].generation = int(slot.generation) + 1
	next[index].switch_ready_at = game_time + float(parameters.equipmentSwitchCooldownSeconds)
	return _commit_growth(next, enhancement_progress, reactor_progress, research_progress, wallet, "refit")

func quote_levels(slot_id: String, count: int) -> Dictionary:
	for slot in slots:
		if str(slot.id) == slot_id:
			var row: Dictionary = equipment_definitions.laser if slot.category == "weapon" else equipment_definitions.armour
			return Equipment.quote_levels(row, int(slot.paid_level), count, evolution, int(campaign.highest_reached) >= int(rules.hyperspace_unlock_reached), amount_api)
	return {"ok": false, "reason": "UnknownSlot"}

func buy_max_levels(slot_id: String) -> Dictionary:
	var level: int = -1
	for slot in slots:
		if str(slot.id) == slot_id:
			level = int(slot.paid_level)
	if level < 0:
		return {"ok": false, "reason": "UnknownSlot"}
	var limit: int = 9223372036854775807 - level
	if limit <= 0:
		return {"ok": false, "reason": "EquipmentLevelRangeExceeded"}
	var low: int = 0
	var high: int = 1
	while high <= limit:
		var quote = quote_levels(slot_id, high)
		if not quote.ok or not Economy.payment(wallet, quote.costs, amount_api).ok:
			break
		low = high
		if high == limit:
			return {"ok": false, "reason": "EquipmentLevelRangeExceeded"}
		high = limit if high > limit / 2 else high * 2
	while low + 1 < high:
		@warning_ignore("integer_division")
		var middle: int = low + (high - low) / 2
		var quote = quote_levels(slot_id, middle)
		if quote.ok and Economy.payment(wallet, quote.costs, amount_api).ok:
			low = middle
		else:
			high = middle
	if low == 0:
		return {"ok": false, "reason": "NoChange"}
	return buy_levels(slot_id, low)

func buy_all_levels(count: int) -> Dictionary:
	var purchased: Array = []
	var ship: Dictionary = ship_definitions[selected_ship]
	for category in ["weapon", "defence"]:
		for slot in slots:
			if slot.category != category or int(slot.index) >= int(ship.para_1 if category == "weapon" else ship.para_2):
				continue
			var result = buy_levels(str(slot.id), count)
			if result.ok:
				purchased.append(str(slot.id))
			elif result.get("reason", "") not in ["InsufficientResources", "EvolutionMaterialLocked"]:
				return result
	return {"ok": not purchased.is_empty(), "reason": "NoChange" if purchased.is_empty() else "", "slots": purchased}

func _clear_switch_locks() -> void:
	for slot in slots:
		slot.switch_ready_at = 0.0

func change_ship(ship_id: String) -> Dictionary:
	if ship_id == selected_ship:
		return {"ok": false, "reason": "NoChange"}
	if not ship_definitions.has(ship_id) or not unlocked("ship", ship_id):
		return {"ok": false, "reason": "ShipLocked"}
	var current: Dictionary = ship_definitions[selected_ship]
	var target: Dictionary = ship_definitions[ship_id]
	var next: Array = slots.duplicate(true)
	for category in ["weapon", "defence"]:
		var old_count: int = int(current.para_1 if category == "weapon" else current.para_2)
		var new_count: int = int(target.para_1 if category == "weapon" else target.para_2)
		for index in maxi(old_count, new_count):
			var id: String = category + ":" + str(index)
			var found: bool = false
			for slot in next:
				if slot.id != id:
					continue
				found = true
				if (index < old_count) != (index < new_count):
					if int(slot.generation) == 9223372036854775807:
						return {"ok": false, "reason": "ModuleGenerationRangeExceeded"}
					slot.generation = int(slot.generation) + 1
			if not found:
				next.append({"id": id, "category": category, "index": index, "equipment_id": "",
					"paid_level": 1, "extra_levels": 0, "generation": 1, "switch_ready_at": 0.0})
	return _commit_growth(next, enhancement_progress, reactor_progress, research_progress, wallet, "refit", ship_id)

func set_equipped_drone_contributions(contributions: Array) -> Dictionary:
	# These are assembled contributions from actual equipped entities, not a
	# warehouse, item generator, reward path or second owner of drone progress.
	if contributions.size() > int(ship_definitions[selected_ship].para_5):
		return {"ok": false, "reason": "DroneCapacityExceeded"}
	for contribution in contributions:
		if not contribution is Dictionary or not contribution.get("id") is String or str(contribution.id).is_empty() or not contribution.has("generation") or not contribution.get("weapon") is Dictionary or not contribution.weapon.get("entry") is Dictionary:
			return {"ok": false, "reason": "InvalidDroneContribution"}
	return _commit_growth(slots, enhancement_progress, reactor_progress, research_progress, wallet, "refit", "", contributions)

func equipment_label(id: String) -> String:
	if id.is_empty():
		return "空槽"
	for row in configuration.unlock.unlock:
		if row.type == "equipment" and str(row.target) == id:
			return str(row.title)
	return id

func _begin_death_retreat() -> void:
	retreat_from = _global_position()
	retreat_to = maxf(0.0, retreat_from - float(parameters.backRange))
	retreat_elapsed = 0.0
	if int(guard.death_option) == 0:
		guard.enabled = false
	_clear_switch_locks()
	kernel.begin_retreat()
	campaign.state = "retreat"

func _world_contributions() -> Dictionary:
	var planet = Planet.factors(planet_progress, planet_buildings, amount_api)
	if not planet.ok:
		return planet
	var galaxy = Galaxy.factors(galaxy_progress, galaxy_buildings, amount_api)
	if not galaxy.ok:
		return galaxy
	var equipment = Crew.job_factor(crew_progress, crew_definitions, crew_jobs, "equipment_upgrade", crew_rules, amount_api)
	var capacity = Crew.job_factor(crew_progress, crew_definitions, crew_jobs, "reactor_upgrade", crew_rules, amount_api)
	var fragments = Crew.job_factor(crew_progress, crew_definitions, crew_jobs, "jewel_auto", crew_rules, amount_api)
	var research = Crew.job_factor(crew_progress, crew_definitions, crew_jobs, "hightech_scientists", crew_rules, amount_api)
	for result in [equipment, capacity, fragments, research]:
		if not result.ok:
			return result
	var external: Array = []
	for value in [planet.equipment, equipment.value, galaxy["values"].equipment_value]:
		var text = amount_api.apply("to_display", [value])
		if not text.ok:
			return text
		external.append(text.text)
	capacity = amount_api.apply("mul", [capacity.value, galaxy["values"].charge_max])
	if not capacity.ok:
		return capacity
	return {"ok": true, "external": external, "capacity": capacity.value, "fragments": fragments.value,
		"galaxy_fragments": galaxy["values"].gem_fragment, "crew_experience": galaxy["values"].crew_exp,
		"research": research.value, "refinery": planet.refinery,
		"equipment_levels": int(Planet.buff(planet_progress, planet_buffs, "level_bonus", "equipment")),
		"enhancement_levels": int(Planet.buff(planet_progress, planet_buffs, "level_bonus", "enhancement")),
		"free_charge": Planet.buff(planet_progress, planet_buffs, "free_charge", "all")}

func _commit_world() -> Dictionary:
	var result = _commit_growth(slots, enhancement_progress, reactor_progress, research_progress, wallet, "refit")
	if not result.ok and last_error.is_empty():
		return _fail(str(result.get("error", result.get("reason", "WorldGrowthUpdateFailed"))))
	return result

func _personnel_view(kind: String) -> Dictionary:
	var view: Dictionary = {}
	for id in crew_progress:
		var member: Dictionary = crew_progress[id]
		if member.kind != kind:
			continue
		if not view.has(member.target):
			view[member.target] = []
		view[member.target].append(id)
	for target in view:
		view[target].sort()
	return view

func planet_unlocked(id: String) -> bool:
	return planet_definitions.has(id) and unlocked("planet", id) and (int(id) == 1 or Planet.buff(planet_progress, planet_buffs, "planet_unlock", "planet") >= int(id))

func assign_crew(id: String, kind: String, target: String, mode: String = "1") -> Dictionary:
	if not crew_progress.has(id) or not unlocked("crew", id):
		return {"ok": false, "reason": "CrewLocked"}
	var capacity: int = 0
	if kind == "system_job":
		if not crew_jobs.has(target) or crew_jobs[target].targetType == "galaxy":
			return {"ok": false, "reason": "UnknownCrewJob"}
		if (target == "jewel_auto" and not unlocked("feature", "jewels")) or (target == "reactor_upgrade" and not unlocked("feature", "reactor")):
			return {"ok": false, "reason": "CrewJobLocked"}
		capacity = int(crew_jobs[target].maxCrew)
	elif kind == "planet_explore":
		if not planet_unlocked(target):
			return {"ok": false, "reason": "PlanetLocked"}
		capacity = 1
	elif kind == "planet_build":
		var parts: PackedStringArray = target.split(":")
		if parts.size() != 2 or not planet_unlocked(parts[0]) or not planet_progress[parts[0]].buildings.has(parts[1]):
			return {"ok": false, "reason": "PlanetBuildingUnavailable"}
		if planet_progress[parts[0]].buildings[parts[1]].state != "building":
			return {"ok": false, "reason": "PlanetBuildingUnavailable"}
		capacity = int(planet_buildings[parts[1]].extra_crew)
	elif kind == "galaxy":
		if not galaxy_unlocked(target):
			return {"ok": false, "reason": "GalaxyUnavailable"}
		capacity = int(crew_jobs.galaxy_explore.maxCrew)
	elif not kind.is_empty():
		return {"ok": false, "reason": "CrewAssignmentUnavailable"}
	var old_kind: String = str(crew_progress[id].kind)
	var old_target: String = str(crew_progress[id].target)
	if old_kind == "hyperspace":
		return {"ok": false, "reason": "HyperspaceCrewReserved"}
	var selected_mode: String = mode if kind == "system_job" and target == "equipment_upgrade" else str(crew_progress[id].mode)
	var changed = Crew.assign(crew_progress, id, kind, target if not kind.is_empty() else "", capacity, selected_mode)
	if not changed.ok:
		return changed
	if old_kind == "planet_explore" and (kind != old_kind or target != old_target):
		Planet.cancel(planet_progress[old_target])
	if kind == "planet_explore" and not planet_progress[target].running:
		var started = Planet.start(planet_progress[target], planet_definitions[target])
		if not started.ok:
			return _fail(str(started.reason))
	return _commit_world() if old_kind != kind or old_target != target else {"ok": true}

func cancel_planet(id: String) -> Dictionary:
	if not planet_progress.has(id):
		return {"ok": false, "reason": "UnknownPlanet"}
	Planet.cancel(planet_progress[id])
	Crew.release(crew_progress, "planet_explore", id)
	return _commit_world()

func set_planet_automatic(id: String, enabled: bool) -> Dictionary:
	if not planet_unlocked(id):
		return {"ok": false, "reason": "PlanetLocked"}
	return Planet.set_automatic(planet_progress[id], enabled)

func claim_planet_build(id: String, building: String) -> Dictionary:
	if not planet_unlocked(id):
		return {"ok": false, "reason": "PlanetLocked"}
	var result = Planet.claim_build(planet_progress[id], building)
	return _commit_world() if result.ok else result

func _advance_planets(dt: float) -> bool:
	var result = Planet.advance(planet_progress, planet_definitions, planet_buildings,
		_personnel_view("planet_explore"), _personnel_view("planet_build"), dt)
	if not result.ok:
		_fail(str(result.get("reason", "PlanetAdvanceFailed")))
		return false
	for completion in result.completed:
		for target in completion.released:
			Crew.release(crew_progress, "planet_build", str(target))
		var id: String = str(completion.planet)
		if unlocked("feature", "crew_level"):
			var recipients: Array = crew_progress.keys() if Planet.buff(planet_progress, planet_buffs, "crew_exp_share", "all", id) > 0 else [completion.explorer]
			var level: int = maxi(int(campaign.highest_reached), int(campaign.lifetime_highest_reached))
			var experience = Planet.experience_reward(planet_definitions[id], level_definitions[level].planetExpRatio, galaxy_crew_experience, amount_api)
			if not experience.ok:
				_fail(str(experience.error))
				return false
			var awarded = Crew.add_experience(crew_progress, recipients, experience.value, crew_rules, amount_api)
			if not awarded.ok:
				_fail(str(awarded.get("error", awarded.get("reason", "CrewExperienceFailed"))))
				return false
		if not completion.again:
			Crew.release(crew_progress, "planet_explore", id)
	if not result.completed.is_empty() and not _commit_world().ok:
		return false
	return true

func _advance_crew_jobs(dt: float) -> bool:
	for attempt in Crew.advance_jobs(crew_progress, crew_jobs, dt):
		if attempt.job == "equipment_upgrade":
			if attempt.mode != "max":
				buy_all_levels(int(attempt.mode))
			else:
				var ship: Dictionary = ship_definitions[selected_ship]
				for category in ["weapon", "defence"]:
					for slot in slots:
						if slot.category == category and int(slot.index) < int(ship.para_1 if category == "weapon" else ship.para_2):
							buy_max_levels(str(slot.id))
							if not last_error.is_empty(): return false
		elif attempt.job == "jewel_auto":
			buy_enhancement(1)
		elif attempt.job == "reactor_upgrade":
			var purchase = buy_reactor(1)
			if not last_error.is_empty(): return false
			if purchase.ok:
				distribute_reactor()
		if not last_error.is_empty(): return false
	return true

func galaxy_unlocked(key: String) -> bool:
	if not galaxy_progress.has(key) or not galaxy_definitions.has(key):
		return false
	if galaxy_progress[key].get("unlocked", false):
		return true
	var row: Dictionary = galaxy_definitions[key]
	return unlocked("feature", "galaxy") and row.unlock_type == "stage_cleared" and campaign.cleared_stages.has(int(row.unlock_value))

func _advance_galaxies(dt: float) -> bool:
	Economy.prune_income(income_samples, wall_time, game_time, float(rules.research_income_window))
	var personnel: Dictionary = _personnel_view("galaxy")
	var counts: Dictionary = {}
	var enabled: Dictionary = {}
	for key in galaxy_progress:
		counts[key] = personnel.get(key, []).size()
		enabled[key] = galaxy_unlocked(key)
		if enabled[key]: galaxy_progress[key].unlocked = true
	var result = Galaxy.advance(galaxy_progress, galaxy_definitions, galaxy_buildings, counts, enabled, dt, float(galaxy_rules.income_interval))
	if not result.ok:
		_fail(str(result.get("reason", "GalaxyAdvanceFailed")))
		return false
	if result.changed and not _commit_world().ok:
		return false
	if not result.payments.is_empty():
		var production = Economy.income_rates(income_samples, wall_time, game_time, float(rules.research_income_window), "production", amount_api)
		if not production.ok:
			_fail(str(production.get("error", "ProductionQueryFailed")))
			return false
		for payment in result.payments:
			var region: Dictionary = {payment.galaxy: galaxy_progress[payment.galaxy]}
			var income = Galaxy.income(region, galaxy_buildings, production.rates, float(payment.seconds), amount_api)
			if not income.ok:
				_fail(str(income.get("error", "GalaxyIncomeFailed")))
				return false
			for resource in income.amounts:
				var credited = Economy.credit_yield(wallet, income_samples, str(resource), income.amounts[resource], wall_time, game_time, amount_api)
				if not credited.ok:
					_fail(str(credited.get("error", "GalaxyCreditFailed")))
					return false
	return true
