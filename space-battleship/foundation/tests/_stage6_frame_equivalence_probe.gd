extends SceneTree
## Fixed native business steps with different presentation frame grouping.
const Session = preload("res://src/game_session.gd")

func _initialize() -> void:
	var loaded = GDExtensionManager.load_extension(OS.get_environment("SPACE_IDLE_NATIVE_EXTENSION"))
	if loaded != GDExtensionManager.LOAD_STATUS_OK and loaded != GDExtensionManager.LOAD_STATUS_ALREADY_LOADED:
		printerr("native extension unavailable")
		quit(1)
		return
	call_deferred("_run")

func _fixture() -> Dictionary:
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
	enemy.hp = "1e0"
	enemy.max_hp = "1e0"
	enemy.shield = "0e0"
	enemy.max_shield = "0e0"
	enemy.armourType = 0
	var second: Dictionary = enemy.duplicate(true)
	second.uid = 2
	second.slot = 8
	second.x = 360.0
	second.hp = "1e6"
	second.max_hp = "1e6"
	setup.wave.enemies.append(second)
	setup.wave.weapons = []
	ready = session.battle.start_wave(setup)
	if not ready.ok: return ready
	return {"ok": true, "session": session}

func _run_group(group: int) -> Dictionary:
	var fixture: Dictionary = _fixture()
	if not fixture.ok: return fixture
	var session = fixture.session
	var drops: Array = []
	var receipts: Array = []
	for step in 1000:
		if step % group == 0: session.battle.begin_frame()
		var result: Dictionary = session.battle.advance(0.01)
		if not result.ok: return result
		for drop in result.drops: drops.append(drop.duplicate(true))
		for receipt in session.battle.consume_damage_receipts():
			receipts.append({"clock": receipt.clock, "damage": receipt.damage,
				"x": receipt.position.x, "hostile": receipt.hostile})
	return {"ok": true, "history": session.battle._kernel.read_history(),
		"state": session.battle._kernel.persistent_state(),
		"enemies": session.battle._kernel.enemy_views(), "drops": drops, "receipts": receipts}

func _run() -> void:
	var single: Dictionary = _run_group(1)
	var grouped: Dictionary = _run_group(4)
	if not single.ok or not grouped.ok:
		printerr("frame fixture: ", single if not single.ok else grouped)
		quit(1)
		return
	for key in ["history", "state", "enemies", "drops", "receipts"]:
		if single[key] != grouped[key]:
			printerr("display-frame equivalence mismatch in ", key)
			quit(1)
			return
	if single.drops.is_empty() or single.receipts.size() < 3:
		printerr("frame fixture did not exercise death/drop and surviving-target impacts")
		quit(1)
		return
	print("STAGE6_FRAME_EQUIVALENCE_OK 1000 fixed 0.01s steps, 1/4-step draw grouping; drops=",
		single.drops.size(), " receipts=", single.receipts.size())
	quit()
