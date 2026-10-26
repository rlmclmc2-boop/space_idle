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
	var ready: Dictionary = session.initialize("res://generated/config.json", 41)
	if ready.ok: ready = session.campaign_system.accept_reforge(session.campaign_system.save_state(), 8)
	if not ready.ok:
		printerr("C12 progress: ", ready)
		quit(1)
		return
	session.equipment.refresh_availability(session.campaign_system.available, 8, false)
	ready = session.equipment.equip_slot("weapon:0", "cannon", session.equipment_inputs(), session.publish_equipment_refit)
	if ready.ok: ready = session.campaign_system.start_sortie(1, session.equipment.clear_switch_locks)
	if not ready.ok:
		printerr("C12 cannon equip: ", ready)
		quit(1)
		return
	var value: Dictionary = session.battle._values.weapons["weapon:0"].duplicate()
	value.base = "1e2"
	ready = session.battle._kernel.set_player_values({"weapon:0": value}, {}, "growth", "")
	if not ready.ok:
		printerr("C12 cannon value: ", ready)
		quit(1)
		return
	var inputs: Dictionary = session.battle.wave_inputs()
	var setup: Dictionary = session.campaign_system.prepare_wave(session.equipment.enemy_override, inputs.geometry, inputs.motion)
	if not setup.ok:
		printerr("C12 wave: ", setup)
		quit(1)
		return
	var enemy: Dictionary = setup.wave.enemies[0]
	enemy.hp = "1e4"
	enemy.max_hp = "1e4"
	enemy.shield = "0e0"
	enemy.max_shield = "0e0"
	enemy.armourType = 0
	setup.wave.weapons = []
	ready = session.battle.start_wave(setup)
	if not ready.ok:
		printerr("C12 native wave: ", ready)
		quit(1)
		return
	var fired: bool = false
	for step in 500:
		session.battle.begin_frame()
		var result: Dictionary = session.battle.advance(0.01)
		if not result.ok:
			printerr("C12 native step: ", result)
			quit(1)
			return
		var hits: Array = session.battle.consume_damage_receipts()
		if int(session.battle._kernel.read_history().attacks) == 0:
			if not hits.is_empty() or str(session.battle._kernel.enemy_views()[0].hp) != "1e4":
				printerr("C12 damage before fire: ", hits)
				quit(1)
				return
			continue
		fired = true
		if hits.size() != 1 or str(hits[0].damage) != "1e2" or str(session.battle._kernel.enemy_views()[0].hp) != "9.9e3":
			printerr("C12 cannon did not hit at fire clock: ", hits, " ", session.battle._kernel.enemy_views())
			quit(1)
			return
		print("C12 ordinary cannon fired and hit at clock=", hits[0].clock, " damage=", hits[0].damage)
		break
	if not fired:
		printerr("C12 ordinary cannon never fired")
		quit(1)
		return
	var enemy_probe: Dictionary = _enemy_cannon()
	if not enemy_probe.ok:
		printerr("C12 enemy cannon: ", enemy_probe)
		quit(1)
		return
	var higgs_probe: Dictionary = _higgs_cannon()
	if not higgs_probe.ok:
		printerr("C12 Higgs cannon: ", higgs_probe)
		quit(1)
		return
	var chain_probe: Dictionary = _cannon_chain()
	if not chain_probe.ok:
		printerr("C12 cannon chain: ", chain_probe)
		quit(1)
		return
	print("STAGE6_CANNON_ORACLE_OK C12 ordinary/enemy/Higgs/chain cannon")
	quit()

