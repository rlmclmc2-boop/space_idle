extends SceneTree

const Session = preload("res://src/game_session.gd")

func _initialize() -> void:
	var loaded = GDExtensionManager.load_extension(OS.get_environment("SPACE_IDLE_NATIVE_EXTENSION"))
	if loaded != GDExtensionManager.LOAD_STATUS_OK and loaded != GDExtensionManager.LOAD_STATUS_ALREADY_LOADED:
		printerr("native extension unavailable")
		quit(1)
		return
	call_deferred("_run")

func _fixture(seed: int, level: int, b3: bool) -> Dictionary:
	var session = Session.new()
	var ready: Dictionary = session.initialize("res://generated/config.json", seed)
	if ready.ok: ready = session.campaign_system.start_sortie(1, session.equipment.clear_switch_locks)
	if not ready.ok: return ready
	var state: Dictionary = session.enhancement.save_state()
	state.level = level
	state.weapon_order = ["critical", "proficiency", "repeat"]
	if b3: state.branches = {"critical": ["", "", "B"]}
	ready = session.enhancement.restore_state(state)
	if not ready.ok: return ready
	var output: Dictionary = session.enhancement.evaluate(0, func(_kind, _key): return true, 1)
	if not output.ok: return output
	var value: Dictionary = session.battle._values.weapons["weapon:0"].duplicate()
	value.base = "1e2"
	ready = session.battle._kernel.set_player_values({"weapon:0": value}, {}, "growth", "", output)
	if not ready.ok: return ready
	var inputs: Dictionary = session.battle.wave_inputs()
	var setup: Dictionary = session.campaign_system.prepare_wave(session.equipment.enemy_override, inputs.geometry, inputs.motion)
	if not setup.ok: return setup
	var enemy: Dictionary = setup.wave.enemies[0]
	enemy.shield = "0e0"
	enemy.max_shield = "0e0"
	enemy.hp = "1e4"
	enemy.max_hp = "1e4"
	enemy.armourType = 0
	setup.wave.weapons = []
	ready = session.battle.start_wave(setup)
	if not ready.ok: return ready
	var native_state: Dictionary = session.battle._kernel.persistent_state()
	var random := RandomNumberGenerator.new()
	random.state = int(native_state.rng_state)
	return {"ok": true, "session": session, "output": output,
		"u1": random.randf(), "u2": random.randf()}

func _first_receipt(session) -> Dictionary:
	for step in 500:
		session.battle.begin_frame()
		var result: Dictionary = session.battle.advance(0.01)
		if not result.ok: return result
		var receipts: Array = session.battle.consume_damage_receipts()
		if not receipts.is_empty(): return {"ok": true, "receipt": receipts[0]}
	return {"ok": false, "reason": "NoImpact"}

func _run() -> void:
	var cases: Array = [
		{"id": "CR01", "seed": 120828829812621612, "level": 0, "b3": false,
			"rate": 0.0, "multiplier": 2.0, "critical": false, "bonus": false, "damage": "1e2"},
		{"id": "CR02", "seed": 120828829812621612, "level": 1, "b3": false,
			"rate": 0.25, "multiplier": 2.3, "critical": true, "bonus": true, "damage": "2.3e2"},
		{"id": "CR03", "seed": 2478752393832935995, "level": 1, "b3": false,
			"rate": 0.25, "multiplier": 2.3, "critical": false, "bonus": false, "damage": "1e2"},
		{"id": "CR04", "seed": 1014960426271799216, "level": 50, "b3": true,
			"rate": 0.25, "multiplier": 17.0, "critical": true, "bonus": true, "damage": "1.7e3"},
		{"id": "CR05", "seed": 120828829812621612, "level": 50, "b3": true,
			"rate": 0.25, "multiplier": 17.0, "critical": true, "bonus": false, "damage": "1e2"},
	]
	for expected in cases:
		var fixture: Dictionary = _fixture(int(expected.seed), int(expected.level), bool(expected.b3))
		if not fixture.ok:
			printerr(expected.id, " fixture: ", fixture)
			quit(1)
			return
		var rate: float = float(fixture.output.weapon.critical_rate)
		var multiplier: float = float(fixture.output.weapon.critical_multiplier)
		if not is_equal_approx(rate, expected.rate) or not is_equal_approx(multiplier, expected.multiplier) or bool(fixture.output.effects.critical.b3) != expected.b3:
			printerr(expected.id, " enhancement values: ", fixture.output.weapon, " ", fixture.output.effects.critical)
			quit(1)
			return
		if bool(expected.b3):
			if bool(expected.bonus) != (float(fixture.u2) < rate):
				printerr(expected.id, " u2 boundary: ", fixture.u2)
				quit(1)
				return
		elif bool(expected.critical) != (float(fixture.u1) < rate):
			printerr(expected.id, " u1 boundary: ", fixture.u1)
			quit(1)
			return
		var first: Dictionary = _first_receipt(fixture.session)
		if not first.ok or bool(first.receipt.critical) != expected.critical or bool(first.receipt.critical_bonus_applied) != expected.bonus or str(first.receipt.damage) != expected.damage:
			printerr(expected.id, " native impact: ", first)
			quit(1)
			return
		print(expected.id, " seed=", expected.seed, " u1=", fixture.u1,
			" u2=", fixture.u2 if expected.b3 else "unused", " damage=", first.receipt.damage)
	print("STAGE6_CRITICAL_ORACLE_OK CR01-CR05")
	quit()
