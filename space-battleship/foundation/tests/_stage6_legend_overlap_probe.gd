extends "res://foundation/tests/_stage6_critical_oracle_probe.gd"
## C11: scatter and laser charge overlap, then charge is unequipped.

func _run() -> void:
	var session = Session.new()
	var ready: Dictionary = session.initialize("res://generated/config.json", 107)
	if ready.ok: ready = session.campaign_system.accept_reforge(session.campaign_system.save_state(), 21)
	if not ready.ok:
		printerr(ready)
		quit(1)
		return
	session.equipment.refresh_availability(session.campaign_system.available, 21, false)
	ready = session.campaign_system.change_ship("Cruiser", session.commit_ship_refit)
	var motion: Dictionary = session.battle.wave_inputs().motion
	var donor: Dictionary = session.equipment.drone_weapon_source("laser", 0, 0, session._research_factors, session._reactor_factors, motion)
	if not ready.ok or not donor.ok:
		printerr(ready, donor)
		quit(1)
		return
	donor.weapon.interval = 1000000.0
	donor.weapon.remaining = 1000000.0
	var scatter: Dictionary = {"id": "overlap-scatter", "generation": 1, "quality": "white", "weapon": donor.weapon,
		"legendary_effect": "scatter_pulse", "legendary_parameters": {"single_target_bonus": 2.5}}
	var charge: Dictionary = {"id": "overlap-charge", "generation": 1, "quality": "white", "weapon": donor.weapon,
		"legendary_effect": "laser_charge", "legendary_parameters": {"maximum_bonus": 2.5}}
	ready = session.set_equipped_drone_contributions([scatter, charge])
	if ready.ok: ready = session.campaign_system.start_sortie(1, session.equipment.clear_switch_locks)
	var value: Dictionary = session.battle._values.weapons["weapon:0"].duplicate()
	value.base = "1e2"
	if ready.ok: ready = session.battle._kernel.set_player_values({"weapon:0": value}, {}, "growth", "")
	var inputs: Dictionary = session.battle.wave_inputs()
	var setup: Dictionary = session.campaign_system.prepare_wave(session.equipment.enemy_override, inputs.geometry, inputs.motion)
	if not ready.ok or not setup.ok:
		printerr(ready, setup)
		quit(1)
		return
	setup.wave.enemies[0].hp = "1e6"
	setup.wave.enemies[0].max_hp = "1e6"
	setup.wave.enemies[0].shield = "0e0"
	setup.wave.enemies[0].max_shield = "0e0"
	setup.wave.enemies[0].armourType = 0
	setup.wave.weapons = []
	ready = session.battle.start_wave(setup)
	if not ready.ok:
		printerr(ready)
		quit(1)
		return
	var first: Dictionary = _first_receipt(session)
	ready = session.set_equipped_drone_contributions([scatter])
	# Session publication recomputes module values; set the independent 100 base again.
	if ready.ok: ready = session.battle._kernel.set_player_values({"weapon:0": value}, {}, "growth", "")
	var second: Dictionary = _first_receipt(session)
	if not ready.ok or not first.ok or not second.ok or str(first.receipt.damage) != "8.75e2" or str(second.receipt.damage) != "3.5e2":
		printerr("C11 overlap/unload: ", ready, first, second)
		quit(1)
		return
	ready = session.set_equipped_drone_contributions([])
	if ready.ok: ready = session.battle._kernel.set_player_values({"weapon:0": value}, {}, "growth", "")
	var third: Dictionary = _first_receipt(session)
	if ready.ok: ready = session.set_equipped_drone_contributions([scatter, charge])
	if ready.ok: ready = session.battle._kernel.set_player_values({"weapon:0": value}, {}, "growth", "")
	var fourth: Dictionary = _first_receipt(session)
	if not ready.ok or not third.ok or not fourth.ok or str(third.receipt.damage) != "1e2" or str(fourth.receipt.damage) != "8.75e2":
		printerr("C11 unload/reinstall: ", ready, third, fourth)
		quit(1)
		return
	print("STAGE6_LEGEND_OVERLAP_OK C11; overlap 875, charge unload 350, full unload 100, reinstall 875")
	quit()
