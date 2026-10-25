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
var galaxy_crew_experience: Dictionary = {}
var research_speed: Dictionary = {}
var world_factors: Dictionary = {}
var planet_factors: Dictionary = {}
var crew_factors: Dictionary = {}
var galaxy_factors: Dictionary = {}
var research_factors: Dictionary = {}
var reactor_factors: Dictionary = {}
var income_factors: Dictionary = {}
var campaign_system
var pause_reasons: Dictionary = {}
var pending_seconds: float = 0.0
var wall_time: float = 0.0
var game_time: float = 0.0

func _init() -> void:
	income_factors.make_read_only()

func initialize(path: String, combat_seed: int) -> Dictionary:
	if not run_state.is_running(): return run_state.rejection()
	if battle != null:
		return {"ok": false, "reason": "AlreadyInitialized"}
	if not ClassDB.class_exists("SpaceCombatKernel") or not ClassDB.class_exists("FoundationAmount"):
		return _fail("NativeExtensionRequired")
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return _fail("ConfigurationReadFailed")
	var configuration: Dictionary = parsed
	var parameters: Dictionary = {}
	var rules: Dictionary = {}
	for row in configuration.config.config:
		parameters[str(row.name)] = row.para_1
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
	equipment.initialize_slots(str(parameters.startEquip), campaign_system.ship_facts().mounts)
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
	campaign_system.bind_native(battle.native_owner(), amount_api)
	planet_factors = planet_system.contributions()
	crew_factors = crew_system.contributions()
	galaxy_factors = galaxy_system.contributions()
	world_factors = _world_contributions()
	if not world_factors.ok: return _fail(str(world_factors.get("error", "WorldAssemblyFailed")))
	var setup = _growth_setup()
	if not setup.ok:
		return _fail(str(setup.get("error", setup.get("reason", "EquipmentAssemblyFailed"))))
	var initialized = battle.initialize_player(setup)
	if not initialized.ok: return _fail(str(initialized.reason))
	reactor_system.accept()
	reactor_factors = setup.reactor_factors
	research_factors = setup.research_factors
	enhancement.accept_output()
	income_factors = setup.income_factors
	research_speed = setup.research_speed
	galaxy_crew_experience = setup.galaxy_crew_experience
	campaign_system.progress_changed.connect(_publish_progress)
	return {"ok": true}

func set_pause(reason: String, held: bool) -> void:
	if not run_state.is_running(): return
	if held:
		pause_reasons[reason] = true
	else:
		pause_reasons.erase(reason)

func frame(real_dt: float, _focused: bool) -> void:
	if not run_state.is_running(): return
	if battle != null: battle.begin_frame()
	if battle == null or not is_finite(real_dt) or real_dt < 0:
		return
	wall_time += real_dt
	if not pause_reasons.is_empty():
		return
	var accepted: float = campaign_system.consume_departure(real_dt)
	pending_seconds += accepted
	var steps: int = 0
	while pending_seconds >= STEP and steps < FRAME_STEPS and not campaign_system.departure_active() and pause_reasons.is_empty() and run_state.is_running():
		_step(STEP)
		if not run_state.is_running(): return
		pending_seconds -= STEP
		steps += 1

