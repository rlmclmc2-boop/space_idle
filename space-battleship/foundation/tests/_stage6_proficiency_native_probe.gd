extends "res://foundation/tests/_stage6_critical_oracle_probe.gd"
## C09 native proficiency focus growth and attack interval.

func _case(choices: Array, armour_type: int = 0) -> Dictionary:
	var fixture: Dictionary = _fixture(37, 0, false, [], 1, [], 0.0, false, 1.0, armour_type)
	if not fixture.ok: return fixture
	var session = fixture.session
	var state: Dictionary = session.enhancement.save_state()
	state.level = 50
	state.weapon_order = ["proficiency", "repeat", "critical"]
	state.branches = {"proficiency": choices}
	var ready: Dictionary = session.enhancement.restore_state(state)
	if not ready.ok: return ready
	var output: Dictionary = session.enhancement.evaluate(0, func(_kind, _key): return true, 1)
	if not output.ok: return output
	var weapon: Dictionary = output.weapon.duplicate(true)
	weapon.critical_rate = 0.0
	weapon.repeat_probability = 0.0
	var globals: Dictionary = output.globals.duplicate(true)
	globals.counter_growth = 0.0
	var applied: Dictionary = {"globals": globals, "weapon": weapon, "defence": output.defence, "effects": output.effects}
	ready = session.battle._kernel.set_player_values({}, {}, "growth", "", applied)
	if not ready.ok: return ready
	var hits: Array = []
	for index in 1800:
		session.battle.begin_frame()
		var result: Dictionary = session.battle.advance(0.01)
		if not result.ok: return result
		for receipt in session.battle.consume_damage_receipts():
			if not receipt.hostile: hits.append(receipt)
		if hits.size() >= 8: break
	return {"ok": hits.size() >= 8, "hits": hits, "rules": session.enhancement._rules}

func _run() -> void:
	var plain: Dictionary = _case(["", "", ""])
	var focused: Dictionary = _case(["B", "", ""])
	var rapid: Dictionary = _case(["", "B", ""])
	var amplified: Dictionary = _case(["A", "A", "A"])
	var piercing: Dictionary = _case(["", "", "B"], 1)
	if not plain.ok or not focused.ok or not rapid.ok or not amplified.ok or not piercing.ok:
		printerr("C09 proficiency fixture: ", plain.ok, " ", focused.ok, " ", rapid.ok)
		quit(1)
		return
	var amplified_expected: float = 100.0 * (1.0 + 3.0 * float(amplified.rules.proficiency_a_damage_bonus))
	var piercing_expected: float = 100.0 * (1.0 - float(piercing.rules.proficiency_b3_resistance))
	if absf(float(amplified.hits[0].damage) - amplified_expected) > 1.0 or absf(float(piercing.hits[0].damage) - piercing_expected) > 1.0:
		printerr("C09 proficiency A/B3 values: ", amplified.hits[0], " ", piercing.hits[0], " expected=", amplified_expected, "/", piercing_expected)
		quit(1)
		return
	var first: float = float(focused.hits[0].clock)
	for hit in focused.hits:
		var ticks: int = int(floor((float(hit.clock) - first + 1e-8) / float(focused.rules.proficiency_b1_interval)))
		var expected: float = 100.0 * pow(1.0 + float(focused.rules.proficiency_b1_growth), ticks)
		if absf(float(hit.damage) - expected) > 1.0:
			printerr("C09 focus damage: ", hit, " expected=", expected, " first=", first, " interval=", focused.rules.proficiency_b1_interval, " all=", focused.hits)
			quit(1)
			return
	var plain_gap: float = float(plain.hits[2].clock) - float(plain.hits[1].clock)
	var rapid_gap: float = float(rapid.hits[2].clock) - float(rapid.hits[1].clock)
	if absf(rapid_gap / plain_gap - float(rapid.rules.proficiency_b2_interval_multiplier)) > 0.02:
		printerr("C09 rapid interval: ", plain_gap, " ", rapid_gap)
		quit(1)
		return
	print("STAGE6_PROFICIENCY_NATIVE_OK C09 A1/A2/A3, B1 eight focus hits, B2 interval and B3 resistance; gaps=", plain_gap, "/", rapid_gap)
	quit()
