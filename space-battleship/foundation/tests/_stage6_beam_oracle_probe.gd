extends SceneTree
const Session = preload("res://src/game_session.gd")

func _initialize() -> void:
	var loaded = GDExtensionManager.load_extension(OS.get_environment("SPACE_IDLE_NATIVE_EXTENSION"))
	if loaded != GDExtensionManager.LOAD_STATUS_OK and loaded != GDExtensionManager.LOAD_STATUS_ALREADY_LOADED:
		printerr("native extension unavailable")
		quit(1)
		return
	call_deferred("_run")

func _run() -> void:
	var session = Session.new()
	var ready: Dictionary = session.initialize("res://generated/config.json", 59)
	if ready.ok: ready = session.campaign_system.accept_reforge(session.campaign_system.save_state(), 8)
	if not ready.ok:
		printerr("C08 progress: ", ready)
		quit(1)
		return
	session.equipment.refresh_availability(session.campaign_system.available, 8, false)
	ready = session.equipment.equip_slot("weapon:0", "longLaser", session.equipment_inputs(), session.publish_equipment_refit)
	if ready.ok: ready = session.campaign_system.start_sortie(1, session.equipment.clear_switch_locks)
	if not ready.ok:
		printerr("C08 beam equip: ", ready)
		quit(1)
		return
	var value: Dictionary = session.battle._values.weapons["weapon:0"].duplicate()
	value.base = "1e2"
	ready = session.battle._kernel.set_player_values({"weapon:0": value}, {}, "growth", "")
	if not ready.ok:
		printerr("C08 beam value: ", ready)
		quit(1)
		return
	var inputs: Dictionary = session.battle.wave_inputs()
	var setup: Dictionary = session.campaign_system.prepare_wave(session.equipment.enemy_override, inputs.geometry, inputs.motion)
	if not setup.ok:
		printerr("C08 wave: ", setup)
		quit(1)
		return
	var enemy: Dictionary = setup.wave.enemies[0]
	enemy.hp = "1e6"
	enemy.max_hp = "1e6"
	enemy.shield = "0e0"
	enemy.max_shield = "0e0"
	enemy.armourType = 0
	setup.wave.weapons = []
	ready = session.battle.start_wave(setup)
	if not ready.ok:
		printerr("C08 native wave: ", ready)
		quit(1)
		return
	var hits: Array = []
	for step in 30:
		session.battle.begin_frame()
		var advanced: Dictionary = session.battle.advance(0.37)
		if not advanced.ok:
			printerr("C08 advance: ", advanced)
			quit(1)
			return
		for receipt in session.battle.consume_damage_receipts():
			if not receipt.hostile: hits.append({"clock": receipt.clock, "damage": receipt.damage})
		if hits.size() >= 10: break
	var amounts: Array = [100.0, 125.0, 150.0, 175.0, 200.0, 225.0, 250.0, 275.0, 300.0, 300.0]
	if hits.size() != amounts.size():
		printerr("C08 beam ticks missing: ", hits)
		quit(1)
		return
	for index in amounts.size():
		var due: float = 1.0 + 0.25 * index
		if not is_equal_approx(float(hits[index].clock), due) or not is_equal_approx(float(hits[index].damage), amounts[index]):
			printerr("C08 used frame-end multiplier rather than due clock: ", hits[index], " expected=", due, ",", amounts[index])
			quit(1)
			return
	print("STAGE6_BEAM_ORACLE_OK C08 dueTime 1.00..3.25, ramp 100..300")
	var disconnected: Dictionary = _normal_disconnect()
	if not disconnected.ok:
		printerr("C08 normal beam disconnect: ", disconnected)
		quit(1)
		return
	var endless: Dictionary = _normal_disconnect(true)
	if not endless.ok:
		printerr("C08 endless beam continuation: ", endless)
		quit(1)
		return
	quit()

