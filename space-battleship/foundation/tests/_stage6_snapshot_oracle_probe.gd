extends SceneTree
## CR08 missile half: a live refit after launch must not reroll in-flight attacks.
const Session = preload("res://src/game_session.gd")

func _initialize() -> void:
	var loaded = GDExtensionManager.load_extension(OS.get_environment("SPACE_IDLE_NATIVE_EXTENSION"))
	if loaded != GDExtensionManager.LOAD_STATUS_OK and loaded != GDExtensionManager.LOAD_STATUS_ALREADY_LOADED:
		printerr("native extension unavailable")
		quit(1)
		return
	call_deferred("_run")

func _fixture(seed: int, laser_repeat: bool = false) -> Dictionary:
	var session = Session.new()
	var ready: Dictionary = session.initialize("res://generated/config.json", seed)
	if ready.ok: ready = session.campaign_system.accept_reforge(session.campaign_system.save_state(), 8)
	if not ready.ok: return ready
	session.equipment.refresh_availability(session.campaign_system.available, 8, false)
	if not laser_repeat:
		ready = session.equipment.equip_slot("weapon:0", "missile", session.equipment_inputs(), session.publish_equipment_refit)
	if ready.ok: ready = session.campaign_system.start_sortie(1, session.equipment.clear_switch_locks)
	if not ready.ok: return ready
	var state: Dictionary = session.enhancement.save_state()
	state.level = 50
	state.weapon_order = ["critical", "proficiency", "repeat"]
	state.branches = {"critical": ["", "", "B"]}
	ready = session.enhancement.restore_state(state)
	if not ready.ok: return ready
	var output: Dictionary = session.enhancement.evaluate(0, func(_kind, _key): return true, 1)
	if not output.ok: return output
	var value: Dictionary = session.battle._values.weapons["weapon:0"].duplicate()
	value.base = "1e2"
	var native_output: Dictionary = output
	if laser_repeat:
		var weapon_output: Dictionary = {}
		for key in output.weapon: weapon_output[key] = output.weapon[key]
		weapon_output.repeat_probability = 1.0
		native_output = {"globals": output.globals, "weapon": weapon_output,
			"defence": output.defence, "effects": output.effects}
	ready = session.battle._kernel.set_player_values({"weapon:0": value}, {}, "growth", "", native_output)
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
	setup.wave.weapons = []
	ready = session.battle.start_wave(setup)
	if not ready.ok: return ready
	var rng := RandomNumberGenerator.new()
	rng.state = int(session.battle._kernel.persistent_state().rng_state)
	return {"ok": true, "session": session, "u1": rng.randf(), "u2": rng.randf(),
		"repeat_multiplier": float(output.weapon.repeat_multiplier)}

func _install_drone_bonus(session) -> Dictionary:
	var motion: Dictionary = session.battle.wave_inputs().motion
	var donor: Dictionary = session.equipment.drone_weapon_source("laser", 0, 0, session._research_factors, session._reactor_factors, motion)
	if not donor.ok: return donor
	donor.weapon.interval = 1000000.0
	donor.weapon.remaining = 1000000.0
	return session.set_equipped_drone_contributions([{"id": "snapshot-probe", "generation": 1,
		"quality": "white", "weapon": donor.weapon, "critical_rate_bonus": 0.8}])

