extends "res://foundation/tests/_stage6_adaptation_native_probe.gd"
## Independently project positive recovery RNG rolls and the shared one-second buff.

func _run() -> void:
	var fixture: Dictionary = _defence_case(["B", "", ""], false, "memory", 1,
		{"memory_heal": 0.001, "memory_cap": 0.0}, {"before_advance": true})
	if not fixture.ok:
		printerr(fixture)
		quit(1)
		return
	var session = fixture.session
	var health: float = 10000.0
	var until: float = 0.0
	var proc_count: int = 0
	var reduced: int = 0
	var normal: int = 0
	for index in 1000:
		var clock: float = float(index + 1) * 0.01
		if (index + 1) % 20 == 0:
			var recovery: float = minf(10000.0 - health, 10.0)
			health += recovery
			if recovery > 0.0:
				var oracle := RandomNumberGenerator.new()
				oracle.state = int(session.battle._kernel.persistent_state().rng_state)
				if oracle.randf() < 0.1:
					until = clock + 1.0
					proc_count += 1
		session.battle.begin_frame()
		var advanced: Dictionary = session.battle.advance(0.01)
		if not advanced.ok:
			printerr(advanced)
			quit(1)
			return
		for receipt in session.battle.consume_damage_receipts():
			if not receipt.hostile: continue
			var expected: float = 25.0 if clock < until - 1e-8 else 50.0
			if float(receipt.damage) != expected:
				printerr("C09 memory B1 roll/duration: ", receipt, " oracle until=", until, " expected=", expected)
				quit(1)
				return
			health -= expected
			if expected == 25.0: reduced += 1
			else: normal += 1
		if absf(float(session.battle._kernel.player_view().armour) - health) > 0.01:
			printerr("C09 memory B1 recovery double-count: ", clock, " ", health, " ", session.battle._kernel.player_view())
			quit(1)
			return
	if proc_count == 0 or reduced == 0 or normal == 0:
		printerr("C09 memory B1 fixture did not exercise both states: ", proc_count, reduced, normal)
		quit(1)
		return
	print("STAGE6_MEMORY_BUFF_NATIVE_OK C09 B1 fixed RNG/shared recovery/one-second duration; procs=", proc_count, " reduced=", reduced, " normal=", normal)
	quit()
