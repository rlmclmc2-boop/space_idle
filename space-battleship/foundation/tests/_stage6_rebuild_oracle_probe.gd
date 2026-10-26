extends SceneTree
## C13: one drone sacrifice rebuilds; the next lethal hit retreats.
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
	var ready: Dictionary = session.initialize("res://generated/config.json", 97)
	if ready.ok: ready = session.campaign_system.accept_reforge(session.campaign_system.save_state(), 8)
	if not ready.ok:
		printerr("C13 progress: ", ready)
		quit(1)
		return
	session.equipment.refresh_availability(session.campaign_system.available, 8, false)
	var motion: Dictionary = session.battle.wave_inputs().motion
	var donor: Dictionary = session.equipment.drone_weapon_source("cannon", 0, 0, session._research_factors, session._reactor_factors, motion)
	if not donor.ok:
		printerr("C13 donor: ", donor)
		quit(1)
		return
	ready = session.set_equipped_drone_contributions([{"id": "rebuild-probe", "generation": 1,
		"quality": "white", "weapon": donor.weapon, "legendary_effect": "drone_rebuild",
		"legendary_parameters": {"damage_and_defence_bonus": 0.7}}])
	if ready.ok: ready = session.campaign_system.start_sortie(1, session.equipment.clear_switch_locks)
	if not ready.ok:
		printerr("C13 equip rebuild: ", ready)
		quit(1)
		return
	var value: Dictionary = session.battle._values.weapons["weapon:0"].duplicate()
	value.base = "0e0"
	ready = session.battle._kernel.set_player_values({"weapon:0": value}, {}, "growth", "")
	if not ready.ok:
		printerr("C13 zero attack: ", ready)
		quit(1)
		return
	var inputs: Dictionary = session.battle.wave_inputs()
	var setup: Dictionary = session.campaign_system.prepare_wave(session.equipment.enemy_override, inputs.geometry, inputs.motion)
	if not setup.ok:
		printerr("C13 wave: ", setup)
		quit(1)
		return
	setup.wave.enemies[0].hp = "1e6"
	setup.wave.enemies[0].max_hp = "1e6"
	var source: Dictionary = setup.wave.weapons[0]
	source.damage = "1e4"
	source.interval = 0.5
	source.remaining = 0.5
	ready = session.battle.start_wave(setup)
	if not ready.ok:
		printerr("C13 native wave: ", ready)
		quit(1)
		return
	var contacts: Array = []
	for step in 500:
		session.battle.begin_frame()
		var result: Dictionary = session.battle.advance(0.01)
		if not result.ok:
			printerr("C13 native step: ", result)
			quit(1)
			return
		for receipt in session.battle.consume_damage_receipts():
			if receipt.hostile:
				contacts.append({"clock": receipt.clock, "player": session.battle._kernel.player_view(),
					"dead": result.player_dead})
		if result.player_dead: break
	if contacts.size() != 2 or not is_equal_approx(float(contacts[0].clock), 1.16) or \
			not is_equal_approx(float(contacts[1].clock), 1.66) or contacts[0].dead or not contacts[1].dead or \
			str(contacts[0].player.armour) != "1.7e3" or str(contacts[1].player.armour) != "0e0":
		printerr("C13 rebuild did not consume exactly one drone before retreat: ", contacts)
		quit(1)
		return
	print("STAGE6_REBUILD_ORACLE_OK C13; full 1700 armour at 1.16, final death at 1.66")
	quit()
