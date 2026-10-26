extends SceneTree
## C06: a launched missile keeps its source after the drone is unequipped.
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
	var ready: Dictionary = session.initialize("res://generated/config.json", 83)
	if ready.ok: ready = session.campaign_system.accept_reforge(session.campaign_system.save_state(), 8)
	if not ready.ok:
		printerr("C06 progress: ", ready)
		quit(1)
		return
	session.equipment.refresh_availability(session.campaign_system.available, 8, false)
	ready = session.equipment.equip_slot("weapon:0", "cannon", session.equipment_inputs(), session.publish_equipment_refit)
	if not ready.ok:
		printerr("C06 player cannon: ", ready)
		quit(1)
		return
	var motion: Dictionary = session.battle.wave_inputs().motion
	var donor: Dictionary = session.equipment.drone_weapon_source("missile", 0, 0, session._research_factors, session._reactor_factors, motion)
	if not donor.ok:
		printerr("C06 drone source: ", donor)
		quit(1)
		return
	donor.weapon.damage = "1e2"
	ready = session.set_equipped_drone_contributions([{"id": "source-probe", "generation": 1,
		"quality": "white", "weapon": donor.weapon}])
	if ready.ok: ready = session.campaign_system.start_sortie(1, session.equipment.clear_switch_locks)
	if not ready.ok:
		printerr("C06 equip drone: ", ready)
		quit(1)
		return
	var player: Dictionary = session.battle._values.weapons["weapon:0"].duplicate()
	player.base = "0e0"
	ready = session.battle._kernel.set_player_values({"weapon:0": player}, {}, "growth", "")
	if not ready.ok:
		printerr("C06 zero player attack: ", ready)
		quit(1)
		return
	var inputs: Dictionary = session.battle.wave_inputs()
	var setup: Dictionary = session.campaign_system.prepare_wave(session.equipment.enemy_override, inputs.geometry, inputs.motion)
	if not setup.ok:
		printerr("C06 wave: ", setup)
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
		printerr("C06 native wave: ", ready)
		quit(1)
		return
	var launched: bool = false
	var launch_clock: float = -1.0
	for step in 500:
		session.battle.begin_frame()
		var result: Dictionary = session.battle.advance(0.01)
		if not result.ok:
			printerr("C06 launch step: ", result)
			quit(1)
			return
		if int(session.battle._kernel.read_history().attacks) > 0:
			if not session.battle.consume_damage_receipts().is_empty():
				printerr("C06 source changed after contact")
				quit(1)
				return
			launched = true
			launch_clock = float(step + 1) * 0.01
			break
	if not launched:
		printerr("C06 donor missile did not launch")
		quit(1)
		return
	ready = session.set_equipped_drone_contributions([])
	if not ready.ok or not session.battle._equipped_drones.is_empty():
		printerr("C06 remove in-flight source: ", ready)
		quit(1)
		return
	var receipts: Array = []
	for step in 600:
		session.battle.begin_frame()
		var result: Dictionary = session.battle.advance(0.01)
		if not result.ok:
			printerr("C06 after source removal: ", result)
			quit(1)
			return
		for receipt in session.battle.consume_damage_receipts():
			if not receipt.hostile: receipts.append(receipt)
		if receipts.any(func(receipt): return int(receipt.type) == 2): break
	var totals: Dictionary = session.battle.statistics()._totals
	var drone_total: Dictionary = totals.get("drone:source-probe", {})
	if receipts.size() != 1 or int(receipts[0].type) != 2 or str(receipts[0].damage) != "1e2" or \
			float(receipts[0].clock) <= launch_clock or drone_total.is_empty() or totals.has("module:0") or \
			float(session.amount_api.apply("to_display", [drone_total.health]).text) != 100.0:
		printerr("C06 in-flight source lost or reassigned: ", receipts, " ", totals)
		quit(1)
		return
	print("STAGE6_SOURCE_SNAPSHOT_ORACLE_OK C06; source removed at ", launch_clock,
		" before its missile hit at ", receipts[0].clock)
	quit()
