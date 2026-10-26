extends SceneTree
const Session = preload("res://src/game_session.gd")

func _initialize() -> void:
	var loaded = GDExtensionManager.load_extension(OS.get_environment("SPACE_IDLE_NATIVE_EXTENSION"))
	if loaded != GDExtensionManager.LOAD_STATUS_OK and loaded != GDExtensionManager.LOAD_STATUS_ALREADY_LOADED:
		printerr("extension: ", loaded)
		quit(1)
		return
	call_deferred("_run_probe")

func _run_probe() -> void:
	var session = Session.new()
	var initialized: Dictionary = session.initialize("res://generated/config.json", 67)
	if not initialized.ok:
		printerr("session: ", initialized)
		quit(1)
		return
	var sortie: Dictionary = session.campaign_system.start_sortie(1, session.equipment.clear_switch_locks)
	if not sortie.ok:
		printerr("sortie: ", sortie)
		quit(1)
		return
	session.campaign_system._state.highest_reached = 8
	var boosted_slots: Array = session.equipment._slots.duplicate(true)
	for slot in boosted_slots: slot.paid_level = 100
	session.equipment._pending_slots = boosted_slots
	session.equipment._pending_level_slots = boosted_slots
	session.equipment._pending_notice = {"kind": "levels", "ids": []}
	var boosted: Dictionary = session.publish_equipment_levels(session.economy.budget())
	if not boosted.ok:
		printerr("fixture equipment growth: ", boosted)
		quit(1)
		return
	var mainline_inputs: Dictionary = session.battle.wave_inputs()
	var mainline_setup: Dictionary = session.campaign_system.prepare_wave(session.equipment.enemy_override,
		mainline_inputs.geometry, mainline_inputs.motion)
	if not mainline_setup.ok or not session.battle.start_wave(mainline_setup).ok:
		printerr("mainline native precheck: ", mainline_setup.get("reason", "NativeWaveRejected"))
		quit(1)
		return
	var manual: Dictionary = session.start_hyperspace_manual("alpha")
	if not manual.ok:
		printerr("manual: ", manual)
		quit(1)
		return
	var run_id: int = int(manual.receipt.run_id)
	var completed: bool = false
	for step in 30000:
		session._step(1.0 / 60.0)
		if not session.run_state.is_running():
			printerr("session fault at step ", step, ": ", session.run_state.rejection())
			quit(1)
			return
		if session.hyperspace_system.manual_receipt().status != "Started":
			print("manual ended at step ", step, ": ", session.hyperspace_system.manual_receipt().status,
				" wave ", session.hyperspace_system.manual_receipt().wave)
			completed = true
			break
	if not completed or session.hyperspace_system.manual_receipt().status != "CompletedPending" or int(session.hyperspace_system.manual_receipt().wave) != 10 or session.campaign_system._state.state != "travel":
		printerr("manual completion/return: ", session.hyperspace_system.manual_receipt())
		quit(1)
		return
	var wallet_before: Dictionary = session.economy.budget().duplicate(true)
	var drones_before: int = session.hyperspace_system.warehouse().main.size()
	var claimed: Dictionary = session.claim_hyperspace(run_id)
	if not claimed.ok or claimed.already_claimed:
		printerr("manual claim: ", claimed)
		quit(1)
		return
	var wallet_after: Dictionary = session.economy.budget().duplicate(true)
	var drones_after: int = session.hyperspace_system.warehouse().main.size()
	if wallet_after == wallet_before or drones_after != drones_before + 1 or not session.claim_hyperspace(run_id).already_claimed or session.economy.budget() != wallet_after or session.hyperspace_system.warehouse().main.size() != drones_after:
		printerr("manual reward double credit")
		quit(1)
		return
	print("manual ten battles, return and one credit accepted")
	var cleared_stages: Dictionary = session.campaign_system._state.cleared_stages.duplicate()
	cleared_stages[10] = true
	session.campaign_system._state.cleared_stages = cleared_stages
	session.campaign_system._state.highest_reached = 11
	session.crew_system.refresh_availability(session.campaign_system.available)
	var crew_id: String = str(session.crew_system._members.keys()[0])
	if not session.crew_system.hyperspace_candidate(crew_id).ok:
		printerr("runtime crew unlock fixture")
		quit(1)
		return
	var auto_started: Dictionary = session.start_hyperspace_auto("alpha", crew_id)
	if not auto_started.ok:
		printerr("runtime auto start: ", auto_started)
		quit(1)
		return
	var first_id: int = int(auto_started.receipt.run_id)
	var first_claimed: bool = false
	for step in 30000:
		session._step(1.0 / 60.0)
		if not session.run_state.is_running():
			printerr("runtime auto fault at step ", step, ": ", session.run_state.rejection())
			quit(1)
			return
		if session.hyperspace_system.online_status().idle.status == "Claimed":
			first_claimed = true
			break
	if not first_claimed or not session.claim_hyperspace(first_id).already_claimed:
		printerr("runtime auto first receipt")
		quit(1)
		return
	session._step(1.0 / 60.0)
	var second: Dictionary = session.hyperspace_system.online_status().idle
	if not session.run_state.is_running() or second.status != "Started" or int(second.run_id) == first_id or float(second.work) <= 0.0:
		printerr("runtime auto second start: ", session.hyperspace_system.online_status(), " crew ", session.crew_system._members[crew_id], " run ", session.run_state.rejection(), " game ", session.game_time)
		quit(1)
		return
	var owner = session.hyperspace_system
	var filler: int = 0
	while owner._warehouse.size() < owner._warehouse_capacity():
		owner._warehouse.append({"id": "runtime-fill-" + str(filler)})
		filler += 1
	while owner._overflow.size() < int(owner._parameters.overflow_capacity):
		owner._overflow.append({"id": "runtime-fill-" + str(filler)})
		filler += 1
	var pending: bool = false
	for step in 30000:
		session._step(1.0 / 60.0)
		if not session.run_state.is_running():
			printerr("runtime full warehouse fault: ", session.run_state.rejection())
			quit(1)
			return
		if owner.online_status().idle.status == "CompletedPending":
			pending = true
			break
	if not pending or owner.prepare_claim(int(second.run_id)).get("reason") != "WarehouseFull":
		printerr("runtime full warehouse did not hold receipt: ", owner.online_status())
		quit(1)
		return
	var blocked_wallet: Dictionary = session.economy.budget().duplicate(true)
	session._step(1.0 / 60.0)
	if owner.online_status().idle.status != "CompletedPending" or session.economy.budget() != blocked_wallet:
		printerr("runtime full warehouse double credit")
		quit(1)
		return
	var freed_for_claim: Dictionary = session.dismantle_hyperspace_drone(str(claimed.reward.drone.id))
	if not freed_for_claim.ok:
		printerr("runtime storage release for claim: ", freed_for_claim)
		quit(1)
		return
	session._step(1.0 / 60.0)
	if owner.online_status().idle.status != "Claimed" or not session.claim_hyperspace(int(second.run_id)).already_claimed or session.economy.budget() == blocked_wallet:
		printerr("runtime full warehouse recovery: ", owner.online_status())
		quit(1)
		return
	var freed_for_next: Dictionary = session.dismantle_hyperspace_drone(str(owner._receipts[first_id].reward.drone.id))
	if not freed_for_next.ok:
		printerr("runtime storage release for continuation: ", freed_for_next)
		quit(1)
		return
	session._step(1.0 / 60.0)
	if not session.run_state.is_running() or owner.online_status().idle.status != "Started" or int(owner.online_status().idle.run_id) == int(second.run_id):
		printerr("runtime auto continuation after recovery: ", owner.online_status())
		quit(1)
		return
	print("runtime auto two rounds and warehouse recovery accepted")
	quit(0)
