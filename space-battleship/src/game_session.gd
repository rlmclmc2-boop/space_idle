extends RefCounted

const Battle = preload("res://src/systems/battle.gd")
const RunState = preload("res://src/systems/run_state.gd")
const Campaign = preload("res://src/systems/campaign.gd")
const Equipment = preload("res://src/systems/equipment.gd")
const Enhancement = preload("res://src/systems/enhancement.gd")
const Reactor = preload("res://src/systems/reactor.gd")
const Research = preload("res://src/systems/research.gd")
const Economy = preload("res://src/systems/economy.gd")
const Crew = preload("res://src/systems/crew.gd")
const Planet = preload("res://src/systems/planet.gd")
const Galaxy = preload("res://src/systems/galaxy.gd")
const Hyperspace = preload("res://src/systems/hyperspace.gd")
const StateCodec = preload("res://foundation/host/state_codec.gd")
const SaveFiles = preload("res://foundation/host/save_files.gd")
const Notifications = preload("res://src/systems/notifications.gd")
const Tutorial = preload("res://src/systems/tutorial.gd")
const STEP: float = 1.0 / 60.0
const FRAME_STEPS: int = 64

var battle
var run_state = RunState.new()
var amount_api
var equipment
var economy
var enhancement
var reactor_system
var research
var planet_system
var crew_system
var galaxy_system
var hyperspace_system
var _galaxy_crew_experience: Dictionary = {}
var _research_speed: Dictionary = {}
var _world_factors: Dictionary = {}
var _planet_factors: Dictionary = {}
var _crew_factors: Dictionary = {}
var _galaxy_factors: Dictionary = {}
var _research_factors: Dictionary = {}
var _reactor_factors: Dictionary = {}
var _income_factors: Dictionary = {}
var _final_collection_changed: bool = false
var _battle_drops_changed: bool = false
var campaign_system
var pause_reasons: Dictionary = {}
var pending_seconds: float = 0.0
var wall_time: float = 0.0
var game_time: float = 0.0
var _configuration_path: String = ""
var _combat_seed: int = 0
var _session_id: String = ""
var _change_number: int = 0
var _offline_max_hours: int = 0
var _chrono_rate: String = "0"
var _chrono_speed: int = 1
var _chrono_costs: Dictionary = {}
var save_files
var notifications = Notifications.new()
var tutorial = Tutorial.new()

func _init() -> void:
	_income_factors.make_read_only()

func initialize(path: String, combat_seed: int, native_state: Dictionary = {}, saved: Dictionary = {}) -> Dictionary:
	if not run_state.is_running(): return run_state.rejection()
	if battle != null:
		return {"ok": false, "reason": "AlreadyInitialized"}
	if not ClassDB.class_exists("SpaceCombatKernel") or not ClassDB.class_exists("FoundationAmount"):
		return _fail("NativeExtensionRequired")
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return _fail("ConfigurationReadFailed")
	var configuration: Dictionary = parsed
	_configuration_path = path
	_combat_seed = combat_seed
	_session_id = str(Time.get_unix_time_from_system()) + ":" + str(combat_seed)
	var parameters: Dictionary = {}
	var rules: Dictionary = {}
	for row in configuration.config.config:
		parameters[str(row.name)] = row.para_1
	_offline_max_hours = int(parameters.offlineMax)
	_chrono_rate = str(parameters.chronoParticlesPerSecond)
	for entry in str(parameters.chronoSpeeds).split(","):
		var columns: PackedStringArray = entry.split("|")
		if columns.size() != 2: return _fail("InvalidChronoConfiguration")
		_chrono_costs[int(columns[0])] = int(columns[1])
	if not _chrono_costs.has(1) or int(_chrono_costs[1]) != 0:
		return _fail("InvalidChronoConfiguration")
	for row in configuration.game_rules.game_rules:
		rules[str(row.id)] = row.value
	campaign_system = Campaign.new(configuration, parameters, rules, run_state)
	if campaign_system.selected_ship().is_empty():
		return _fail("InitialShipUnavailable")
	amount_api = ClassDB.instantiate("FoundationAmount")
	battle = Battle.new(configuration, parameters, rules, campaign_system.ship_keys(), campaign_system.selected_ship(), amount_api, combat_seed, run_state)
	var battle_ready = battle.initialization_result()
	if not battle_ready.ok: return _fail(str(battle_ready.reason))
	economy = Economy.new(parameters, rules, amount_api, run_state)
	equipment = Equipment.new(configuration.equipment.equipment, configuration.equipment_evolution.equipment_evolution,
		configuration.unlock.unlock, parameters, rules, amount_api, run_state)
	equipment.refresh_availability(campaign_system.available, int(campaign_system.progress_facts().highest_reached))
	var initial_slots: Dictionary = equipment.initialize_slots(str(parameters.startEquip), campaign_system.ship_facts().mounts)
	if not initial_slots.ok: return _fail(str(initial_slots.reason))
	reactor_system = Reactor.new(parameters, amount_api, run_state)
	reactor_system.refresh_availability(campaign_system.available)
	enhancement = Enhancement.new(configuration.enhance_config.enhance_config, amount_api, run_state)
	research = Research.new(configuration.ai_tech_tree.ai_tech_tree, rules, amount_api, run_state)
	research.refresh_progress(campaign_system.available)
	crew_system = Crew.new(configuration.crew.crew, configuration.crew_config.crew_config, configuration.crew_assignment.crew_assignment, amount_api, run_state)
	crew_system.refresh_availability(campaign_system.available)
	planet_system = Planet.new(configuration.planet.planet, configuration.planet_build.planet_build, configuration.planet_buff.planet_buff, amount_api, run_state)
	planet_system.refresh_availability(campaign_system.available)
	galaxy_system = Galaxy.new(configuration.galaxy.galaxy, configuration.galaxy_build.galaxy_build, configuration.galaxy_config.galaxy_config, amount_api, run_state)
	var galaxies = galaxy_system.initialization_result()
	if not galaxies.ok: return _fail(str(galaxies.reason))
	galaxy_system.refresh_availability(campaign_system.available, campaign_system.progress_facts().cleared_stages)
	hyperspace_system = Hyperspace.new(configuration, amount_api, run_state, combat_seed)
	campaign_system.bind_battle(battle, amount_api)
	if not saved.is_empty():
		var restored: Dictionary = _restore_modules(saved)
		if not restored.ok: return restored
	equipment.loadout_changed.connect(func(): tutorial.record("equip"))
	equipment.slots_changed.connect(func(_ids: Array): tutorial.record("upgrade"))
	economy.drop_collected.connect(func(): tutorial.record("pickup"))
	campaign_system.retreat_started.connect(func(): tutorial.record("retreat"))
	_planet_factors = planet_system.contributions()
	_crew_factors = crew_system.contributions()
	_galaxy_factors = galaxy_system.contributions()
	_world_factors = _world_contributions()
	if not _world_factors.ok: return _fail(str(_world_factors.get("error", "WorldAssemblyFailed")))
	var setup = _growth_setup()
	if not setup.ok:
		return _fail(str(setup.get("error", setup.get("reason", "EquipmentAssemblyFailed"))))
	var initialized = battle.initialize_player(native_state)
	if not initialized.ok: return _fail(str(initialized.reason))
	reactor_system.accept()
	_reactor_factors = setup.reactor_factors
	_research_factors = setup.research_factors
	enhancement.accept_output()
	_income_factors = setup.income_factors
	_research_speed = setup.research_speed
	_galaxy_crew_experience = setup.galaxy_crew_experience
	if not saved.is_empty():
		var checkpoint: String = campaign_system.restore_checkpoint()
		if checkpoint == "combat":
			_start_wave()
			if not run_state.is_running(): return run_state.rejection()
		elif checkpoint == "hyperspace":
			if hyperspace_system.manual_active():
				var interrupted: Dictionary = hyperspace_system.finish_manual(false)
				if not interrupted.ok: return interrupted
				campaign_system.return_from_hyperspace(interrupted.receipt.return_target, false)
			else:
				return {"ok": false, "reason": "InvalidHyperspaceCheckpoint"}
	_record_unlocks()
	return {"ok": true}

