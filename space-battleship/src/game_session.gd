extends RefCounted
const CombatSetup = preload("res://src/combat_setup.gd")
const Economy = preload("res://src/systems/economy.gd")
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
var player_muzzles := PackedVector2Array()
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
var claimed_drops: Dictionary = {}
var income_samples: Array = []
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
	for row in configuration.game_rules.game_rules:
		rules[str(row.id)] = row.value
	for row in configuration.battle_geometry.battle_geometry:
		geometry[str(row.id)] = row.value
	for row in configuration.equipment_evolution.equipment_evolution:
		evolution[str(row.key)] = row.value
	for row in configuration.enhance_config.enhance_config:
		enhancement[str(row.id)] = row.value
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
	for key in [selected_ship, "enemy_1", "enemy_2", "enemy_3", "enemy_4", "enemy_5", "enemy_6"]:
		var art: Dictionary = art_data.ships[key]
		var image := Image.load_from_file(str(art.texture))
		if image == null or image.is_empty():
			return _fail("MissingHullAsset:" + str(key))
		models[key] = {"hull": Geometry.normalized_hull(image), "size": Vector2(image.get_size()), "art": art}
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
	amount_api = ClassDB.instantiate("FoundationAmount")
	kernel = ClassDB.instantiate("SpaceCombatKernel")
	var setup = CombatSetup.build_player(self)
	if not setup.ok:
		return _fail(str(setup.get("error", setup.get("reason", "EquipmentAssemblyFailed"))))
	for row in setup.descriptor.weapons:
		player_muzzles.append(row.muzzle)
	if not kernel.initialize(setup.descriptor):
		return _fail("NativeInitializationFailed")
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
	var settled = Economy.collect_due(drops, claimed_drops, wallet, income_samples,
		float(parameters.autoCollectReduce), wall_time, game_time, amount_api)
	if not settled.ok:
		_fail(str(settled.get("error", "CollectionFailed")))
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
				var point: int = 0
				while point < campaign.points.size() - 1 and float(campaign.points[point].position) * float(level_definitions[int(campaign.stage)].length) < float(campaign.distance):
					point += 1
				campaign.point = point
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
	last_events.append_array(result.events)
	var registered = Economy.register_drops(drops, claimed_drops, result.drops, game_time, rules, amount_api)
	if not registered.ok:
		_fail(str(registered.get("error", "DropRegistrationFailed")))
		return false
	if not str(result.error).is_empty():
		_fail(str(result.error))
		return false
	if result.player_dead and campaign.state != "retreat":
		retreat_from = _global_position()
		retreat_to = maxf(0.0, retreat_from - float(parameters.backRange))
		retreat_elapsed = 0.0
		if int(guard.death_option) == 0:
			guard.enabled = false
		kernel.begin_retreat()
		campaign.state = "retreat"
	elif result.wave_cleared:
		kernel.finish_wave(bool(result.final_cleared))
		if result.final_cleared:
			var settled = Economy.collect_due(drops, claimed_drops, wallet, income_samples,
				float(parameters.autoCollectReduce), wall_time, game_time, amount_api, true)
			if not settled.ok:
				_fail(str(settled.get("error", "FinalCollectionFailed")))
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
	var setup = CombatSetup.build_wave(self, int(campaign.point))
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
	var muzzles := PackedVector2Array()
	# Native weapon order is player slots followed by wave-local enemy mounts.
	muzzles.append_array(player_muzzles)
	for actor in actors:
		var entries: PackedStringArray = str(actor.equipment).replace("｛", "").replace("｝", "").replace("{", "").replace("}", "").replace("，", ",").split(",")
		for entry in entries:
			for _mount in int(entry.split("|")[1]):
				muzzles.append(Vector2(float(actor.x), float(actor.y)))
	enemy_hulls = hulls
	kernel.input_geometry(points, muzzles)
	kernel.input_ballistic_geometry(hulls, points, muzzles, stationary)
	var player_point := Vector2(float(geometry.player_x), float(geometry.player_y))
	kernel.input_player_point(player_point)
	var player_hull: PackedVector2Array = Geometry.transform_hull(models[selected_ship].hull, player_point, player_dimensions, 0.0)
	if not kernel.input_player_hull(player_hull):
		_fail("InvalidPlayerGeometry")

func collect_drop(id: int) -> Dictionary:
	return Economy.collect_drop(drops, claimed_drops, wallet, income_samples, id, false,
		float(parameters.autoCollectReduce), wall_time, game_time, amount_api)

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

func _fail(reason: String) -> Dictionary:
	last_error = reason
	pause_reasons.error = true
	return {"ok": false, "reason": reason}
