extends SceneTree
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
	if ready.ok: ready = session.campaign_system.accept_reforge(session.campaign_system.save_state(), 8)
	if not ready.ok:
		printerr("C02 progression: ", ready)
		quit(1)
		return
	session.equipment.refresh_availability(session.campaign_system.available, 8, false)
	ready = session.equipment.equip_slot("defence:0", "shield", session.equipment_inputs(), session.publish_equipment_refit)
	if ready.ok: ready = session.campaign_system.start_sortie(1, session.equipment.clear_switch_locks)
	if not ready.ok:
		printerr("C02 shield fixture: ", ready)
		quit(1)
	_run_wave(session)

func _run_wave(session) -> void:
	var player_weapon: Dictionary = session.battle._values.weapons["weapon:0"].duplicate()
	player_weapon.base = "0e0"
	var ready: Dictionary = session.battle._kernel.set_player_values({"weapon:0": player_weapon}, {}, "growth", "")
	if not ready.ok:
		printerr("C02 zero attack: ", ready)
		quit(1)
		return
	var inputs: Dictionary = session.battle.wave_inputs()
	var setup: Dictionary = session.campaign_system.prepare_wave(session.equipment.enemy_override, inputs.geometry, inputs.motion)
	if not setup.ok:
		printerr("C02 wave: ", setup)
		quit(1)
		return
	setup.wave.enemies[0].hp = "1e6"
	setup.wave.enemies[0].max_hp = "1e6"
	var source: Dictionary = setup.wave.weapons[0]
	source.damage = "1e2"
	source.interval = 1000000.0
	source.remaining = 0.5
	ready = session.battle.start_wave(setup)
	if not ready.ok:
		printerr("C02 native start: ", ready)
		quit(1)
		return
	var hit_clock: float = -1.0
	var shield_after: String = ""
	for step in 500:
		session.battle.begin_frame()
		var advanced: Dictionary = session.battle.advance(0.01)
		if not advanced.ok:
			printerr("C02 native step: ", advanced)
			quit(1)
			return
		for receipt in session.battle.consume_damage_receipts():
			if receipt.hostile:
				hit_clock = float(receipt.clock)
				shield_after = str(session.battle._kernel.player_view().shield)
				break
		if hit_clock > 0: break
	if hit_clock < 0:
		printerr("C02 no hostile impact")
		quit(1)
		return
	session.battle.begin_frame()
	var before_due: Dictionary = session.battle.advance(1.99)
	var shield_before_due: String = str(session.battle._kernel.player_view().shield)
	session.battle.begin_frame()
	var after_due: Dictionary = session.battle.advance(0.02)
	var shield_after_due: String = str(session.battle._kernel.player_view().shield)
	if not before_due.ok or not after_due.ok or shield_after != "7e2" or shield_before_due != "7e2" or shield_after_due != "7.0225e2":
		printerr("C02 recovery crossed delay early or used wrong elapsed time: ", shield_after, ",", shield_before_due, ",", shield_after_due)
		quit(1)
		return
	var crossed: Dictionary = _multi_beam_ticks()
	if not crossed.ok:
		printerr("C02 multi-beam boundary: ", crossed)
		quit(1)
		return
	var layered: Dictionary = _two_shields()
	if not layered.ok:
		printerr("C03 layered shields: ", layered)
		quit(1)
		return
	var rounded: Dictionary = _two_shields(true)
	if not rounded.ok:
		printerr("C03 single layer rounding: ", rounded)
		quit(1)
		return
	print("STAGE6_SHIELD_TIMING_ORACLE_OK C02/C03; first hit=", hit_clock)
	quit()

func _multi_beam_ticks() -> Dictionary:
	var session = Session.new()
	var ready: Dictionary = session.initialize("res://generated/config.json", 71)
	if ready.ok: ready = session.campaign_system.accept_reforge(session.campaign_system.save_state(), 8)
	if not ready.ok: return ready
	session.equipment.refresh_availability(session.campaign_system.available, 8, false)
	ready = session.equipment.equip_slot("weapon:0", "longLaser", session.equipment_inputs(), session.publish_equipment_refit)
	if ready.ok: ready = session.campaign_system.start_sortie(1, session.equipment.clear_switch_locks)
	if not ready.ok: return ready
	var value: Dictionary = session.battle._values.weapons["weapon:0"].duplicate()
	value.base = "1e2"
	ready = session.battle._kernel.set_player_values({"weapon:0": value}, {}, "growth", "")
	if not ready.ok: return ready
	var inputs: Dictionary = session.battle.wave_inputs()
	var setup: Dictionary = session.campaign_system.prepare_wave(session.equipment.enemy_override, inputs.geometry, inputs.motion)
	if not setup.ok: return setup
	var enemy: Dictionary = setup.wave.enemies[0]
	enemy.hp = "1e6"
	enemy.max_hp = "1e6"
	enemy.shield = "3e1"
	enemy.max_shield = "3e1"
	enemy.shieldType = 1
	enemy.shieldRecovery = 0.0
	enemy.shieldDelay = 2.0
	enemy.armourType = 0
	setup.wave.weapons = []
	ready = session.battle.start_wave(setup)
	if not ready.ok: return ready
	session.battle.begin_frame()
	var advanced: Dictionary = session.battle.advance(1.6)
	if not advanced.ok: return advanced
	var receipts: Array = session.battle.consume_damage_receipts()
	if receipts.size() != 3: return {"ok": false, "reason": "BeamTickCount", "receipts": receipts}
	for index in 3:
		var due: float = 1.0 + 0.25 * index
		var expected: String = ["7e1", "1.25e2", "1.5e2"][index]
		if not is_equal_approx(float(receipts[index].clock), due) or str(receipts[index].damage) != expected:
			return {"ok": false, "reason": "BeamTickOrder", "receipts": receipts}
	var totals: Dictionary = session.battle.statistics()._totals.get("module:0", {})
	if totals.is_empty() or float(session.amount_api.apply("to_display", [totals.shield]).text) != 30.0 or float(session.amount_api.apply("to_display", [totals.health]).text) != 315.0 or str(session.battle._kernel.enemy_views()[0].hp) != "9.99685e5":
		return {"ok": false, "reason": "ShieldOrArmourOverdraw", "totals": totals}
	print("C02 1.6s frame settled three beam due times; shield=30 armour=315")
	return {"ok": true}

