extends SceneTree
const Session = preload("res://src/game_session.gd")

func _initialize() -> void:
	var loaded = GDExtensionManager.load_extension(OS.get_environment("SPACE_IDLE_NATIVE_EXTENSION"))
	if loaded != GDExtensionManager.LOAD_STATUS_OK and loaded != GDExtensionManager.LOAD_STATUS_ALREADY_LOADED:
		printerr("native extension unavailable")
		quit(1)
		return
	call_deferred("_run")

func _fixture(interval: float, count: int) -> Dictionary:
	var session = Session.new()
	var ready: Dictionary = session.initialize("res://generated/config.json", 79)
	if ready.ok: ready = session.campaign_system.start_sortie(1, session.equipment.clear_switch_locks)
	if not ready.ok: return ready
	var value: Dictionary = session.battle._values.weapons["weapon:0"].duplicate()
	value.base = "1e2"
	ready = session.battle._kernel.set_player_values({"weapon:0": value}, {}, "growth", "",
		{"weapon": {"interval_multiplier": interval / 1.5}})
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
	enemy.reactiveReduction = 1
	setup.wave.weapons = []
	ready = session.battle.start_wave(setup)
	if not ready.ok: return ready
	var hits: Array = []
	for step in 2500:
		session.battle.begin_frame()
		var advanced: Dictionary = session.battle.advance(0.01)
		if not advanced.ok: return advanced
		for receipt in session.battle.consume_damage_receipts():
			if not receipt.hostile: hits.append({"clock": receipt.clock, "damage": receipt.damage})
		if hits.size() >= count: break
	return {"ok": true, "hits": hits}

func _run() -> void:
	for sample in [{"interval": 0.15, "values": ["1e2", "1e2", "8e1", "8e1"]},
		{"interval": 0.17, "values": ["1e2", "8e1", "6e1", "4e1", "4e1"]},
		{"interval": 2.2, "values": ["1e2", "8e1"]},
		{"interval": 2.21, "values": ["1e2", "1e2"]}]:
		var result: Dictionary = _fixture(float(sample.interval), sample.values.size())
		if not result.ok or result.hits.size() != sample.values.size():
			printerr("C05 fixture: ", result)
			quit(1)
			return
		for index in sample.values.size():
			if str(result.hits[index].damage) != sample.values[index]:
				printerr("C05 reactive layer interval=", sample.interval, " hits=", result.hits)
				quit(1)
				return
		print("C05 interval=", sample.interval, " hits=", result.hits)
	print("STAGE6_REACTIVE_ORACLE_OK C05")
	quit()
