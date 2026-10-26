extends SceneTree
## C14: delayed damage starts at the next global 0.2-second tick.
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
	var ready: Dictionary = session.initialize("res://generated/config.json", 67)
	if ready.ok: ready = session.campaign_system.accept_reforge(session.campaign_system.save_state(), 8)
	if not ready.ok:
		printerr("C14 progress: ", ready)
		quit(1)
		return
	session.equipment.refresh_availability(session.campaign_system.available, 8, false)
	ready = session.equipment.equip_slot("defence:0", "shield", session.equipment_inputs(), session.publish_equipment_refit)
	if ready.ok: ready = session.campaign_system.start_sortie(1, session.equipment.clear_switch_locks)
	if not ready.ok:
		printerr("C14 shield fixture: ", ready)
		quit(1)
		return
	var setup: Dictionary = session._growth_setup()
	if not setup.ok:
		printerr("C14 growth setup: ", setup)
		quit(1)
		return
	for row in session.battle._prepared_player.descriptor.defences:
		if str(row.entry.id) == "defence:0":
			row.base = "1e2"
			row.deferred_fraction = 0.5
			row.delay = 100.0
	ready = session.battle.commit_player("growth", false)
	if not ready.ok:
		printerr("C14 defence commit: ", ready)
		quit(1)
		return
	var player_weapon: Dictionary = session.battle._values.weapons["weapon:0"].duplicate()
	player_weapon.base = "0e0"
	ready = session.battle._kernel.set_player_values({"weapon:0": player_weapon}, {}, "growth", "")
	if not ready.ok:
		printerr("C14 zero attack: ", ready)
		quit(1)
		return
	var inputs: Dictionary = session.battle.wave_inputs()
	var wave: Dictionary = session.campaign_system.prepare_wave(session.equipment.enemy_override, inputs.geometry, inputs.motion)
	if not wave.ok:
		printerr("C14 wave: ", wave)
		quit(1)
		return
	wave.wave.enemies[0].hp = "1e6"
	wave.wave.enemies[0].max_hp = "1e6"
	var source: Dictionary = wave.wave.weapons[0]
	source.damage = "1e2"
	source.interval = 1000000.0
	source.remaining = 0.5
	ready = session.battle.start_wave(wave)
	if not ready.ok:
		printerr("C14 native wave: ", ready)
		quit(1)
		return
	var initial_shield: String = str(session.battle._kernel.player_view().shield)
	var at_hit: float = -1.0
	var after_hit: String = ""
	for step in 500:
		session.battle.begin_frame()
		var advanced: Dictionary = session.battle.advance(0.01)
		if not advanced.ok:
			printerr("C14 advance: ", advanced)
			quit(1)
			return
		for receipt in session.battle.consume_damage_receipts():
			if receipt.hostile:
				at_hit = float(receipt.clock)
				after_hit = str(session.battle._kernel.player_view().shield)
				break
		if at_hit > 0: break
	if at_hit < 0:
		printerr("C14 no hostile impact")
		quit(1)
		return
	var sampled: Array = []
	for step in 40:
		session.battle.begin_frame()
		var advanced: Dictionary = session.battle.advance(0.01)
		if not advanced.ok:
			printerr("C14 debt advance: ", advanced)
			quit(1)
			return
		sampled.append(str(session.battle._kernel.player_view().shield))
	if initial_shield != "1e2" or not is_equal_approx(at_hit, 1.16) or after_hit != "7.5e1" or \
			sampled[2] != "7.5e1" or sampled[3] != "7.25e1" or \
			sampled[22] != "7.25e1" or sampled[23] != "7e1":
		printerr("C14 global debt tick or duplicate payment: ", initial_shield, " ", at_hit, " ", after_hit, " ", sampled)
		quit(1)
		return
	print("STAGE6_DEFERRED_ORACLE_OK C14; hit at 1.16, debt at 1.20 and 1.40")
	quit()