func _run() -> void:
	for sample in [{"name": "CR04", "seed": 1014960426271799216, "bonus": true, "damage": "1.7e3"},
		{"name": "CR05", "seed": 120828829812621612, "bonus": false, "damage": "1e2"}]:
		var fixture: Dictionary = _fixture(int(sample.seed))
		if not fixture.ok:
			printerr("CR08 fixture: ", fixture)
			quit(1)
			return
		var session = fixture.session
		var fired: bool = false
		for step in 300:
			session.battle.begin_frame()
			var result: Dictionary = session.battle.advance(0.01)
			if not result.ok:
				printerr("CR08 launch: ", result)
				quit(1)
				return
			if int(session.battle._kernel.read_history().attacks) > 0:
				if not session.battle.consume_damage_receipts().is_empty():
					printerr("CR08 contact preceded refit")
					quit(1)
					return
				fired = true
				break
		if not fired:
			printerr("CR08 root attack missing")
			quit(1)
			return
		var changed: Dictionary = _install_drone_bonus(session)
		if not changed.ok:
			printerr("CR08 in-flight refit: ", changed)
			quit(1)
			return
		var impacts: Array = []
		for step in 500:
			session.battle.begin_frame()
			var advanced: Dictionary = session.battle.advance(0.01)
			if not advanced.ok:
				printerr("CR08 advance: ", advanced)
				quit(1)
				return
			for receipt in session.battle.consume_damage_receipts():
				if not receipt.hostile: impacts.append(receipt)
			if impacts.size() >= 4: break
		if impacts.size() != 4:
			printerr("CR08 missile snapshot missing impacts: ", impacts)
			quit(1)
			return
		for impact in impacts:
			if not bool(impact.critical) or bool(impact.critical_bonus_applied) != bool(sample.bonus) or str(impact.damage) != sample.damage:
				printerr("CR08 missile snapshot rerolled: ", sample, " ", impacts)
				quit(1)
				return
		print("CR08 ", sample.name, " u1=", fixture.u1, " u2=", fixture.u2, " impacts=4 damage=", sample.damage)
	for sample in [{"name": "CR04", "seed": 1014960426271799216, "bonus": true, "damage": "1.7e3"},
		{"name": "CR05", "seed": 120828829812621612, "bonus": false, "damage": "1e2"}]:
		var fixture: Dictionary = _fixture(int(sample.seed), true)
		if not fixture.ok:
			printerr("CR08 repeat fixture: ", fixture)
			quit(1)
			return
		var session = fixture.session
		var fired: bool = false
		for step in 300:
			session.battle.begin_frame()
			var result: Dictionary = session.battle.advance(0.01)
			if not result.ok:
				printerr("CR08 repeat launch: ", result)
				quit(1)
				return
			if int(session.battle._kernel.read_history().attacks) > 0:
				if not session.battle.consume_damage_receipts().is_empty():
					printerr("CR08 repeat contact preceded refit")
					quit(1)
					return
				fired = true
				break
		if not fired:
			printerr("CR08 repeat root missing")
			quit(1)
			return
		var changed: Dictionary = _install_drone_bonus(session)
		if not changed.ok:
			printerr("CR08 repeat in-flight refit: ", changed)
			quit(1)
			return
		var impacts: Array = []
		for step in 250:
			session.battle.begin_frame()
			var advanced: Dictionary = session.battle.advance(0.01)
			if not advanced.ok:
				printerr("CR08 repeat advance: ", advanced)
				quit(1)
				return
			for receipt in session.battle.consume_damage_receipts():
				if not receipt.hostile: impacts.append(receipt)
			if impacts.size() >= 2: break
		if impacts.size() != 2 or int(session.battle._kernel.read_history().attacks) != 1:
			printerr("CR08 repeat count or root changed: ", impacts)
			quit(1)
			return
		for impact in impacts:
			if not bool(impact.critical) or bool(impact.critical_bonus_applied) != bool(sample.bonus):
				printerr("CR08 repeat flags changed: ", impacts)
				quit(1)
				return
		if str(impacts[0].damage) != sample.damage or absf(float(impacts[1].damage) / (float(impacts[0].damage) * fixture.repeat_multiplier) - 1.0) > 0.01:
			printerr("CR08 delayed repeat damage changed: ", impacts, " multiplier=", fixture.repeat_multiplier)
			quit(1)
			return
		print("CR08 delayed ", sample.name, " impacts=", impacts[0].damage, ",", impacts[1].damage)
	print("STAGE6_SNAPSHOT_ORACLE_OK CR08 missile and delayed repeat")
	quit()
