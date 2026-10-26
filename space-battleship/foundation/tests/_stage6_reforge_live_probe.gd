extends SceneTree

const Session = preload("res://src/game_session.gd")

func _initialize() -> void:
	var loaded = GDExtensionManager.load_extension(OS.get_environment("SPACE_IDLE_NATIVE_EXTENSION"))
	if loaded != GDExtensionManager.LOAD_STATUS_OK and loaded != GDExtensionManager.LOAD_STATUS_ALREADY_LOADED:
		printerr("extension: ", loaded)
		quit(1)
		return
	call_deferred("_run")

func _run() -> void:
	var directory: String = OS.get_environment("SPACE_IDLE_SAVE_TEST_DIR")
	if directory.is_empty():
		printerr("missing disposable directory")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(directory)
	var session = Session.new()
	var result: Dictionary = session.initialize("res://generated/config.json", 121)
	if not result.ok:
		printerr("initialize: ", result)
		quit(1)
		return
	# The fixture advances only Campaign's gate; Planet construction and crew work
	# below use their public business operations from the untouched initial state.
	result = session.campaign_system.accept_reforge(session.campaign_system.save_state(), 8)
	session.planet_system.refresh_availability(session.campaign_system.available, false)
	session.crew_system.refresh_availability(session.campaign_system.available, false)
	var crew_ids: Array = session.crew_system.save_state().members.keys()
	if not result.ok or not session.planet_system.is_available("1") or crew_ids.size() < 2:
		printerr("first planet or crew unavailable: ", result)
		quit(1)
		return
	var explorer: String = str(crew_ids[0])
	var builder: String = str(crew_ids[1])
	var route: String = str(session.hyperspace_system.routes()[0].route)
	result = session.start_hyperspace_manual(route)
	if not result.ok:
		printerr("manual challenge start failed: ", result)
		quit(1)
		return
	var run_id: int = int(result.receipt.run_id)
	# Combat is outside this fixture; feed ten completed waves through the
	# Hyperspace business port, then exercise its real reward/claim ledger.
	for wave in 10: session.hyperspace_system.wave_cleared()
	session.hyperspace_system.advance_manual(1.0)
	if not session._finish_hyperspace_manual(true):
		printerr("manual challenge completion failed")
		quit(1)
		return
	result = session.claim_hyperspace(run_id)
	if not result.ok or result.reward.drone.is_empty():
		printerr("manual reward claim failed: ", result)
		quit(1)
		return
	var claimed_drone: String = str(result.reward.drone.id)
	if not session.claim_hyperspace(run_id).get("already_claimed", false):
		printerr("manual reward claimed twice")
		quit(1)
		return
	var legacy: Dictionary = session.hyperspace_system.save_state()
	legacy.warehouse[0].planet_id = "1.0"
	legacy.manual.reward.drone.planet_id = "1.0"
	legacy.receipts[run_id].reward.drone.planet_id = "1.0"
	result = session.hyperspace_system.restore_state(legacy)
	if not result.ok:
		printerr("legacy planet ID compatibility failed: ", result)
		quit(1)
		return
	var building_assigned: bool = false
	for cycle in 220:
		var state: Dictionary = session.planet_system.save_state().planets["1"]
		if state.buildings.shipyard.state == "ready": break
		if state.buildings.shipyard.state == "building" and not building_assigned:
			result = session.coordinate_assignment(builder, "planet_build", "1:shipyard")
			if not result.ok: break
			building_assigned = true
		result = session.coordinate_assignment(explorer, "planet_explore", "1")
		if not result.ok: break
		var builders: Dictionary = {"1:shipyard": [builder]} if building_assigned else {}
		if not session._advance_planets(1000000.0, {"1": [explorer]}, builders):
			result = session.run_state.rejection()
			break
	if not result.ok or session.planet_system.save_state().planets["1"].buildings.shipyard.state != "ready":
		printerr("real shipyard work failed: ", result, " ", session.planet_system.save_state().planets["1"].buildings.shipyard)
		quit(1)
		return
	result = session.planet_system.claim_build("1", "shipyard", session.publish_planet_claim)
	if not result.ok or session.planet_system.save_state().planets["1"].buildings.shipyard.state != "built":
		printerr("real shipyard claim failed: ", result)
		quit(1)
		return
	var candidate: Dictionary = session.prepare_reforge("1", [claimed_drone], directory)
	if not candidate.ok or not candidate.session.planet_system.save_state().planets["1"].conquered or session.planet_system.save_state().planets["1"].conquered:
		printerr("real shipyard reforge failed: ", candidate)
		quit(1)
		return
	if not candidate.session.hyperspace_system.warehouse().sealed.has(claimed_drone) or int(candidate.session.hyperspace_system.warehouse().sealed[claimed_drone]) <= 0 or candidate.session.hyperspace_system.prepare_claim(run_id).ok:
		printerr("retained real drone or receipt boundary failed")
		quit(1)
		return
	result = candidate.session.request_save()
	if result.ok: result = candidate.session.save_files.close(2000)
	if not result.ok:
		printerr("real reforge save failed: ", result)
		quit(1)
		return
	var loaded: Dictionary = Session.load_candidate("res://generated/config.json", directory)
	if not loaded.ok or not loaded.session.hyperspace_system.warehouse().sealed.has(claimed_drone) or not loaded.session.planet_system.save_state().planets["1"].conquered:
		printerr("real reforge restore failed: ", loaded)
		quit(1)
		return
	loaded.session.save_files.close(2000)
	print("STAGE6_REFORGE_LIVE_PROBE_OK")
	quit(0)
