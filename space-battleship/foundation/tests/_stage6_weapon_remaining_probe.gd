extends "res://foundation/tests/_stage6_offensive_legends_probe.gd"

func _birth_case(b2: bool) -> Dictionary:
	var session = Session.new()
	var ready: Dictionary = session.initialize("res://generated/config.json", 157)
	if ready.ok: ready = session.campaign_system.accept_reforge(session.campaign_system.save_state(), 51)
	if not ready.ok: return ready
	session.equipment.refresh_availability(session.campaign_system.available, 51, false)
	var state: Dictionary = session.enhancement.save_state()
	state.level = 50
	state.branches = {"proficiency": ["", "B" if b2 else "", ""]}
	ready = session.enhancement.restore_state(state)
	if ready.ok: ready = session.equipment.equip_slot("weapon:0", "cannon", session.equipment_inputs(), session.publish_equipment_refit)
	if ready.ok: ready = session.campaign_system.start_sortie(1, session.equipment.clear_switch_locks)
	if not ready.ok: return ready
	var inputs: Dictionary = session.battle.wave_inputs()
	var setup: Dictionary = session.campaign_system.prepare_wave(session.equipment.enemy_override, inputs.geometry, inputs.motion)
	if not setup.ok: return setup
	setup.wave.enemies[0].hp = "1e6"
	setup.wave.enemies[0].max_hp = "1e6"
	setup.wave.weapons = []
	ready = session.battle.start_wave(setup)
	if not ready.ok: return ready
	for index in 500:
		session.battle.begin_frame()
		var advanced: Dictionary = session.battle.advance(0.01)
		if not advanced.ok: return advanced
		if int(session.battle._kernel.read_history().attacks) > 0: return {"ok": true, "clock": float(index + 1) * 0.01}
	return {"ok": false, "reason": "NoBirth"}

func _run() -> void:
	for choices in [["", "", ""], ["A", "", ""], ["A", "A", "A"]]:
		var fixture: Dictionary = _fixture(1014960426271799216, 50, true, [], 1, choices)
		if not fixture.ok:
			printerr(fixture)
			quit(1)
			return
		var hit: Dictionary = _first_receipt(fixture.session)
		var expected: bool = choices[0] == "A"
		if not hit.ok or bool(hit.receipt.critical) != expected or str(hit.receipt.damage) != ("1.7e3" if expected else "1e2"):
			printerr("C09 critical A native probability: ", choices, fixture.u1, hit)
			quit(1)
			return
	var plain: Dictionary = _birth_case(false)
	var rapid: Dictionary = _birth_case(true)
	if not plain.ok or not rapid.ok or not is_equal_approx(float(plain.clock), 3.5) or not is_equal_approx(float(rapid.clock), 2.45):
		printerr("C09 proficiency B2 initial wait: ", plain, rapid)
		quit(1)
		return
	var target: Dictionary = _legend_fixture("", "laser", {}, 2, "3e2")
	if not target.ok:
		printerr(target)
		quit(1)
		return
	var session = target.session
	var state: Dictionary = session.enhancement.save_state()
	state.level = 50
	state.branches = {"proficiency": ["B", "", ""]}
	var ready: Dictionary = session.enhancement.restore_state(state)
	var output: Dictionary = session.enhancement.evaluate(0, func(_kind, _key): return true, 1)
	var weapon: Dictionary = output.weapon.duplicate(true)
	weapon.critical_rate = 0.0
	weapon.repeat_probability = 0.0
	var globals: Dictionary = output.globals.duplicate(true)
	globals.counter_growth = 0.0
	if ready.ok: ready = session.battle._kernel.set_player_values({}, {}, "growth", "", {"globals": globals, "weapon": weapon, "effects": output.effects})
	var advanced: Dictionary = _advance_case(target, 650)
	if not ready.ok or not advanced.ok or advanced.hits.size() != 4 or str(advanced.hits[3].damage) != "1e2" or float(advanced.hits[3].position.y) != 315.0:
		printerr("C09 proficiency B1 target reset: ", ready, advanced)
		quit(1)
		return
	print("STAGE6_WEAPON_REMAINING_OK C09 critical A probability, proficiency B2 birth3.50/2.45, B1 new target resets to100")
	quit()
