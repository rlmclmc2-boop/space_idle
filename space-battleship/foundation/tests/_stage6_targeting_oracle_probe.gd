extends SceneTree
## C07: real native four-missile salvo, target cycling, and exhausted targets.
const Session = preload("res://src/game_session.gd")

func _initialize() -> void:
	var loaded = GDExtensionManager.load_extension(OS.get_environment("SPACE_IDLE_NATIVE_EXTENSION"))
	if loaded != GDExtensionManager.LOAD_STATUS_OK and loaded != GDExtensionManager.LOAD_STATUS_ALREADY_LOADED:
		printerr("native extension unavailable")
		quit(1)
		return
	call_deferred("_run")

func _fixture(targets: int, hp: String, other_hp: String = "") -> Dictionary:
	var session = Session.new()
	var ready: Dictionary = session.initialize("res://generated/config.json", 17)
	if ready.ok: ready = session.campaign_system.accept_reforge(session.campaign_system.save_state(), 8)
	if not ready.ok: return ready
	session.equipment.refresh_availability(session.campaign_system.available, 8, false)
	ready = session.equipment.equip_slot("weapon:0", "missile", session.equipment_inputs(), session.publish_equipment_refit)
	if ready.ok: ready = session.campaign_system.start_sortie(1, session.equipment.clear_switch_locks)
	if not ready.ok: return ready
	var inputs: Dictionary = session.battle.wave_inputs()
	var setup: Dictionary = session.campaign_system.prepare_wave(session.equipment.enemy_override, inputs.geometry, inputs.motion)
	if not setup.ok: return setup
	var enemy: Dictionary = setup.wave.enemies[0]
	enemy.hp = hp
	enemy.max_hp = hp
	enemy.shield = "0e0"
	enemy.max_shield = "0e0"
	enemy.armourType = 0
	if targets == 2:
		var other: Dictionary = enemy.duplicate(true)
		other.uid = 2
		other.slot = 8
		other.x = 360.0
		if not other_hp.is_empty():
			other.hp = other_hp
			other.max_hp = other_hp
		setup.wave.enemies.append(other)
	setup.wave.weapons = []
	ready = session.battle.start_wave(setup)
	if not ready.ok: return ready
	return {"ok": true, "session": session}

func _receipts(session, count: int) -> Dictionary:
	var receipts: Array = []
	var drops: int = 0
	for step in 1500:
		session.battle.begin_frame()
		var result: Dictionary = session.battle.advance(0.01)
		if not result.ok: return result
		drops += result.drops.size()
		for receipt in session.battle.consume_damage_receipts():
			if not receipt.hostile: receipts.append(receipt)
		if receipts.size() >= count: break
	return {"ok": true, "receipts": receipts, "drops": drops}

func _run() -> void:
	for targets in [1, 2]:
		var fixture: Dictionary = _fixture(targets, "1e6")
		if not fixture.ok:
			printerr("C07 fixture: ", fixture)
			quit(1)
			return
		var result: Dictionary = _receipts(fixture.session, 4)
		if not result.ok or result.receipts.size() != 4:
			printerr("C07 missing salvo hits: ", result)
			quit(1)
			return
		var expected_x: Array = [286.0, 286.0, 286.0, 286.0] if targets == 1 else [286.0, 360.0, 286.0, 360.0]
		for index in 4:
			var receipt: Dictionary = result.receipts[index]
			if int(receipt.type) != 2 or str(receipt.damage) != "1.7e2" or not is_equal_approx(float(receipt.position.x), expected_x[index]):
				printerr("C07 salvo allocation ", targets, " ", index, " ", receipt)
				quit(1)
				return
		if int(fixture.session.battle._kernel.read_history().attacks) != 1:
			printerr("C07 multiple roots before first four impacts")
			quit(1)
			return
		print("C07 targets=", targets, " four impacts at ", expected_x)
	var orphan: Dictionary = _fixture(2, "1e0", "1e6")
	if not orphan.ok:
		printerr("C06 orphan fixture: ", orphan)
		quit(1)
		return
	var orphan_result: Dictionary = _receipts(orphan.session, 3)
	if not orphan_result.ok or orphan_result.receipts.size() != 3 or orphan_result.drops != 2 or not orphan.session.battle._kernel.enemy_views()[0].dead:
		printerr("C06 orphan impact/drop count: ", orphan_result)
		quit(1)
		return
	var orphan_x: Array = [286.0, 360.0, 360.0]
	for index in 3:
		if not is_equal_approx(float(orphan_result.receipts[index].position.x), orphan_x[index]):
			printerr("C06 dead-target missile retargeted: ", orphan_result)
			quit(1)
			return
	print("C06 target died mid-salvo; three impacts=", orphan_x, " drop entries=2")
	var dying: Dictionary = _fixture(1, "1e0")
	if not dying.ok:
		printerr("C07 empty fixture: ", dying)
		quit(1)
		return
	var death: Dictionary = _receipts(dying.session, 1)
	if not death.ok or death.receipts.size() != 1 or not dying.session.battle._kernel.enemy_views()[0].dead:
		printerr("C07 missing target death: ", death)
		quit(1)
		return
	var count_before: int = int(dying.session.battle._kernel.read_history().attacks)
	var empty_run: Dictionary = _receipts(dying.session, 1000)
	if not empty_run.ok or int(dying.session.battle._kernel.read_history().attacks) != count_before:
		printerr("C07 generated root without targets: ", empty_run)
		quit(1)
		return
	print("STAGE6_TARGETING_ORACLE_OK C07 one/two/no targets")
	quit()