func _enemy_cannon() -> Dictionary:
	var session = Session.new()
	var ready: Dictionary = session.initialize("res://generated/config.json", 43)
	if ready.ok: ready = session.campaign_system.start_sortie(1, session.equipment.clear_switch_locks)
	if not ready.ok: return ready
	var player_weapon: Dictionary = session.battle._values.weapons["weapon:0"].duplicate()
	player_weapon.base = "0e0"
	ready = session.battle._kernel.set_player_values({"weapon:0": player_weapon}, {}, "growth", "")
	if not ready.ok: return ready
	var inputs: Dictionary = session.battle.wave_inputs()
	var setup: Dictionary = session.campaign_system.prepare_wave(session.equipment.enemy_override, inputs.geometry, inputs.motion)
	if not setup.ok: return setup
	var source: Dictionary = setup.wave.weapons[0]
	source.kind = 1
	source.type = 2
	source.damage = "1e2"
	source.speed = 100.0
	source.interval = 1000000.0
	source.remaining = 0.5
	setup.wave.enemies[0].hp = "1e6"
	setup.wave.enemies[0].max_hp = "1e6"
	ready = session.battle.start_wave(setup)
	if not ready.ok: return ready
	var before: Dictionary = session.battle._kernel.player_view()
	var launched: bool = false
	for step in 1100:
		session.battle.begin_frame()
		var advanced: Dictionary = session.battle.advance(0.01)
		if not advanced.ok: return advanced
		var history: Dictionary = session.battle._kernel.read_history()
		var receipts: Array = session.battle.consume_damage_receipts()
		if int(history.incoming) > 0:
			launched = true
			if receipts.is_empty() and session.battle._kernel.player_view().armour != before.armour:
				return {"ok": false, "reason": "EnemyCannonPreContactDamage"}
		for receipt in receipts:
			if not receipt.hostile: continue
			if not launched or session.battle._kernel.player_view().armour == before.armour:
				return {"ok": false, "reason": "EnemyCannonContactMissing"}
			print("C12 enemy cannon fired before contact, hit at clock=", receipt.clock, " damage=", receipt.damage)
			return {"ok": true}
	return {"ok": false, "reason": "EnemyCannonNeverHit"}

func _higgs_cannon() -> Dictionary:
	var session = Session.new()
	var ready: Dictionary = session.initialize("res://generated/config.json", 47)
	if ready.ok: ready = session.campaign_system.accept_reforge(session.campaign_system.save_state(), 8)
	if not ready.ok: return ready
	session.equipment.refresh_availability(session.campaign_system.available, 8, false)
	var motion: Dictionary = session.battle.wave_inputs().motion
	var donor: Dictionary = session.equipment.drone_weapon_source("cannon", 0, 0, session._research_factors, session._reactor_factors, motion)
	if not donor.ok: return donor
	ready = session.set_equipped_drone_contributions([{"id": "higgs-probe", "generation": 1,
		"quality": "legendary", "weapon": donor.weapon, "legendary_effect": "higgs_cannon",
		"legendary_parameters": {"damage_bonus": 2.0, "area_bonus": 1.0}}])
	if ready.ok: ready = session.campaign_system.start_sortie(1, session.equipment.clear_switch_locks)
	if not ready.ok: return ready
	var player_weapon: Dictionary = session.battle._values.weapons["weapon:0"].duplicate()
	player_weapon.base = "0e0"
	ready = session.battle._kernel.set_player_values({"weapon:0": player_weapon}, {}, "growth", "")
	if not ready.ok: return ready
	var inputs: Dictionary = session.battle.wave_inputs()
	var setup: Dictionary = session.campaign_system.prepare_wave(session.equipment.enemy_override, inputs.geometry, inputs.motion)
	if not setup.ok: return setup
	var first: Dictionary = setup.wave.enemies[0]
	first.hp = "1e5"
	first.max_hp = "1e5"
	first.shield = "0e0"
	first.max_shield = "0e0"
	first.armourType = 0
	for entry in [{"uid": 2, "slot": 8, "x": 286.0, "y": 220.0}, {"uid": 3, "slot": 9, "x": 500.0, "y": 140.0}]:
		var other: Dictionary = first.duplicate(true)
		other.uid = entry.uid
		other.slot = entry.slot
		other.x = entry.x
		other.y = entry.y
		setup.wave.enemies.append(other)
	setup.wave.weapons = []
	ready = session.battle.start_wave(setup)
	if not ready.ok: return ready
	var impacts: Array = []
	for step in 450:
		session.battle.begin_frame()
		var advanced: Dictionary = session.battle.advance(0.01)
		if not advanced.ok: return advanced
		for receipt in session.battle.consume_damage_receipts():
			if not receipt.hostile and int(receipt.type) == 2: impacts.append(receipt)
		if not impacts.is_empty(): break
	if impacts.size() != 2 or str(impacts[0].damage) != "3.6e3" or str(impacts[1].damage) != "3.6e3" or not is_equal_approx(float(impacts[0].clock), float(impacts[1].clock)):
		return {"ok": false, "reason": "HiggsBandDamage", "impacts": impacts}
	var positions: Array = [float(impacts[0].position.y), float(impacts[1].position.y)]
	positions.sort()
	if positions != [140.0, 220.0] or str(session.battle._kernel.enemy_views()[2].hp) != "1e5":
		return {"ok": false, "reason": "HiggsOutOfBandHit", "impacts": impacts}
	print("C12 Higgs two in-band targets hit at clock=", impacts[0].clock, " out-of-band unchanged")
	return {"ok": true}

