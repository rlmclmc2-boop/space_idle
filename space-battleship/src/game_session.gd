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

var display_changes: Dictionary = {}
var kernel
var amount_api
var configuration: Dictionary = {}
var parameters: Dictionary = {}
var rules: Dictionary = {}
var geometry: Dictionary = {}
var evolution: Dictionary = {}
var enhancement
var reactor_system
var research
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
var world_factors: Dictionary = {}
var planet_factors: Dictionary = {}
var crew_factors: Dictionary = {}
var galaxy_factors: Dictionary = {}
var research_factors: Dictionary = {}
var reactor_factors: Dictionary = {}
var combat_values: Dictionary = {}
var equipped_drones: Array = []
var legendary_definitions: Dictionary = {}
var legendary_constants: Dictionary = {}
var legendary_ranges: Dictionary = {}
var drone_limits: Dictionary = {}
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
var enemy_muzzles: Dictionary = {}
var selected_ship: String = ""
var slots: Array = []
var seed_value: int = 1
var next_enemy_uid: int = 0
var campaign: Dictionary = {"state": "menu", "stage": 1, "distance": 0.0,
	"point": 0, "points": [], "highest_reached": 1,
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

func _display_changed(kind: String, id: String = "") -> void:
	if not display_changes.has(kind): display_changes[kind] = {}
	display_changes[kind][id] = true

func take_display_changes() -> Dictionary:
	var changed: Dictionary = display_changes
	display_changes = {}
	return changed

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
		var logical_path: String = str(art.get("geometry_texture", art.texture))
		var logical_image := image if logical_path == str(art.texture) else Image.load_from_file(logical_path)
		if logical_image == null or logical_image.is_empty():
			return _fail("MissingGeometryAsset:" + str(key))
		models[key] = {"hull": Geometry.normalized_hull(image), "size": Vector2(image.get_size()), "art": art,
			"geometry_height": float(logical_image.get_height())}
	player_geometry_height = float(models[selected_ship].geometry_height)
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
	amount_api = ClassDB.instantiate("FoundationAmount")
	reactor_system = Reactor.new(parameters, amount_api)
	enhancement = Enhancement.new(configuration.enhance_config.enhance_config, amount_api)
	research = Research.new(configuration.ai_tech_tree.ai_tech_tree, rules, configuration.unlock.unlock, amount_api)
	research.refresh_progress(int(campaign.highest_reached), campaign.cleared_stages)
	crew_progress = Crew.initial(crew_definitions, amount_api)
	planet_progress = Planet.initial(planet_definitions, planet_buildings)
	var galaxies = Galaxy.initial(galaxy_definitions)
	if not galaxies.ok:
		return _fail(str(galaxies.reason))
	galaxy_progress = galaxies.regions
	kernel = ClassDB.instantiate("SpaceCombatKernel")
	planet_factors = Planet.contributions(planet_progress, planet_buildings, planet_buffs, amount_api)
	crew_factors = Crew.contributions(crew_progress, crew_definitions, crew_jobs, crew_rules, amount_api)
	galaxy_factors = Galaxy.contributions(galaxy_progress, galaxy_buildings, amount_api)
	world_factors = _world_contributions()
	if not world_factors.ok: return _fail(str(world_factors.get("error", "WorldAssemblyFailed")))
	var setup = _growth_setup(slots)
	if not setup.ok:
		return _fail(str(setup.get("error", setup.get("reason", "EquipmentAssemblyFailed"))))
	for row in setup.descriptor.weapons:
		player_muzzles[str(row.entry.id)] = row.muzzle
	reactor_system.accept(setup.reactor_update)
	reactor_factors = setup.reactor_factors
	research_factors = setup.research_factors
	enhancement.accept_output(setup.enhancement_values)
	combat_values = setup["values"]
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
	Economy.prune_income(income_samples, wall_time, game_time, research.income_window())
	var people: Dictionary = Crew.step_assignments(crew_progress)
	if not _advance_planets(dt, people.explorers, people.builders) or not _advance_galaxies(dt, people.galaxies) or not _advance_crew_jobs(dt, people.jobs):
		return
	if not _advance_timed_resources(dt):
		return
	var researched = research.advance(wallet, dt, research_speed, crew_factors.research_staffed)
	if not researched.ok:
		_fail(str(researched.get("error", researched.get("reason", "ResearchFailed"))))
		return
	wallet = researched.wallet
	if researched.completed:
		_display_changed("research")
		# Publish completion effects before collection; income-window/automatic
		# investment refresh still happens once, after this step's collections.
		var changed = _publish_research()
		if not changed.ok:
			_fail(str(changed.get("error", changed.get("reason", "ResearchGrowthUpdateFailed"))))
			return
	if researched.has("continuation_error"):
		_fail(str(researched.continuation_error))
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
			if not campaign.cleared_stages.has(int(campaign.stage)):
				campaign.cleared_stages[int(campaign.stage)] = true
				research.refresh_progress(int(campaign.highest_reached), campaign.cleared_stages)
				_display_changed("unlocks")
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
	enemy_muzzles = setup.muzzles
	campaign.state = "combat"
	_sync_geometry()

func _sync_geometry() -> void:
	var packet = Geometry.battle_geometry(kernel.enemy_views(), models, selected_ship, player_art,
		player_dimensions, player_geometry_height, player_muzzles, enemy_muzzles, geometry, parameters)
	enemy_hulls = packet.hulls
	kernel.input_geometry(packet.points, packet.muzzles)
	kernel.input_ballistic_geometry(packet.hulls, packet.points, packet.muzzles, packet.stationary)
	kernel.input_player_point(packet.player_point)
	if not kernel.input_player_hull(packet.player_hull):
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
	if stage > int(campaign.highest_reached):
		campaign.highest_reached = stage
		research.refresh_progress(int(campaign.highest_reached), campaign.cleared_stages)
		_display_changed("unlocks")
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

func reactor_inputs() -> Dictionary:
	return {"available": unlocked("feature", "reactor"), "condensation": unlocked("reactor_module", "condensation"),
		"capacity": world_factors.capacity, "free_charge": world_factors.free_charge}

func _active_slots(source: Array, ship: Dictionary) -> Array:
	return source.filter(func(slot): return int(slot.index) < int(ship.para_1 if slot.category == "weapon" else ship.para_2))

func _growth_setup(next_slots: Array, next_ship: String = "", contributions = null) -> Dictionary:
	var ship_key: String = selected_ship if next_ship.is_empty() else next_ship
	var ship: Dictionary = ship_definitions[ship_key]
	var art: Dictionary = models[ship_key].art
	var dimensions: Vector2 = models[ship_key].size * float(art.display_scale) * float(geometry.player_display_multiplier) * float(parameters["playerVisualScale" + ship_key])
	var world = world_factors
	if not world.ok:
		return world
	var enabled_slots: Array = _active_slots(next_slots, ship)
	var source_drones: Array = equipped_drones if contributions == null else contributions
	var next_drones: Array = source_drones.slice(0, int(ship.para_5)).duplicate(true)
	var reactor = reactor_system.prepare(reactor_inputs())
	if not reactor.ok:
		return reactor
	var ai = research.contributions()
	if not ai.ok: return ai
	var factors := {"ai_weapon": ai["values"].weapon_damage, "ai_defence": ai["values"].equipment_durability,
		"reactor_weapon": reactor.factors.weapons, "reactor_defence": reactor.factors.defence, "external": world.external}
	var upgrades = enhancement.evaluate(int(world.enhancement_levels), unlocked("feature", "jewels"), Equipment.armour_count(enabled_slots))
	if not upgrades.ok: return upgrades
	var drone_weapons: Array = []
	for index in next_drones.size():
		var contribution: Dictionary = next_drones[index]
		var weapon_row: Dictionary = contribution.weapon.duplicate(true)
		weapon_row.entry.id = "drone:" + str(contribution.id)
		weapon_row.entry.drone_id = str(contribution.id)
		weapon_row.entry.generation = int(contribution.generation)
		weapon_row.slot = int(ship.para_1) + index
		drone_weapons.append(weapon_row)
	var setup = CombatSetup.build_player(enabled_slots, int(world.equipment_levels), equipment_definitions, evolution, amount_api,
		art, dimensions, geometry, rules, float(parameters.dmgReduce), motion, upgrades, factors, drone_weapons, seed_value)
	if not setup.ok:
		return setup
	setup.income_factors = {"condensation": reactor.factors.condensation, "refinery": world.refinery, "crew_fragments": world.fragments, "galaxy_fragments": world.galaxy_fragments}
	setup.research_speed = world.research
	setup.galaxy_crew_experience = world.crew_experience
	setup.income_factors.iron = ai["values"].iron_income
	setup.income_factors.uranium = ai["values"].uranium_income
	setup.income_factors.jewel = ai["values"].fragment_income
	setup.research_factors = ai["values"]
	setup.reactor_factors = reactor.factors
	var iron_text = amount_api.apply("to_display", [reactor.factors.smelting])
	if not iron_text.ok:
		return iron_text
	setup.descriptor.iron_drop_factor = iron_text.text
	setup.enhancement_values = upgrades
	setup.reactor_update = reactor
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

func _commit_growth(next_slots: Array,
		next_wallet: Dictionary, change_kind: String, next_ship: String = "", contributions = null) -> Dictionary:
	var geometry_changed: bool = (not next_ship.is_empty() and next_ship != selected_ship) or contributions != null
	if not geometry_changed:
		for index in next_slots.size():
			if index >= slots.size() or next_slots[index].equipment_id != slots[index].equipment_id:
				geometry_changed = true
				break
	var setup = _growth_setup(next_slots, next_ship, contributions)
	if not setup.ok:
		return setup
	# No page callbacks or asynchronous work can interleave this commit.
	var committed: Dictionary = kernel.set_player_configuration(setup.descriptor, change_kind)
	if not committed.ok:
		if committed.fault:
			return _fail(str(committed.reason))
		return committed
	if geometry_changed: _display_changed("loadout")
	slots = next_slots
	selected_ship = setup.ship_key
	player_art = setup.player_art
	player_dimensions = setup.player_dimensions
	player_geometry_height = float(models[selected_ship].geometry_height)
	equipped_drones = setup.equipped_drones
	reactor_system.accept(setup.reactor_update)
	reactor_factors = setup.reactor_factors
	research_factors = setup.research_factors
	enhancement.accept_output(setup.enhancement_values)
	combat_values = setup["values"]
	income_factors = setup.income_factors
	research_speed = setup.research_speed
	galaxy_crew_experience = setup.galaxy_crew_experience
	wallet = next_wallet
	player_muzzles = {}
	for row in setup.descriptor.weapons:
		player_muzzles[str(row.entry.id)] = row.muzzle
	if geometry_changed:
		_sync_geometry()
	_retreat_if_dead()
	return {"ok": true}

func _refresh_growth() -> bool:
	var reactor_context: Dictionary = reactor_inputs()
	if reactor_system.modules_changed(reactor_context):
		var updated = reactor_system.refresh(reactor_context, publish_reactor)
		if not updated.ok:
			_fail(str(updated.get("error", updated.get("reason", "ReactorUpdateFailed"))))
			return false
	var automatic_due: bool = research.automatic_due(crew_factors.research_staffed)
	var peaks: Dictionary = {}
	var investment: Dictionary = {}
	if income_dirty:
		var query = Economy.income_rates(income_samples, wall_time, game_time, research.income_window(), "peak", amount_api)
		if not query.ok:
			_fail(str(query.get("error", "IncomeQueryFailed")))
			return false
		peaks = query.rates
	if automatic_due:
		var query = Economy.income_rates(income_samples, wall_time, game_time, research.income_window(), "investment", amount_api)
		if not query.ok:
			_fail(str(query.get("error", "IncomeQueryFailed")))
			return false
		investment = query.rates
	var refreshed = research.refresh_income(peaks, investment, income_dirty, automatic_due)
	if not refreshed.ok:
		_fail(str(refreshed.get("error", "ResearchIncomeFailed")))
		return false
	var factors_changed: bool = refreshed.factors_changed
	income_dirty = false
	if factors_changed:
		var changed = _publish_research()
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
	return _buy_quoted_levels(index, quote)

func _buy_quoted_levels(index: int, quote: Dictionary) -> Dictionary:
	if not quote.ok: return quote
	var paid = Economy.payment(wallet, quote.costs, amount_api)
	if not paid.ok: return paid
	var next: Array = slots.duplicate(true)
	next[index].paid_level = int(slots[index].paid_level) + int(quote.count)
	return _commit_levels(next, paid.wallet, [next[index]])

# World/equipment availability and payment/native publication are the cross-module ports.
func enhancement_inputs() -> Dictionary:
	return {"bonus": int(world_factors.enhancement_levels), "available": unlocked("feature", "jewels"),
		"armours": Equipment.armour_count(_active_slots(slots, ship_definitions[selected_ship]))}

func can_pay_costs(costs: Dictionary) -> bool:
	return Economy.can_pay(wallet, costs, amount_api).ok

func publish_enhancement(changed: Dictionary, costs: Dictionary, kind: String) -> Dictionary:
	var paid = Economy.payment(wallet, costs, amount_api)
	if not paid.ok: return paid
	var result = _commit_values({"weapons": {}, "defences": {}}, kind, "", changed)
	if result.ok: wallet = paid.wallet
	return result

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
	return _commit_growth(next, wallet, "refit")

func quote_levels(slot_id: String, count: int) -> Dictionary:
	for slot in slots:
		if str(slot.id) == slot_id:
			var row: Dictionary = equipment_definitions.laser if slot.category == "weapon" else equipment_definitions.armour
			return Equipment.quote_levels(row, int(slot.paid_level), count, evolution, int(campaign.highest_reached) >= int(rules.hyperspace_unlock_reached), amount_api)
	return {"ok": false, "reason": "UnknownSlot"}

func buy_max_levels(slot_id: String) -> Dictionary:
	for index in slots.size():
		if str(slots[index].id) == slot_id:
			return _buy_quoted_levels(index, Equipment.quote_affordable_levels(
				equipment_definitions.laser if slots[index].category == "weapon" else equipment_definitions.armour,
				int(slots[index].paid_level), evolution, int(campaign.highest_reached) >= int(rules.hyperspace_unlock_reached),
				amount_api, func(costs): return Economy.can_pay(wallet, costs, amount_api).ok))
	return {"ok": false, "reason": "UnknownSlot"}

func buy_all_levels(count: int, maximum: bool = false) -> Dictionary:
	var purchased: Array = []
	var changed: Array = []
	var next: Array = slots.duplicate(true)
	var balances: Dictionary = wallet
	var failure: Dictionary = {}
	var ship: Dictionary = ship_definitions[selected_ship]
	var material_unlocked: bool = int(campaign.highest_reached) >= int(rules.hyperspace_unlock_reached)
	for category in ["weapon", "defence"]:
		for slot in next:
			if slot.category != category or int(slot.index) >= int(ship.para_1 if category == "weapon" else ship.para_2):
				continue
			var row: Dictionary = equipment_definitions.laser if category == "weapon" else equipment_definitions.armour
			var quote = Equipment.quote_affordable_levels(row, int(slot.paid_level), evolution, material_unlocked, amount_api,
				func(costs): return Economy.can_pay(balances, costs, amount_api).ok) if maximum else Equipment.quote_levels(row, int(slot.paid_level), count, evolution, material_unlocked, amount_api)
			var paid = Economy.payment(balances, quote.costs, amount_api) if quote.ok else quote
			if paid.ok:
				balances = paid.wallet
				slot.paid_level = int(slot.paid_level) + int(quote.count)
				purchased.append(str(slot.id))
				changed.append(slot)
			elif not maximum and paid.get("reason", "") not in ["InsufficientResources", "EvolutionMaterialLocked"]:
				failure = paid
				break
		if not failure.is_empty(): break
	if not purchased.is_empty():
		var committed = _commit_levels(next, balances, changed)
		if not committed.ok: return committed
	if not failure.is_empty(): return failure
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
	return _commit_growth(next, wallet, "refit", ship_id)

func set_equipped_drone_contributions(contributions: Array) -> Dictionary:
	# These are assembled contributions from actual equipped entities, not a
	# warehouse, item generator, reward path or second owner of drone progress.
	if contributions.size() > int(ship_definitions[selected_ship].para_5):
		return {"ok": false, "reason": "DroneCapacityExceeded"}
	for contribution in contributions:
		if not contribution is Dictionary or not contribution.get("id") is String or str(contribution.id).is_empty() or not contribution.has("generation") or not contribution.get("weapon") is Dictionary or not contribution.weapon.get("entry") is Dictionary:
			return {"ok": false, "reason": "InvalidDroneContribution"}
	return _commit_growth(slots, wallet, "refit", "", contributions)

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
	for result in [planet_factors, crew_factors, galaxy_factors]:
		if not result.ok: return result
	var galaxy: Dictionary = galaxy_factors["values"]
	var sources: Array = [planet_factors.equipment, crew_factors.equipment, galaxy.equipment_value]
	var external: Array = world_factors.get("external", []).duplicate()
	for index in sources.size():
		if world_factors.get("_external_sources", []).size() > index and world_factors._external_sources[index] == sources[index]: continue
		var text = amount_api.apply("to_display", [sources[index]])
		if not text.ok: return text
		if external.size() <= index: external.append(text.text)
		else: external[index] = text.text
	var capacity_sources: Array = [crew_factors.capacity, galaxy.charge_max]
	var capacity: Dictionary = world_factors.get("capacity", {})
	if world_factors.get("_capacity_sources", []) != capacity_sources:
		var value = amount_api.apply("mul", capacity_sources)
		if not value.ok: return value
		capacity = value.value
	return {"ok": true, "external": external, "capacity": capacity, "fragments": crew_factors.fragments,
		"galaxy_fragments": galaxy.gem_fragment, "crew_experience": galaxy.crew_exp,
		"research": crew_factors.research, "refinery": planet_factors.refinery,
		"equipment_levels": planet_factors.equipment_levels, "enhancement_levels": planet_factors.enhancement_levels,
		"free_charge": planet_factors.free_charge, "_external_sources": sources, "_capacity_sources": capacity_sources}

func _publish_native_values(ai: Dictionary, reactor: Dictionary, kind: String) -> Dictionary:
	var weapons: bool = ai.weapon_damage != research_factors.weapon_damage or reactor.weapons != reactor_factors.weapons
	var defences: bool = ai.equipment_durability != research_factors.equipment_durability or reactor.defence != reactor_factors.defence
	var iron: String = ""
	if reactor.smelting != reactor_factors.smelting:
		var text = amount_api.apply("to_display", [reactor.smelting])
		if not text.ok: return text
		iron = text.text
	var values: Dictionary = {"weapons": {}, "defences": {}}
	if weapons or defences:
		values = CombatSetup.values(_active_slots(slots, ship_definitions[selected_ship]), int(world_factors.equipment_levels), equipment_definitions, evolution, amount_api, ai, reactor, weapons, defences)
		if not values.ok: return values
	for group in ["weapons", "defences"]:
		for id in values[group].keys():
			if values[group][id] == combat_values[group].get(id): values[group].erase(id)
	return _commit_values(values, kind, iron)

func _commit_values(values: Dictionary, kind: String, iron: String = "", upgrades: Dictionary = {}) -> Dictionary:
	if values.weapons.is_empty() and values.defences.is_empty() and iron.is_empty() and upgrades.is_empty(): return {"ok": true}
	var committed: Dictionary = kernel.set_player_values(values.weapons, values.defences, kind, iron, upgrades)
	if not committed.ok: return _fail(str(committed.reason)) if committed.fault else committed
	for group in ["weapons", "defences"]:
		for id in values[group]:
			if not values[group][id].has("base"): continue
			var row: Dictionary = values[group][id].duplicate()
			row.erase("external")
			combat_values[group][id] = row
	_retreat_if_dead()
	return {"ok": true}

func _commit_levels(next: Array, balances: Dictionary, changed: Array) -> Dictionary:
	var values = CombatSetup.values(_active_slots(changed, ship_definitions[selected_ship]), int(world_factors.equipment_levels), equipment_definitions, evolution, amount_api, research_factors, reactor_factors, true, true)
	if not values.ok: return values
	var result = _commit_values(values, "upgrade")
	if result.ok:
		for slot in changed: _display_changed("slots", str(slot.id))
		slots = next
		wallet = balances
	return result

func _publish_world_values(previous: Dictionary) -> Dictionary:
	var reactor: Dictionary = {"ok": true, "factors": reactor_factors}
	if world_factors.capacity != previous.capacity or world_factors.free_charge != previous.free_charge:
		reactor = reactor_system.prepare(reactor_inputs())
		if not reactor.ok: return reactor
	var levels: bool = world_factors.equipment_levels != previous.equipment_levels
	var weapons: bool = levels or reactor.factors.weapons != reactor_factors.weapons
	var defences: bool = levels or reactor.factors.defence != reactor_factors.defence
	var values: Dictionary = {"weapons": {}, "defences": {}}
	var active: Array = _active_slots(slots, ship_definitions[selected_ship])
	if weapons or defences:
		values = CombatSetup.values(active, int(world_factors.equipment_levels), equipment_definitions, evolution, amount_api, research_factors, reactor.factors, weapons, defences)
		if not values.ok: return values
	if world_factors.external != previous.external:
		for slot in active:
			if str(slot.equipment_id).is_empty(): continue
			var group: String = "weapons" if slot.category == "weapon" else "defences"
			var row: Dictionary = values[group].get(str(slot.id), {"key": str(slot.equipment_id), "generation": int(slot.generation)})
			row.external = world_factors.external.duplicate()
			values[group][str(slot.id)] = row
	if world_factors.external != previous.external:
		for drone in equipped_drones:
			var entry: Dictionary = drone.weapon.entry
			var external: Array = world_factors.external.duplicate()
			external.append_array(drone.weapon.get("external_factors", []))
			values.weapons["drone:" + str(drone.id)] = {"key": entry.key, "generation": int(drone.generation), "external": external}
	var output: Dictionary = enhancement.published_output()
	var upgrades: Dictionary = {}
	if world_factors.enhancement_levels != previous.enhancement_levels:
		output = enhancement.evaluate(int(world_factors.enhancement_levels), unlocked("feature", "jewels"), Equipment.armour_count(active))
		if not output.ok: return output
		upgrades = enhancement.difference(output)
	var iron: String = ""
	if reactor.factors.smelting != reactor_factors.smelting:
		var text = amount_api.apply("to_display", [reactor.factors.smelting])
		if not text.ok: return text
		iron = text.text
	var result = _commit_values(values, "refit", iron, upgrades)
	if result.ok: enhancement.accept_output(output)
	if result.ok:
		reactor_system.accept(reactor)
		reactor_factors = reactor.factors
		income_factors.condensation = reactor.factors.condensation
	return result

func _retreat_if_dead() -> void:
	var armour = amount_api.apply("from_decimal", [str(kernel.player_view().armour)])
	if armour.ok and amount_api.apply("compare", [armour.value, amount_api.apply("zero", []).value]).scalar <= 0 and campaign.state not in ["menu", "retreat", "departing"]:
		_begin_death_retreat()

func _publish_research() -> Dictionary:
	var result = research.contributions()
	if not result.ok: return result
	var values: Dictionary = result["values"]
	var updated = _publish_native_values(values, reactor_factors, "growth")
	if not updated.ok: return updated
	research_factors = values
	income_factors.iron = values.iron_income
	income_factors.uranium = values.uranium_income
	income_factors.jewel = values.fragment_income
	return {"ok": true}

func publish_reactor(factors: Dictionary, costs: Dictionary, kind: String) -> Dictionary:
	var paid = Economy.payment(wallet, costs, amount_api)
	if not paid.ok: return paid
	var updated = _publish_native_values(research_factors, factors, kind)
	if not updated.ok: return updated
	reactor_factors = factors
	wallet = paid.wallet
	income_factors.condensation = factors.condensation
	return {"ok": true}

func _commit_world(planet: Dictionary = {}, crew: Dictionary = {}, galaxy: Dictionary = {}) -> Dictionary:
	if not planet.is_empty(): planet_factors = planet
	if not crew.is_empty(): crew_factors = crew
	if not galaxy.is_empty(): galaxy_factors = galaxy
	var world = _world_contributions()
	if not world.ok: return _fail(str(world.get("error", "WorldAssemblyFailed")))
	var previous: Dictionary = world_factors
	world_factors = world
	income_factors.refinery = world.refinery
	income_factors.crew_fragments = world.fragments
	income_factors.galaxy_fragments = world.galaxy_fragments
	research_speed = world.research
	galaxy_crew_experience = world.crew_experience
	var result: Dictionary = {"ok": true}
	if world.enhancement_levels != previous.enhancement_levels or world.external != previous.external or world.equipment_levels != previous.equipment_levels or world.capacity != previous.capacity or world.free_charge != previous.free_charge:
		result = _publish_world_values(previous)
	if not result.ok and last_error.is_empty():
		return _fail(str(result.get("error", result.get("reason", "WorldGrowthUpdateFailed"))))
	return result

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
		Planet.set_explorer(planet_progress[old_target], planet_definitions[old_target], false)
	if kind == "planet_explore":
		var started = Planet.set_explorer(planet_progress[target], planet_definitions[target], true)
		if not started.ok:
			return _fail(str(started.reason))
	_display_changed("crew", id)
	if old_kind == "planet_explore": _display_changed("planets", old_target)
	if kind == "planet_explore": _display_changed("planets", target)
	return _commit_world({}, Crew.contributions(crew_progress, crew_definitions, crew_jobs, crew_rules, amount_api, crew_factors, changed.jobs)) if not changed.jobs.is_empty() else {"ok": true}

func cancel_planet(id: String) -> Dictionary:
	if not planet_progress.has(id):
		return {"ok": false, "reason": "UnknownPlanet"}
	_display_changed("planets", id)
	Planet.cancel(planet_progress[id])
	for member in Crew.release(crew_progress, "planet_explore", id): _display_changed("crew", str(member))
	return {"ok": true}

func set_planet_automatic(id: String, enabled: bool) -> Dictionary:
	if not planet_unlocked(id):
		return {"ok": false, "reason": "PlanetLocked"}
	return Planet.set_automatic(planet_progress[id], enabled)

func claim_planet_build(id: String, building: String) -> Dictionary:
	if not planet_unlocked(id):
		return {"ok": false, "reason": "PlanetLocked"}
	var result = Planet.claim_build(planet_progress[id], building)
	if result.ok: _display_changed("buildings", id)
	return _commit_world(Planet.contributions(planet_progress, planet_buildings, planet_buffs, amount_api, planet_factors, {id: [building]})) if result.ok else result

func _advance_planets(dt: float, explorers: Dictionary, builders: Dictionary) -> bool:
	var result = Planet.advance(planet_progress, planet_definitions, planet_buildings,
		explorers, builders, dt)
	if not result.ok:
		_fail(str(result.get("reason", "PlanetAdvanceFailed")))
		return false
	for id in result.progressed: _display_changed("planets", str(id))
	var changed_jobs: Array = []
	var changed_planets: Dictionary = {}
	for completion in result.completed:
		for target in completion.released:
			for member in Crew.release(crew_progress, "planet_build", str(target)): _display_changed("crew", str(member))
		var id: String = str(completion.planet)
		changed_planets[id] = []
		if completion.buildings_changed: _display_changed("buildings", id)
		if completion.assignments_changed: _display_changed("construction", id)
		if unlocked("feature", "crew_level"):
			var recipients: Array = crew_progress.keys() if Planet.buff(planet_progress, planet_buffs, "crew_exp_share", "all", id) > 0 else [completion.explorer]
			var level: int = int(campaign.highest_reached)
			var experience = Planet.experience_reward(planet_definitions[id], level_definitions[level].planetExpRatio, galaxy_crew_experience, amount_api)
			if not experience.ok:
				_fail(str(experience.error))
				return false
			var awarded = Crew.add_experience(crew_progress, recipients, experience.value, crew_rules, amount_api)
			if not awarded.ok:
				_fail(str(awarded.get("error", awarded.get("reason", "CrewExperienceFailed"))))
				return false
			for member in awarded.members: _display_changed("crew", str(member))
			for job in awarded.jobs:
				if job not in changed_jobs: changed_jobs.append(job)
		if not completion.again:
			_display_changed("crew", str(completion.explorer))
			Crew.release(crew_progress, "planet_explore", id)
	if not result.completed.is_empty() and not _commit_world(Planet.contributions(planet_progress, planet_buildings, planet_buffs, amount_api, planet_factors, changed_planets), Crew.contributions(crew_progress, crew_definitions, crew_jobs, crew_rules, amount_api, crew_factors, changed_jobs) if not changed_jobs.is_empty() else {}).ok:
		return false
	return true

func _advance_crew_jobs(dt: float, ids: Array) -> bool:
	for attempt in Crew.advance_jobs(crew_progress, ids, crew_jobs, dt):
		if attempt.job == "equipment_upgrade":
			if attempt.mode != "max":
				buy_all_levels(int(attempt.mode))
			else:
				buy_all_levels(1, true)
		elif attempt.job == "jewel_auto":
			enhancement.purchase(1, enhancement_inputs(), can_pay_costs, publish_enhancement)
		elif attempt.job == "reactor_upgrade":
			reactor_system.purchase(1, true, reactor_inputs(), publish_reactor)
		if not last_error.is_empty(): return false
	return true

func galaxy_unlocked(key: String) -> bool:
	if not galaxy_progress.has(key) or not galaxy_definitions.has(key):
		return false
	if galaxy_progress[key].get("unlocked", false):
		return true
	var row: Dictionary = galaxy_definitions[key]
	return unlocked("feature", "galaxy") and row.unlock_type == "stage_cleared" and campaign.cleared_stages.has(int(row.unlock_value))

func _advance_galaxies(dt: float, counts: Dictionary) -> bool:
	var enabled: Dictionary = {}
	for key in galaxy_progress:
		enabled[key] = galaxy_unlocked(key)
		if enabled[key]: galaxy_progress[key].unlocked = true
	var result = Galaxy.advance(galaxy_progress, galaxy_definitions, galaxy_buildings, counts, enabled, dt, float(galaxy_rules.income_interval))
	if not result.ok:
		_fail(str(result.get("reason", "GalaxyAdvanceFailed")))
		return false
	for key in result.displayed: _display_changed("galaxies", str(key))
	if not result.changes.is_empty():
		var contributions = Galaxy.contributions(galaxy_progress, galaxy_buildings, amount_api, galaxy_factors, result.changes)
		if not contributions.ok:
			_fail(str(contributions.get("error", "GalaxyContributionFailed")))
			return false
		galaxy_factors = contributions
		if contributions.growth_changed and not _commit_world({}, {}, contributions).ok: return false
	if not result.payments.is_empty():
		var production = Economy.income_rates(income_samples, wall_time, game_time, research.income_window(), "production", amount_api)
		if not production.ok:
			_fail(str(production.get("error", "ProductionQueryFailed")))
			return false
		for payment in result.payments:
			var income = Galaxy.income(galaxy_factors, str(payment.galaxy), production.rates, float(payment.seconds), amount_api)
			if not income.ok:
				_fail(str(income.get("error", "GalaxyIncomeFailed")))
				return false
			for resource in income.amounts:
				var credited = Economy.credit_yield(wallet, income_samples, str(resource), income.amounts[resource], wall_time, game_time, amount_api)
				if not credited.ok:
					_fail(str(credited.get("error", "GalaxyCreditFailed")))
					return false
	return true