func _restore_modules(saved: Dictionary) -> Dictionary:
	if not saved.get("modules") is Dictionary or not saved.get("times") is Dictionary:
		return {"ok": false, "reason": "InvalidSessionState"}
	var modules: Dictionary = saved.modules
	var campaign = campaign_system.restore_state(modules.get("campaign", {}))
	if not campaign.ok: return campaign
	equipment.refresh_availability(campaign_system.available, int(campaign_system.progress_facts().cycle_reached), false)
	var ports: Array = [
		[economy, "economy"], [equipment, "equipment"], [enhancement, "enhancement"],
		[reactor_system, "reactor"], [research, "research"], [crew_system, "crew"],
		[planet_system, "planet"], [galaxy_system, "galaxy"], [hyperspace_system, "hyperspace"]]
	for port in ports:
		var result: Dictionary
		if port[1] == "equipment":
			result = port[0].restore_state(modules.get(port[1], {}), campaign_system.ship_facts().mounts)
		else:
			result = port[0].restore_state(modules.get(port[1], {}))
		if not result.ok: return result
	# Native DropIds and the host registration frontier are one monotonic stream.
	var saved_native = saved.get("native", {})
	if not saved_native is Dictionary:
		return {"ok": false, "reason": "InvalidNativeDropWatermark"}
	var native_ids = saved_native.get("next_ids", {})
	if not native_ids is Dictionary or not SaveFiles.integer_text(native_ids.get("drop")):
		return {"ok": false, "reason": "InvalidNativeDropWatermark"}
	var drop_watermark: int = str(native_ids.drop).to_int()
	var economy_state: Dictionary = economy.save_state()
	var registered: int = int(economy_state.cursor.registered_through)
	if registered > drop_watermark:
		return {"ok": false, "reason": "InvalidNativeDropWatermark"}
	for key in economy_state.drops:
		if str(key).begins_with("native:") and int(economy_state.drops[key].uid) > registered:
			return {"ok": false, "reason": "InvalidNativeDropWatermark"}
	var restored_notifications: Dictionary = notifications.restore_state(modules.get("notifications", {"entries": {}}))
	if not restored_notifications.ok: return restored_notifications
	var tutorial_state = modules.get("tutorial", {"completed": {}, "seen": {}})
	if not tutorial_state is Dictionary: return {"ok": false, "reason": "InvalidTutorialState"}
	var restored_tutorial: Dictionary = tutorial.restore_state(tutorial_state)
	if not restored_tutorial.ok: return restored_tutorial
	var times: Dictionary = saved.times
	for key in ["wall", "game", "pending"]:
		if not times.get(key) is float or not is_finite(times[key]) or times[key] < 0.0:
			return {"ok": false, "reason": "InvalidSessionClock"}
	if not times.get("speed", 1) is int or not _chrono_costs.has(times.get("speed", 1)):
		return {"ok": false, "reason": "InvalidChronoSpeed"}
	wall_time = times.wall
	game_time = times.game
	pending_seconds = times.pending
	_chrono_speed = times.get("speed", 1)
	var reasons = saved.get("pause_reasons", {})
	if not reasons is Dictionary: return {"ok": false, "reason": "InvalidPauseState"}
	for key in reasons:
		if not key is String or key.is_empty() or reasons[key] != true:
			return {"ok": false, "reason": "InvalidPauseState"}
	if reasons.has("tutorial") and tutorial.next_prompt().is_empty():
		return {"ok": false, "reason": "InvalidPauseState"}
	if reasons.has("unlock"):
		var pending_unlock: bool = false
		for notice in notifications.entries():
			if notice.topic == "unlock" and not notice.seen: pending_unlock = true
		if not pending_unlock: return {"ok": false, "reason": "InvalidPauseState"}
	pause_reasons = reasons.duplicate()
	reactor_system.refresh_availability(campaign_system.available, false)
	research.refresh_progress(campaign_system.available, false)
	crew_system.refresh_availability(campaign_system.available, false)
	planet_system.refresh_availability(campaign_system.available, false)
	galaxy_system.refresh_availability(campaign_system.available, campaign_system.progress_facts().cleared_stages, false)
	return crew_system.validate_assignments(assignment_admission, hyperspace_system.online_status().auto)

func save_payload() -> Dictionary:
	if not run_state.is_running() or battle == null: return run_state.rejection()
	var native: Dictionary = battle.persistent_state()
	if not native.ok: return native
	var reasons: Dictionary = pause_reasons.duplicate()
	reasons.erase("reforge")
	var snapshot: Dictionary = {"seed": _combat_seed, "native": native.state,
		"times": {"wall": wall_time, "game": game_time, "pending": pending_seconds,
			"speed": _chrono_speed},
		"pause_reasons": reasons,
		"modules": {"campaign": campaign_system.save_state(), "economy": economy.save_state(),
			"equipment": equipment.save_state(), "enhancement": enhancement.save_state(),
			"reactor": reactor_system.save_state(), "research": research.save_state(),
			"crew": crew_system.save_state(), "planet": planet_system.save_state(),
			"galaxy": galaxy_system.save_state(), "hyperspace": hyperspace_system.save_state(),
			"notifications": notifications.save_state(), "tutorial": tutorial.save_state()}}
	var packed: Dictionary = StateCodec.pack(snapshot)
	if not packed.ok: return packed
	return {"ok": true, "payload": packed.value}

func configure_save_directory(directory: String) -> Dictionary:
	if directory.is_empty() or not DirAccess.dir_exists_absolute(directory):
		return {"ok": false, "reason": "SaveDirectoryRequired"}
	if save_files != null:
		if save_files._directory == directory: return {"ok": true}
		var closed: Dictionary = save_files.close()
		if not closed.ok: return closed
	save_files = SaveFiles.new(directory)
	return {"ok": true}

func request_save() -> Dictionary:
	if save_files == null: return {"ok": false, "reason": "SaveDirectoryRequired"}
	var snapshot: Dictionary = save_payload()
	if not snapshot.ok: return snapshot
	if _change_number == 9223372036854775807: return {"ok": false, "reason": "ChangeNumberRange"}
	_change_number += 1
	var config_hash: String = FileAccess.get_file_as_string(_configuration_path).sha256_text()
	return save_files.request(snapshot.payload, str(_change_number), _session_id,
		str(int(Time.get_unix_time_from_system())), config_hash)

func dirty_since_save() -> Dictionary:
	if save_files == null: return {"ok": true, "dirty": true}
	var snapshot: Dictionary = save_payload()
	if not snapshot.ok: return snapshot
	var hash: String = JSON.stringify(snapshot.payload).sha256_text()
	return {"ok": true, "dirty": save_files.dirty(str(_change_number), hash)}

static func load_candidate(path: String, directory: String, backup: bool = false) -> Dictionary:
	var pointer: String = "previous.json" if backup else "active.json"
	var stored: Dictionary = SaveFiles.read_pointer(directory, pointer)
	if not stored.ok: return {"ok": false, "reason": "InvalidBackup" if backup else "InvalidPrimarySave"}
	return _candidate_from_envelope(path, directory, stored.envelope)

