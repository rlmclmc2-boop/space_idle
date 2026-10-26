extends "res://foundation/tests/_stage6_adaptation_native_probe.gd"

func _run() -> void:
	var fixture: Dictionary = _defence_case(["", "", ""], false, "adaptation", 1, {},
		{"legend": "drone_master", "parameters": {"maximum_reduction": 0.5}, "quality": "white",
		"large_ship": true, "dummy_quality": "gold", "defence_type": 0})
	if not fixture.ok:
		printerr(fixture)
		quit(1)
		return
	for hit in fixture.hits:
		if absf(float(hit[1]) - 62.0) > 0.000001:
			printerr("C11 master should use highest gold quality: ", fixture.hits)
			quit(1)
			return
	var session = fixture.session
	var master: Dictionary = session.battle._equipped_drones[0].duplicate(true)
	var ready: Dictionary = session.set_equipped_drone_contributions([master])
	if ready.ok: ready = session.battle._kernel.set_player_values(fixture.weapon_values, {}, "growth", "", fixture.upgrades)
	if not ready.ok:
		printerr(ready)
		quit(1)
		return
	var count: int = 0
	for index in 150:
		session.battle.begin_frame()
		var advanced: Dictionary = session.battle.advance(0.01)
		if not advanced.ok:
			printerr(advanced)
			quit(1)
			return
		for hit in session.battle.consume_damage_receipts():
			if hit.hostile:
				count += 1
				if absf(float(hit.damage) - 73.0) > 0.000001:
					printerr("C11 master retained removed gold contribution: ", hit)
					quit(1)
					return
	if count != 3:
		printerr("C11 master source fixture contact count: ", count)
		quit(1)
		return
	print("STAGE6_MASTER_SOURCE_OK C11; white master uses gold companion ratio damage62, removing gold immediately changes three hits to73")
	quit()
