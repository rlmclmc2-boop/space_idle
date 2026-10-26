extends "res://foundation/tests/_stage6_offensive_legends_probe.gd"

func _case(choices: Array, secondary_roll: bool, repeat_low: float, repeat_high: float, first_hp: String = "1e6", options: Dictionary = {}, weapon_name: String = "laser", steps: int = 260) -> Dictionary:
	var fixture: Dictionary = _legend_fixture("", weapon_name, {}, 3, first_hp, options)
	if not fixture.ok: return fixture
	var session = fixture.session
	var state: Dictionary = session.enhancement.save_state()
	state.level = 50
	state.weapon_order = ["repeat", "proficiency", "critical"]
	state.branches = {"repeat": choices}
	var ready: Dictionary = session.enhancement.restore_state(state)
	if not ready.ok: return ready
	var output: Dictionary = session.enhancement.evaluate(0, func(_kind, _key): return true, 1)
	var weapon: Dictionary = output.weapon.duplicate(true)
	weapon.critical_rate = 0.0
	var globals: Dictionary = output.globals.duplicate(true)
	globals.counter_growth = 0.0
	ready = session.battle._kernel.set_player_values({}, {}, "growth", "", {"globals": globals, "weapon": weapon, "effects": output.effects})
	if not ready.ok: return ready
	var chosen: int = 0
	for seed_value in range(1, 10000):
		var oracle := RandomNumberGenerator.new()
		oracle.seed = seed_value
		var original: int = oracle.state
		oracle.randf()
		var secondary: float = oracle.randf()
		var repeated: float = oracle.randf()
		if (not secondary_roll or secondary < 0.2) and repeated >= repeat_low and repeated < repeat_high:
			chosen = original
			break
	if chosen == 0: return {"ok": false, "reason": "NoRepeatSeed"}
	var native_state: Dictionary = session.battle._kernel.persistent_state()
	native_state.rng_state = str(chosen)
	if not session.battle._kernel.restore_persistent_state(native_state): return {"ok": false, "reason": "RepeatSeedRejected"}
	return _advance_case(fixture, steps)

func _run() -> void:
	var plain: Dictionary = _case(["", "", ""], false, 0.5, 0.8)
	var amplified: Dictionary = _case(["A", "A", "A"], false, 0.5, 0.8)
	var combined: Dictionary = _case(["B", "", "B"], true, 0.0, 0.5)
	var clear: Dictionary = _case(["B", "", "B"], true, 0.0, 0.5, "1e0", {"explosion": 1.0, "other_hp": "1e0", "adjacent": true, "guaranteed_drop": true})
	var derived_death: Dictionary = _case(["B", "", "B"], true, 0.0, 0.5, "1.5e2", {"explosion": 1.0, "adjacent": true, "guaranteed_drop": true})
	for result in [plain, amplified, combined, clear, derived_death]:
		if not result.ok:
			printerr(result)
			quit(1)
			return
	var trace: Array = []
	for hit in combined.hits: trace.append([hit.clock, hit.position.y, hit.damage])
	if plain.hits.size() != 1 or amplified.hits.size() != 2 or str(amplified.hits[1].damage) != "1.1e3" or combined.hits.size() != 5:
		printerr("C09 repeat A/B1/B3 counts: ", plain.hits, amplified.hits, trace)
		quit(1)
		return
	for index in 5:
		if str(combined.hits[index].damage) != ["1e2", "1e2", "1e2", "1.1e3", "1.1e3"][index]:
			printerr("C10 chain/secondary/repeat damage: ", trace)
			quit(1)
			return
	if clear.hits.size() != 3 or clear.drops.size() != 3 or derived_death.drops.size() != 1 or derived_death.hits.size() != 5 or str(derived_death.enemies[2].hp) != "1e6":
		printerr("C10 derived passive recursion or duplicate death/drop: ", clear, derived_death)
		quit(1)
		return
	var ids: Array = []
	var sources: Array = []
	for drop in clear.drops:
		if drop.uid in ids or drop.source_uid in sources:
			printerr("C10 duplicate drop/source identity: ", clear.drops)
			quit(1)
			return
		ids.append(drop.uid)
		sources.append(drop.source_uid)
	var api = ClassDB.instantiate("FoundationAmount")
	for row in [[combined, "2500"], [clear, "3"], [derived_death, "1450"]]:
		if int(row[0].history.attacks) != 1 or row[0].totals.size() != 1 or not row[0].totals.has("module:0") or int(api.apply("compare", [row[0].totals["module:0"].health, api.apply("from_decimal", [row[1]]).value]).scalar) != 0:
			printerr("C10 root count/source attribution mismatch: ", row)
			quit(1)
			return
	print("STAGE6_REPEAT_IDENTITY_OK C09 A probability/B1 chain/B3 secondary; C10 combined root1 total2500, root explosion3 unique drops, repeat kill one drop/no death-passive recursion total1450")
	quit()
