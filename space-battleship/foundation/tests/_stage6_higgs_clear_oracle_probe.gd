extends SceneTree
## C12: the first Higgs target explodes the other frozen candidates.
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
	var ready: Dictionary = session.initialize("res://generated/config.json", 47)
	if ready.ok: ready = session.campaign_system.accept_reforge(session.campaign_system.save_state(), 8)
	if not ready.ok:
		printerr("C12 progress: ", ready)
		quit(1)
		return
	session.equipment.refresh_availability(session.campaign_system.available, 8, false)
	var motion: Dictionary = session.battle.wave_inputs().motion
	var donor: Dictionary = session.equipment.drone_weapon_source("cannon", 0, 0, session._research_factors, session._reactor_factors, motion)
	if not donor.ok:
		printerr("C12 donor: ", donor)
		quit(1)
		return
	ready = session.set_equipped_drone_contributions([{"id": "higgs-clear-probe", "generation": 1,
		"quality": "legendary", "weapon": donor.weapon, "legendary_effect": "higgs_cannon",
		"legendary_parameters": {"damage_bonus": 2.0, "area_bonus": 1.0}}])
	if ready.ok: ready = session.campaign_system.start_sortie(1, session.equipment.clear_switch_locks)
	if not ready.ok:
		printerr("C12 equip Higgs: ", ready)
		quit(1)
		return
	var player: Dictionary = session.battle._values.weapons["weapon:0"].duplicate()
	player.base = "0e0"
	ready = session.battle._kernel.set_player_values({"weapon:0": player}, {}, "growth", "")
	if not ready.ok:
		printerr("C12 zero player weapon: ", ready)
		quit(1)
		return
	var inputs: Dictionary = session.battle.wave_inputs()
	var setup: Dictionary = session.campaign_system.prepare_wave(session.equipment.enemy_override, inputs.geometry, inputs.motion)
	if not setup.ok:
		printerr("C12 wave: ", setup)
		quit(1)
		return
	var first: Dictionary = setup.wave.enemies[0]
	first.hp = "1e2"
	first.max_hp = "1e4"
	first.shield = "0e0"
	first.max_shield = "0e0"
	first.armourType = 0
	first.x = 286.0
	first.y = 300.0
	first.jewelExplosion = 1.0
	for entry in [{"uid": 2, "slot": 8, "y": 220.0}, {"uid": 3, "slot": 9, "y": 140.0}]:
		var other: Dictionary = first.duplicate(true)
		other.uid = entry.uid
		other.slot = entry.slot
		other.y = entry.y
		other.hp = "1e0"
		other.max_hp = "1e0"
		other.jewelExplosion = 0.0
		setup.wave.enemies.append(other)
	setup.wave.weapons = []
	setup.wave.final = true
	ready = session.battle.start_wave(setup)
	if not ready.ok:
		printerr("C12 native wave: ", ready)
		quit(1)
		return
	var damage: Array = []
	var impacts: Array = []
	var final_cleared: bool = false
	var drops: int = 0
	for step in 450:
		session.battle.begin_frame()
		var result: Dictionary = session.battle.advance(0.01)
		if not result.ok:
			printerr("C12 native step: ", result)
			quit(1)
			return
		for receipt in session.battle.consume_damage_receipts():
			if not receipt.hostile and int(receipt.type) == 2: damage.append(receipt)
		for event in result.events:
			if int(event.kind) == 1 and int(event.type) == 2 and not event.hostile: impacts.append(event)
		drops += result.drops.size()
		if result.final_cleared:
			final_cleared = true
			break
	if not final_cleared or damage.size() != 3 or impacts.size() != 1:
		printerr("C12 Higgs clear emitted another frozen-candidate impact: ", final_cleared, " ", damage, " ", impacts)
		quit(1)
		return
	for index in 3:
		if str(damage[index].damage) != (["9.8e1", "1e0", "1e0"][index]) or \
				not is_equal_approx(float(damage[index].clock), float(damage[0].clock)) or \
				not session.battle._kernel.enemy_views()[index].dead:
			printerr("C12 Higgs explosion/clear order: ", damage, " ", session.battle._kernel.enemy_views())
			quit(1)
			return
	session.battle.begin_frame()
	var tail: Dictionary = session.battle.advance(1.0)
	if not tail.ok or not session.battle.consume_damage_receipts().is_empty():
		printerr("C12 damage after final clear: ", tail)
		quit(1)
		return
	var drone_total: Dictionary = session.battle.statistics()._totals.get("drone:higgs-clear-probe", {})
	if drone_total.is_empty() or float(session.amount_api.apply("to_display", [drone_total.health]).text) != 100.0 or \
			drops < 3 or int(session.battle._kernel.read_history().attacks) != 3:
		printerr("C10/C12 source, drops or attack history: ", drops, " ", session.battle.statistics()._totals,
			" ", session.battle._kernel.read_history())
		quit(1)
		return
	print("STAGE6_HIGGS_CLEAR_ORACLE_OK C12; three deaths at ", damage[0].clock,
		" one Higgs impact, no post-clear damage; C10 drone source carries all 100 explosion damage")
	quit()
