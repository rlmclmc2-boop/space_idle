extends SceneTree

const Session = preload("res://src/game_session.gd")

func _initialize() -> void:
	var loaded = GDExtensionManager.load_extension(OS.get_environment("SPACE_IDLE_NATIVE_EXTENSION"))
	if loaded != GDExtensionManager.LOAD_STATUS_OK and loaded != GDExtensionManager.LOAD_STATUS_ALREADY_LOADED:
		printerr("native extension unavailable")
		quit(1)
		return
	call_deferred("_run")

func _fixture(seed: int, level: int, b3: bool, order: Array = [], paid_level: int = 1, critical_choices: Array = [], drone_bonus: float = 0.0, force_repeat: bool = false, interval_multiplier: float = 1.0, enemy_armour_type: int = 0) -> Dictionary:
	var session = Session.new()
	var ready: Dictionary = session.initialize("res://generated/config.json", seed)
	if ready.ok and paid_level != 1:
		var equipment_state: Dictionary = session.equipment.save_state()
		for slot in equipment_state.slots:
			if slot.id == "weapon:0": slot.paid_level = paid_level
		ready = session.equipment.restore_state(equipment_state, session.campaign_system.ship_facts().mounts)
	if ready.ok and drone_bonus > 0.0:
		var motion: Dictionary = session.battle.wave_inputs().motion
		var donor: Dictionary = session.equipment.drone_weapon_source("laser", 0, 0, session._research_factors, session._reactor_factors, motion)
		if not donor.ok: return donor
		donor.weapon.interval = 1000000.0
		donor.weapon.remaining = 1000000.0
		ready = session.set_equipped_drone_contributions([{"id": "critical-probe", "generation": 1,
			"quality": "white", "weapon": donor.weapon, "critical_rate_bonus": drone_bonus}])
	if ready.ok: ready = session.campaign_system.start_sortie(1, session.equipment.clear_switch_locks)
	if not ready.ok: return ready
	var state: Dictionary = session.enhancement.save_state()
	state.level = level
	state.weapon_order = order if not order.is_empty() else ["critical", "proficiency", "repeat"]
	if b3: state.branches = {"critical": critical_choices if not critical_choices.is_empty() else ["", "", "B"]}
	ready = session.enhancement.restore_state(state)
	if not ready.ok: return ready
	var output: Dictionary = session.enhancement.evaluate(0, func(_kind, _key): return true, 1)
	if not output.ok: return output
	var value: Dictionary = session.battle._values.weapons["weapon:0"].duplicate()
	value.base = "1e2"
	var native_output: Dictionary = output
	if force_repeat or interval_multiplier != 1.0:
		var weapon_output: Dictionary = {}
		for key in output.weapon: weapon_output[key] = output.weapon[key]
		if force_repeat: weapon_output.repeat_probability = 1.0
		if interval_multiplier != 1.0: weapon_output.interval_multiplier = interval_multiplier
		native_output = {"globals": output.globals, "weapon": weapon_output,
			"defence": output.defence, "effects": output.effects}
	ready = session.battle._kernel.set_player_values({"weapon:0": value}, {}, "growth", "", native_output)
	if not ready.ok: return ready
	var inputs: Dictionary = session.battle.wave_inputs()
	var setup: Dictionary = session.campaign_system.prepare_wave(session.equipment.enemy_override, inputs.geometry, inputs.motion)
	if not setup.ok: return setup
	var enemy: Dictionary = setup.wave.enemies[0]
	enemy.shield = "0e0"
	enemy.max_shield = "0e0"
	enemy.hp = "1e4"
	enemy.max_hp = "1e4"
	enemy.armourType = enemy_armour_type
	setup.wave.weapons = []
	ready = session.battle.start_wave(setup)
	if not ready.ok: return ready
	var native_state: Dictionary = session.battle._kernel.persistent_state()
	var random := RandomNumberGenerator.new()
	random.state = int(native_state.rng_state)
	return {"ok": true, "session": session, "output": output,
		"u1": random.randf(), "u2": random.randf()}

func _first_receipt(session) -> Dictionary:
	for step in 500:
		session.battle.begin_frame()
		var result: Dictionary = session.battle.advance(0.01)
		if not result.ok: return result
		var receipts: Array = session.battle.consume_damage_receipts()
		if not receipts.is_empty(): return {"ok": true, "receipt": receipts[0]}
	return {"ok": false, "reason": "NoImpact"}

