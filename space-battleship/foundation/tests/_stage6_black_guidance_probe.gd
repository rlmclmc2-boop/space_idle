extends "res://foundation/tests/_stage6_adaptation_native_probe.gd"

func _guidance(black: bool) -> Dictionary:
	var fixture: Dictionary = _defence_case(["", "", ""], false, "adaptation", 1, {},
		{"before_advance": true, "large_ship": true, "player_weapon": "missile", "donor_weapon": "missile",
		"legend": "precise_guidance", "parameters": {}, "black_overlap": black, "enemy_armour_type": 0})
	if not fixture.ok: return fixture
	var session = fixture.session
	var value: Dictionary = session.battle._values.weapons["weapon:0"].duplicate()
	value.base = "1e2"
	var ready: Dictionary = session.battle._kernel.set_player_values({"weapon:0": value}, {}, "growth", "")
	if not ready.ok: return ready
	var hits: Array = []
	for index in 2600:
		session.battle.begin_frame()
		var advanced: Dictionary = session.battle.advance(0.01)
		if not advanced.ok: return advanced
		for hit in session.battle.consume_damage_receipts():
			if not hit.hostile: hits.append(hit)
	return {"ok": true, "hits": hits}

func _run() -> void:
	var plain: Dictionary = _guidance(false)
	var black: Dictionary = _guidance(true)
	if not plain.ok or not black.ok:
		printerr(plain, black)
		quit(1)
		return
	var expected: Array = []
	var accumulated: float = 0.0
	var absorbed: int = 0
	for index in plain.hits.size():
		var hit: Dictionary = plain.hits[index]
		if float(hit.clock) >= 20.0 - 1e-8 and float(hit.clock) < 25.0 - 1e-8:
			@warning_ignore("integer_division")
			var batch: int = index / 4
			var raw: float = 100.0 * pow(1.5, batch)
			if absf(float(hit.damage) - ceilf(raw)) > 0.00001:
				printerr("C11 guidance baseline salvo factor: ", index, hit, raw)
				quit(1)
				return
			accumulated += raw
			absorbed += 1
		else: expected.append([hit.clock, hit.damage])
	var actual: Array = []
	var releases: Array = []
	for hit in black.hits:
		if int(hit.type) == 0 and is_equal_approx(float(hit.clock), 25.0): releases.append(hit)
		else: actual.append([hit.clock, hit.damage])
	if absorbed == 0 or releases.size() != 1 or absf(float(releases[0].damage) - ceilf(accumulated * 1.3)) > 0.00001 or actual != expected:
		printerr("C11 black/guidance absorption/cache/raw release: absorbed=", absorbed, " raw=", accumulated, " releases=", releases, " expected outside=", expected, " actual=", actual)
		quit(1)
		return
	print("STAGE6_BLACK_GUIDANCE_OK C11; absorbed guided contacts=", absorbed, " raw=", accumulated, " release=", releases[0].damage, " outside-window salvos exactly match guidance-only run")
	quit()