static func import_candidate(path: String, directory: String, source_file: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(source_file, FileAccess.READ)
	if file == null: return {"ok": false, "reason": "InvalidImportFile"}
	if file.get_length() > SaveFiles.MAX_BYTES:
		file.close()
		return {"ok": false, "reason": "InvalidImportFile"}
	var parser := JSON.new()
	var parse_result: Error = parser.parse(file.get_as_text())
	file.close()
	if parse_result != OK: return {"ok": false, "reason": "InvalidImportEnvelope"}
	var envelope = parser.data
	if not envelope is Dictionary or envelope.get("formatVersion") != 1 or not envelope.get("payload") is Dictionary or not envelope.get("sessionId") is String or envelope.sessionId.is_empty():
		return {"ok": false, "reason": "InvalidImportEnvelope"}
	for field in ["changeNumber", "generation", "savedUtc"]:
		if not SaveFiles.integer_text(envelope.get(field)):
			return {"ok": false, "reason": "InvalidImportEnvelope"}
	if JSON.stringify(envelope.payload).sha256_text() != envelope.get("payloadHash"):
		return {"ok": false, "reason": "InvalidImportChecksum"}
	return _candidate_from_envelope(path, directory, envelope)

static func _candidate_from_envelope(path: String, directory: String, envelope: Dictionary) -> Dictionary:
	if FileAccess.get_file_as_string(path).sha256_text() != envelope.configHash:
		return {"ok": false, "reason": "ConfigurationMismatch"}
	var decoded: Dictionary = StateCodec.unpack(envelope.payload)
	if not decoded.ok or not decoded.value is Dictionary:
		return {"ok": false, "reason": "InvalidSavePayload"}
	var saved: Dictionary = decoded.value
	if not saved.get("seed") is int or not saved.get("native") is Dictionary:
		return {"ok": false, "reason": "InvalidSavePayload"}
	var candidate = load("res://src/game_session.gd").new()
	var ready: Dictionary = candidate.initialize(path, saved.seed, saved.native, saved)
	if not ready.ok: return ready
	candidate._session_id = envelope.sessionId
	candidate._change_number = str(envelope.changeNumber).to_int()
	var elapsed: int = offline_elapsed(str(envelope.savedUtc).to_int(), int(Time.get_unix_time_from_system()))
	var offline: Dictionary = candidate.economy.credit_offline(elapsed, candidate._offline_max_hours, candidate._chrono_rate)
	if not offline.ok: return offline
	var configured: Dictionary = candidate.configure_save_directory(directory)
	if not configured.ok: return configured
	return {"ok": true, "session": candidate,
		"summary": {"stage": candidate.campaign_system.progress_facts().cycle_reached,
			"ship": candidate.campaign_system.selected_ship(),
			"generation": envelope.generation, "savedUtc": envelope.savedUtc}}

static func offline_elapsed(saved_utc: int, current_utc: int) -> int:
	return maxi(0, current_utc - saved_utc)

func prepare_reforge(planet_id: String, retained_ids: Array, directory: String) -> Dictionary:
	if not run_state.is_running(): return run_state.rejection()
	var planet_offer: Dictionary = planet_system.prepare_reforge(planet_id)
	if not planet_offer.ok: return planet_offer
	var drones: Dictionary = hyperspace_system.prepare_reforge(retained_ids)
	if not drones.ok: return drones
	if not DirAccess.dir_exists_absolute(directory):
		return {"ok": false, "reason": "SaveDirectoryRequired"}
	var candidate = load("res://src/game_session.gd").new()
	var ready: Dictionary = candidate.initialize(_configuration_path, _combat_seed)
	if not ready.ok: return ready
	ready = candidate.campaign_system.accept_reforge(campaign_system.save_state(), planet_offer.start)
	if not ready.ok: return ready
	var old_wallet: Dictionary = economy.budget()
	var retained_wallet: Dictionary = {}
	for resource in ["1", "2", "chrono"]:
		if old_wallet.has(resource): retained_wallet[resource] = old_wallet[resource].duplicate(true)
	candidate.economy.accept_budget(retained_wallet, false)
	ready = candidate.crew_system.restore_state(crew_system.save_state())
	if not ready.ok: return ready
	ready = candidate.planet_system.restore_state(planet_system.save_state())
	if not ready.ok: return ready
	ready = candidate.galaxy_system.restore_state(galaxy_system.save_state())
	if not ready.ok: return ready
	ready = candidate.hyperspace_system.restore_state(hyperspace_system.save_state())
	if not ready.ok: return ready
	ready = candidate.hyperspace_system.accept_reforge(drones.retained)
	if not ready.ok: return ready
	var retained_notices: Dictionary = {"entries": {}}
	for row in notifications.entries():
		if row.topic == "unlock":
			retained_notices.entries[row.key] = {"topic": row.topic, "id": row.id,
				"seen": row.seen, "read": row.read}
	candidate.notifications.restore_state(retained_notices)
	candidate.equipment.refresh_availability(candidate.campaign_system.available, planet_offer.start, false)
	candidate.reactor_system.refresh_availability(candidate.campaign_system.available, false)
	candidate.research.refresh_progress(candidate.campaign_system.available, false)
	candidate.crew_system.refresh_availability(candidate.campaign_system.available, false)
	candidate.planet_system.refresh_availability(candidate.campaign_system.available, false)
	candidate.galaxy_system.refresh_availability(candidate.campaign_system.available, candidate.campaign_system.progress_facts().cleared_stages, false)
	ready = candidate.planet_system.accept_reforge(planet_id)
	if not ready.ok: return ready
	var occupations: Dictionary = candidate.crew_system.retain_reforge_assignments(candidate.assignment_admission)
	for id in occupations.released_planets:
		candidate.planet_system.set_explorer(id, false, false)
	ready = candidate.crew_system.validate_assignments(candidate.assignment_admission, candidate.hyperspace_system.online_status().auto)
	if not ready.ok: return ready
	candidate._planet_factors = candidate.planet_system.contributions()
	candidate._crew_factors = candidate.crew_system.contributions()
	candidate._galaxy_factors = candidate.galaxy_system.contributions()
	candidate._world_factors = {}
	candidate._world_factors = candidate._world_contributions()
	if not candidate._world_factors.ok: return candidate._world_factors
	ready = candidate.publish_equipment_refit(candidate.economy.budget(), "refit", "", null, false)
	if not ready.ok: return ready
	ready = candidate.campaign_system.start_sortie(planet_offer.start, candidate.equipment.clear_switch_locks)
	if not ready.ok: return ready
	candidate._record_unlocks()
	ready = candidate.configure_save_directory(directory)
	if not ready.ok: return ready
	return {"ok": true, "session": candidate,
		"summary": {"planet": planet_id, "start": planet_offer.start,
			"retained": retained_ids.duplicate(), "wallet": retained_wallet.duplicate(true),
			"round": candidate.hyperspace_system.warehouse().reforge_count,
			"reset": "普通配装、强化、反应炉、研究、强化碎片、专用材料、本轮超空间状态及战场",
			"message": "重铸至关卡 %s（第 %s 轮），保留 %s 架无人机、铁/铀/微粒余额、船员、星球与星系进度；重置普通配装、强化、反应炉、研究、强化碎片、专用材料、本轮超空间状态及战场。确认后替换。" % [
				planet_offer.start, candidate.hyperspace_system.warehouse().reforge_count, retained_ids.size()]}}

func set_pause(reason: String, held: bool) -> void:
	if not run_state.is_running(): return
	if held:
		pause_reasons[reason] = true
	else:
		pause_reasons.erase(reason)

func set_chrono_speed(speed: int) -> Dictionary:
	if not _chrono_costs.has(speed): return {"ok": false, "reason": "InvalidChronoSpeed"}
	_chrono_speed = speed
	return {"ok": true}

func chrono_speed_options() -> Array:
	var options: Array = []
	for speed in _chrono_costs:
		options.append({"speed": speed, "cost": _chrono_costs[speed]})
	options.sort_custom(func(a, b): return a.speed < b.speed)
	return options

func current_chrono_speed() -> int:
	return _chrono_speed

func _accept_real_time(seconds: float, focused: bool) -> Dictionary:
	var speed: int = _chrono_speed if focused else 1
	var cost: int = int(_chrono_costs[speed])
	if cost == 0: return {"ok": true, "accepted": seconds}
	var rate: Dictionary = amount_api.apply("from_decimal", [str(cost)])
	var requested: Dictionary = amount_api.apply("from_decimal", [str(seconds * cost)])
	if not rate.ok or not requested.ok: return {"ok": false, "reason": "ChronoAmountFailed"}
	var zero: Dictionary = amount_api.apply("zero", []).value
	var balance: Dictionary = economy.budget().get("chrono", zero)
	var compared: Dictionary = amount_api.apply("compare", [balance, requested.value])
	if not compared.ok: return compared
	var accelerated: float = seconds
	var charged: Dictionary = requested.value
	if compared.scalar < 0:
		var duration: Dictionary = amount_api.apply("div", [balance, rate.value])
		if not duration.ok: return duration
		var one: Dictionary = amount_api.apply("from_decimal", ["1"]).value
		var ratio: Dictionary = amount_api.apply("to_ratio", [duration.value, one])
		if not ratio.ok: return ratio
		accelerated = clampf(float(ratio.scalar), 0.0, seconds)
		charged = balance
	var paid: Dictionary = economy.payment({"chrono": charged})
	if not paid.ok: return paid
	economy.accept_budget(paid.wallet, false)
	return {"ok": true, "accepted": accelerated * float(speed) + (seconds - accelerated)}

func frame(real_dt: float, focused: bool) -> void:
	if not run_state.is_running(): return
	if battle != null: battle.begin_frame()
	if battle == null or not is_finite(real_dt) or real_dt < 0:
		return
	wall_time += real_dt
	if not pause_reasons.is_empty():
		return
	var available: float = campaign_system.consume_departure(real_dt)
	var accepted: Dictionary = _accept_real_time(available, focused)
	if not accepted.ok:
		_fail(str(accepted.get("error", accepted.get("reason", "ChronoAcceptanceFailed"))))
		return
	pending_seconds += accepted.accepted
	var steps: int = 0
	while pending_seconds >= STEP and steps < FRAME_STEPS and not campaign_system.departure_active() and pause_reasons.is_empty() and run_state.is_running():
		pending_seconds -= STEP
		_step(STEP)
		if not run_state.is_running(): return
		steps += 1

func _step(dt: float) -> void:
	if not run_state.is_running(): return
	game_time += dt
	if not _advance_hyperspace_online(dt): return
	economy.prune_income(wall_time, game_time, research.income_window())
	var people: Dictionary = crew_system.step_assignments()
	if not _advance_planets(dt, people.explorers, people.builders) or not _advance_galaxies(dt, people.galaxies) or not _advance_crew_jobs(dt, people.jobs):
		return
	var positions: Dictionary = battle.resource_positions()
	var advanced = economy.advance_timed(dt, campaign_system.resource_generation_active(), campaign_system.timed_resource_ratio,
		positions.origin, float(positions.target_y), wall_time, game_time, _income_factors)
	if not advanced.ok:
		_fail(str(advanced.get("error", advanced.get("reason", "TimedResourceFailed"))))
		return
	var researched = research.advance(economy.budget(), dt, _research_speed, _crew_factors.research_staffed)
	if not researched.ok:
		_fail(str(researched.get("error", researched.get("reason", "ResearchFailed"))))
		return
	var research_budget_changed: bool = economy.accept_budget(researched.wallet, false)
	if researched.completed:
		notifications.record("research", str(researched.completed_id) + ":" + str(research.save_state().levels.get(researched.completed_id, 0)))
		# Publish completion effects before collection; income-window/automatic
		# investment refresh still happens once, after this step's collections.
		var changed = _publish_research()
		if not changed.ok:
			_fail(str(changed.get("error", changed.get("reason", "ResearchGrowthUpdateFailed"))))
			return
	if researched.choices_changed: research.publish_choices_changed()
	if research_budget_changed: economy.publish_budget_change()
	if researched.has("continuation_error"):
		_fail(str(researched.continuation_error))
		return
	var settled = economy.collect_due(wall_time, game_time, false, _income_factors)
	if not settled.ok:
		_fail(str(settled.get("error", "CollectionFailed")))
		return

	if not refresh_growth():
		return
	var status_changed: bool = campaign_system.advance(dt, _advance_kernel, _start_wave)
	if not run_state.is_running(): return
	var progress_changed: bool = campaign_system.take_progress_changed()
	var progress_notices: Dictionary = {}
	var progress_defence_changed: bool = false
	if progress_changed:
		var prepared: Dictionary = _publish_progress()
		if not prepared.ok: return
		progress_notices = prepared.notices
		progress_defence_changed = prepared.defence_changed
	if _final_collection_changed and not refresh_growth(): return
	var collection_changed: bool = _final_collection_changed or _battle_drops_changed
	_final_collection_changed = false
	_battle_drops_changed = false
	# All owners and dependent caches have accepted before any listener runs.
	if progress_defence_changed: campaign_system.retreat_if_dead(equipment.clear_switch_locks)
	if progress_changed: _notify_progress(progress_notices)
	if progress_changed: _record_unlocks()
	if progress_changed and not campaign_system.progress_facts().cleared_stages.is_empty(): tutorial.record("clear")
	if progress_changed: campaign_system.publish_progress_change()
	if status_changed: campaign_system.publish_status_change()
	if collection_changed: economy.publish_budget_change()

func _advance_hyperspace_online(dt: float) -> bool:
	var before: Dictionary = hyperspace_system.online_status()
	if before.auto.enabled and before.idle.get("status") == "Claimed":
		var crew: Dictionary = crew_system.hyperspace_assignee(str(before.auto.crew_id), str(before.auto.route))
		if not crew.ok:
			_fail(str(crew.reason))
			return false
		var next: Dictionary = hyperspace_system.prepare_auto_continuation(int(crew.level), float(_planet_factors.luck))
		if next.ok: hyperspace_system.accept_idle(next.receipt, true)
		elif next.get("reason") != "WarehouseFull":
			_fail(str(next.get("reason", "AutoContinuationFailed")))
			return false
	hyperspace_system.advance_online(dt, campaign_system.progress_facts().cleared_stages)
	var online: Dictionary = hyperspace_system.online_status()
	if not online.auto.enabled or online.idle.get("status") != "CompletedPending": return true
	var claimed: Dictionary = claim_hyperspace(int(online.idle.run_id))
	if claimed.ok or claimed.get("reason") == "WarehouseFull": return true
	_fail(str(claimed.get("reason", "AutoClaimFailed")))
	return false

func _advance_kernel(dt: float) -> bool:
	if dt <= 0:
		return true
	if hyperspace_system.manual_active(): hyperspace_system.advance_manual(dt)
	var result = battle.advance(dt)
	if not result.ok:
		_fail(str(result.get("error", result.get("reason", "NativeAdvanceRejected"))))
		return false
	var registered = economy.register_drops(result.drops, game_time, _income_factors.refinery, false)
	if not registered.ok:
		_fail(str(registered.get("error", "DropRegistrationFailed")))
		return false
	_battle_drops_changed = _battle_drops_changed or registered.registered
	if hyperspace_system.manual_active():
		if result.player_dead:
			return _finish_hyperspace_manual(false)
		if result.wave_cleared:
			var final: bool = hyperspace_system.wave_cleared()
			battle.finish_wave(final)
			if final: return _finish_hyperspace_manual(true)
			_start_hyperspace_wave()
			return run_state.is_running()
		return true
	return campaign_system.observe_battle(result, equipment.clear_switch_locks, settle_final_collection)

func start_hyperspace_manual(route: String) -> Dictionary:
	if not run_state.is_running(): return run_state.rejection()
	var progress: Dictionary = campaign_system.progress_facts()
	var target: Dictionary = campaign_system.hyperspace_return_target()
	var prepared: Dictionary = hyperspace_system.prepare_manual(route, int(progress.cycle_reached), target, float(_planet_factors.luck))
	if not prepared.ok: return prepared
	if not settle_final_collection(): return run_state.rejection()
	equipment.clear_switch_locks()
	battle.reset_for_sortie()
	campaign_system.enter_hyperspace(false)
	hyperspace_system.accept_manual(prepared.receipt)
	_start_hyperspace_wave()
	if not run_state.is_running(): return run_state.rejection()
	if _final_collection_changed: economy.publish_budget_change()
	campaign_system.publish_status_change()
	return {"ok": true, "receipt": hyperspace_system.manual_receipt()}

func exit_hyperspace_manual() -> Dictionary:
	if not run_state.is_running(): return run_state.rejection()
	if not hyperspace_system.manual_active(): return {"ok": false, "reason": "NoManualChallenge"}
	if not _finish_hyperspace_manual(false): return run_state.rejection()
	if _final_collection_changed: economy.publish_budget_change()
	campaign_system.publish_status_change()
	return {"ok": true, "receipt": hyperspace_system.manual_receipt()}

func claim_hyperspace(run_id: int) -> Dictionary:
	if not run_state.is_running(): return run_state.rejection()
	var claim: Dictionary = hyperspace_system.prepare_claim(run_id)
	if not claim.ok or claim.already_claimed: return claim
	var credited: Dictionary = _hyperspace_credit(claim.reward)
	if not credited.ok: return credited
	var future_modules: Dictionary = hyperspace_system.future_module_contributions(claim.reward.hanging_rewards)
	if future_modules != hyperspace_system.module_contributions():
		var loadout: Dictionary = hyperspace_system.prepare_loadout(hyperspace_system.equipped_ids(),
			int(campaign_system.ship_facts().drone_capacity), _hyperspace_weapon_source())
		if not loadout.ok: return loadout
		var published: Dictionary = publish_equipment_refit(credited.wallet, "refit", "", loadout.contributions, false,
			func(): hyperspace_system.accept_claim(run_id), {}, future_modules)
		if published.ok: notifications.record("hyperspace", str(hyperspace_system.save_state().round_id) + ":" + str(run_id))
		return {"ok": true, "already_claimed": false, "reward": claim.reward} if published.ok else published
	hyperspace_system.accept_claim(run_id)
	notifications.record("hyperspace", str(hyperspace_system.save_state().round_id) + ":" + str(run_id))
	var changed: bool = economy.accept_budget(credited.wallet, false)
	if changed: economy.publish_budget_change()
	return {"ok": true, "already_claimed": false, "reward": claim.reward}

func dismantle_hyperspace_drone(id: String) -> Dictionary:
	if not run_state.is_running(): return run_state.rejection()
	var prepared: Dictionary = hyperspace_system.prepare_dismantle(id)
	if not prepared.ok: return prepared
	var credited: Dictionary = _hyperspace_credit(prepared.reward)
	if not credited.ok: return credited
	var future_modules: Dictionary = hyperspace_system.future_module_contributions(prepared.reward.hanging_rewards)
	if future_modules != hyperspace_system.module_contributions():
		var loadout: Dictionary = hyperspace_system.prepare_loadout(hyperspace_system.equipped_ids(),
			int(campaign_system.ship_facts().drone_capacity), _hyperspace_weapon_source())
		if not loadout.ok: return loadout
		var published: Dictionary = publish_equipment_refit(credited.wallet, "refit", "", loadout.contributions, false,
			func(): hyperspace_system.accept_dismantle(id, prepared.reward), {}, future_modules)
		return {"ok": true, "reward": prepared.reward} if published.ok else published
	hyperspace_system.accept_dismantle(id, prepared.reward)
	var changed: bool = economy.accept_budget(credited.wallet, false)
	if changed: economy.publish_budget_change()
	return {"ok": true, "reward": prepared.reward}

func _hyperspace_credit(reward: Dictionary) -> Dictionary:
	var next_wallet: Dictionary = economy.budget().duplicate()
	var amounts: Dictionary = reward.materials.duplicate()
	if int(reward.ultimate_cores) > 0: amounts.ultimate_cores = int(reward.ultimate_cores)
	for resource in amounts:
		var quantity = amount_api.apply("from_decimal", [str(amounts[resource])])
		if not quantity.ok: return quantity
		var old = next_wallet.get(resource, amount_api.apply("zero", []).value)
		var added = amount_api.apply("add", [old, quantity.value])
		if not added.ok: return added
		next_wallet[resource] = added.value
	return {"ok": true, "wallet": next_wallet}

func start_hyperspace_single(route: String) -> Dictionary:
	if not run_state.is_running(): return run_state.rejection()
	if not hyperspace_system.unlocked(int(campaign_system.progress_facts().cycle_reached)):
		return {"ok": false, "reason": "HyperspaceLocked"}
	var prepared: Dictionary = hyperspace_system.prepare_idle(route, false, "", 0, float(_planet_factors.luck))
	if not prepared.ok: return prepared
	hyperspace_system.accept_idle(prepared.receipt, false)
	return {"ok": true, "receipt": hyperspace_system.online_status().idle}

func start_hyperspace_auto(route: String, crew_id: String) -> Dictionary:
	if not run_state.is_running(): return run_state.rejection()
	if hyperspace_system.online_status().auto.enabled: return {"ok": false, "reason": "AutoRunning"}
	if not hyperspace_system.unlocked(int(campaign_system.progress_facts().cycle_reached)):
		return {"ok": false, "reason": "HyperspaceLocked"}
	var crew: Dictionary = crew_system.hyperspace_candidate(crew_id)
	if not crew.ok: return crew
	var prepared: Dictionary = hyperspace_system.prepare_idle(route, true, crew_id, int(crew.level), float(_planet_factors.luck))
	if not prepared.ok: return prepared
	var reserved: Dictionary = crew_system.reserve_hyperspace(crew_id, route, false)
	if not reserved.ok: return reserved
	hyperspace_system.accept_idle(prepared.receipt, true)
	crew_system.publish_members([crew_id])
	return {"ok": true, "receipt": hyperspace_system.online_status().idle}

func stop_hyperspace_auto() -> Dictionary:
	if not run_state.is_running(): return run_state.rejection()
	var stopped: Dictionary = hyperspace_system.stop_auto()
	if not stopped.ok: return stopped
	var members: Array = crew_system.release_hyperspace(str(stopped.route), false)
	crew_system.publish_members(members)
	return {"ok": true}

func _start_hyperspace_wave() -> void:
	var latest_cleared: int = 1
	for stage in campaign_system.progress_facts().cleared_stages:
		latest_cleared = maxi(latest_cleared, int(stage))
	var inputs: Dictionary = battle.wave_inputs()
	var setup: Dictionary = hyperspace_system.prepare_wave(latest_cleared, equipment.enemy_override,
		inputs.geometry, inputs.motion, campaign_system.jewel_drop_probability())
	if not setup.ok:
		_fail(str(setup.get("reason", "HyperspaceWaveAssemblyFailed")))
		return
	var started: Dictionary = battle.start_wave(setup)
	if not started.ok:
		_fail(str(started.get("reason", "HyperspaceNativeWaveRejected")))
		return
	hyperspace_system.accept_wave(setup)

func _finish_hyperspace_manual(success: bool) -> bool:
	if not settle_final_collection(): return false
	var finished: Dictionary = hyperspace_system.finish_manual(success)
	if not finished.ok:
		_fail(str(finished.reason))
		return false
	if success: notifications.record("hyperspace", str(finished.receipt.round_id) + ":" + str(finished.receipt.run_id))
	battle.reset_for_sortie()
	campaign_system.return_from_hyperspace(finished.receipt.return_target, false)
	return true

func settle_final_collection() -> bool:
	var settled = economy.collect_due(wall_time, game_time, true, _income_factors, false)
	if not settled.ok:
		_fail(str(settled.get("error", "FinalCollectionFailed")))
		return false
	_final_collection_changed = _final_collection_changed or settled.collected
	return true

func _start_wave() -> void:
	var inputs: Dictionary = battle.wave_inputs()
	var setup = campaign_system.prepare_wave(equipment.enemy_override, inputs.geometry, inputs.motion)
	if not setup.ok:
		_fail(str(setup.get("error", setup.get("reason", "WaveAssemblyFailed"))))
		return
	var started = battle.start_wave(setup)
	if not started.ok:
		_fail(str(started.reason))
		return
	campaign_system.accept_wave(setup)

func _fail(reason: String) -> Dictionary:
	run_state.fail(reason)
	pause_reasons.error = true
	return {"ok": false, "reason": reason, "fault": true}

func economy_display_context() -> Dictionary:
	var context := {"wall": wall_time, "game": game_time, "factors": _income_factors}
	context.make_read_only()
	return context

func reactor_inputs() -> Dictionary:
	var multiplier: Dictionary = _hyperspace_module_factor("extra_storage")
	if not multiplier.ok: return multiplier
	var capacity: Dictionary = amount_api.apply("mul", [_world_factors.capacity, multiplier.value])
	if not capacity.ok: return capacity
	return {"capacity": capacity.value, "free_charge": _world_factors.free_charge}

func _hyperspace_module_factor(module_id: String, totals = null) -> Dictionary:
	var active: Dictionary = hyperspace_system.module_contributions() if totals == null else totals
	return amount_api.apply("from_decimal", [str(1.0 + float(active.get(module_id, 0.0)))])

func equipment_inputs() -> Dictionary:
	return {"mounts": campaign_system.ship_facts().mounts, "balances": economy.budget(),
		"game_time": game_time}

func _growth_setup(next_ship: String = "", contributions = null, hanging_overrides: Dictionary = {}, module_totals = null,
		drone_replacements: Dictionary = {}, refresh_contributions: bool = true) -> Dictionary:
	if not run_state.is_running(): return run_state.rejection()
	var ship_key: String = campaign_system.selected_ship() if next_ship.is_empty() else next_ship
	var ship: Dictionary = campaign_system.ship_facts(ship_key)
	var mount: Dictionary = battle.mount_inputs(ship_key)
	var world = _world_factors
	if not world.ok:
		return world
	var drone_ids = null
	if contributions != null:
		drone_ids = []
		for contribution in contributions: drone_ids.append(str(contribution.id))
	var modules: Dictionary = hyperspace_system.module_contributions(drone_ids, hanging_overrides) if module_totals == null else module_totals
	var storage: Dictionary = _hyperspace_module_factor("extra_storage", modules)
	if not storage.ok: return storage
	var capacity: Dictionary = amount_api.apply("mul", [world.capacity, storage.value])
	if not capacity.ok: return capacity
	var reactor = reactor_system.prepare({"capacity": capacity.value, "free_charge": world.free_charge})
	if not reactor.ok:
		return reactor
	var ai = research.contributions()
	if not ai.ok: return ai
	var factors := {"ai_weapon": ai["values"].weapon_damage, "ai_defence": ai["values"].equipment_durability,
		"reactor_weapon": reactor.factors.weapons, "reactor_defence": reactor.factors.defence, "external": world.external}
	var upgrades = enhancement.evaluate(int(world.enhancement_levels), campaign_system.available, equipment.equipped_armours(ship.mounts))
	if not upgrades.ok: return upgrades
	var mounted = equipment.mounted_configuration(ship.mounts, int(world.equipment_levels), ai["values"], reactor.factors,
		mount.art, mount.dimensions, mount.geometry, mount.motion, world.external)
	if not mounted.ok: return mounted
	if contributions == null:
		var refreshed: Dictionary = _prepare_drone_growth(ai["values"], reactor.factors, int(world.equipment_levels))
		if not refreshed.ok: return refreshed
		contributions = refreshed.contributions
	elif refresh_contributions:
		var refreshed: Dictionary = hyperspace_system.prepare_loadout(drone_ids, int(ship.drone_capacity),
			_hyperspace_weapon_source(ai["values"], reactor.factors, int(world.equipment_levels)), drone_replacements)
		if not refreshed.ok: return refreshed
		contributions = refreshed.contributions
	var setup = battle.prepare_player(mounted, upgrades, factors, reactor.factors, ship, ship_key, mount, contributions, equipment.damage_types())
	if not setup.ok:
		return setup
	setup.ship_key = ship_key
	var collector = _hyperspace_module_factor("resource_collector", modules)
	if not collector.ok: return collector
	setup.income_factors = {"condensation": reactor.factors.condensation, "refinery": world.refinery,
		"resource_collection": collector.value, "crew_fragments": world.fragments, "galaxy_fragments": world.galaxy_fragments}
	var algorithm: Dictionary = _hyperspace_module_factor("distributed_algorithm", modules)
	if not algorithm.ok: return algorithm
	var research_speed: Dictionary = amount_api.apply("mul", [world.research, algorithm.value])
	if not research_speed.ok: return research_speed
	setup.research_speed = research_speed.value
	setup.galaxy_crew_experience = world.crew_experience
	setup.income_factors.iron = ai["values"].iron_income
	setup.income_factors.uranium = ai["values"].uranium_income
	var refiner: Dictionary = _hyperspace_module_factor("gem_refiner", modules)
	if not refiner.ok: return refiner
	var jewel_income: Dictionary = amount_api.apply("mul", [ai["values"].fragment_income, refiner.value])
	if not jewel_income.ok: return jewel_income
	setup.income_factors.jewel = jewel_income.value
	setup.income_factors.make_read_only()
	setup.research_factors = ai["values"]
	setup.reactor_factors = reactor.factors
	setup.drone_contributions = contributions
	return setup

func publish_equipment_refit(next_wallet: Dictionary, change_kind: String, next_ship: String = "", contributions = null, accept_equipment: bool = true, accept_drones: Callable = Callable(), hanging_overrides: Dictionary = {}, module_totals = null, drone_replacements: Dictionary = {}, refresh_contributions: bool = true) -> Dictionary:
	if not run_state.is_running(): return run_state.rejection()
	var geometry_changed: bool = (not next_ship.is_empty() and next_ship != campaign_system.selected_ship()) or contributions != null
	geometry_changed = geometry_changed or equipment.geometry_changed()
	var setup = _growth_setup(next_ship, contributions, hanging_overrides, module_totals, drone_replacements, refresh_contributions)
	if not setup.ok:
		reactor_system.discard_prepared()
		enhancement.discard_output()
		return setup
	# No page callbacks or asynchronous work can interleave this commit.
	var committed: Dictionary = battle.commit_player(change_kind, geometry_changed)
	if not committed.ok:
		reactor_system.discard_prepared()
		enhancement.discard_output()
		if committed.get("fault", false):
			return _fail(str(committed.reason))
		return committed
	var equipment_notice: Dictionary = {}
	if accept_equipment:
		equipment_notice = equipment.accept_prepared()
	if accept_drones.is_valid(): accept_drones.call()
	reactor_system.accept()
	_reactor_factors = setup.reactor_factors
	_research_factors = setup.research_factors
	enhancement.accept_output()
	_income_factors = setup.income_factors
	_research_speed = setup.research_speed
	_galaxy_crew_experience = setup.galaxy_crew_experience
	var ship_changed: bool = campaign_system.accept_ship(str(setup.ship_key), false)
	var budget_changed: bool = economy.accept_budget(next_wallet, false)
	campaign_system.retreat_if_dead(equipment.clear_switch_locks)
	if ship_changed: campaign_system.publish_ship_change()
	if budget_changed: economy.publish_budget_change()
	if accept_equipment: equipment.publish_accepted(equipment_notice)
	return {"ok": true}

func refresh_growth() -> bool:
	if not run_state.is_running(): return false
	if reactor_system.modules_changed():
		var updated = reactor_system.refresh(reactor_inputs(), publish_reactor)
		if not updated.ok:
			_fail(str(updated.get("error", updated.get("reason", "ReactorUpdateFailed"))))
			return false
	var automatic_due: bool = research.automatic_due(_crew_factors.research_staffed)
	var peaks: Dictionary = {}
	var investment: Dictionary = {}
	if economy.income_changed():
		var query = economy.income_rates(wall_time, game_time, research.income_window(), "peak")
		if not query.ok:
			_fail(str(query.get("error", "IncomeQueryFailed")))
			return false
		peaks = query.rates
	if automatic_due:
		var query = economy.income_rates(wall_time, game_time, research.income_window(), "investment")
		if not query.ok:
			_fail(str(query.get("error", "IncomeQueryFailed")))
			return false
		investment = query.rates
	var refreshed = research.refresh_income(peaks, investment, economy.income_changed(), automatic_due)
	if not refreshed.ok:
		_fail(str(refreshed.get("error", "ResearchIncomeFailed")))
		return false
	var factors_changed: bool = refreshed.factors_changed
	economy.acknowledge_income()
	if factors_changed:
		var changed = _publish_research()
		if not changed.ok:
			_fail(str(changed.get("error", changed.get("reason", "GrowthUpdateFailed"))))
			return false
	return true

# World/equipment availability and payment/native publication are the cross-module ports.
func enhancement_inputs() -> Dictionary:
	return {"bonus": int(_world_factors.enhancement_levels), "unlocked": campaign_system.available,
		"armours": equipment.equipped_armours(campaign_system.ship_facts().mounts)}

func publish_enhancement(changed: Dictionary, costs: Dictionary, kind: String) -> Dictionary:
	if not run_state.is_running(): return run_state.rejection()
	var paid: Dictionary = {"ok": true, "wallet": economy.budget()}
	if not costs.is_empty(): paid = economy.payment(costs)
	if not paid.ok: return paid
	var result = _commit_values({"weapons": {}, "defences": {}}, kind, "", changed, false)
	if result.ok:
		enhancement.accept_prepared()
		var budget_changed: bool = economy.accept_budget(paid.wallet, false)
		if result.defence_changed: campaign_system.retreat_if_dead(equipment.clear_switch_locks)
		if budget_changed: economy.publish_budget_change()
	return result

func commit_ship_refit(ship_id: String) -> Dictionary:
	if not run_state.is_running(): return run_state.rejection()
	var ids: Array = hyperspace_system.equipped_ids().slice(0, int(campaign_system.ship_facts(ship_id).drone_capacity))
	var prepared: Dictionary = hyperspace_system.prepare_loadout(ids, int(campaign_system.ship_facts(ship_id).drone_capacity), _hyperspace_weapon_source())
	if not prepared.ok: return prepared
	return equipment.resize_mounts(campaign_system.ship_facts().mounts, campaign_system.ship_facts(ship_id).mounts,
		economy.budget(), func(balances, kind):
			return publish_equipment_refit(balances, kind, ship_id, prepared.contributions, true,
				func(): hyperspace_system.accept_loadout(prepared.ids)))

func set_equipped_drone_contributions(contributions: Array) -> Dictionary:
	if not run_state.is_running(): return run_state.rejection()
	var valid = battle.validate_drones(contributions, int(campaign_system.ship_facts().drone_capacity))
	if not valid.ok: return valid
	return publish_equipment_refit(economy.budget(), "refit", "", contributions, false, Callable(), {}, null, {}, false)

func equip_hyperspace_drones(ids: Array) -> Dictionary:
	if not run_state.is_running(): return run_state.rejection()
	var prepared: Dictionary = hyperspace_system.prepare_loadout(ids, int(campaign_system.ship_facts().drone_capacity), _hyperspace_weapon_source())
	if not prepared.ok: return prepared
	return publish_equipment_refit(economy.budget(), "refit", "", prepared.contributions, false,
		func(): hyperspace_system.accept_loadout(prepared.ids))

func _hyperspace_weapon_source(ai = null, reactor = null, equipment_levels: int = -1) -> Callable:
	var motion: Dictionary = battle.wave_inputs().motion
	var research_values: Dictionary = _research_factors if ai == null else ai
	var reactor_values: Dictionary = _reactor_factors if reactor == null else reactor
	var levels: int = int(_world_factors.equipment_levels) if equipment_levels < 0 else equipment_levels
	return func(drone):
		return equipment.drone_weapon_source(str(drone.weapon), hyperspace_system.weapon_level_bonus(drone),
			levels, research_values, reactor_values, motion)

func _prepare_drone_growth(ai: Dictionary, reactor: Dictionary, equipment_levels: int) -> Dictionary:
	return hyperspace_system.prepare_loadout(hyperspace_system.equipped_ids(),
		int(campaign_system.ship_facts().drone_capacity), _hyperspace_weapon_source(ai, reactor, equipment_levels))

func preview_hyperspace_forge(id: String, operation: String, args: Dictionary = {}) -> Dictionary:
	if not run_state.is_running(): return run_state.rejection()
	return hyperspace_system.preview_forge(id, operation, args, int(campaign_system.progress_facts().cycle_reached))

func forge(id: String, operation: String, args: Dictionary, operation_id: String) -> Dictionary:
	if not run_state.is_running(): return run_state.rejection()
	if operation_id.is_empty(): return {"ok": false, "reason": "OperationIdRequired"}
	var fingerprint: String = JSON.stringify({"id": id, "operation": operation, "args": args}, "", true)
	var repeated: Dictionary = hyperspace_system.forge_repeat(operation_id, fingerprint)
	if not repeated.is_empty(): return repeated
	var forecast: Dictionary = hyperspace_system.preview_forge(id, operation, args, int(campaign_system.progress_facts().cycle_reached))
	if not forecast.ok: return forecast
	var costs: Dictionary = {}
	for resource in forecast.costs:
		var amount: Dictionary = amount_api.apply("from_decimal", [str(forecast.costs[resource])])
		if not amount.ok: return amount
		costs[resource] = amount.value
	var paid: Dictionary = economy.payment(costs)
	if not paid.ok: return paid
	var result: Dictionary = {"ok": true, "drone": forecast.drone.duplicate(true), "costs": forecast.costs.duplicate(), "draws": forecast.draws}
	if id in hyperspace_system.equipped_ids():
		var prepared: Dictionary = hyperspace_system.prepare_loadout(hyperspace_system.equipped_ids(),
			int(campaign_system.ship_facts().drone_capacity), _hyperspace_weapon_source(), {id: forecast.drone})
		if not prepared.ok: return prepared
		if battle.matches_drone_contributions(prepared.contributions):
			hyperspace_system.accept_forge(id, forecast.drone, operation_id, fingerprint, result)
			if economy.accept_budget(paid.wallet, false): economy.publish_budget_change()
			return result
		var committed: Dictionary = publish_equipment_refit(paid.wallet, "refit", "", prepared.contributions, false,
			func(): hyperspace_system.accept_forge(id, forecast.drone, operation_id, fingerprint, result), {}, null, {id: forecast.drone})
		return result if committed.ok else committed
	hyperspace_system.accept_forge(id, forecast.drone, operation_id, fingerprint, result)
	if economy.accept_budget(paid.wallet, false): economy.publish_budget_change()
	return result

func save_hyperspace_preset(name: String) -> Dictionary:
	if not run_state.is_running(): return run_state.rejection()
	return hyperspace_system.save_preset(name)

func apply_hyperspace_preset(name: String) -> Dictionary:
	if not run_state.is_running(): return run_state.rejection()
	var prepared: Dictionary = hyperspace_system.prepare_preset(name, int(campaign_system.ship_facts().drone_capacity),
		int(campaign_system.progress_facts().cycle_reached), _hyperspace_weapon_source())
	if not prepared.ok: return prepared
	var hangings: Dictionary = {}
	for entry in prepared.entries: hangings[str(entry.id)] = entry.hangings
	return publish_equipment_refit(economy.budget(), "refit", "", prepared.contributions, false,
		func(): hyperspace_system.accept_preset(prepared), hangings)

func set_hyperspace_hangings(id: String, module_ids: Array) -> Dictionary:
	if not run_state.is_running(): return run_state.rejection()
	var prepared: Dictionary = hyperspace_system.prepare_hangings(id, module_ids,
		int(campaign_system.progress_facts().cycle_reached))
	if not prepared.ok: return prepared
	if id in hyperspace_system.equipped_ids():
		var loadout: Dictionary = hyperspace_system.prepare_loadout(hyperspace_system.equipped_ids(),
			int(campaign_system.ship_facts().drone_capacity), _hyperspace_weapon_source())
		if not loadout.ok: return loadout
		return publish_equipment_refit(economy.budget(), "refit", "", loadout.contributions, false,
			func(): hyperspace_system.accept_hangings(id, prepared.hangings), {id: prepared.hangings})
	hyperspace_system.accept_hangings(id, prepared.hangings)
	return {"ok": true}

func exchange_hyperspace_materials(source: String, target: String, amount: String) -> Dictionary:
	if not run_state.is_running(): return run_state.rejection()
	var materials: Array = hyperspace_system.material_ids()
	if source == target or source not in materials or target not in materials:
		return {"ok": false, "reason": "InvalidExchange"}
	var received: Dictionary = amount_api.apply("from_decimal", [amount.strip_edges()])
	if not received.ok: return received
	var zero: Dictionary = amount_api.apply("zero", [])
	if not zero.ok: return zero
	var positive: Dictionary = amount_api.apply("compare", [received.value, zero.value])
	if not positive.ok: return positive
	var integer: Dictionary = amount_api.apply("floor", [received.value])
	if not integer.ok: return integer
	var integral: Dictionary = amount_api.apply("compare", [received.value, integer.value])
	if not integral.ok: return integral
	if int(positive.scalar) <= 0 or int(integral.scalar) != 0: return {"ok": false, "reason": "InvalidExchange"}
	var doubled: Dictionary = amount_api.apply("mul", [received.value, amount_api.apply("from_decimal", ["2"]).value])
	if not doubled.ok: return doubled
	var paid: Dictionary = economy.payment({source: doubled.value})
	if not paid.ok: return paid
	var old = paid.wallet.get(target, amount_api.apply("zero", []).value)
	var credited: Dictionary = amount_api.apply("add", [old, received.value])
	if not credited.ok: return credited
	var wallet: Dictionary = paid.wallet.duplicate()
	wallet[target] = credited.value
	if economy.accept_budget(wallet, false): economy.publish_budget_change()
	return {"ok": true}

func _world_contributions() -> Dictionary:
	for result in [_planet_factors, _crew_factors, _galaxy_factors]:
		if not result.ok: return result
	var galaxy: Dictionary = _galaxy_factors["values"]
	var sources: Array = [_planet_factors.equipment, _crew_factors.equipment, galaxy.equipment_value]
	var external: Array = _world_factors.get("external", []).duplicate()
	for index in sources.size():
		if _world_factors.get("_external_sources", []).size() > index and _world_factors._external_sources[index] == sources[index]: continue
		var text = amount_api.apply("to_display", [sources[index]])
		if not text.ok: return text
		if external.size() <= index: external.append(text.text)
		else: external[index] = text.text
	var capacity_sources: Array = [_crew_factors.capacity, galaxy.charge_max]
	var capacity: Dictionary = _world_factors.get("capacity", {})
	if _world_factors.get("_capacity_sources", []) != capacity_sources:
		var value = amount_api.apply("mul", capacity_sources)
		if not value.ok: return value
		capacity = value.value
	external.make_read_only()
	sources.make_read_only()
	capacity_sources.make_read_only()
	var published := {"ok": true, "external": external, "capacity": capacity, "fragments": _crew_factors.fragments,
		"galaxy_fragments": galaxy.gem_fragment, "crew_experience": galaxy.crew_exp,
		"research": _crew_factors.research, "refinery": _planet_factors.refinery,
		"equipment_levels": _planet_factors.equipment_levels, "enhancement_levels": _planet_factors.enhancement_levels,
		"free_charge": _planet_factors.free_charge, "_external_sources": sources, "_capacity_sources": capacity_sources}
	published.make_read_only()
	return published

func _publish_native_values(ai: Dictionary, reactor: Dictionary, kind: String, retreat_after_commit: bool = true) -> Dictionary:
	var weapons: bool = ai.weapon_damage != _research_factors.weapon_damage or reactor.weapons != _reactor_factors.weapons
	var defences: bool = ai.equipment_durability != _research_factors.equipment_durability or reactor.defence != _reactor_factors.defence
	var iron: String = ""
	if reactor.smelting != _reactor_factors.smelting:
		var text = amount_api.apply("to_display", [reactor.smelting])
		if not text.ok: return text
		iron = text.text
	var values: Dictionary = {"weapons": {}, "defences": {}}
	if weapons or defences:
		values = equipment.values(campaign_system.ship_facts().mounts, int(_world_factors.equipment_levels), ai, reactor, weapons, defences)
		if not values.ok: return values
	battle.filter_values(values)
	var drones: Dictionary = _prepare_drone_growth(ai, reactor, int(_world_factors.equipment_levels))
	if not drones.ok: return drones
	return _commit_values(values, kind, iron, {}, retreat_after_commit, drones.contributions)

func _commit_values(values: Dictionary, kind: String, iron: String = "", upgrades: Dictionary = {}, retreat_after_commit: bool = true, drone_contributions = null) -> Dictionary:
	if not run_state.is_running(): return run_state.rejection()
	if drone_contributions != null:
		battle.append_drone_growth(values, drone_contributions, _world_factors.external)
		battle.filter_values(values)
	var committed: Dictionary = battle.commit_values(values, kind, iron, upgrades)
	if not committed.ok: return _fail(str(committed.reason)) if committed.get("fault", false) else committed
	if drone_contributions != null: battle.accept_drone_growth(drone_contributions)
	if committed.defence_changed and retreat_after_commit: campaign_system.retreat_if_dead(equipment.clear_switch_locks)
	return {"ok": true, "defence_changed": committed.defence_changed}

func publish_equipment_levels(balances: Dictionary) -> Dictionary:
	if not run_state.is_running(): return run_state.rejection()
	var values = equipment.values(campaign_system.ship_facts().mounts, int(_world_factors.equipment_levels), _research_factors, _reactor_factors, true, true, true)
	if not values.ok: return values
	var drones: Dictionary = _prepare_drone_growth(_research_factors, _reactor_factors, int(_world_factors.equipment_levels))
	if not drones.ok: return drones
	var result = _commit_values(values, "upgrade", "", {}, false, drones.contributions)
	if result.ok:
		var notice: Dictionary = equipment.accept_prepared()
		var budget_changed: bool = economy.accept_budget(balances, false)
		if result.defence_changed: campaign_system.retreat_if_dead(equipment.clear_switch_locks)
		if budget_changed: economy.publish_budget_change()
		equipment.publish_accepted(notice)
	return result

func _publish_world_values(previous: Dictionary, retreat_after_commit: bool = true) -> Dictionary:
	var reactor: Dictionary = {"ok": true, "factors": _reactor_factors}
	var reactor_prepared: bool = _world_factors.capacity != previous.capacity or _world_factors.free_charge != previous.free_charge
	if reactor_prepared:
		reactor = reactor_system.prepare(reactor_inputs())
		if not reactor.ok: return reactor
	var levels: bool = _world_factors.equipment_levels != previous.equipment_levels
	var weapons: bool = levels or reactor.factors.weapons != _reactor_factors.weapons
	var defences: bool = levels or reactor.factors.defence != _reactor_factors.defence
	var values: Dictionary = {"weapons": {}, "defences": {}}
	if weapons or defences:
		values = equipment.values(campaign_system.ship_facts().mounts, int(_world_factors.equipment_levels), _research_factors, reactor.factors, weapons, defences)
		if not values.ok: return values
	if _world_factors.external != previous.external:
		equipment.apply_external(values, campaign_system.ship_facts().mounts, _world_factors.external)
	var drones: Dictionary = _prepare_drone_growth(_research_factors, reactor.factors, int(_world_factors.equipment_levels))
	if not drones.ok: return drones
	var output: Dictionary = enhancement.published_output()
	var upgrades: Dictionary = {}
	var enhancement_prepared: bool = _world_factors.enhancement_levels != previous.enhancement_levels
	if enhancement_prepared:
		output = enhancement.evaluate(int(_world_factors.enhancement_levels), campaign_system.available, equipment.equipped_armours(campaign_system.ship_facts().mounts))
		if not output.ok: return output
		upgrades = enhancement.difference(output)
	var iron: String = ""
	if reactor.factors.smelting != _reactor_factors.smelting:
		var text = amount_api.apply("to_display", [reactor.factors.smelting])
		if not text.ok: return text
		iron = text.text
	var result = _commit_values(values, "refit", iron, upgrades, false, drones.contributions)
	if result.ok and enhancement_prepared: enhancement.accept_output()
	if result.ok:
		if reactor_prepared: reactor_system.accept()
		_reactor_factors = reactor.factors
		if _income_factors.condensation != reactor.factors.condensation:
			var income: Dictionary = _income_factors.duplicate()
			income.condensation = reactor.factors.condensation
			income.make_read_only()
			_income_factors = income
		if result.defence_changed and retreat_after_commit: campaign_system.retreat_if_dead(equipment.clear_switch_locks)
	return result

func _publish_research() -> Dictionary:
	var result = research.contributions()
	if not result.ok: return result
	var values: Dictionary = result["values"]
	var refiner: Dictionary = _hyperspace_module_factor("gem_refiner")
	if not refiner.ok: return refiner
	var jewel: Dictionary = amount_api.apply("mul", [values.fragment_income, refiner.value])
	if not jewel.ok: return jewel
	var updated = _publish_native_values(values, _reactor_factors, "growth")
	if not updated.ok: return updated
	_research_factors = values
	if _income_factors.iron != values.iron_income or _income_factors.uranium != values.uranium_income or _income_factors.jewel != jewel.value:
		var income: Dictionary = _income_factors.duplicate()
		income.iron = values.iron_income
		income.uranium = values.uranium_income
		income.jewel = jewel.value
		income.make_read_only()
		_income_factors = income
	return {"ok": true}

func publish_reactor(factors: Dictionary, next_wallet, kind: String, retreat_after_commit: bool = true) -> Dictionary:
	if not run_state.is_running(): return run_state.rejection()
	var updated = _publish_native_values(_research_factors, factors, kind, false)
	if not updated.ok: return updated
	reactor_system.accept()
	_reactor_factors = factors
	if _income_factors.condensation != factors.condensation:
		var income: Dictionary = _income_factors.duplicate()
		income.condensation = factors.condensation
		income.make_read_only()
		_income_factors = income
	var budget_changed: bool = next_wallet != null and economy.accept_budget(next_wallet, false)
	if updated.defence_changed and retreat_after_commit: campaign_system.retreat_if_dead(equipment.clear_switch_locks)
	if budget_changed: economy.publish_budget_change()
	return {"ok": true, "defence_changed": updated.defence_changed}

func publish_world(planet: Dictionary = {}, crew: Dictionary = {}, galaxy: Dictionary = {}, retreat_after_commit: bool = true) -> Dictionary:
	if not run_state.is_running(): return run_state.rejection()
	var old_planet: Dictionary = _planet_factors
	var old_crew: Dictionary = _crew_factors
	var old_galaxy: Dictionary = _galaxy_factors
	var old_income: Dictionary = _income_factors
	var old_research_speed: Dictionary = _research_speed
	var old_crew_experience: Dictionary = _galaxy_crew_experience
	if not planet.is_empty(): _planet_factors = planet
	if not crew.is_empty(): _crew_factors = crew
	if not galaxy.is_empty(): _galaxy_factors = galaxy
	var world = _world_contributions()
	if not world.ok:
		_planet_factors = old_planet
		_crew_factors = old_crew
		_galaxy_factors = old_galaxy
		return world
	var previous: Dictionary = _world_factors
	_world_factors = world
	if _income_factors.refinery != world.refinery or _income_factors.crew_fragments != world.fragments or _income_factors.galaxy_fragments != world.galaxy_fragments:
		var income: Dictionary = _income_factors.duplicate()
		income.refinery = world.refinery
		income.crew_fragments = world.fragments
		income.galaxy_fragments = world.galaxy_fragments
		income.make_read_only()
		_income_factors = income
	var algorithm: Dictionary = _hyperspace_module_factor("distributed_algorithm")
	if not algorithm.ok: return algorithm
	var speed: Dictionary = amount_api.apply("mul", [world.research, algorithm.value])
	if not speed.ok: return speed
	_research_speed = speed.value
	_galaxy_crew_experience = world.crew_experience
	var result: Dictionary = {"ok": true}
	if world.enhancement_levels != previous.enhancement_levels or world.external != previous.external or world.equipment_levels != previous.equipment_levels or world.capacity != previous.capacity or world.free_charge != previous.free_charge:
		result = _publish_world_values(previous, retreat_after_commit)
	if not result.ok and run_state.is_running():
		reactor_system.discard_prepared()
		enhancement.discard_output()
		_planet_factors = old_planet
		_crew_factors = old_crew
		_galaxy_factors = old_galaxy
		_world_factors = previous
		_income_factors = old_income
		_research_speed = old_research_speed
		_galaxy_crew_experience = old_crew_experience
		return result
	return result

func publish_planet_claim(planet: Dictionary) -> Dictionary:
	var result: Dictionary = publish_world(planet, {}, {}, false)
	if result.ok:
		var accepted: Dictionary = planet_system.accept_prepared_claim()
		if result.get("defence_changed", false): campaign_system.retreat_if_dead(equipment.clear_switch_locks)
		planet_system.publish_claim(accepted)
	return result

func assignment_admission(kind: String, target: String) -> Dictionary:
	if kind in ["planet_explore", "planet_build"]: return planet_system.assignment_capacity(kind, target)
	return galaxy_system.assignment_admission(target)

func coordinate_assignment(id: String, kind: String, target: String, mode: String = "1") -> Dictionary:
	if not run_state.is_running(): return run_state.rejection()
	var changed = crew_system.assign(id, kind, target, mode, assignment_admission, false)
	if not changed.ok: return changed
	var planet_status: Array = []
	if changed.old_kind == "planet_explore" and (kind != changed.old_kind or target != changed.old_target):
		var stopped = planet_system.set_explorer(str(changed.old_target), false, false)
		if not stopped.ok: return _fail(str(stopped.reason))
		planet_status.append(str(changed.old_target))
	if kind == "planet_explore":
		var started = planet_system.set_explorer(target, true, false)
		if not started.ok: return _fail(str(started.reason))
		if target not in planet_status: planet_status.append(target)
	var result: Dictionary = publish_world({}, crew_system.contributions()) if changed.effects_changed else {"ok": true}
	if not result.ok: return _fail(str(result.get("reason", result.get("error", "AssignmentGrowthFailed"))))
	crew_system.publish_members([id])
	planet_system.publish_status(planet_status)
	return result

func coordinate_planet_cancel(id: String) -> Dictionary:
	if not run_state.is_running(): return run_state.rejection()
	var cancelled = planet_system.cancel(id, false)
	if not cancelled.ok: return cancelled
	var released: Array = crew_system.release("planet_explore", id, false)
	crew_system.publish_members(released)
	planet_system.publish_status([id])
	return cancelled

func planet_experience_context() -> Dictionary:
	return {"enabled": crew_system.experience_enabled(), "ratio": campaign_system.planet_experience_ratio(), "factor": _galaxy_crew_experience}

func _publish_progress() -> Dictionary:
	if not run_state.is_running(): return run_state.rejection()
	var facts: Dictionary = campaign_system.progress_facts()
	var research_changed: bool = research.refresh_progress(campaign_system.available, false)
	var reactor_changed: bool = reactor_system.refresh_availability(campaign_system.available, false)
	var equipment_changed: bool = equipment.refresh_availability(campaign_system.available, int(facts.cycle_reached), false)
	var crew_changed: bool = crew_system.refresh_availability(campaign_system.available, false)
	var planet_changed: bool = planet_system.refresh_availability(campaign_system.available, false)
	var galaxy_changed: bool = galaxy_system.refresh_availability(campaign_system.available, facts.cleared_stages, false)
	var planet_factors: Dictionary = planet_system.contributions()
	var crew_factors: Dictionary = crew_system.contributions()
	var galaxy_factors: Dictionary = galaxy_system.contributions()
	for result in [planet_factors, crew_factors, galaxy_factors]:
		if not result.ok:
			return _fail(str(result.get("error", result.get("reason", "ProgressContributionFailed"))))
	var defence_changed: bool = false
	if planet_factors != _planet_factors or crew_factors != _crew_factors or galaxy_factors != _galaxy_factors:
		var published: Dictionary = publish_world(planet_factors, crew_factors, galaxy_factors, false)
		if not published.ok:
			return _fail(str(published.get("reason", "ProgressGrowthFailed"))) if run_state.is_running() else published
		defence_changed = published.get("defence_changed", false)
	if reactor_system.modules_changed():
		var updated: Dictionary = reactor_system.refresh(reactor_inputs(), publish_reactor.bind(false))
		if not updated.ok:
			return _fail(str(updated.get("reason", "ProgressReactorFailed"))) if run_state.is_running() else updated
		defence_changed = defence_changed or updated.get("defence_changed", false)
	return {"ok": true, "defence_changed": defence_changed, "notices": {"research": research_changed, "reactor": reactor_changed,
		"equipment": equipment_changed, "crew": crew_changed, "planet": planet_changed, "galaxy": galaxy_changed}}

func _notify_progress(notices: Dictionary) -> void:
	if notices.research: research.publish_choices_changed()
	if notices.reactor: reactor_system.publish_availability()
	if notices.equipment: equipment.publish_availability()
	if notices.crew: crew_system.publish_availability()
	if notices.planet: planet_system.publish_availability()
	if notices.galaxy: galaxy_system.publish_availability()

func _record_unlocks() -> void:
	for id in campaign_system.available_unlock_ids():
		notifications.record("unlock", str(id))

func pending_guidance() -> Dictionary:
	var event: String = tutorial.next_prompt()
	if not event.is_empty(): return {"kind": "tutorial", "id": event}
	for row in notifications.entries():
		if row.topic == "unlock" and not row.seen:
			return {"kind": "unlock", "id": str(row.key)}
	return {}

func dismiss_guidance(kind: String, id: String) -> Dictionary:
	var pending: Dictionary = pending_guidance()
	if pending.is_empty() or pending.kind != kind or pending.id != id:
		return {"ok": false, "reason": "GuidanceMismatch"}
	var result: Dictionary = tutorial.mark_seen(id) if kind == "tutorial" else notifications.mark_seen(id)
	if result.ok: set_pause(kind, false)
	return result

func _advance_planets(dt: float, explorers: Dictionary, builders: Dictionary) -> bool:
	var result = planet_system.advance(explorers, builders, dt, planet_experience_context)
	if not result.ok:
		_fail(str(result.get("error", result.get("reason", "PlanetAdvanceFailed"))))
		return false
	var crew_changed: bool = false
	var crew_notifications: Array = []
	for completion in result.completed:
		for target in completion.released:
			for member in crew_system.release("planet_build", str(target), false):
				if member not in crew_notifications: crew_notifications.append(member)
		if completion.award_experience:
			var awarded = crew_system.award_exploration(str(completion.explorer), bool(completion.share_experience), completion.experience, false)
			if not awarded.ok:
				_fail(str(awarded.get("error", awarded.get("reason", "CrewExperienceFailed"))))
				return false
			for member in awarded.members:
				if member not in crew_notifications: crew_notifications.append(member)
			crew_changed = crew_changed or awarded.effects_changed
		if not completion.again:
			for member in crew_system.release("planet_explore", str(completion.planet), false):
				if member not in crew_notifications: crew_notifications.append(member)
	if not result.completed.is_empty():
		var published: Dictionary = publish_world(result.contributions, crew_system.contributions() if crew_changed else {})
		if not published.ok:
			_fail(str(published.get("reason", published.get("error", "PlanetGrowthFailed"))))
			return false
	crew_system.publish_members(crew_notifications)
	planet_system.publish_advance(result)
	return true

func _advance_crew_jobs(dt: float, ids: Array) -> bool:
	for request in crew_system.advance_jobs(ids, dt):
		match str(request.module):
			"equipment": equipment.buy_all_levels(int(request.count), bool(request.maximum), equipment_inputs(), economy.affordable, economy.payment, publish_equipment_levels)
			"enhancement": enhancement.purchase(int(request.count), enhancement_inputs(), economy.affordable, publish_enhancement)
			"reactor": reactor_system.purchase(int(request.count), bool(request.automatic), reactor_inputs(), economy.payment, publish_reactor)
		if not run_state.is_running(): return false
	return true

func _advance_galaxies(dt: float, counts: Dictionary) -> bool:
	var result = galaxy_system.advance(counts, dt)
	if not result.ok:
		_fail(str(result.get("reason", "GalaxyAdvanceFailed")))
		return false
	if result.has("contributions"):
		var contributions: Dictionary = result.contributions
		if not contributions.ok:
			_fail(str(contributions.get("error", "GalaxyContributionFailed")))
			return false
		_galaxy_factors = contributions
		if contributions.growth_changed:
			var published: Dictionary = publish_world({}, {}, contributions)
			if not published.ok:
				_fail(str(published.get("reason", published.get("error", "GalaxyGrowthFailed"))))
				return false
	var credits_changed: bool = false
	if not result.payments.is_empty():
		var production = economy.income_rates(wall_time, game_time, research.income_window(), "production")
		if not production.ok:
			_fail(str(production.get("error", "ProductionQueryFailed")))
			return false
		for payment in result.payments:
			var income = galaxy_system.income(str(payment.galaxy), production.rates, float(payment.seconds))
			if not income.ok:
				_fail(str(income.get("error", "GalaxyIncomeFailed")))
				return false
			for resource in income.amounts:
				var credited = economy.credit_yield(str(resource), income.amounts[resource], wall_time, game_time, false)
				if not credited.ok:
					_fail(str(credited.get("error", "GalaxyCreditFailed")))
					return false
				credits_changed = credits_changed or credited.credited
	if credits_changed: economy.publish_budget_change()
	galaxy_system.publish_status(result.displayed)
	return true
