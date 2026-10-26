extends SceneTree
## C14: debt, recovery, cannon death explosion and final clear at one clock.
const Session = preload("res://src/game_session.gd")

func _initialize() -> void:
	var loaded = GDExtensionManager.load_extension(OS.get_environment("SPACE_IDLE_NATIVE_EXTENSION"))
	if loaded != GDExtensionManager.LOAD_STATUS_OK and loaded != GDExtensionManager.LOAD_STATUS_ALREADY_LOADED:
		printerr("native extension unavailable")
		quit(1)
		return
	call_deferred("_run")

func _run() -> void:
	var session = Session.new()
	var ready: Dictionary = session.initialize("res://generated/config.json", 67)
	if ready.ok: ready = session.campaign_system.accept_reforge(session.campaign_system.save_state(), 21)
	if not ready.ok:
		printerr("C14 progress: ", ready)
		quit(1)
		return
	session.equipment.refresh_availability(session.campaign_system.available, 21, false)
	ready = session.campaign_system.change_ship("Cruiser", session.commit_ship_refit)
	if ready.ok: ready = session.equipment.equip_slot("defence:0", "shield", session.equipment_inputs(), session.publish_equipment_refit)
	if ready.ok: ready = session.equipment.equip_slot("defence:1", "armour", session.equipment_inputs(), session.publish_equipment_refit)
	if ready.ok: ready = session.equipment.equip_slot("weapon:0", "cannon", session.equipment_inputs(), session.publish_equipment_refit)
	if ready.ok: ready = session.campaign_system.start_sortie(1, session.equipment.clear_switch_locks)
	if not ready.ok:
		printerr("C14 shield fixture: ", ready)
		quit(1)
		return
	var setup: Dictionary = session._growth_setup()
	if not setup.ok:
		printerr("C14 growth setup: ", setup)
		quit(1)
		return
	for row in session.battle._prepared_player.descriptor.defences:
		if str(row.entry.id) == "defence:0":
			row.base = "1e2"
			row.deferred_fraction = 0.5
			row.memory_heal = 0.1
			row.memory_cap = 0.0
			row.delay = 100.0
		elif str(row.entry.id) == "defence:1":
			row.base = "1e2"
	session.battle._prepared_player.descriptor.memory_interval = 0.1
	session.battle._prepared_player.descriptor.deferred_interval = 0.1
	session.battle._prepared_player.descriptor.deferred_duration = 1.0
	ready = session.battle.commit_player("growth", false)
	if not ready.ok:
		printerr("C14 defence commit: ", ready)
		quit(1)
		return
	var player_weapon: Dictionary = session.battle._values.weapons["weapon:0"].duplicate()
	player_weapon.base = "1e2"
	ready = session.battle._kernel.set_player_values({"weapon:0": player_weapon}, {}, "growth", "")
	if not ready.ok:
		printerr("C14 zero attack: ", ready)
		quit(1)
		return
	var inputs: Dictionary = session.battle.wave_inputs()
	var wave: Dictionary = session.campaign_system.prepare_wave(session.equipment.enemy_override, inputs.geometry, inputs.motion)
	if not wave.ok:
		printerr("C14 wave: ", wave)
		quit(1)
		return
	var enemy: Dictionary = wave.wave.enemies[0]
	enemy.hp = "1e2"
	enemy.max_hp = "1e4"
	enemy.shield = "0e0"
	enemy.max_shield = "0e0"
	enemy.armourType = 0
	enemy.jewelExplosion = 1.0
	var adjacent: Dictionary = enemy.duplicate(true)
	adjacent.uid = 2
	adjacent.slot = 8
	adjacent.hp = "1e0"
	adjacent.max_hp = "1e0"
	adjacent.jewelExplosion = 0.0
	wave.wave.enemies.append(adjacent)
	wave.wave.final = true
	var source: Dictionary = wave.wave.weapons[0]
	source.damage = "4e2"
	source.interval = 1000000.0
	source.remaining = 2.8
	var second: Dictionary = source.duplicate(true)
	second.damage = "5e0"
	second.remaining = 2.87
	wave.wave.weapons.append(second)
	ready = session.battle.start_wave(wave)
	if not ready.ok:
		printerr("C14 native wave: ", ready)
		quit(1)
		return
	var initial_shield: String = str(session.battle._kernel.player_view().shield)
	var at_hit: float = -1.0
	var after_hit: String = ""
	var armour_at_hit: String = ""
	for step in 500:
		session.battle.begin_frame()
		var advanced: Dictionary = session.battle.advance(0.01)
		if not advanced.ok:
			printerr("C14 advance: ", advanced)
			quit(1)
			return
		for receipt in session.battle.consume_damage_receipts():
			if receipt.hostile:
				at_hit = float(receipt.clock)
				after_hit = str(session.battle._kernel.player_view().shield)
				armour_at_hit = str(session.battle._kernel.player_view().armour)
				break
		if at_hit > 0: break
	if at_hit < 0:
		printerr("C14 no hostile impact")
		quit(1)
		return
	var sampled: Array = []
	var contacts: Array = []
	var outgoing: Array = []
	var cleared: bool = false
	for step in 10:
		session.battle.begin_frame()
		var advanced: Dictionary = session.battle.advance(0.01)
		if not advanced.ok:
			printerr("C14 debt advance: ", advanced)
			quit(1)
			return
		var view: Dictionary = session.battle._kernel.player_view()
		cleared = cleared or bool(advanced.final_cleared)
		sampled.append([str(view.shield), str(view.armour)])
		for receipt in session.battle.consume_damage_receipts():
			if receipt.hostile: contacts.append([receipt.clock, receipt.damage])
			else: outgoing.append([receipt.clock, receipt.damage])
	if initial_shield != "1e2" or not is_equal_approx(at_hit, 3.43) or \
			after_hit != "0e0" or armour_at_hit != "1e2" or not contacts.is_empty():
		printerr("C04/C14 same-clock contact timing: ", at_hit, " ", contacts)
		quit(1)
		return
	for index in sampled.size():
		var expected: Array = ["0e0", "1e2"]
		if sampled[index] != expected:
			printerr("C04/C14 recovery, debt and contact order at 1.20: ", sampled)
			quit(1)
			return
	var enemies: Array = session.battle._kernel.enemy_views()
	if not cleared or enemies.size() != 2 or not enemies[0].dead or not enemies[1].dead or outgoing.size() != 2:
		printerr("C14 explosion clear failed: ", enemies)
		quit(1)
		return
	if str(outgoing[0][1]) != "1e2" or str(outgoing[1][1]) != "1e0" or not is_equal_approx(float(outgoing[0][0]), 3.5) or not is_equal_approx(float(outgoing[1][0]), 3.5):
		printerr("C14 cannon/explosion amounts or clock: ", outgoing)
		quit(1)
		return
	print("STAGE6_DEBT_EXPLOSION_CLEAR_OK C14; debt/recovery then cannon/explosion clear at 3.50 cancels hostile contact")
	quit()
