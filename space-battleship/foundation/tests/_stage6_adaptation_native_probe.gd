extends "res://foundation/tests/_stage6_critical_oracle_probe.gd"
## C09 native adaptation capacity, per-source reduction, covers and resistance.

func _defence_case(choices: Array, second_source: bool = false, effect_name: String = "adaptation", other_type: int = 1, defence_overrides: Dictionary = {}, options: Dictionary = {}) -> Dictionary:
	var session = Session.new()
	var ready: Dictionary = session.initialize("res://generated/config.json", 139)
	if ready.ok and (options.get("shield", false) or options.get("large_ship", false)):
		ready = session.campaign_system.accept_reforge(session.campaign_system.save_state(), 21)
		if ready.ok:
			session.equipment.refresh_availability(session.campaign_system.available, 21, false)
			ready = session.campaign_system.change_ship("Cruiser", session.commit_ship_refit)
		if ready.ok and options.get("shield", false): ready = session.equipment.equip_slot("defence:1", "shield", session.equipment_inputs(), session.publish_equipment_refit)
	if ready.ok and options.has("player_weapon"):
		ready = session.equipment.equip_slot("weapon:0", options.player_weapon, session.equipment_inputs(), session.publish_equipment_refit)
	if ready.ok and options.has("legend"):
		var donor: Dictionary = session.equipment.drone_weapon_source(options.get("donor_weapon", "laser"), 0, 0, session._research_factors, session._reactor_factors, session.battle.wave_inputs().motion)
		if not donor.ok: return donor
		donor.weapon.interval = 1000000.0
		donor.weapon.remaining = 1000000.0
		donor.weapon.damage = options.get("donor_damage", "0e0")
		var legends: Array = [{"id": "defence-legend", "generation": 1,
			"quality": options.get("quality", "white"), "weapon": donor.weapon,
			"legendary_effect": options.legend, "legendary_parameters": options.parameters}]
		if options.get("black_overlap", false):
			legends.append({"id": "black-overlap", "generation": 1, "quality": "white", "weapon": donor.weapon,
				"legendary_effect": "black_hole", "legendary_parameters": {"damage_multiplier": 1.3}})
		if options.has("dummy_quality"):
			legends.append({"id": "quality-donor", "generation": 1, "quality": options.dummy_quality, "weapon": donor.weapon})
		ready = session.set_equipped_drone_contributions(legends)
	if ready.ok: ready = session.campaign_system.start_sortie(1, session.equipment.clear_switch_locks)
	if ready.ok: ready = session._growth_setup("", session.battle._equipped_drones, {}, null, {}, false)
	if not ready.ok: return ready
	for row in session.battle._prepared_player.descriptor.defences:
		row.base = "1e4"
		row.type = options.get("defence_type", 1)
	ready = session.battle.commit_player("refit", false)
	if not ready.ok: return ready
	var state: Dictionary = session.enhancement.save_state()
	state.level = 50
	state.defence_order = ["adaptation", "memory", "deferred"]
	state.branches = {effect_name: choices}
	ready = session.enhancement.restore_state(state)
	if not ready.ok: return ready
	var output: Dictionary = session.enhancement.evaluate(0, func(_kind, _key): return true, 1)
	var globals: Dictionary = output.globals.duplicate(true)
	globals.counter_growth = 0.0
	globals.defence_counter_growth = 0.0
	var defence: Dictionary = output.defence.duplicate(true)
	defence.memory_heal = 0.0
	defence.memory_cap = 0.0
	defence.deferred_fraction = 0.0
	if options.get("authored_memory", false):
		defence.memory_heal = output.defence.memory_heal
		defence.memory_cap = output.defence.memory_cap
	if options.get("authored_deferred", false): defence.deferred_fraction = output.defence.deferred_fraction
	defence.merge(defence_overrides, true)
	var weapon: Dictionary = session.battle._values.weapons["weapon:0"].duplicate()
	weapon.base = "0e0"
	ready = session.battle._kernel.set_player_values({"weapon:0": weapon}, {}, "growth", "", {"globals": globals, "defence": defence, "effects": output.effects})
	if not ready.ok: return ready
	session.battle.reset_for_sortie()
	var inputs: Dictionary = session.battle.wave_inputs()
	var setup: Dictionary = session.campaign_system.prepare_wave(session.equipment.enemy_override, inputs.geometry, inputs.motion)
	if not setup.ok: return setup
	setup.wave.enemies[0].hp = "1e6"
	setup.wave.enemies[0].max_hp = "1e6"
	if options.has("enemy_armour_type"): setup.wave.enemies[0].armourType = options.enemy_armour_type
	var source: Dictionary = setup.wave.weapons[0]
	source.damage = "1e2"
	source.interval = 0.5
	source.remaining = 0.5
	source.damage = options.get("damage", source.damage)
	source.interval = options.get("interval", source.interval)
	source.remaining = options.get("remaining", source.remaining)
	if second_source:
		var enemy: Dictionary = setup.wave.enemies[0].duplicate(true)
		enemy.uid = 2
		enemy.slot = 8
		setup.wave.enemies.append(enemy)
		var other: Dictionary = source.duplicate(true)
		other.source = 1
		other.remaining = 0.75
		other.type = other_type
		other.remaining = options.get("other_remaining", other.remaining)
		other.damage = options.get("other_damage", other.damage)
		setup.wave.weapons.append(other)
	ready = session.battle.start_wave(setup)
	if not ready.ok: return ready
	var initial: Dictionary = session.battle._kernel.player_view()
	if options.get("before_advance", false): return {"ok": true, "session": session, "initial": initial, "setup": setup}
	var hits: Array = []
	var samples: Dictionary = {}
	for step in 430:
		session.battle.begin_frame()
		var advanced: Dictionary = session.battle.advance(0.01)
		if not advanced.ok: return advanced
		for receipt in session.battle.consume_damage_receipts():
			if receipt.hostile: hits.append([receipt.clock, receipt.damage])
		if step in [219, 319, 419]: samples[step] = session.battle._kernel.player_view().armour
	return {"ok": true, "initial": initial, "hits": hits, "samples": samples, "session": session,
		"weapon_values": {"weapon:0": weapon}, "upgrades": {"globals": globals, "defence": defence, "effects": output.effects}}

