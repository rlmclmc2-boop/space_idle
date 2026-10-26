extends "res://foundation/tests/_stage6_offensive_legends_probe.gd"

func _strange(proc: bool) -> Dictionary:
	var fixture: Dictionary = _legend_fixture("strange_matter", "cannon", {"damage_multiplier": 1.3}, 3)
	if not fixture.ok: return fixture
	var chosen: int = 0
	for seed_value in range(1, 10000):
		var oracle := RandomNumberGenerator.new()
		oracle.seed = seed_value
		var original: int = oracle.state
		for index in 3: oracle.randf()
		if (oracle.randf() < 0.4) == proc:
			chosen = original
			break
	var state: Dictionary = fixture.session.battle._kernel.persistent_state()
	state.rng_state = str(chosen)
	if chosen == 0 or not fixture.session.battle._kernel.restore_persistent_state(state): return {"ok": false, "reason": "StrangeSeed"}
	return _advance_case(fixture, 600)

func _run() -> void:
	var prism: Dictionary = _advance_case(_legend_fixture("prism_tower", "longLaser", {"maximum_multiplier_bonus": 1.3}, 7, "1e6",
		{"other_hp": "1e0", "guaranteed_drop": true}), 500)
	if not prism.ok or str(prism.enemies[6].hp) != "1e0":
		printerr("C11 prism dead-link neighbor limit")
		quit(1)
		return
	var sources: Array = []
	for drop in prism.drops:
		if not drop.has("source_uid"): continue
		if drop.source_uid in sources:
			printerr("C11 prism repeated dead link drop: ", prism.drops)
			quit(1)
			return
		sources.append(drop.source_uid)
	if sources.size() != 5:
		printerr("C11 prism guaranteed drops: ", sources)
		quit(1)
		return
	for proc in [false, true]:
		var strange: Dictionary = _strange(proc)
		if not strange.ok or strange.hits.size() != (4 if proc else 1) or int(strange.history.attacks) != 1:
			printerr("C11 strange nonkill40%: ", proc, strange)
			quit(1)
			return
		if proc:
			for index in range(1, 4):
				if str(strange.hits[index].damage) != "1.3e2" or not is_equal_approx(float(strange.hits[index].clock), 4.5):
					printerr("C11 strange nonkill packet timing: ", strange.hits)
					quit(1)
					return
	var fixture: Dictionary = _legend_fixture("wild_missile", "missile", {"damage_multiplier": 7.0}, 2)
	if not fixture.ok:
		printerr(fixture)
		quit(1)
		return
	var ready: Dictionary = fixture.session.battle._kernel.set_player_values({}, {}, "growth", "", {"weapon": {"repeat_probability": 1.0, "secondary_probability": 1.0}})
	var wild: Dictionary = _advance_case(fixture, 1150)
	var counts: Dictionary = {}
	if wild.ok:
		for hit in wild.hits:
			var amount: int = int(round(float(hit.damage)))
			counts[amount] = int(counts.get(amount, 0)) + 1
	if not ready.ok or not wild.ok or int(wild.history.attacks) != 4 or counts.get(700, 0) != 1 or counts.get(350, 0) != 2:
		printerr("C11 wild inherited repeat/secondary should be suppressed: ", ready, counts, wild.get("history"))
		quit(1)
		return
	print("STAGE6_LEGEND_EDGE_COMBINATIONS_OK C11 prism dead links produce five unique drops, strange40% both fixed-RNG outcomes, wild suppresses forced repeat/secondary")
	quit()