func _step(dt: float) -> void:
	if not run_state.is_running(): return
	game_time += dt
	economy.prune_income(wall_time, game_time, research.income_window())
	var people: Dictionary = crew_system.step_assignments()
	if not _advance_planets(dt, people.explorers, people.builders) or not _advance_galaxies(dt, people.galaxies) or not _advance_crew_jobs(dt, people.jobs):
		return
	var positions: Dictionary = battle.resource_positions()
	var advanced = economy.advance_timed(dt, campaign_system.resource_generation_active(), campaign_system.timed_resource_ratio,
		positions.origin, float(positions.target_y), wall_time, game_time, income_factors)
	if not advanced.ok:
		_fail(str(advanced.get("error", advanced.get("reason", "TimedResourceFailed"))))
		return
	var researched = research.advance(economy.budget(), dt, research_speed, crew_factors.research_staffed)
	if not researched.ok:
		_fail(str(researched.get("error", researched.get("reason", "ResearchFailed"))))
		return
	economy.accept_budget(researched.wallet)
	if researched.completed:
		# Publish completion effects before collection; income-window/automatic
		# investment refresh still happens once, after this step's collections.
		var changed = _publish_research()
		if not changed.ok:
			_fail(str(changed.get("error", changed.get("reason", "ResearchGrowthUpdateFailed"))))
			return
	if researched.has("continuation_error"):
		_fail(str(researched.continuation_error))
		return
	var settled = economy.collect_due(wall_time, game_time, false, income_factors)
	if not settled.ok:
		_fail(str(settled.get("error", "CollectionFailed")))
		return

	if not refresh_growth():
		return
	campaign_system.advance(dt, _advance_kernel, _start_wave)

func _advance_kernel(dt: float) -> bool:
	if dt <= 0:
		return true
	var result = battle.advance(dt)
	if not result.ok:
		_fail(str(result.get("error", result.get("reason", "NativeAdvanceRejected"))))
		return false
	var registered = economy.register_drops(result.drops, game_time, income_factors.refinery)
	if not registered.ok:
		_fail(str(registered.get("error", "DropRegistrationFailed")))
		return false
	return campaign_system.observe_battle(result, equipment.clear_switch_locks, settle_final_collection)

func settle_final_collection() -> bool:
	var settled = economy.collect_due(wall_time, game_time, true, income_factors)
	if not settled.ok:
		_fail(str(settled.get("error", "FinalCollectionFailed")))
		return false
	return refresh_growth()

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
	return {"ok": false, "reason": reason}

func economy_display_context() -> Dictionary:
	var context := {"wall": wall_time, "game": game_time, "factors": income_factors}
	context.make_read_only()
	return context

func reactor_inputs() -> Dictionary:
	return {"capacity": world_factors.capacity, "free_charge": world_factors.free_charge}

func equipment_inputs() -> Dictionary:
	return {"mounts": campaign_system.ship_facts().mounts, "balances": economy.budget(),
		"game_time": game_time}

func _growth_setup(next_ship: String = "", contributions = null) -> Dictionary:
	if not run_state.is_running(): return run_state.rejection()
	var ship_key: String = campaign_system.selected_ship() if next_ship.is_empty() else next_ship
	var ship: Dictionary = campaign_system.ship_facts(ship_key)
	var mount: Dictionary = battle.mount_inputs(ship_key)
	var world = world_factors
	if not world.ok:
		return world
	var reactor = reactor_system.prepare(reactor_inputs())
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
	var setup = battle.prepare_player(mounted, upgrades, factors, reactor.factors, ship, ship_key, mount, contributions, equipment.damage_types())
	if not setup.ok:
		return setup
	setup.income_factors = {"condensation": reactor.factors.condensation, "refinery": world.refinery, "crew_fragments": world.fragments, "galaxy_fragments": world.galaxy_fragments}
	setup.research_speed = world.research
	setup.galaxy_crew_experience = world.crew_experience
	setup.income_factors.iron = ai["values"].iron_income
	setup.income_factors.uranium = ai["values"].uranium_income
	setup.income_factors.jewel = ai["values"].fragment_income
	setup.income_factors.make_read_only()
	setup.research_factors = ai["values"]
	setup.reactor_factors = reactor.factors
	return setup

