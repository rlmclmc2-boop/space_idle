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
	var single: Dictionary = system.prepare_idle("alpha", false, "", 0, 0.0)
	if not single.ok or float(single.receipt.duration) != 10.0:
		printerr("single: ", single)
		quit(1)
		return
	system.accept_idle(single.receipt, false)
	system.advance_online(10.0, false)
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
	system.advance_online(10.0, false)
	if system.online_status().idle.status != "CompletedPending":
		printerr("auto completion")
		quit(1)
		return
	system.accept_claim(int(auto.receipt.run_id))
	system.advance_online(1.0 / 60.0, false)
	if system.online_status().idle.status != "Started":
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
	var stored: Array = own.warehouse().main
	if not stored.is_empty():
		var outfitted: Dictionary = session.equip_hyperspace_drones([stored[0].id])
		if not outfitted.ok:
			printerr("session equip: ", outfitted)
			quit(1)
			return
		var before_drone: Dictionary = own.warehouse().main[0]
		var forecast: Dictionary = session.preview_hyperspace_forge(str(before_drone.id), "enable_omen")
		if not forecast.ok or own.warehouse().main[0].omen:
			printerr("forge preview: ", forecast)
			quit(1)
			return
		var credited: Dictionary = session._hyperspace_credit({"materials": {"zero_point_energy": 100}, "ultimate_cores": 0})
		session.economy.accept_budget(credited.wallet)
		var forged: Dictionary = session.forge(str(before_drone.id), "enable_omen", {}, "probe-omen")
		var repeat_forge: Dictionary = session.forge(str(before_drone.id), "enable_omen", {}, "probe-omen")
		if not forged.ok or not repeat_forge.ok or not repeat_forge.drone.omen or not own.warehouse().main[0].omen:
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
	print("manual entry and return accepted")
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