func _run() -> void:
	var cases: Array = [
		{"id": "CR01", "seed": 120828829812621612, "level": 0, "b3": false,
			"rate": 0.0, "multiplier": 2.0, "critical": false, "bonus": false, "damage": "1e2"},
		{"id": "CR02", "seed": 120828829812621612, "level": 1, "b3": false,
			"rate": 0.25, "multiplier": 2.3, "critical": true, "bonus": true, "damage": "2.3e2"},
		{"id": "CR03", "seed": 2478752393832935995, "level": 1, "b3": false,
			"rate": 0.25, "multiplier": 2.3, "critical": false, "bonus": false, "damage": "1e2"},
		{"id": "CR04", "seed": 1014960426271799216, "level": 50, "b3": true,
			"rate": 0.25, "multiplier": 17.0, "critical": true, "bonus": true, "damage": "1.7e3"},
		{"id": "CR05", "seed": 120828829812621612, "level": 50, "b3": true,
			"rate": 0.25, "multiplier": 17.0, "critical": true, "bonus": false, "damage": "1e2"},
	]
	for expected in cases:
		var fixture: Dictionary = _fixture(int(expected.seed), int(expected.level), bool(expected.b3))
		if not fixture.ok:
			printerr(expected.id, " fixture: ", fixture)
			quit(1)
			return
		var rate: float = float(fixture.output.weapon.critical_rate)
		var multiplier: float = float(fixture.output.weapon.critical_multiplier)
		if not is_equal_approx(rate, expected.rate) or not is_equal_approx(multiplier, expected.multiplier) or bool(fixture.output.effects.critical.b3) != expected.b3:
			printerr(expected.id, " enhancement values: ", fixture.output.weapon, " ", fixture.output.effects.critical)
			quit(1)
			return
		if bool(expected.b3):
			if bool(expected.bonus) != (float(fixture.u2) < rate):
				printerr(expected.id, " u2 boundary: ", fixture.u2)
				quit(1)
				return
		elif bool(expected.critical) != (float(fixture.u1) < rate):
			printerr(expected.id, " u1 boundary: ", fixture.u1)
			quit(1)
			return
		var first: Dictionary = _first_receipt(fixture.session)
		if not first.ok or bool(first.receipt.critical) != expected.critical or bool(first.receipt.critical_bonus_applied) != expected.bonus or str(first.receipt.damage) != expected.damage:
			printerr(expected.id, " native impact: ", first)
			quit(1)
			return
		print(expected.id, " seed=", expected.seed, " u1=", fixture.u1,
			" u2=", fixture.u2 if expected.b3 else "unused", " damage=", first.receipt.damage)
	var gate_reference: Dictionary = _fixture(1014960426271799216, 50, true)
	if not gate_reference.ok:
		printerr("CR09 gate reference: ", gate_reference)
		quit(1)
		return
	var gate_rules: Dictionary = gate_reference.session.enhancement._rules
	for position in 3:
		var order: Array = ["proficiency", "repeat", "critical"]
		order.remove_at(2)
		order.insert(position, "critical")
		var gate: int = int(gate_rules.branch_threshold_3) + int(gate_rules["branch_position_offset_" + str(position + 1)])
		for level in [gate - 1, gate]:
			for paid_level in [1, 30]:
				var selected: Dictionary = _fixture(1014960426271799216, level, true, order, paid_level)
				if not selected.ok:
					printerr("CR09 fixture: ", selected)
					quit(1)
					return
				var active: bool = level >= gate
				if bool(selected.output.effects.critical.b3) != active:
					printerr("CR09 branch gate position=", position, " level=", level, " paid=", paid_level)
					quit(1)
					return
				var receipt: Dictionary = _first_receipt(selected.session)
				if not receipt.ok or bool(receipt.receipt.critical) != active or bool(receipt.receipt.critical_bonus_applied) != active:
					printerr("CR09 native gate position=", position, " level=", level, " paid=", paid_level, " receipt=", receipt)
					quit(1)
					return
				print("CR09 position=", position + 1, " E=", level, " paid=", paid_level, " b3=", active)
	var marked: Dictionary = _fixture(120828829812621612, 50, true, [], 1, ["B", "B", "B"])
	if not marked.ok or not bool(marked.output.effects.critical.b1) or not bool(marked.output.effects.critical.b2):
		printerr("CR07 branch fixture: ", marked)
		quit(1)
		return
	var first_mark: Dictionary = _first_receipt(marked.session)
	var second_mark: Dictionary = _first_receipt(marked.session)
	if not first_mark.ok or not second_mark.ok:
		printerr("CR07 missing attacks: ", first_mark, " ", second_mark)
		quit(1)
		return
	if str(first_mark.receipt.damage) != "1e2" or not bool(first_mark.receipt.critical) or bool(first_mark.receipt.critical_bonus_applied):
		printerr("CR07 first mark: ", first_mark)
		quit(1)
		return
	var reference: Dictionary = _fixture(120828829812621612, 50, true)
	if not reference.ok:
		printerr("CR07 unmarked reference: ", reference)
		quit(1)
		return
	var reference_first: Dictionary = _first_receipt(reference.session)
	var reference_second: Dictionary = _first_receipt(reference.session)
	if not reference_first.ok or not reference_second.ok or str(reference_first.receipt.damage) != str(first_mark.receipt.damage) or bool(reference_second.receipt.critical_bonus_applied) != bool(second_mark.receipt.critical_bonus_applied):
		printerr("CR07 mismatched native reference: ", reference_first, " ", reference_second)
		quit(1)
		return
	var second_expected: float = float(reference_second.receipt.damage) * 1.5 * 1.1
	if not bool(second_mark.receipt.critical) or absf(float(second_mark.receipt.damage) / second_expected - 1.0) > 0.01:
		printerr("CR07 following attack did not read B1/B2 marks: ", second_mark, " expected~", second_expected)
		quit(1)
		return
	var derived: Dictionary = _fixture(120828829812621612, 50, true, [], 1, ["B", "B", "B"], 0.0, true)
	if not derived.ok:
		printerr("CR07 derived fixture: ", derived)
		quit(1)
		return
	var root_mark: Dictionary = _first_receipt(derived.session)
	var repeated_mark: Dictionary = _first_receipt(derived.session)
	var next_root_mark: Dictionary = _first_receipt(derived.session)
	if not root_mark.ok or not repeated_mark.ok or not next_root_mark.ok:
		printerr("CR07 derived receipts missing: ", root_mark, " ", repeated_mark, " ", next_root_mark)
		quit(1)
		return
	if str(root_mark.receipt.damage) != "1e2" or not bool(repeated_mark.receipt.critical) or bool(repeated_mark.receipt.critical_bonus_applied) or absf(float(repeated_mark.receipt.damage) / (100.0 * float(derived.output.weapon.repeat_multiplier)) - 1.0) > 0.01:
		printerr("CR07 derived inherited branch: ", repeated_mark)
		quit(1)
		return
	if str(next_root_mark.receipt.damage) != str(second_mark.receipt.damage) or int(derived.session.battle._kernel.read_history().attacks) != 2:
		printerr("CR07 derived hit refreshed B1/B2 marks: ", next_root_mark, " expected=", second_mark)
		quit(1)
		return
	var slow_marked: Dictionary = _fixture(120828829812621612, 50, true, [], 1, ["B", "B", "B"], 0.0, false, 2.0)
	var slow_reference: Dictionary = _fixture(120828829812621612, 50, true, [], 1, [], 0.0, false, 2.0)
	if not slow_marked.ok or not slow_reference.ok:
		printerr("CR07 expiry fixture: ", slow_marked, " ", slow_reference)
		quit(1)
		return
	var slow_first: Dictionary = _first_receipt(slow_marked.session)
	var slow_second: Dictionary = _first_receipt(slow_marked.session)
	var baseline_first: Dictionary = _first_receipt(slow_reference.session)
	var baseline_second: Dictionary = _first_receipt(slow_reference.session)
	if not slow_first.ok or not slow_second.ok or not baseline_first.ok or not baseline_second.ok:
		printerr("CR07 expiry receipts missing")
		quit(1)
		return
	var expired_expected: float = float(baseline_second.receipt.damage) * 1.5
	if absf(float(slow_second.receipt.damage) / expired_expected - 1.0) > 0.01:
		printerr("CR07 expired B2 stack still affected next attack: ", slow_second, " expected~", expired_expected)
		quit(1)
		return
	print("CR07 first=", first_mark.receipt.damage, " second=", second_mark.receipt.damage)
	var drone_natural: Dictionary = _fixture(1014960426271799216, 1, false, [], 1, [], 0.2)
	if not drone_natural.ok or drone_natural.u1 < 0.25 or drone_natural.u1 >= 0.45 or not is_equal_approx(float(drone_natural.output.weapon.critical_rate), 0.25):
		printerr("CR06 non-B3 boundary fixture: ", drone_natural)
		quit(1)
		return
	var natural_hit: Dictionary = _first_receipt(drone_natural.session)
	if not natural_hit.ok or not bool(natural_hit.receipt.critical) or not bool(natural_hit.receipt.critical_bonus_applied) or str(natural_hit.receipt.damage) != "2.3e2":
		printerr("CR06 drone probability did not raise natural roll to 0.45: ", natural_hit)
		quit(1)
		return
	var drone_guaranteed: Dictionary = _fixture(1, 50, true, [], 1, [], 0.2)
	if not drone_guaranteed.ok or drone_guaranteed.u2 < 0.25 or drone_guaranteed.u2 >= 0.45:
		printerr("CR06 B3 boundary fixture: ", drone_guaranteed)
		quit(1)
		return
	var guaranteed_hit: Dictionary = _first_receipt(drone_guaranteed.session)
	if not guaranteed_hit.ok or not bool(guaranteed_hit.receipt.critical) or bool(guaranteed_hit.receipt.critical_bonus_applied) or str(guaranteed_hit.receipt.damage) != "1e2":
		printerr("CR06 drone probability polluted original-rate bonus roll: ", guaranteed_hit)
		quit(1)
		return
	print("CR06 natural u1=", drone_natural.u1, " B3 u2=", drone_guaranteed.u2)
	print("STAGE6_CRITICAL_ORACLE_OK CR01-CR07 CR09")
	quit()