func publish_equipment_refit(next_wallet: Dictionary, change_kind: String, next_ship: String = "", contributions = null) -> Dictionary:
	if not run_state.is_running(): return run_state.rejection()
	var geometry_changed: bool = (not next_ship.is_empty() and next_ship != campaign_system.selected_ship()) or contributions != null
	geometry_changed = geometry_changed or equipment.geometry_changed()
	var setup = _growth_setup(next_ship, contributions)
	if not setup.ok:
		return setup
	# No page callbacks or asynchronous work can interleave this commit.
	var committed: Dictionary = battle.commit_player(setup, change_kind, geometry_changed)
	if not committed.ok:
		if committed.get("fault", false):
			return _fail(str(committed.reason))
		return committed
	campaign_system.accept_ship(setup.ship_key)
	reactor_system.accept()
	reactor_factors = setup.reactor_factors
	research_factors = setup.research_factors
	enhancement.accept_output()
	income_factors = setup.income_factors
	research_speed = setup.research_speed
	galaxy_crew_experience = setup.galaxy_crew_experience
	economy.accept_budget(next_wallet)
	campaign_system.retreat_if_dead(equipment.clear_switch_locks)
	return {"ok": true}

func refresh_growth() -> bool:
	if not run_state.is_running(): return false
	if reactor_system.modules_changed():
		var updated = reactor_system.refresh(reactor_inputs(), publish_reactor)
		if not updated.ok:
			_fail(str(updated.get("error", updated.get("reason", "ReactorUpdateFailed"))))
			return false
	var automatic_due: bool = research.automatic_due(crew_factors.research_staffed)
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
	return {"bonus": int(world_factors.enhancement_levels), "unlocked": campaign_system.available,
		"armours": equipment.equipped_armours(campaign_system.ship_facts().mounts)}

func publish_enhancement(changed: Dictionary, costs: Dictionary, kind: String) -> Dictionary:
	if not run_state.is_running(): return run_state.rejection()
	var paid: Dictionary = {"ok": true, "wallet": economy.budget()}
	if not costs.is_empty(): paid = economy.payment(costs)
	if not paid.ok: return paid
	var result = _commit_values({"weapons": {}, "defences": {}}, kind, "", changed)
	if result.ok: economy.accept_budget(paid.wallet)
	return result

func commit_ship_refit(ship_id: String) -> Dictionary:
	if not run_state.is_running(): return run_state.rejection()
	return equipment.resize_mounts(campaign_system.ship_facts().mounts, campaign_system.ship_facts(ship_id).mounts,
		economy.budget(), publish_equipment_refit.bind(ship_id))

func set_equipped_drone_contributions(contributions: Array) -> Dictionary:
	if not run_state.is_running(): return run_state.rejection()
	var valid = battle.validate_drones(contributions, int(campaign_system.ship_facts().drone_capacity))
	if not valid.ok: return valid
	return publish_equipment_refit(economy.budget(), "refit", "", contributions)

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
		values = equipment.values(campaign_system.ship_facts().mounts, int(world_factors.equipment_levels), ai, reactor, weapons, defences)
		if not values.ok: return values
	battle.filter_values(values)
	return _commit_values(values, kind, iron)

func _commit_values(values: Dictionary, kind: String, iron: String = "", upgrades: Dictionary = {}) -> Dictionary:
	if not run_state.is_running(): return run_state.rejection()
	var committed: Dictionary = battle.commit_values(values, kind, iron, upgrades)
	if not committed.ok: return _fail(str(committed.reason)) if committed.get("fault", false) else committed
	if committed.defence_changed: campaign_system.retreat_if_dead(equipment.clear_switch_locks)
	return {"ok": true}

func publish_equipment_levels(balances: Dictionary) -> Dictionary:
	if not run_state.is_running(): return run_state.rejection()
	var values = equipment.values(campaign_system.ship_facts().mounts, int(world_factors.equipment_levels), research_factors, reactor_factors, true, true, true)
	if not values.ok: return values
	var result = _commit_values(values, "upgrade")
	if result.ok:
		economy.accept_budget(balances)
	return result

