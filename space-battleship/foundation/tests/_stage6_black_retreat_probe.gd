extends "res://foundation/tests/_stage6_adaptation_native_probe.gd"

func _run() -> void:
	var fixture: Dictionary = _defence_case(["", "", ""], false, "adaptation", 1, {},
		{"before_advance": true, "legend": "black_hole", "parameters": {"damage_multiplier": 1.3}, "enemy_armour_type": 0})
	if not fixture.ok:
		printerr(fixture)
		quit(1)
		return
	var session = fixture.session
	var value: Dictionary = session.battle._values.weapons["weapon:0"].duplicate()
	value.base = "1e2"
	var ready: Dictionary = session.battle._kernel.set_player_values({"weapon:0": value}, {}, "growth", "")
	if not ready.ok:
		printerr(ready)
		quit(1)
		return
	for index in 2200:
		session.battle.begin_frame()
		var advanced: Dictionary = session.battle.advance(0.01)
		if not advanced.ok:
			printerr(advanced)
			quit(1)
			return
		for hit in session.battle.consume_damage_receipts():
			if float(hit.clock) >= 20.0 - 1e-8:
				printerr("C11 black hole did not absorb before retreat: ", hit)
				quit(1)
				return
	# At22 the first guided-free 100-raw player shot has been accumulated.
	# Retreat must discard it, leave the old25 release empty and restart at42.
	session.battle._kernel.begin_retreat()
	session.battle._kernel.finish_retreat()
	ready = session.battle.start_wave(fixture.setup)
	if not ready.ok:
		printerr(ready)
		quit(1)
		return
	var player: int = 0
	var hostile: int = 0
	for index in 400:
		session.battle.begin_frame()
		var advanced: Dictionary = session.battle.advance(0.01)
		if not advanced.ok:
			printerr(advanced)
			quit(1)
			return
		for hit in session.battle.consume_damage_receipts():
			var expected: float = 50.0 if hit.hostile else 100.0
			var resumed_drone: bool = not hit.hostile and absf(float(hit.damage) - 1.0) < 0.000001
			if (absf(float(hit.damage) - expected) > 0.000001 and not resumed_drone) or int(hit.type) == 0:
				printerr("C11 stale black-hole release/window after retreat: ", hit)
				quit(1)
				return
			if hit.hostile: hostile += 1
			elif not resumed_drone: player += 1
	if hostile < 3 or player < 2:
		printerr("C11 retreat continuation lacked contacts: ", hostile, player)
		quit(1)
		return
	print("STAGE6_BLACK_RETREAT_OK C11; active window/cached raw discarded at22, normal contacts resume, old25 release canceled")
	quit()