func _run() -> void:
	var plain: Dictionary = _defence_case(["", "", ""])
	var capacity: Dictionary = _defence_case(["A", "A", "A"])
	var source: Dictionary = _defence_case(["B", "", ""])
	var cover: Dictionary = _defence_case(["", "B", ""])
	var resistance: Dictionary = _defence_case(["", "", "B"])
	var split: Dictionary = _defence_case(["B", "", ""], true)
	for result in [plain, capacity, source, cover, resistance, split]:
		if not result.ok:
			printerr("C09 adaptation fixture: ", result)
			quit(1)
			return
	if str(capacity.initial.max_armour) != "2.5e4" or str(capacity.initial.armour) != "2.5e4" or cover.samples != {219: "9.9e3", 319: "9.85e3", 419: "9.8e3"}:
		printerr("C09 adaptation capacity or cover birth/expiry: ", capacity.initial, " ", cover.samples)
		quit(1)
		return
	for index in 7:
		if str(plain.hits[index][1]) != "5e1" or str(resistance.hits[index][1]) != "2.5e1" or str(source.hits[index][1]) != ["5e1", "4e1", "3e1", "2e1", "2e1", "2e1", "2e1"][index]:
			printerr("C09 adaptation reduction: ", plain.hits, source.hits, resistance.hits)
			quit(1)
			return
	for index in 4:
		if str(split.hits[index][1]) != ["5e1", "5e1", "4e1", "4e1"][index]:
			printerr("C09 adaptation merged independent sources: ", split.hits)
			quit(1)
			return
	print("STAGE6_ADAPTATION_NATIVE_OK C09 A1/A2/A3 capacity, B1 independent-source capped stacks, B2 cover birth/expiry, B3 resistance")
	quit()