func _publish_world_values(previous: Dictionary) -> Dictionary:
	var reactor: Dictionary = {"ok": true, "factors": reactor_factors}
	var reactor_prepared: bool = world_factors.capacity != previous.capacity or world_factors.free_charge != previous.free_charge
	if reactor_prepared:
		reactor = reactor_system.prepare(reactor_inputs())
		if not reactor.ok: return reactor
	var levels: bool = world_factors.equipment_levels != previous.equipment_levels
	var weapons: bool = levels or reactor.factors.weapons != reactor_factors.weapons
	var defences: bool = levels or reactor.factors.defence != reactor_factors.defence
	var values: Dictionary = {"weapons": {}, "defences": {}}
	if weapons or defences:
		values = equipment.values(campaign_system.ship_facts().mounts, int(world_factors.equipment_levels), research_factors, reactor.factors, weapons, defences)
		if not values.ok: return values
	if world_factors.external != previous.external:
		equipment.apply_external(values, campaign_system.ship_facts().mounts, world_factors.external)
	if world_factors.external != previous.external:
		battle.apply_drone_external(values, world_factors.external)
	var output: Dictionary = enhancement.published_output()
	var upgrades: Dictionary = {}
	var enhancement_prepared: bool = world_factors.enhancement_levels != previous.enhancement_levels
	if enhancement_prepared:
		output = enhancement.evaluate(int(world_factors.enhancement_levels), campaign_system.available, equipment.equipped_armours(campaign_system.ship_facts().mounts))
		if not output.ok: return output
		upgrades = enhancement.difference(output)
	var iron: String = ""
	if reactor.factors.smelting != reactor_factors.smelting:
		var text = amount_api.apply("to_display", [reactor.factors.smelting])
		if not text.ok: return text
		iron = text.text
	var result = _commit_values(values, "refit", iron, upgrades)
	if result.ok and enhancement_prepared: enhancement.accept_output()
	if result.ok:
		if reactor_prepared: reactor_system.accept()
		reactor_factors = reactor.factors
		if income_factors.condensation != reactor.factors.condensation:
			var income: Dictionary = income_factors.duplicate()
			income.condensation = reactor.factors.condensation
			income.make_read_only()
			income_factors = income
	return result

func _publish_research() -> Dictionary:
	var result = research.contributions()
	if not result.ok: return result
	var values: Dictionary = result["values"]
	var updated = _publish_native_values(values, reactor_factors, "growth")
	if not updated.ok: return updated
	research_factors = values
	if income_factors.iron != values.iron_income or income_factors.uranium != values.uranium_income or income_factors.jewel != values.fragment_income:
		var income: Dictionary = income_factors.duplicate()
		income.iron = values.iron_income
		income.uranium = values.uranium_income
		income.jewel = values.fragment_income
		income.make_read_only()
		income_factors = income
	return {"ok": true}

func publish_reactor(factors: Dictionary, next_wallet, kind: String) -> Dictionary:
	if not run_state.is_running(): return run_state.rejection()
	var updated = _publish_native_values(research_factors, factors, kind)
	if not updated.ok: return updated
	reactor_factors = factors
	if next_wallet != null: economy.accept_budget(next_wallet)
	if income_factors.condensation != factors.condensation:
		var income: Dictionary = income_factors.duplicate()
		income.condensation = factors.condensation
		income.make_read_only()
		income_factors = income
	return {"ok": true}

