extends "res://foundation/tests/_stage6_adaptation_native_probe.gd"
## Kill one source without clearing the encounter; its already-owned hit loses stacks.

func _run() -> void:
	var fixture: Dictionary = _defence_case(["B", "", ""], true)
	if not fixture.ok:
		printerr(fixture)
		quit(1)
		return
	var session = fixture.session
	var value: Dictionary = session.battle._values.weapons["weapon:0"].duplicate()
	value.base = "1e9"
	var ready: Dictionary = session.battle._kernel.set_player_values({"weapon:0": value}, {}, "growth", "")
	if not ready.ok:
		printerr(ready)
		quit(1)
		return
	var killed: bool = false
	var after: Array = []
	for index in 500:
		session.battle.begin_frame()
		var result: Dictionary = session.battle.advance(0.01)
		if not result.ok:
			printerr(result)
			quit(1)
			return
		var receipts: Array = session.battle.consume_damage_receipts()
		if not killed and session.battle._kernel.enemy_views()[0].dead:
			killed = true
			value.base = "0e0"
			ready = session.battle._kernel.set_player_values({"weapon:0": value}, {}, "growth", "")
			if not ready.ok or result.wave_cleared or session.battle._kernel.enemy_views()[1].dead:
				printerr("source death fixture cleared encounter: ", ready, result)
				quit(1)
				return
			continue
		if killed:
			for receipt in receipts:
				if receipt.hostile: after.append([receipt.clock, receipt.damage])
			if after.size() >= 3: break
	if not killed or after.size() != 3 or str(after[0][1]) != "5e1" or str(after[1][1]) != "2e1" or str(after[2][1]) != "2e1":
		printerr("C09 dead-source stacks: ", killed, " ", after)
		quit(1)
		return
	print("STAGE6_ADAPTATION_DEATH_OK C09; dead source orphan loses stacks (50), surviving source retains capped reduction (20/20)")
	quit()