func _cannon_chain() -> Dictionary:
	var session = Session.new()
	var ready: Dictionary = session.initialize("res://generated/config.json", 53)
	if ready.ok: ready = session.campaign_system.accept_reforge(session.campaign_system.save_state(), 8)
	if not ready.ok: return ready
	session.equipment.refresh_availability(session.campaign_system.available, 8, false)
	ready = session.equipment.equip_slot("weapon:0", "cannon", session.equipment_inputs(), session.publish_equipment_refit)
	if ready.ok: ready = session.campaign_system.start_sortie(1, session.equipment.clear_switch_locks)
	if not ready.ok: return ready
	var state: Dictionary = session.enhancement.save_state()
	state.level = 50
	state.weapon_order = ["repeat", "proficiency", "critical"]
	state.branches = {"repeat": ["B", "", ""]}
	ready = session.enhancement.restore_state(state)
	if not ready.ok: return ready
	var output: Dictionary = session.enhancement.evaluate(0, func(_kind, _key): return true, 1)
	if not output.ok or int(output.weapon.chain_count) < 1: return {"ok": false, "reason": "ChainBranchInactive"}
	var value: Dictionary = session.battle._values.weapons["weapon:0"].duplicate()
	value.base = "1e2"
	ready = session.battle._kernel.set_player_values({"weapon:0": value}, {}, "growth", "", output)
	if not ready.ok: return ready
	var inputs: Dictionary = session.battle.wave_inputs()
	var setup: Dictionary = session.campaign_system.prepare_wave(session.equipment.enemy_override, inputs.geometry, inputs.motion)
	if not setup.ok: return setup
	var first: Dictionary = setup.wave.enemies[0]
	first.hp = "1e4"
	first.max_hp = "1e4"
	first.shield = "0e0"
	first.max_shield = "0e0"
	first.armourType = 0
	var other: Dictionary = first.duplicate(true)
	other.uid = 2
	other.slot = 8
	other.x = 360.0
	setup.wave.enemies.append(other)
	setup.wave.weapons = []
	ready = session.battle.start_wave(setup)
	if not ready.ok: return ready
	var primary: Dictionary = {}
	for step in 500:
		session.battle.begin_frame()
		var advanced: Dictionary = session.battle.advance(0.01)
		if not advanced.ok: return advanced
		var receipts: Array = session.battle.consume_damage_receipts()
		if int(session.battle._kernel.read_history().attacks) == 0: continue
		if receipts.size() != 1 or not is_equal_approx(float(receipts[0].position.x), 286.0) or str(session.battle._kernel.enemy_views()[1].hp) != "1e4":
			return {"ok": false, "reason": "ChainHitAtCannonLaunch", "receipts": receipts}
		primary = receipts[0]
		break
	if primary.is_empty(): return {"ok": false, "reason": "ChainRootMissing"}
	for step in 200:
		session.battle.begin_frame()
		var advanced: Dictionary = session.battle.advance(0.01)
		if not advanced.ok: return advanced
		for receipt in session.battle.consume_damage_receipts():
			if not receipt.hostile and is_equal_approx(float(receipt.position.x), 360.0):
				if float(receipt.clock) <= float(primary.clock) or str(session.battle._kernel.enemy_views()[1].hp) == "1e4":
					return {"ok": false, "reason": "ChainArrivalNotDelayed"}
				print("C12 cannon chain root clock=", primary.clock, " chain clock=", receipt.clock)
				return {"ok": true}
	return {"ok": false, "reason": "CannonChainNeverArrived"}