func publish_world(planet: Dictionary = {}, crew: Dictionary = {}, galaxy: Dictionary = {}) -> Dictionary:
	if not run_state.is_running(): return run_state.rejection()
	if not planet.is_empty(): planet_factors = planet
	if not crew.is_empty(): crew_factors = crew
	if not galaxy.is_empty(): galaxy_factors = galaxy
	var world = _world_contributions()
	if not world.ok: return _fail(str(world.get("error", "WorldAssemblyFailed")))
	var previous: Dictionary = world_factors
	world_factors = world
	if income_factors.refinery != world.refinery or income_factors.crew_fragments != world.fragments or income_factors.galaxy_fragments != world.galaxy_fragments:
		var income: Dictionary = income_factors.duplicate()
		income.refinery = world.refinery
		income.crew_fragments = world.fragments
		income.galaxy_fragments = world.galaxy_fragments
		income.make_read_only()
		income_factors = income
	research_speed = world.research
	galaxy_crew_experience = world.crew_experience
	var result: Dictionary = {"ok": true}
	if world.enhancement_levels != previous.enhancement_levels or world.external != previous.external or world.equipment_levels != previous.equipment_levels or world.capacity != previous.capacity or world.free_charge != previous.free_charge:
		result = _publish_world_values(previous)
	if not result.ok and run_state.is_running():
		return _fail(str(result.get("error", result.get("reason", "WorldGrowthUpdateFailed"))))
	return result

func assignment_admission(kind: String, target: String) -> Dictionary:
	if kind in ["planet_explore", "planet_build"]: return planet_system.assignment_capacity(kind, target)
	return galaxy_system.assignment_admission(target)

func coordinate_assignment(id: String, kind: String, target: String, mode: String = "1") -> Dictionary:
	if not run_state.is_running(): return run_state.rejection()
	var changed = crew_system.assign(id, kind, target, mode, assignment_admission)
	if not changed.ok: return changed
	if changed.old_kind == "planet_explore" and (kind != changed.old_kind or target != changed.old_target):
		planet_system.set_explorer(str(changed.old_target), false)
	if kind == "planet_explore":
		var started = planet_system.set_explorer(target, true)
		if not started.ok: return _fail(str(started.reason))
	return publish_world({}, crew_system.contributions()) if changed.effects_changed else {"ok": true}

func coordinate_planet_cancel(id: String) -> Dictionary:
	if not run_state.is_running(): return run_state.rejection()
	var cancelled = planet_system.cancel(id)
	if not cancelled.ok: return cancelled
	crew_system.release("planet_explore", id)
	return cancelled

func planet_experience_context() -> Dictionary:
	return {"enabled": crew_system.experience_enabled(), "ratio": campaign_system.planet_experience_ratio(), "factor": galaxy_crew_experience}

func _publish_progress() -> void:
	if not run_state.is_running(): return
	var facts: Dictionary = campaign_system.progress_facts()
	research.refresh_progress(campaign_system.available)
	reactor_system.refresh_availability(campaign_system.available)
	equipment.refresh_availability(campaign_system.available, int(facts.highest_reached))
	crew_system.refresh_availability(campaign_system.available)
	planet_system.refresh_availability(campaign_system.available)
	galaxy_system.refresh_availability(campaign_system.available, facts.cleared_stages)

func _advance_planets(dt: float, explorers: Dictionary, builders: Dictionary) -> bool:
	var result = planet_system.advance(explorers, builders, dt, planet_experience_context)
	if not result.ok:
		_fail(str(result.get("error", result.get("reason", "PlanetAdvanceFailed"))))
		return false
	var crew_changed: bool = false
	for completion in result.completed:
		for target in completion.released:
			crew_system.release("planet_build", str(target))
		if completion.award_experience:
			var awarded = crew_system.award_exploration(str(completion.explorer), bool(completion.share_experience), completion.experience)
			if not awarded.ok:
				_fail(str(awarded.get("error", awarded.get("reason", "CrewExperienceFailed"))))
				return false
			crew_changed = crew_changed or awarded.effects_changed
		if not completion.again:
			crew_system.release("planet_explore", str(completion.planet))
	if not result.completed.is_empty() and not publish_world(result.contributions,
		crew_system.contributions() if crew_changed else {}).ok:
		return false
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
		galaxy_factors = contributions
		if contributions.growth_changed and not publish_world({}, {}, contributions).ok: return false
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
				var credited = economy.credit_yield(str(resource), income.amounts[resource], wall_time, game_time)
				if not credited.ok:
					_fail(str(credited.get("error", "GalaxyCreditFailed")))
					return false
	return true
