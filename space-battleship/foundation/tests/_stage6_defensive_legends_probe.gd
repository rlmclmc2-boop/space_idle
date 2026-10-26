extends "res://foundation/tests/_stage6_adaptation_native_probe.gd"

func _master(quality: String, expected: String) -> bool:
	var fixture: Dictionary = _defence_case(["", "", ""], false, "adaptation", 1, {},
		{"legend": "drone_master", "parameters": {"maximum_reduction": 0.5}, "quality": quality})
	if not fixture.ok: return false
	for hit in fixture.hits:
		if absf(float(hit[1]) - float(expected)) > 0.000001:
			printerr("C11 drone master quality ratio: ", quality, fixture.hits, " expected=", expected)
			return false
	return true

func _black() -> Dictionary:
	var fixture: Dictionary = _defence_case(["", "", ""], false, "adaptation", 1, {},
		{"before_advance": true, "legend": "black_hole", "parameters": {"damage_multiplier": 1.3}})
	if not fixture.ok: return fixture
	var session = fixture.session
	var value: Dictionary = session.battle._values.weapons["weapon:0"].duplicate()
	value.base = "1e2"
	var ready: Dictionary = session.battle._kernel.set_player_values({"weapon:0": value}, {}, "growth", "")
	if not ready.ok: return ready
	var release: Array = []
	var hostile: int = 0
	for index in 2600:
		session.battle.begin_frame()
		var advanced: Dictionary = session.battle.advance(0.01)
		if not advanced.ok: return advanced
		for hit in session.battle.consume_damage_receipts():
			if hit.hostile:
				hostile += 1
				if float(hit.clock) >= 20.0 - 1e-8 and float(hit.clock) < 25.0 - 1e-8: return {"ok": false, "reason": "BlackHoleIncomingNotAbsorbed", "hit": hit}
			else:
				if float(hit.clock) >= 20.0 - 1e-8 and float(hit.clock) < 25.0 - 1e-8: return {"ok": false, "reason": "BlackHoleOutgoingNotAbsorbed", "hit": hit}
				if is_equal_approx(float(hit.clock), 25.0): release.append(hit)
	return {"ok": true, "release": release, "hostile": hostile, "history": session.battle._kernel.read_history()}

func _run() -> void:
	if not _master("white", "3.7e1") or not _master("gold", "3.1e1"):
		printerr("C11 drone master fixture failed")
		quit(1)
		return
	var black: Dictionary = _black()
	if not black.ok or black.release.size() != 1 or str(black.release[0].damage) != "3.9e2" or black.hostile != 40 or int(black.history.incoming) != 50:
		printerr("C11 black hole 20-25s absorption/raw release/history: ", black)
		quit(1)
		return
	print("STAGE6_DEFENSIVE_LEGENDS_OK C11 master white/gold damage37/31; black hole absorbs ten incoming contacts, three 100-raw shots release390 at25, incoming history50")
	quit()
