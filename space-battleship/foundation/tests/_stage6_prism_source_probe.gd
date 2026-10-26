extends "res://foundation/tests/_stage6_offensive_legends_probe.gd"

func _run() -> void:
	var fixture: Dictionary = _legend_fixture("prism_tower", "longLaser", {"maximum_multiplier_bonus": 1.3}, 7, "1e6", {"second_beam": true})
	var first: Dictionary = _advance_case(fixture, 500)
	if not first.ok:
		printerr(first)
		quit(1)
		return
	var session = fixture.session
	var contributions: Array = session.battle._equipped_drones.duplicate(true)
	var publish = func(wallet, kind): return session.publish_equipment_refit(wallet, kind, "", contributions, true, Callable(), {}, null, {}, false)
	var ready: Dictionary = session.equipment.equip_slot("weapon:0", "laser", session.equipment_inputs(), publish)
	var values: Dictionary = {}
	for key in ["weapon:0", "weapon:1"]:
		values[key] = session.battle._values.weapons[key].duplicate()
		values[key].base = "1e2"
	if ready.ok: ready = session.battle._kernel.set_player_values(values, {}, "growth", "")
	session.battle.finish_wave(false)
	session.battle.reset_for_sortie()
	session.battle.statistics()._totals.clear()
	if ready.ok: ready = session.battle.start_wave(fixture.setup)
	var second: Dictionary = _advance_case(fixture, 500)
	if not ready.ok or not second.ok:
		printerr(ready, second)
		quit(1)
		return
	var api = session.amount_api
	var plain: Dictionary = api.apply("from_decimal", ["4200"]).value
	var six_plain: Dictionary = api.apply("from_decimal", ["25200"]).value
	var lasers: Dictionary = api.apply("from_decimal", ["300"]).value
	if not first.totals.has("module:0") or not first.totals.has("module:1") or not second.totals.has("module:1") or not second.totals.has("module:0") or \
			int(api.apply("compare", [first.totals["module:1"].health, plain]).scalar) != 0 or \
			int(api.apply("compare", [first.totals["module:0"].health, six_plain]).scalar) <= 0 or \
			int(api.apply("compare", [second.totals["module:1"].health, six_plain]).scalar) <= 0 or \
			int(api.apply("compare", [second.totals["module:0"].health, lasers]).scalar) != 0:
		printerr("C11 unique prism source selection/replacement: ", first.totals, second.totals)
		quit(1)
		return
	print("STAGE6_PRISM_SOURCE_OK C11 slot0 wins competing beam births, slot1 remains ordinary4200, replacement/reset moves tower to slot1")
	quit()
