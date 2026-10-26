extends SceneTree
const Hyperspace = preload("res://src/systems/hyperspace.gd")
const RunState = preload("res://src/systems/run_state.gd")
const Session = preload("res://src/game_session.gd")
const Main = preload("res://src/main.gd")

func _initialize() -> void:
	var loaded = GDExtensionManager.load_extension(OS.get_environment("SPACE_IDLE_NATIVE_EXTENSION"))
	if loaded != GDExtensionManager.LOAD_STATUS_OK and loaded != GDExtensionManager.LOAD_STATUS_ALREADY_LOADED:
		printerr("extension: ", loaded)
		quit(1)
		return
	call_deferred("_run_probe")

func _run_probe() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://generated/config.json"))
	var api = ClassDB.instantiate("FoundationAmount")
	var system = Hyperspace.new(data, api, RunState.new())
	var supply = Hyperspace.new(data, api, RunState.new(), 31)
	supply._parameters.late_supply_unlock_stage = 7
	supply.advance_online(3.0, {60: true})
	if supply._late_supply_work != 0.0:
		printerr("late supply used literal stage")
		quit(1)
		return
	supply.advance_online(2.0, {7: true})
	if absf(supply._late_supply_work - 2.0) > 1e-9:
		printerr("late supply configured stage")
		quit(1)
		return
	var geometry: Dictionary = {}
	var motion: Dictionary = {}
	var equipment: Dictionary = {}
	for row in data.battle_geometry.battle_geometry: geometry[str(row.id)] = row.value
	for row in data.weapon_motion.weapon_motion: motion[str(row.id)] = row.value
	for row in data.equipment.equipment: equipment[str(row.name)] = row
	var override = func(id): return equipment.get(id, {})
	var session = Session.new()
	var initialized: Dictionary = session.initialize("res://generated/config.json", 17)
	if not initialized.ok:
		printerr("session: ", initialized)
		quit(1)
		return
	var count: int = 0
	for route in ["alpha", "beta", "gamma", "delta"]:
		var prepared: Dictionary = system.prepare_manual(route, 8, {"stage": 8, "point": 0, "guard": false, "guard_point": 0})
		if not prepared.ok:
			printerr("prepare: ", route, " ", prepared)
			quit(1)
			return
		system.accept_manual(prepared.receipt)
		for wave in 10:
			var setup: Dictionary = system.prepare_wave(8, override, geometry, motion, 0.0)
			if not setup.ok:
				printerr("wave: ", route, " ", wave, " ", setup)
				quit(1)
				return
			if wave == 0 and not setup.wave.enemies.is_empty():
				var actor: Dictionary = setup.wave.enemies[0]
				var base_hp: Dictionary = api.apply("from_decimal", [str(actor.health)])
				var layer_ratio: Dictionary = api.apply("from_decimal", [str(system._levels[int(system.manual_receipt().level)].lifeRatio)])
				var expected_hp: Dictionary = api.apply("ceil", [api.apply("mul", [base_hp.value, layer_ratio.value]).value])
				var actual_hp: Dictionary = api.apply("from_decimal", [str(actor.hp)])
				if not expected_hp.ok or not actual_hp.ok or int(api.apply("compare", [expected_hp.value, actual_hp.value]).scalar) != 0:
					printerr("hyperspace first-wave endpoint ratio: ", route, " ", actor.hp)
					quit(1)
					return
			session.battle.reset_for_sortie()
			var started: Dictionary = session.battle.start_wave(setup)
			if not started.ok:
				printerr("native wave: ", route, " ", wave, " ", started)
				quit(1)
				return
			system.accept_wave(setup)
			count += 1
			system.wave_cleared()
		system.advance_manual(2.0)
		var completed: Dictionary = system.finish_manual(true)
		if not completed.ok:
			printerr("finish: ", completed)
			quit(1)
			return
		var claim: Dictionary = system.prepare_claim(int(prepared.receipt.run_id))
		if not claim.ok:
			printerr("claim: ", claim)
			quit(1)
			return
		system.accept_claim(int(prepared.receipt.run_id))
	var original_omen_drone: Dictionary = system._warehouse[0].duplicate(true)
	var omen_id: String = str(original_omen_drone.id)
	var omen_key: String = str(system._affixes.keys()[0])
	var omen_rows: Array = [
		{"key": omen_key, "tier": 3, "value": -999.0, "locked": false},
		{"key": omen_key, "tier": 3, "value": -999.0, "locked": false},
		{"key": omen_key, "tier": 1, "value": -999.0, "locked": false}]
	var omen_choices: Dictionary = {0: 0, 1: 0}
	for rng_state in 32:
		var omen_rng := RandomNumberGenerator.new()
		omen_rng.seed = rng_state + 1
		system._warehouse[0].omen = true
		system._warehouse[0].affixes = omen_rows.duplicate(true)
		system._warehouse[0].forge_rng_state = str(omen_rng.state)
		var omen_quote: Dictionary = system.preview_forge(omen_id, "replace_affix")
		if not omen_quote.ok:
			printerr("omen replacement preview: ", omen_quote)
			quit(1)
			return
		var changed_index: int = -1
		for index in 3:
			if float(omen_quote.drone.affixes[index].value) != -999.0: changed_index = index
		if changed_index not in [0, 1]:
			printerr("omen selected non-worst affix: ", changed_index)
			quit(1)
			return
		omen_choices[changed_index] = int(omen_choices[changed_index]) + 1
	if int(omen_choices[0]) == 0 or int(omen_choices[1]) == 0:
		printerr("omen tie was not randomized: ", omen_choices)
		quit(1)
		return
	system._warehouse[0] = original_omen_drone
	var single: Dictionary = system.prepare_idle("alpha", false, "", 0, 0.0)
	if not single.ok or float(single.receipt.duration) != 10.0:
		printerr("single: ", single)
		quit(1)
		return
	system.accept_idle(single.receipt, false)
	system.advance_online(10.0, {})
	var single_claim: Dictionary = system.prepare_claim(int(single.receipt.run_id))
	if not single_claim.ok:
		printerr("single claim: ", single_claim)
		quit(1)
		return
	system.accept_claim(int(single.receipt.run_id))
	var auto: Dictionary = system.prepare_idle("alpha", true, "navigator", 20, 0.0)
	if not auto.ok or float(auto.receipt.duration) != 10.0:
		printerr("auto: ", auto)
		quit(1)
		return
	system.accept_idle(auto.receipt, true)
	system.advance_online(10.0, {})
	if system.online_status().idle.status != "CompletedPending":
		printerr("auto completion")
		quit(1)
		return
	system.accept_claim(int(auto.receipt.run_id))
	var claim_snapshot: Dictionary = system.prepare_claim(int(auto.receipt.run_id))
	var original_drone_id: String = str(system._receipts[int(auto.receipt.run_id)].reward.drone.id)
	claim_snapshot.reward.drone.id = "tampered-copy"
	if str(system._receipts[int(auto.receipt.run_id)].reward.drone.id) != original_drone_id or str(system.warehouse().main[-1].id) != original_drone_id:
		printerr("claim receipt/warehouse alias")
		quit(1)
		return
	system._warehouse[-1].id = "tampered-entity"
	if str(system._receipts[int(auto.receipt.run_id)].reward.drone.id) != original_drone_id:
		printerr("warehouse entity/receipt alias")
		quit(1)
		return
	system._warehouse[-1].id = original_drone_id
	var continued: Dictionary = system.prepare_auto_continuation(20, 0.0)
	if not continued.ok:
		printerr("auto continuation: ", continued)
		quit(1)
		return
	system.accept_idle(continued.receipt, true)
	system.advance_online(1.0 / 60.0, {})
	if system.online_status().idle.status != "Started" or absf(float(system.online_status().idle.work) - 1.0 / 60.0) > 1e-9:
		printerr("auto next step")
		quit(1)
		return
	var repeated_claim: Dictionary = system.prepare_claim(int(auto.receipt.run_id))
	if not repeated_claim.ok or not repeated_claim.already_claimed:
		printerr("claim ledger: ", repeated_claim)
		quit(1)
		return
	var motion_inputs: Dictionary = session.battle.wave_inputs().motion
	var source = func(drone): return session.equipment.drone_weapon_source(str(drone.weapon),
		system.weapon_level_bonus(drone), 0, session._research_factors, session._reactor_factors, motion_inputs)
	for drone in system.warehouse().main:
		var loadout: Dictionary = system.prepare_loadout([drone.id], 1, source)
		if not loadout.ok:
			printerr("loadout: ", loadout)
			quit(1)
			return
		var committed: Dictionary = session.set_equipped_drone_contributions(loadout.contributions)
		if not committed.ok:
			printerr("native drone: ", committed)
			quit(1)
			return
	print("prepared and admitted waves: ", count)
	var sortie: Dictionary = session.campaign_system.start_sortie(1, session.equipment.clear_switch_locks)
	if not sortie.ok:
		printerr("sortie: ", sortie)
		quit(1)
		return
	session.campaign_system._state.highest_reached = 8
	var manual: Dictionary = session.start_hyperspace_manual("alpha")
	if not manual.ok:
		printerr("manual entry: ", manual)
		quit(1)
		return
	var before_work: float = float(session.hyperspace_system.manual_receipt().work)
	session.campaign_system.advance(1.0 / 60.0, session._advance_kernel, session._start_wave)
	if float(session.hyperspace_system.manual_receipt().work) <= before_work:
		printerr("manual campaign tick")
		quit(1)
		return
	var exit_result: bool = session._finish_hyperspace_manual(false)
	if not exit_result or session.campaign_system._state.state != "travel":
		printerr("manual return")
		quit(1)
		return
	var own = session.hyperspace_system
	var owned: Dictionary = own.prepare_manual("alpha", 8, session.campaign_system.hyperspace_return_target())
	own.accept_manual(owned.receipt)
	own.advance_manual(2.0)
	for wave in 10: own.wave_cleared()
	own.finish_manual(true)
	var paid: Dictionary = session.claim_hyperspace(int(owned.receipt.run_id))
	if not paid.ok:
		printerr("session claim: ", paid)
		quit(1)
		return
	var core_before = session.economy.budget().get("ultimate_cores", api.apply("zero", []).value)
	var core_credit: Dictionary = session._hyperspace_credit({"materials": {}, "ultimate_cores": 3})
	if not core_credit.ok or int(api.apply("compare", [core_credit.wallet.ultimate_cores, core_before]).scalar) <= 0:
		printerr("ultimate core credit key: ", core_credit)
		quit(1)
		return
	var crew_id: String = str(session.crew_system._members.keys()[0])
	session.crew_system._available[crew_id] = true
	var route_level: int = int(own._history.alpha.cleared)
	own._history.alpha.best[route_level] = 100.0
	var first_planet: Dictionary = session._planet_factors.duplicate()
	first_planet.luck = 2.5
	session._planet_factors = first_planet
	var auto_started: Dictionary = session.start_hyperspace_auto("alpha", crew_id)
	if not auto_started.ok:
		printerr("session auto start: ", auto_started)
		quit(1)
		return
	var auto_run_id: int = int(auto_started.receipt.run_id)
	var first_snapshot: Dictionary = auto_started.receipt.duplicate(true)
	own = session.hyperspace_system
	if not session._advance_hyperspace_online(float(auto_started.receipt.duration)) or own.online_status().idle.status != "Claimed":
		printerr("session auto first claim: ", own.online_status())
		quit(1)
		return
	if session.claim_hyperspace(auto_run_id).get("already_claimed") != true:
		printerr("session auto claim ledger")
		quit(1)
		return
	session.crew_system._members[crew_id].level = 20
	var next_planet: Dictionary = session._planet_factors.duplicate()
	next_planet.luck = 4.5
	session._planet_factors = next_planet
	session._advance_hyperspace_online(1.0 / 60.0)
	var second_snapshot: Dictionary = own.online_status().idle
	if second_snapshot.status != "Started" or int(second_snapshot.run_id) == auto_run_id or session.crew_system._members[crew_id].kind != "hyperspace" or absf(float(second_snapshot.work) - 1.0 / 60.0) > 1e-9 or absf(float(first_snapshot.duration) - 100.0) > 1e-9 or absf(float(second_snapshot.duration) - 50.0) > 1e-9 or absf(float(first_snapshot.luck) - 2.5) > 1e-9 or absf(float(second_snapshot.luck) - 24.5) > 1e-9 or int(own._receipts[auto_run_id].crew_level) != 0 or absf(float(own._receipts[auto_run_id].luck) - 2.5) > 1e-9:
		printerr("session auto continuation: ", own.online_status())
		quit(1)
		return
	var second_run_id: int = int(own.online_status().idle.run_id)
	if not session._advance_hyperspace_online(float(own.online_status().idle.duration)) or own.online_status().idle.status != "Claimed" or session.claim_hyperspace(second_run_id).get("already_claimed") != true:
		printerr("session auto second claim: ", own.online_status())
		quit(1)
		return
	var auto_stopped: Dictionary = session.stop_hyperspace_auto()
	if not auto_stopped.ok:
		printerr("session auto stop: ", auto_stopped)
		quit(1)
		return
	var stored: Array = own.warehouse().main
	if not stored.is_empty():
		var outfitted: Dictionary = session.equip_hyperspace_drones([stored[0].id])
		if not outfitted.ok:
			printerr("session equip: ", outfitted)
			quit(1)
			return
		var before_drone: Dictionary = own.warehouse().main[0]
		var stable_generation: int = int(session.battle._equipped_drones[0].generation)
		var route: String = own._route_for_weapon(str(before_drone.weapon))
		own._history[route].cleared = 9
		own._history[route].best[3] = 12.0
		own._history[route].best[9] = 11.0
		var modernization: Dictionary = session.preview_hyperspace_forge(str(before_drone.id), "modernize")
		if not modernization.ok or int(modernization.drone.level) != 3 or session.preview_hyperspace_forge(str(before_drone.id), "modernize", {"target_level": 9}).ok:
			printerr("modernization mainline cap/best record: ", modernization)
			quit(1)
			return
		own._history[route].best[8] = 12.0
		var original_cost_parameters: Dictionary = own._parameters.duplicate()
		own._parameters.modernization_cost_base = 12
		own._parameters.material_reward_start_level = 4
		own._parameters.modernization_level_step = 2
		own._parameters.modernization_base_coefficient = 1.4
		var rounded_quote: Dictionary = session.preview_hyperspace_forge(str(before_drone.id), "modernize")
		var material_id: String = str(own._routes[route].material)
		if not rounded_quote.ok or int(rounded_quote.costs[material_id]) != 480:
			printerr("modernization parameterized rounding: ", rounded_quote)
			quit(1)
			return
		own._parameters = original_cost_parameters
		var drone_source_id: String = "drone:" + str(before_drone.id)
		var matching_slot: String = ""
		for slot in session.equipment._slots:
			if slot.category == "weapon" and slot.equipment_id == before_drone.weapon: matching_slot = str(slot.id)
		if matching_slot.is_empty():
			printerr("drone paid growth fixture missing mounted source: ", before_drone.weapon)
			quit(1)
			return
		if not matching_slot.is_empty():
			var old_paid: int = int(session.battle._equipped_drones[0].weapon.entry.paid_level)
			var quote: Dictionary = session.equipment.quote_slot(matching_slot, 1)
			if not quote.ok:
				printerr("drone equipment quote: ", quote)
				quit(1)
				return
			var funded: Dictionary = session.economy.budget().duplicate()
			for resource in quote.costs: funded[resource] = api.apply("from_decimal", ["1e40"]).value
			session.economy.accept_budget(funded)
			var upgraded: Dictionary = session.equipment.buy_levels(matching_slot, 1, session.equipment_inputs(),
				func(costs, balances): return session.economy.payment(costs, balances), session.publish_equipment_levels)
			if not upgraded.ok or int(session.battle._equipped_drones[0].weapon.entry.paid_level) <= old_paid or not session.battle._values.weapons.has(drone_source_id):
				printerr("drone paid growth: ", upgraded)
				quit(1)
				return
		var boosted_ai: Dictionary = session._research_factors.duplicate()
		boosted_ai.weapon_damage = api.apply("mul", [boosted_ai.weapon_damage, api.apply("from_decimal", ["2"]).value]).value
		var old_damage: String = str(session.battle._equipped_drones[0].weapon.damage)
		var research_growth: Dictionary = session._publish_native_values(boosted_ai, session._reactor_factors, "growth")
		if not research_growth.ok or str(session.battle._equipped_drones[0].weapon.damage) == old_damage:
			printerr("drone research growth: ", research_growth)
			quit(1)
			return
		session._research_factors = boosted_ai
		var boosted_reactor: Dictionary = session._reactor_factors.duplicate()
		boosted_reactor.weapons = api.apply("mul", [boosted_reactor.weapons, api.apply("from_decimal", ["2"]).value]).value
		old_damage = str(session.battle._equipped_drones[0].weapon.damage)
		var reactor_growth: Dictionary = session._publish_native_values(boosted_ai, boosted_reactor, "growth")
		if not reactor_growth.ok or str(session.battle._equipped_drones[0].weapon.damage) == old_damage:
			printerr("drone reactor growth: ", reactor_growth)
			quit(1)
			return
		session._reactor_factors = boosted_reactor
		var previous_world: Dictionary = session._world_factors
		var boosted_world: Dictionary = previous_world.duplicate()
		boosted_world.equipment_levels = int(previous_world.equipment_levels) + 1
		session._world_factors = boosted_world
		old_damage = str(session.battle._equipped_drones[0].weapon.damage)
		var world_growth: Dictionary = session._publish_world_values(previous_world)
		if not world_growth.ok or str(session.battle._equipped_drones[0].weapon.damage) == old_damage or int(session.battle._equipped_drones[0].generation) != stable_generation:
			printerr("drone world growth/generation: ", world_growth)
			quit(1)
			return
		var forecast: Dictionary = session.preview_hyperspace_forge(str(before_drone.id), "enable_omen")
		if not forecast.ok or own.warehouse().main[0].omen:
			printerr("forge preview: ", forecast)
			quit(1)
			return
		var credited: Dictionary = session._hyperspace_credit({"materials": {"zero_point_energy": 100}, "ultimate_cores": 0})
		session.economy.accept_budget(credited.wallet)
		var commits_before_omen: int = session.battle.configuration_commits
		var forged: Dictionary = session.forge(str(before_drone.id), "enable_omen", {}, "probe-omen")
		var repeat_forge: Dictionary = session.forge(str(before_drone.id), "enable_omen", {}, "probe-omen")
		if not forged.ok or not repeat_forge.ok or not repeat_forge.drone.omen or not own.warehouse().main[0].omen or int(session.battle._equipped_drones[0].generation) != stable_generation or session.battle.configuration_commits != commits_before_omen:
			printerr("forge commit/retry: ", forged, " ", repeat_forge)
			quit(1)
			return
		if session.forge(str(before_drone.id), "disable_omen", {}, "probe-omen").get("reason") != "OperationIdConflict":
			printerr("forge id conflict")
			quit(1)
			return
		own._modules.resource_collector = {"unlocked": true, "level": 1, "exp": 0.0}
		own._warehouse[0].hanging_slots = 1
		var mounted: Dictionary = session.set_hyperspace_hangings(str(before_drone.id), ["resource_collector"])
		var collection = session.amount_api.apply("to_display", [session._income_factors.resource_collection])
		if not mounted.ok or not collection.ok or float(collection.text) <= 1.0:
			printerr("module publication: ", mounted, " ", collection)
			quit(1)
			return
		var module_receipt: Dictionary = {"round_id": own._round_id, "run_id": 999, "status": "CompletedPending",
			"reward": {"drone": {}, "materials": {}, "ultimate_cores": 0, "hanging_rewards": {"resource_collector": 2}}}
		own._receipts[999] = module_receipt
		own._idle = module_receipt
		var module_claim: Dictionary = session.claim_hyperspace(999)
		var upgraded = session.amount_api.apply("to_display", [session._income_factors.resource_collection])
		if not module_claim.ok or int(own.module_growth().resource_collector.level) <= 1 or float(upgraded.text) <= float(collection.text):
			printerr("module reward publication: ", module_claim, " ", upgraded)
			quit(1)
			return
		var preset_saved: Dictionary = session.save_hyperspace_preset("probe")
		var removed: Dictionary = session.set_hyperspace_hangings(str(before_drone.id), [])
		var preset_applied: Dictionary = session.apply_hyperspace_preset("probe")
		if not preset_saved.ok or not removed.ok or not preset_applied.ok or own._warehouse[0].hangings != ["resource_collector"]:
			printerr("preset transaction: ", preset_saved, " ", removed, " ", preset_applied)
			quit(1)
			return
		own._modules.extra_storage = {"unlocked": true, "level": 1, "exp": 0.0}
		session.campaign_system._state.highest_reached = 60
		session.reactor_system._enabled = ["weapons"]
		session.reactor_system._state.level = 10
		session.reactor_system._state.allocations.weapons = api.apply("from_decimal", ["1e10"]).value
		var storage_mounted: Dictionary = session.set_hyperspace_hangings(str(before_drone.id), ["extra_storage"])
		var boosted_factor = session._reactor_factors.weapons
		var boosted_damage: String = str(session.battle._equipped_drones[0].weapon.damage)
		var storage_preset: Dictionary = session.save_hyperspace_preset("capacity")
		var storage_removed: Dictionary = session.set_hyperspace_hangings(str(before_drone.id), [])
		var reduced_factor = session._reactor_factors.weapons
		var expected_source: Dictionary = session._hyperspace_weapon_source().call(own._warehouse[0])
		if not storage_mounted.ok or not storage_preset.ok or not storage_removed.ok or not expected_source.ok or int(api.apply("compare", [boosted_factor, reduced_factor]).scalar) <= 0 or boosted_damage == str(session.battle._equipped_drones[0].weapon.damage) or str(session.battle._equipped_drones[0].weapon.damage) != str(expected_source.weapon.damage):
			printerr("capacity shrink drone growth: ", storage_mounted, " ", storage_removed)
			quit(1)
			return
		var storage_reapplied: Dictionary = session.apply_hyperspace_preset("capacity")
		var reapplied_source: Dictionary = session._hyperspace_weapon_source().call(own._warehouse[0])
		if not storage_reapplied.ok or own._warehouse[0].hangings != ["extra_storage"] or not reapplied_source.ok or str(session.battle._equipped_drones[0].weapon.damage) != str(reapplied_source.weapon.damage):
			printerr("capacity preset drone growth: ", storage_reapplied)
			quit(1)
			return
		own._warehouse[0].ultimate = true
		var ultimate_preset: Dictionary = session.save_hyperspace_preset("ultimate-unchanged")
		var ultimate_applied: Dictionary = session.apply_hyperspace_preset("ultimate-unchanged")
		if not ultimate_preset.ok or not ultimate_applied.ok or own._warehouse[0].hangings != ["extra_storage"]:
			printerr("ultimate unchanged preset: ", ultimate_preset, " ", ultimate_applied)
			quit(1)
			return
		own._warehouse[0].ultimate = false
		var restored_quality: Dictionary = session.equip_hyperspace_drones([str(before_drone.id)])
		if not restored_quality.ok:
			printerr("ultimate preset fixture restore: ", restored_quality)
			quit(1)
			return
		if own.prepare_dismantle(str(before_drone.id)).get("reason") != "ProtectedDrone":
			printerr("preset protection")
			quit(1)
			return
		var filter_config: Dictionary = {"version": 2, "enabled": true, "mode": "all", "action": "keep_matches",
			"conditions": [{"field": "weapon", "value": "laser"}]}
		var filter_set: Dictionary = own.set_filter(filter_config)
		var filter_import: Dictionary = own.import_filter(own.export_filter())
		var filter_bad: Dictionary = own.import_filter("SPACE-FILTER-v2:bad")
		if not filter_set.ok or not filter_import.ok or filter_bad.ok:
			printerr("filter share: ", filter_set, " ", filter_import, " ", filter_bad)
			quit(1)
			return
		var fixture: Dictionary = own._warehouse[0].duplicate(true)
		fixture.origin_quality = "blue"
		fixture.legendary = false
		fixture.weapon = "laser"
		fixture.affixes = [{"key": "damage_laser", "tier": 5, "value": 0.1, "locked": false}]
		own._warehouse.append(fixture)
		own._warehouse[-1].id = "guarantee-fixture"
		var guaranteed: Dictionary = own.preview_forge("guarantee-fixture", "reroll_values", {"guaranteed": true})
		if not guaranteed.ok or not session.amount_api.apply("from_decimal", [str(guaranteed.costs.antiproton)]).ok:
			printerr("guaranteed Amount quote: ", guaranteed)
			quit(1)
			return
		own._warehouse.pop_back()
	print("manual entry and return accepted")
	if not stored.is_empty():
		own._warehouse[0].legendary = true
		own._warehouse[0].legendary_effect = {"effect_id": "scatter_pulse", "parameters": {"single_target_bonus": 2.5}}
		var legend_mounted: Dictionary = session.equip_hyperspace_drones([str(stored[0].id)])
		if not legend_mounted.ok or str(session.battle._equipped_drones[0].legendary_effect) != "scatter_pulse":
			printerr("native legend handoff: ", legend_mounted)
			quit(1)
			return
		var dynamic = Hyperspace.new(data, api, RunState.new(), 23)
		var dynamic_request: Dictionary = dynamic.prepare_manual("alpha", 8, {"stage": 8, "point": 0, "guard": false, "guard_point": 0})
		dynamic.accept_manual(dynamic_request.receipt)
		var dynamic_wave: Dictionary = dynamic.prepare_wave(8, override, geometry, motion, 0.0)
		if not dynamic_wave.ok:
			printerr("dynamic wave: ", dynamic_wave)
			quit(1)
			return
		session.battle.reset_for_sortie()
		var dynamic_started: Dictionary = session.battle.start_wave(dynamic_wave)
		if not dynamic_started.ok:
			printerr("dynamic native admission: ", dynamic_started)
			quit(1)
			return
		for step in 600:
			var moved: Dictionary = session.battle.advance(1.0 / 60.0)
			if not moved.ok:
				printerr("dynamic native advance: ", moved)
				quit(1)
				return
			if moved.wave_cleared or moved.player_dead: break
		if not session.battle.statistics()._totals.has("drone:" + str(stored[0].id)):
			printerr("dynamic drone damage missing: ", session.battle.statistics()._totals.keys())
			quit(1)
			return
		var source_id: String = "drone:" + str(stored[0].id)
		var prior_damage: Dictionary = session.battle.statistics()._totals[source_id].duplicate(true)
		session.battle.reset_for_sortie()
		var removed_drone: Dictionary = session.equip_hyperspace_drones([])
		if not removed_drone.ok or not session.battle.start_wave(dynamic_wave).ok:
			printerr("dynamic drone removal: ", removed_drone)
			quit(1)
			return
		for step in 600:
			var moved: Dictionary = session.battle.advance(1.0 / 60.0)
			if not moved.ok or moved.wave_cleared or moved.player_dead: break
		if session.battle.statistics()._totals[source_id] != prior_damage:
			printerr("removed drone still dealt damage")
			quit(1)
			return
		session.battle.reset_for_sortie()
		print("native drone dynamic damage accepted")
	var huge_source: Dictionary = api.apply("from_decimal", ["1e40"])
	var giant_wallet: Dictionary = session.economy.budget().duplicate()
	giant_wallet.degenerate_matter = huge_source.value
	session.economy.accept_budget(giant_wallet)
	var old_target = giant_wallet.get("glueball", api.apply("zero", []).value)
	var exchanged: Dictionary = session.exchange_hyperspace_materials("degenerate_matter", "glueball", "1000000000000000000000000000000")
	var after_exchange: Dictionary = session.economy.budget()
	if not exchanged.ok or int(api.apply("compare", [after_exchange.degenerate_matter, huge_source.value]).scalar) >= 0 or int(api.apply("compare", [after_exchange.glueball, old_target]).scalar) <= 0:
		printerr("extreme Amount exchange: ", exchanged)
		quit(1)
		return
	if session.exchange_hyperspace_materials("degenerate_matter", "glueball", "1.5").ok or session.economy.budget() != after_exchange:
		printerr("fractional Amount exchange admitted")
		quit(1)
		return
	var unaffordable: Dictionary = api.apply("from_decimal", ["1e500"])
	var refused: Dictionary = session.economy.payment({"degenerate_matter": unaffordable.value})
	if refused.ok or session.economy.budget() != after_exchange:
		printerr("extreme Amount rejection: ", refused)
		quit(1)
		return
	print("extreme Amount exchange and rejection accepted")
	for target_level in [5, 8, 20, 220]:
		for route in ["alpha", "beta", "gamma", "delta"]:
			var upper = Hyperspace.new(data, api, RunState.new(), 19)
			upper._history[route] = {"cleared": target_level - 1, "best": {}}
			var request: Dictionary = upper.prepare_manual(route, maxi(8, target_level),
				{"stage": 8, "point": 0, "guard": false, "guard_point": 0})
			if not request.ok:
				printerr("upper request: ", route, " ", target_level, " ", request)
				quit(1)
				return
			upper.accept_manual(request.receipt)
			for wave in 10:
				var upper_wave: Dictionary = upper.prepare_wave(maxi(8, target_level), override, geometry, motion, 0.0)
				if not upper_wave.ok:
					printerr("upper wave: ", route, " ", target_level, " ", wave, " ", upper_wave)
					quit(1)
					return
				session.battle.reset_for_sortie()
				var admitted: Dictionary = session.battle.start_wave(upper_wave)
				if not admitted.ok:
					printerr("upper native: ", route, " ", target_level, " ", wave, " ", admitted)
					quit(1)
					return
				upper.accept_wave(upper_wave)
				upper.wave_cleared()
	print("upper-level wave admissions: 160")
	var old_round: int = own._round_id
	var reforge: Dictionary = own.prepare_reforge([])
	if not reforge.ok:
		printerr("reforge prepare: ", reforge)
		quit(1)
		return
	own.accept_reforge(reforge.retained)
	if own._round_id != old_round + 1 or own.prepare_claim(int(owned.receipt.run_id)).ok:
		printerr("reforge receipt invalidation")
		quit(1)
		return
	quit()
