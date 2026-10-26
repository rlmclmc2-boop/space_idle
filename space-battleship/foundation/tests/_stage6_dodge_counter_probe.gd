extends "res://foundation/tests/_stage6_adaptation_native_probe.gd"

func _run() -> void:
	var fixture: Dictionary = _defence_case(["", "", ""], false, "adaptation", 1, {},
		{"before_advance": true, "legend": "dodge_counter", "parameters": {"maximum_dodge": 0.75, "counter_damage_bonus": 0.7}, "donor_damage": "1e2"})
	if not fixture.ok:
		printerr(fixture)
		quit(1)
		return
	var session = fixture.session
	var value: Dictionary = session.battle._values.weapons["weapon:0"].duplicate()
	value.base = "1e2"
	var ready: Dictionary = session.battle._kernel.set_player_values({"weapon:0": value}, {}, "growth", "", {"weapon": {"critical_rate": 1.0}})
	if not ready.ok:
		printerr(ready)
		quit(1)
		return
	var health: float = 10000.0
	var next_counter: float = 0.0
	var dodges: int = 0
	var cooldown_hits: int = 0
	var counters: int = 0
	for index in 1000:
		var clock: float = float(index + 1) * 0.01
		if index + 1 >= 116 and (index + 1 - 116) % 50 == 0:
			var oracle := RandomNumberGenerator.new()
			oracle.state = int(session.battle._kernel.persistent_state().rng_state)
			var rolled: bool = oracle.randf() < 0.75
			if rolled and clock >= next_counter - 1e-8:
				next_counter = clock + 2.0
				dodges += 1
			else:
				health -= 50.0
				if rolled: cooldown_hits += 1
		session.battle.begin_frame()
		var advanced: Dictionary = session.battle.advance(0.01)
		if not advanced.ok:
			printerr(advanced)
			quit(1)
			return
		for hit in session.battle.consume_damage_receipts():
			if not hit.hostile and absf(float(hit.damage) - 170.0) < 0.000001: counters += 1
		if absf(float(session.battle._kernel.player_view().armour) - health) > 0.001:
			printerr("C11 dodge fixed RNG/cooldown: ", clock, " expected=", health, " actual=", session.battle._kernel.player_view(), " next=", next_counter)
			quit(1)
			return
	if dodges < 2 or cooldown_hits == 0 or counters == 0 or int(session.battle._kernel.read_history().attacks) != 6:
		printerr("C10/C11 counter ownership not exercised: ", dodges, cooldown_hits, counters, session.battle._kernel.read_history())
		quit(1)
		return
	print("STAGE6_DODGE_COUNTER_OK C11 fixed-RNG dodge cap/cooldown; dodges=", dodges, " cooldown-successes still damaged=", cooldown_hits,
		" C10 170-point counters=", counters, " root history remains6")
	quit()
