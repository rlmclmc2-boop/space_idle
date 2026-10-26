extends SceneTree
## C04/C14: a new hostile contact on the global recovery/debt boundary.
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
	session.battle._prepared_player.descriptor.memory_interval = 0.2
	ready = session.battle.commit_player("growth", false)
	if not ready.ok:
		printerr("C14 defence commit: ", ready)
		quit(1)
		return
	var player_weapon: Dictionary = session.battle._values.weapons["weapon:0"].duplicate()
	player_weapon.base = "0e0"
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
	wave.wave.enemies[0].hp = "1e6"
	wave.wave.enemies[0].max_hp = "1e6"
	var source: Dictionary = wave.wave.weapons[0]
	source.damage = "4e2"
	source.interval = 1000000.0
	source.remaining = 0.5
	var second: Dictionary = source.duplicate(true)
	second.damage = "5e0"
	second.remaining = 0.57
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
	for step in 10:
		session.battle.begin_frame()
		var advanced: Dictionary = session.battle.advance(0.01)
		if not advanced.ok:
			printerr("C14 debt advance: ", advanced)
			quit(1)
			return
		var view: Dictionary = session.battle._kernel.player_view()
		sampled.append([str(view.shield), str(view.armour)])
		for receipt in session.battle.consume_damage_receipts():
			if receipt.hostile: contacts.append([receipt.clock, receipt.damage])
	if initial_shield != "1e2" or not is_equal_approx(at_hit, 1.13) or \
			after_hit != "0e0" or armour_at_hit != "1e2" or contacts.size() != 1 or \
			not is_equal_approx(float(contacts[0][0]), 1.2) or str(contacts[0][1]) != "5e0":
		printerr("C04/C14 same-clock contact timing: ", at_hit, " ", contacts)
		quit(1)
		return
	for index in sampled.size():
		var expected: Array = ["0e0", "1e2"] if index < 6 else ["0e0", "9.5e1"]
		if sampled[index] != expected:
			printerr("C04/C14 recovery, debt and contact order at 1.20: ", sampled)
			quit(1)
			return
	print("STAGE6_SAME_CLOCK_DEBT_CONTACT_OK C04/C14; memory and debt at 1.20 precede exactly one 5-point hostile contact")
	quit()
