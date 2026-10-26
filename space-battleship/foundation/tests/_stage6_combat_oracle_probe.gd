extends SceneTree

const Session = preload("res://src/game_session.gd")

func _initialize() -> void:
	var loaded = GDExtensionManager.load_extension(OS.get_environment("SPACE_IDLE_NATIVE_EXTENSION"))
	if loaded != GDExtensionManager.LOAD_STATUS_OK and loaded != GDExtensionManager.LOAD_STATUS_ALREADY_LOADED:
		printerr("native extension unavailable")
		quit(1)
		return
	call_deferred("_run")

func _fail(reason: String) -> void:
	printerr(reason)
	quit(1)

func _fixture(seed: int, hit_points: String, shield: String) -> Dictionary:
	var session = Session.new()
	var result: Dictionary = session.initialize("res://generated/config.json", seed)
	if result.ok: result = session.campaign_system.start_sortie(1, session.equipment.clear_switch_locks)
	if not result.ok: return result
	var value: Dictionary = session.battle._values.weapons["weapon:0"].duplicate()
	value.base = "1e2"
	result = session.battle._kernel.set_player_values({"weapon:0": value}, {}, "growth", "")
	if not result.ok: return result
	var inputs: Dictionary = session.battle.wave_inputs()
	var setup: Dictionary = session.campaign_system.prepare_wave(session.equipment.enemy_override, inputs.geometry, inputs.motion)
	if not setup.ok: return setup
	var enemy: Dictionary = setup.wave.enemies[0]
	enemy.shield = shield
	enemy.max_shield = shield
	enemy.shieldType = 1
	enemy.hp = hit_points
	enemy.max_hp = hit_points
	enemy.armourType = 0
	setup.wave.weapons = []
	result = session.battle.start_wave(setup)
	if not result.ok: return result
	session.campaign_system.accept_wave(setup)
	return {"ok": true, "session": session}

func _run() -> void:
	var fixture: Dictionary = _fixture(17, "1e3", "3e1")
	if not fixture.ok:
		_fail("C01 fixture: " + str(fixture))
		return
	var session = fixture.session
	var fired_before_contact: bool = false
	var first_receipt: Dictionary = {}
	for step in 500:
		session.battle.begin_frame()
		var result: Dictionary = session.battle.advance(0.01)
		if not result.ok:
			_fail("C01 native step: " + str(result))
			return
		var hp: float = float(session.battle._kernel.enemy_views()[0].hp)
		var attacks: int = int(session.battle._kernel.read_history().attacks)
		if attacks > 0 and hp == 1000.0 and session.battle.statistics()._totals.is_empty():
			fired_before_contact = true
		var receipts: Array = session.battle.consume_damage_receipts()
		if not receipts.is_empty():
			first_receipt = receipts[0]
			if hp != 960.0 or receipts.size() != 1:
				_fail("C01 first impact was not shield 30 plus armour 40: hp=" + str(hp) + " receipts=" + str(receipts))
				return
			break
	if not fired_before_contact or first_receipt.is_empty() or str(first_receipt.damage) != "7e1" or first_receipt.hostile:
		_fail("C01 launch/contact oracle: fired=" + str(fired_before_contact) + " receipt=" + str(first_receipt))
		return
	var totals: Dictionary = session.battle.statistics()._totals.get("module:0", {})
	if totals.is_empty() or float(session.amount_api.apply("to_display", [totals.shield]).text) != 30.0 or float(session.amount_api.apply("to_display", [totals.health]).text) != 40.0:
		_fail("C01 actual damage ledger: " + str(totals))
		return
	fixture = _fixture(19, "4e1", "0e0")
	if not fixture.ok:
		_fail("single death fixture: " + str(fixture))
		return
	session = fixture.session
	var drops: int = 0
	var death_receipts: int = 0
	for step in 500:
		session.battle.begin_frame()
		var result: Dictionary = session.battle.advance(0.01)
		if not result.ok:
			_fail("single death native step: " + str(result))
			return
		drops += result.drops.size()
		for receipt in session.battle.consume_damage_receipts():
			if not receipt.hostile: death_receipts += 1
		if session.battle._kernel.enemy_views()[0].dead: break
	if drops != 1 or death_receipts != 1:
		_fail("single death/drop oracle: drops=" + str(drops) + " receipts=" + str(death_receipts))
		return
	var attacks_after_death: int = int(session.battle._kernel.read_history().attacks)
	for step in 200:
		session.battle.begin_frame()
		var after: Dictionary = session.battle.advance(0.01)
		if not after.ok or not after.drops.is_empty():
			_fail("duplicate drop or stopped native after death: " + str(after))
			return
	if int(session.battle._kernel.read_history().attacks) != attacks_after_death:
		_fail("attacks continued without a target")
		return
	var shield_session = Session.new()
	var ready: Dictionary = shield_session.initialize("res://generated/config.json", 23)
	if ready.ok: ready = shield_session.campaign_system.accept_reforge(shield_session.campaign_system.save_state(), 8)
	if not ready.ok:
		_fail("C13/C15 shield fixture: " + str(ready))
		return
	shield_session.equipment.refresh_availability(shield_session.campaign_system.available, 8, false)
	var before_slots: Array = shield_session.equipment.save_state().slots.duplicate(true)
	var rejected: Dictionary = shield_session.equipment.equip_slot("defence:0", "", shield_session.equipment_inputs(), shield_session.publish_equipment_refit)
	if rejected.ok or rejected.reason != "FirstDefenceRequired" or shield_session.equipment.save_state().slots != before_slots:
		_fail("C15 first defence empty refit mutated slots: " + str(rejected))
		return
	ready = shield_session.equipment.equip_slot("defence:0", "shield", shield_session.equipment_inputs(), shield_session.publish_equipment_refit)
	if not ready.ok:
		_fail("C15 unlocked shield refit: " + str(ready))
		return
	ready = shield_session.campaign_system.start_sortie(8, shield_session.equipment.clear_switch_locks)
	if not ready.ok or not shield_session.battle.defence_capacity_available() or shield_session.battle.defence_depleted():
		_fail("C13 shield-only sortie rejected: " + str(ready))
		return
	var player: Dictionary = shield_session.battle._kernel.player_view()
	if str(player.max_armour) != "0e0" or str(player.armour) != "0e0" or float(player.shield) <= 0.0:
		_fail("C13 shield-only native defence: " + str(player))
		return
	var weapon: Dictionary = shield_session.battle._values.weapons["weapon:0"].duplicate()
	weapon.base = "0e0"
	ready = shield_session.battle._kernel.set_player_values({"weapon:0": weapon}, {}, "growth", "")
	if not ready.ok:
		_fail("C13 unarmed death fixture: " + str(ready))
		return
	shield_session._start_wave()
	var retreat_count: int = 0
	for step in 2400:
		if not shield_session._advance_kernel(0.05):
			_fail("C13 shield-only combat stopped: " + str(shield_session.run_state.reason()))
			return
		if shield_session.campaign_system.restore_checkpoint() == "retreat":
			retreat_count += 1
			break
	if retreat_count != 1 or shield_session.battle._kernel.player_view().shield != "0e0":
		_fail("C13 shield depletion did not begin one retreat: " + str(shield_session.campaign_system.restore_checkpoint()) + " " + str(shield_session.battle._kernel.player_view()))
		return
	print("STAGE6_COMBAT_ORACLE_OK C01 shield=30 armour=40 precontact=0; single death/drop=1; C13 shield-only sortie/depletion; C15 first-slot refit")
	quit()
