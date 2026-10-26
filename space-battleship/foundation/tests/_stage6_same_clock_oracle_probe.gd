extends SceneTree
## C06: two independently configured cannons due on one native clock.
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
	var ready: Dictionary = session.initialize("res://generated/config.json", 61)
	if ready.ok: ready = session.campaign_system.accept_reforge(session.campaign_system.save_state(), 21)
	if not ready.ok:
		printerr("C06 progress: ", ready)
		quit(1)
		return
	session.equipment.refresh_availability(session.campaign_system.available, 21, false)
	ready = session.campaign_system.change_ship("Cruiser", session.commit_ship_refit)
	if ready.ok: ready = session.equipment.equip_slot("weapon:0", "cannon", session.equipment_inputs(), session.publish_equipment_refit)
	if ready.ok: ready = session.equipment.equip_slot("weapon:1", "cannon", session.equipment_inputs(), session.publish_equipment_refit)
	if ready.ok: ready = session.campaign_system.start_sortie(1, session.equipment.clear_switch_locks)
	if not ready.ok:
		printerr("C06 cannons: ", ready)
		quit(1)
		return
	var prepared: Dictionary = session._growth_setup()
	if not prepared.ok:
		printerr("C06 growth: ", prepared)
		quit(1)
		return
	var cannon_count: int = 0
	var due_times: Array = []
	for row in session.battle._prepared_player.descriptor.weapons:
		if str(row.entry.id) in ["weapon:0", "weapon:1"]:
			row.base = "1e2"
			due_times.append(float(row.remaining))
			cannon_count += 1
	if cannon_count != 2 or not is_equal_approx(due_times[0], due_times[1]):
		printerr("C06 missing simultaneous configured cannons: ", due_times)
		quit(1)
		return
	ready = session.battle.commit_player("growth", false)
	if not ready.ok:
		printerr("C06 native commit: ", ready)
		quit(1)
		return
	var inputs: Dictionary = session.battle.wave_inputs()
	var setup: Dictionary = session.campaign_system.prepare_wave(session.equipment.enemy_override, inputs.geometry, inputs.motion)
	if not setup.ok:
		printerr("C06 wave: ", setup)
		quit(1)
		return
	var enemy: Dictionary = setup.wave.enemies[0]
	enemy.hp = "1e0"
	enemy.max_hp = "1e0"
	enemy.shield = "0e0"
	enemy.max_shield = "0e0"
	setup.wave.weapons = []
	ready = session.battle.start_wave(setup)
	if not ready.ok:
		printerr("C06 native wave: ", ready)
		quit(1)
		return
	var receipts: Array = []
	var drops: Array = []
	for step in 500:
		session.battle.begin_frame()
		var result: Dictionary = session.battle.advance(0.01)
		if not result.ok:
			printerr("C06 native advance: ", result)
			quit(1)
			return
		for receipt in session.battle.consume_damage_receipts():
			if not receipt.hostile: receipts.append(receipt)
		for drop in result.drops: drops.append(drop)
		if not receipts.is_empty(): break
	if receipts.size() != 1 or str(receipts[0].damage) != "1e0" or drops.size() != 1 or \
			int(session.battle._kernel.read_history().attacks) != 1 or not session.battle._kernel.enemy_views()[0].dead or \
			not is_equal_approx(float(receipts[0].clock), due_times[0]):
		printerr("C06 same-clock double hit/death: ", receipts, " ", drops, " ", session.battle._kernel.read_history())
		quit(1)
		return
	session.battle.begin_frame()
	var tail: Dictionary = session.battle.advance(4.0)
	if not tail.ok or not tail.drops.is_empty() or not session.battle.consume_damage_receipts().is_empty() or \
			int(session.battle._kernel.read_history().attacks) != 1:
		printerr("C06 duplicate aftermath: ", tail, " ", session.battle._kernel.read_history())
		quit(1)
		return
	print("STAGE6_SAME_CLOCK_ORACLE_OK C06; two cannons due at ", due_times[0],
		" one root, one death, one drop")
	quit()
