extends "res://foundation/tests/_stage6_critical_oracle_probe.gd"

func _legend_fixture(effect: String, weapon_name: String, parameters: Dictionary, targets: int, first_hp: String = "1e6") -> Dictionary:
	var session = Session.new()
	var ready: Dictionary = session.initialize("res://generated/config.json", 149)
	if ready.ok: ready = session.campaign_system.accept_reforge(session.campaign_system.save_state(), 8)
	if not ready.ok: return ready
	session.equipment.refresh_availability(session.campaign_system.available, 8, false)
	ready = session.equipment.equip_slot("weapon:0", weapon_name, session.equipment_inputs(), session.publish_equipment_refit)
	if not ready.ok: return ready
	var donor: Dictionary = session.equipment.drone_weapon_source(weapon_name, 0, 0, session._research_factors, session._reactor_factors, session.battle.wave_inputs().motion)
	if not donor.ok: return donor
	donor.weapon.interval = 1000000.0
	donor.weapon.remaining = 1000000.0
	ready = session.set_equipped_drone_contributions([{"id": "offensive-legend", "generation": 1, "quality": "white", "weapon": donor.weapon,
		"legendary_effect": effect, "legendary_parameters": parameters}])
	if ready.ok: ready = session.campaign_system.start_sortie(1, session.equipment.clear_switch_locks)
	var value: Dictionary = session.battle._values.weapons["weapon:0"].duplicate()
	value.base = "1e2"
	if ready.ok: ready = session.battle._kernel.set_player_values({"weapon:0": value}, {}, "growth", "")
	if not ready.ok: return ready
	var inputs: Dictionary = session.battle.wave_inputs()
	var setup: Dictionary = session.campaign_system.prepare_wave(session.equipment.enemy_override, inputs.geometry, inputs.motion)
	if not setup.ok: return setup
	var enemy: Dictionary = setup.wave.enemies[0]
	enemy.hp = first_hp
	enemy.max_hp = first_hp
	enemy.shield = "0e0"
	enemy.max_shield = "0e0"
	enemy.armourType = 0
	enemy.y = 350.0
	for index in range(1, targets):
		var other: Dictionary = enemy.duplicate(true)
		other.uid = index + 1
		other.slot = index
		other.y = 350.0 - index * 35.0
		other.hp = "1e6"
		other.max_hp = "1e6"
		setup.wave.enemies.append(other)
	setup.wave.weapons = []
	ready = session.battle.start_wave(setup)
	return {"ok": ready.ok, "session": session}

func _advance_case(fixture: Dictionary, steps: int) -> Dictionary:
	if not fixture.ok: return fixture
	var hits: Array = []
	for index in steps:
		fixture.session.battle.begin_frame()
		var result: Dictionary = fixture.session.battle.advance(0.01)
		if not result.ok: return result
		for hit in fixture.session.battle.consume_damage_receipts():
			if not hit.hostile: hits.append(hit)
	return {"ok": true, "hits": hits, "history": fixture.session.battle._kernel.read_history(), "enemies": fixture.session.battle._kernel.enemy_views(), "totals": fixture.session.battle.statistics()._totals}

func _run() -> void:
	var prism: Dictionary = _advance_case(_legend_fixture("prism_tower", "longLaser", {"maximum_multiplier_bonus": 1.3}, 7), 500)
	var strange: Dictionary = _advance_case(_legend_fixture("strange_matter", "cannon", {"damage_multiplier": 1.3}, 3, "1e0"), 600)
	var wild: Dictionary = _advance_case(_legend_fixture("wild_missile", "missile", {"damage_multiplier": 7.0}, 2), 1150)
	for fixture in [prism, strange, wild]:
		if not fixture.ok:
			printerr("C11 offensive fixture: ", fixture)
			quit(1)
			return
	var prism_peak: float = 0.0
	for hit in prism.hits: prism_peak = maxf(prism_peak, float(hit.damage))
	var strange_amounts: Array = []
	for hit in strange.hits: strange_amounts.append([hit.clock, hit.damage])
	var wild_counts: Dictionary = {}
	for hit in wild.hits:
		var key: int = int(round(float(hit.damage)))
		wild_counts[key] = int(wild_counts.get(key, 0)) + 1
	if prism_peak != 430.0 or str(prism.enemies[-1].hp) != "1e6":
		printerr("C11 prism cap or five-neighbor limit: ", prism)
		quit(1)
		return
	for index in 6:
		if str(prism.enemies[index].hp) == "1e6":
			printerr("C11 prism missed selected neighbor: ", index)
			quit(1)
			return
	if strange.hits.size() != 5 or str(strange.hits[0].damage) != "1e0" or int(strange.history.attacks) != 1:
		printerr("C10/C11 strange kill-spawn root ownership: ", strange_amounts, strange.history)
		quit(1)
		return
	for index in range(1, 5):
		if str(strange.hits[index].damage) != "1.3e2" or not is_equal_approx(float(strange.hits[index].clock), 4.5):
			printerr("C11 strange delay/raw damage: ", strange_amounts)
			quit(1)
			return
	if wild_counts != {100: 12, 700: 1, 350: 2} or int(wild.history.attacks) != 4:
		printerr("C10/C11 wild three ordinary then special/broadcast: ", wild_counts, wild.history)
		quit(1)
		return
	var api = ClassDB.instantiate("FoundationAmount")
	for row in [[strange, "521"], [wild, "2600"]]:
		var total: Dictionary = row[0].totals.get("module:0", {})
		if total.is_empty() or int(api.apply("compare", [total.health, api.apply("from_decimal", [row[1]]).value]).scalar) != 0 or row[0].totals.size() != 1:
			printerr("C10 derived damage source attribution: ", row[0].totals, " expected=", row[1])
			quit(1)
			return
	print("STAGE6_OFFENSIVE_LEGENDS_OK C11 prism 5-neighbor/430 cap, strange two delayed packets without recursion, wild fourth-salvo 700+350+350; C10 roots/source totals521/2600")
	quit()