func _normal_disconnect(endless: bool = false) -> Dictionary:
	var session = Session.new()
	var ready: Dictionary = session.initialize("res://generated/config.json", 61)
	if ready.ok: ready = session.campaign_system.accept_reforge(session.campaign_system.save_state(), 8)
	if not ready.ok: return ready
	session.equipment.refresh_availability(session.campaign_system.available, 8, false)
	ready = session.equipment.equip_slot("weapon:0", "longLaser", session.equipment_inputs(), session.publish_equipment_refit)
	if ready.ok and endless:
		var motion: Dictionary = session.battle.wave_inputs().motion
		var donor: Dictionary = session.equipment.drone_weapon_source("laser", 0, 0, session._research_factors, session._reactor_factors, motion)
		if not donor.ok: return donor
		donor.weapon.interval = 1000000.0
		donor.weapon.remaining = 1000000.0
		ready = session.set_equipped_drone_contributions([{"id": "endless-probe", "generation": 1,
			"quality": "legendary", "weapon": donor.weapon, "legendary_effect": "endless_beam",
			"legendary_parameters": {"maximum_multiplier_bonus": 1.0}}])
	if ready.ok: ready = session.campaign_system.start_sortie(1, session.equipment.clear_switch_locks)
	if not ready.ok: return ready
	var value: Dictionary = session.battle._values.weapons["weapon:0"].duplicate()
	value.base = "1e2"
	ready = session.battle._kernel.set_player_values({"weapon:0": value}, {}, "growth", "")
	if not ready.ok: return ready
	var inputs: Dictionary = session.battle.wave_inputs()
	var setup: Dictionary = session.campaign_system.prepare_wave(session.equipment.enemy_override, inputs.geometry, inputs.motion)
	if not setup.ok: return setup
	var first: Dictionary = setup.wave.enemies[0]
	first.hp = "2e2"
	first.max_hp = "2e2"
	first.shield = "0e0"
	first.max_shield = "0e0"
	first.armourType = 0
	var other: Dictionary = first.duplicate(true)
	other.uid = 2
	other.slot = 8
	other.x = 360.0
	other.hp = "1e6"
	other.max_hp = "1e6"
	setup.wave.enemies.append(other)
	setup.wave.weapons = []
	ready = session.battle.start_wave(setup)
	if not ready.ok: return ready
	var impacts: Array = []
	for step in 600:
		session.battle.begin_frame()
		var advanced: Dictionary = session.battle.advance(0.01)
		if not advanced.ok: return advanced
		for receipt in session.battle.consume_damage_receipts():
			if not receipt.hostile: impacts.append({"clock": receipt.clock, "x": receipt.position.x, "damage": receipt.damage})
		if impacts.size() >= 4: break
	if endless:
		var continued: Array = [
			{"clock": 1.0, "x": 286.0, "damage": "1e2"},
			{"clock": 1.25, "x": 286.0, "damage": "1e2"},
			{"clock": 1.5, "x": 360.0, "damage": "1.75e2"},
			{"clock": 1.75, "x": 360.0, "damage": "2.13e2"}]
		if impacts.size() != continued.size(): return {"ok": false, "reason": "EndlessReconnectMissing", "impacts": impacts}
		for index in continued.size():
			if not is_equal_approx(float(impacts[index].clock), float(continued[index].clock)) or not is_equal_approx(float(impacts[index].x), float(continued[index].x)) or impacts[index].damage != continued[index].damage:
				return {"ok": false, "reason": "EndlessLostCharge", "impacts": impacts}
		print("C08 endless beam retained charge; new target hit at 1.50 for 175")
		return {"ok": true}
	var expected: Array = [
		{"clock": 1.0, "x": 286.0, "damage": "1e2"},
		{"clock": 1.25, "x": 286.0, "damage": "1e2"},
		{"clock": 2.25, "x": 360.0, "damage": "1e2"},
		{"clock": 2.5, "x": 360.0, "damage": "1.25e2"}]
	if impacts.size() != expected.size(): return {"ok": false, "reason": "BeamRetargetMissing", "impacts": impacts}
	for index in expected.size():
		if not is_equal_approx(float(impacts[index].clock), float(expected[index].clock)) or not is_equal_approx(float(impacts[index].x), float(expected[index].x)) or impacts[index].damage != expected[index].damage:
			return {"ok": false, "reason": "BeamDidNotResetCharge", "impacts": impacts}
	print("C08 normal beam disconnected at 1.25 and recharged before 2.25")
	return {"ok": true}
