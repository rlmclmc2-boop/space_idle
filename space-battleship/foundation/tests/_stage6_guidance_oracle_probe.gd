extends SceneTree
## C05: a missile salvo caches its first factor separately for each target.
const Session = preload("res://src/game_session.gd")

func _initialize() -> void:
	var loaded = GDExtensionManager.load_extension(OS.get_environment("SPACE_IDLE_NATIVE_EXTENSION"))
	if loaded != GDExtensionManager.LOAD_STATUS_OK and loaded != GDExtensionManager.LOAD_STATUS_ALREADY_LOADED:
		printerr("native extension unavailable")
		quit(1)
		return
	call_deferred("_run")

func _fixture(target_count: int) -> Dictionary:
	var session = Session.new()
	var ready: Dictionary = session.initialize("res://generated/config.json", 79)
	if ready.ok: ready = session.campaign_system.accept_reforge(session.campaign_system.save_state(), 8)
	if not ready.ok: return ready
	session.equipment.refresh_availability(session.campaign_system.available, 8, false)
	ready = session.equipment.equip_slot("weapon:0", "missile", session.equipment_inputs(), session.publish_equipment_refit)
	if not ready.ok: return ready
	var motion: Dictionary = session.battle.wave_inputs().motion
	var donor: Dictionary = session.equipment.drone_weapon_source("missile", 0, 0, session._research_factors, session._reactor_factors, motion)
	if not donor.ok: return donor
	donor.weapon.interval = 1000000.0
	donor.weapon.remaining = 1000000.0
	ready = session.set_equipped_drone_contributions([{"id": "guidance-probe", "generation": 1,
		"quality": "legendary", "weapon": donor.weapon, "legendary_effect": "precise_guidance"}])
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
	enemy.shield = "0e0"
	enemy.max_shield = "0e0"
	enemy.armourType = 0
	if target_count == 2:
		enemy.guidance_layers = 2
		var second: Dictionary = enemy.duplicate(true)
		second.uid = 2
		second.slot = 8
		second.x = 360.0
		second.guidance_layers = 0
		setup.wave.enemies.append(second)
	setup.wave.weapons = []
	ready = session.battle.start_wave(setup)
	if not ready.ok: return ready
	return {"ok": true, "session": session}

func _run() -> void:
	for target_count in [1, 2]:
		var fixture: Dictionary = _fixture(target_count)
		if not fixture.ok:
			printerr("C05 guidance fixture: ", fixture)
			quit(1)
			return
		var session = fixture.session
		var hits: Array = []
		for step in 3000:
			session.battle.begin_frame()
			var advanced: Dictionary = session.battle.advance(0.01)
			if not advanced.ok:
				printerr("C05 guidance advance: ", advanced)
				quit(1)
				return
			for receipt in session.battle.consume_damage_receipts():
				if not receipt.hostile: hits.append(receipt)
			if hits.size() >= 12: break
		if hits.size() != 12:
			printerr("C05 guidance missing impacts: ", hits)
			quit(1)
			return
		var expected_damage: Array = ["1e2", "1e2", "1e2", "1e2", "1.5e2", "1.5e2", "1.5e2", "1.5e2",
			"2.25e2", "2.25e2", "2.25e2", "2.25e2"] if target_count == 1 else [
			"2.25e2", "1e2", "2.25e2", "1e2", "3.38e2", "1.5e2", "3.38e2", "1.5e2",
			"5.07e2", "2.25e2", "5.07e2", "2.25e2"]
		for index in 12:
			var x: float = 286.0 if target_count == 1 or index % 2 == 0 else 360.0
			if str(hits[index].damage) != expected_damage[index] or not is_equal_approx(float(hits[index].position.x), x):
				printerr("C05 guidance cache or per-target factor at ", index, ": ", hits[index])
				quit(1)
				return
		if int(session.battle._kernel.read_history().attacks) != 3:
			printerr("C05 guidance created unexpected root attacks")
			quit(1)
			return
		print("C05 guidance targets=", target_count, " damages=", hits.map(func(hit): return hit.damage),
			" positions=", hits.map(func(hit): return hit.position.x))
	print("STAGE6_GUIDANCE_ORACLE_OK C05")
	quit()
