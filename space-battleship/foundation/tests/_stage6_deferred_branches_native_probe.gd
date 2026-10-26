extends "res://foundation/tests/_stage6_adaptation_native_probe.gd"
## Independent 10-payment ledger plus fixed-RNG clearing and reduction oracle.

func _check(choices: Array, probability: float, b1: bool, b3: bool) -> Dictionary:
	var fixture: Dictionary = _defence_case(choices, false, "deferred", 1, {}, {"authored_deferred": true, "before_advance": true})
	if not fixture.ok: return fixture
	var session = fixture.session
	var health: float = 10000.0
	var until: float = 0.0
	var debts: Dictionary = {}
	var clears: int = 0
	var payments: int = 0
	var reduced: int = 0
	for index in 1000:
		var clock: float = float(index + 1) * 0.01
		if (index + 1) % 20 == 0:
			var tick: int = (index + 1) / 20
			var due: float = float(debts.get(tick, 0.0))
			debts.erase(tick)
			if due > 0.0:
				health -= due
				payments += 1
				var oracle := RandomNumberGenerator.new()
				oracle.state = int(session.battle._kernel.persistent_state().rng_state)
				if oracle.randf() < probability:
					debts.clear()
					clears += 1
					if b1: until = clock + 1.0
		session.battle.begin_frame()
		var advanced: Dictionary = session.battle.advance(0.01)
		if not advanced.ok: return advanced
		for receipt in session.battle.consume_damage_receipts():
			if not receipt.hostile: continue
			var net: float = 87.5 if b3 else 50.0
			if b1 and clock < until - 1e-8:
				net *= 0.8
				reduced += 1
			var immediate: float = net * 0.02
			if absf(float(receipt.damage) - immediate) > 0.00001:
				return {"ok": false, "reason": "DeferredBranchImmediate", "clock": clock, "receipt": receipt, "expected": immediate}
			health -= immediate
			var first: int = int(floor(clock / 0.2 + 1e-8)) + 1
			for tick in range(first, first + 10): debts[tick] = float(debts.get(tick, 0.0)) + net * 0.98 / 10.0
		if absf(float(session.battle._kernel.player_view().armour) - health) > 0.001:
			return {"ok": false, "reason": "DeferredBranchLedger", "clock": clock, "expected": health, "actual": session.battle._kernel.player_view()}
	if clears == 0 or payments == 0 or (b1 and reduced == 0): return {"ok": false, "reason": "DeferredBranchNotExercised"}
	return {"ok": true, "clears": clears, "payments": payments, "reduced": reduced}

func _run() -> void:
	for row in [{"choices": ["A", "A", "A"], "probability": 0.55, "b1": false, "b3": false},
		{"choices": ["B", "", ""], "probability": 0.25, "b1": true, "b3": false},
		{"choices": ["", "", "B"], "probability": 1.0, "b1": false, "b3": true}]:
		var result: Dictionary = _check(row.choices, row.probability, row.b1, row.b3)
		if not result.ok:
			printerr("C09 deferred branches: ", row, " ", result)
			quit(1)
			return
		print("C09 deferred ", row.choices, " ", result)
	print("STAGE6_DEFERRED_BRANCHES_NATIVE_OK C09 A1/A2/A3 probability, B1 clear-triggered reduction duration, B3 forced clearing and damage scaling")
	quit()
