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
	var extra: Dictionary = session.equipment.drone_weapon_source("laser", 0, 0, session._research_factors, session._reactor_factors, motion)
	if not extra.ok:
		printerr(extra)
		quit(1)
		return
	extra.weapon.interval = 1000000.0
	extra.weapon.remaining = 1000000.0
	var scatter: Dictionary = {"id": "zz-scatter", "generation": 1, "quality": "white", "weapon": extra.weapon,
		"legendary_effect": "scatter_pulse", "legendary_parameters": {"single_target_bonus": 2.5}}
	ready = session.campaign_system.accept_reforge(session.campaign_system.save_state(), 21)
	if ready.ok:
		session.equipment.refresh_availability(session.campaign_system.available, 21, false)
		ready = session.campaign_system.change_ship("Cruiser", session.commit_ship_refit)
	if ready.ok: ready = session.set_equipped_drone_contributions([{"id": "rebuild-probe", "generation": 1,
		"quality": "white", "weapon": donor.weapon, "legendary_effect": "drone_rebuild",
		"legendary_parameters": {"damage_and_defence_bonus": 0.7}}, scatter])
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
	if contacts.size() != 2 or not is_equal_approx(float(contacts[0].clock), 1.13) or \
			not is_equal_approx(float(contacts[1].clock), 1.63) or contacts[0].dead or not contacts[1].dead or \
			str(contacts[0].player.armour) != "1.7e3" or str(contacts[1].player.armour) != "0e0":
		printerr("C13 rebuild did not consume exactly one drone before retreat: ", contacts)
		quit(1)
		return
	session.battle.reset_for_sortie()
	ready = session.battle.start_wave(setup)
	var restored: Dictionary = _until_dead(session)
	if not ready.ok or not restored.ok or restored.armour != ["1.7e3", "0e0"]:
		printerr("C11 rebuild did not restore disabled legend after reset: ", ready, restored)
		quit(1)
		return
	ready = session.set_equipped_drone_contributions([scatter])
	if ready.ok: ready = session.battle._kernel.set_player_values({"weapon:0": value}, {}, "growth", "")
	session.battle.reset_for_sortie()
	if ready.ok: ready = session.battle.start_wave(setup)
	var unloaded: Dictionary = _until_dead(session)
	if not ready.ok or not unloaded.ok or unloaded.armour != ["0e0"]:
		printerr("C11 removed rebuild source still active: ", ready, unloaded)
		quit(1)
		return
	print("STAGE6_REBUILD_LEGEND_OVERLAP_OK C11; rebuild+scatter, source sacrifice, reset restoration, rebuild unload leaves one lethal hit")
	quit()

func _until_dead(session) -> Dictionary:
	var armour: Array = []
	for index in 500:
		session.battle.begin_frame()
		var result: Dictionary = session.battle.advance(0.01)
		if not result.ok: return result
		for receipt in session.battle.consume_damage_receipts():
			if receipt.hostile: armour.append(str(session.battle._kernel.player_view().armour))
		if result.player_dead: return {"ok": true, "armour": armour}
	return {"ok": false, "reason": "NoLethalContact", "armour": armour}