func _two_shields(fractional: bool = false) -> Dictionary:
	var session = Session.new()
	var ready: Dictionary = session.initialize("res://generated/config.json", 73)
	if ready.ok: ready = session.campaign_system.accept_reforge(session.campaign_system.save_state(), 51)
	if not ready.ok: return ready
	session.equipment.refresh_availability(session.campaign_system.available, 51, false)
	ready = session.campaign_system.change_ship("Heavy_Battleship", session.commit_ship_refit)
	if not ready.ok: return ready
	ready = session.equipment.equip_slot("defence:1", "shield", session.equipment_inputs(), session.publish_equipment_refit)
	if not ready.ok: return ready
	session.equipment.clear_switch_locks()
	ready = session.equipment.equip_slot("defence:2", "shield", session.equipment_inputs(), session.publish_equipment_refit)
	if not ready.ok: return ready
	ready = session.campaign_system.start_sortie(1, session.equipment.clear_switch_locks)
	if not ready.ok: return ready
	var setup: Dictionary = session._growth_setup()
	if not setup.ok: return setup
	for row in session.battle._prepared_player.descriptor.defences:
		if str(row.entry.id) == "defence:0":
			row.base = "1e2"
		elif str(row.entry.id) == "defence:1":
			row.base = "3e1"
			row.type = 2 if fractional else 1
			row.delay = 2.0
			row.rate = 1.0
		elif str(row.entry.id) == "defence:2":
			row.base = "3e1"
			row.type = 2
			row.delay = 3.0
			row.rate = 1.0
	ready = session.battle.commit_player("growth", false)
	if not ready.ok: return ready
	var before: Dictionary = session.battle._kernel.player_view()
	if str(before.shield) != "6e1" or str(before.armour) != "1e2": return {"ok": false, "reason": "LayerSetup", "player": before}
	var inputs: Dictionary = session.battle.wave_inputs()
	var wave: Dictionary = session.campaign_system.prepare_wave(session.equipment.enemy_override, inputs.geometry, inputs.motion)
	if not wave.ok: return wave
	wave.wave.enemies[0].hp = "1e6"
	wave.wave.enemies[0].max_hp = "1e6"
	var source: Dictionary = wave.wave.weapons[0]
	source.damage = "2.1e0" if fractional else "1.6e2"
	source.interval = 1000000.0
	source.remaining = 0.5
	ready = session.battle.start_wave(wave)
	if not ready.ok: return ready
	for step in 500:
		session.battle.begin_frame()
		var advanced: Dictionary = session.battle.advance(0.01)
		if not advanced.ok: return advanced
		for receipt in session.battle.consume_damage_receipts():
			if receipt.hostile:
				var player: Dictionary = session.battle._kernel.player_view()
				if fractional:
					if str(receipt.damage) != "3e0" or str(player.shield) != "5.7e1" or str(player.armour) != "1e2":
						return {"ok": false, "reason": "LayerRoundedPerModule", "receipt": receipt, "player": player}
					print("C03 raw 2.1 split across two shields rounds once to 3")
					return {"ok": true}
				if str(receipt.damage) != "1.3e2" or str(player.shield) != "0e0" or str(player.armour) != "3e1":
					return {"ok": false, "reason": "LayeredDamageDistribution", "receipt": receipt, "player": player}
				session.battle.begin_frame()
				var recovery: Dictionary = session.battle.advance(2.5)
				if not recovery.ok: return recovery
				var first_recovery: String = str(session.battle._kernel.player_view().shield)
				session.battle.begin_frame()
				recovery = session.battle.advance(1.0)
				if not recovery.ok: return recovery
				var second_recovery: String = str(session.battle._kernel.player_view().shield)
				if first_recovery != "1.5e1" or second_recovery != "4.5e1":
					return {"ok": false, "reason": "LayeredRecoveryOrder", "first": first_recovery, "second": second_recovery}
				print("C03 shields absorbed 30+30 then armour 70; recovery 15/45 at separate delays")
				return {"ok": true}
	return {"ok": false, "reason": "LayeredHitMissing"}
