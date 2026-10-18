extends SceneTree
# Focused encounter observations; full state at each point, no save access.
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func one(label: String, stage: int, point: int, weapon: String, weapon_level: int, defence: String, defence_level: int, reactor_level: int, use_native := false, prebattle_iron := -1.0) -> void:
	var db := ShipDatabase.new()
	var g = preload("res://scripts/presented_battle_game.gd").new(db, false)
	g.native_execution_auto = use_native
	g.rng.seed = 1729
	g.profile.cleared = range(1, stage)
	g.rebuild_unlocks()
	var iron_budget:float=prebattle_iron if prebattle_iron>=0 else 10000.0
	g.profile.resources["1"] = iron_budget
	g.profile.resources["2"] = 10000.0
	if not g.equip_slot("weapons", 0, weapon) or not g.equip_slot("defence", 0, defence):
		printerr("INVALID_EQUIP ", label); failures += 1; return
	if weapon_level > 1 and not g.upgrade_slot("weapons", 0, weapon_level - 1):
		printerr("INVALID_WEAPON_UPGRADE ", label); failures += 1; return
	if defence_level > 1 and not g.upgrade_slot("defence", 0, defence_level - 1):
		printerr("INVALID_DEFENCE_UPGRADE ", label); failures += 1; return
	if reactor_level > 1 and not g.upgrade_reactor(reactor_level - 1):
		printerr("INVALID_REACTOR_UPGRADE ", label); failures += 1; return
	var spent := iron_budget - float(g.profile.resources["1"])
	g.profile.resources["1"] = 0.0
	g.profile.resources["2"] = 0.0
	if g.reactor_unlocked():
		if not g.set_reactor_allocation("weapons", float(g.reactor_capacity() / 2)):
			printerr("INVALID_ALLOCATION ", label); failures += 1; return
		if not g.set_reactor_allocation("defence", float(g.reactor_capacity() / 2)):
			printerr("INVALID_ALLOCATION ", label); failures += 1; return
	if not g.start(stage, false):
		printerr("INVALID_START ", label); failures += 1; return
	var level: Dictionary = db.levels[stage - 1]
	g.group_index = point - 1
	g.distance = 0.0 if point == 1 else float(level.groups[point - 2].position) * float(level.length)
	var elapsed := 0.0
	var entered := -1.0
	var cleared := -1.0
	var armour_in := 0.0
	var shield_in := 0.0
	var armour_out := 0.0
	var shield_out := 0.0
	var previous_state: int = g.state
	var exit_state := -1
	var last_shield := 0.0
	var hit_times: Array = []
	var recovery_frames := 0
	var native_seen := false
	for step in 18000:
		g.tick(1.0 / 60.0)
		elapsed += 1.0 / 60.0
		if previous_state != BattleGame.State.COMBAT and g.state == BattleGame.State.COMBAT:
			entered = elapsed
			armour_in = float(g.player.armour)
			shield_in = float(g.player.shield)
			last_shield = shield_in
			if use_native and g.native_execution == null:
				printerr("NATIVE_ADMISSION_FAILED ", label); failures += 1; return
		if g.state == BattleGame.State.COMBAT and entered >= 0:
			native_seen = native_seen or g.native_execution != null
			var shield_now := float(g.player.shield)
			if shield_now < last_shield - 0.01: hit_times.append(snapped(elapsed - entered, 0.01))
			if shield_now > last_shield + 0.01: recovery_frames += 1
			last_shield = shield_now
		if entered >= 0 and previous_state == BattleGame.State.COMBAT and g.state != BattleGame.State.COMBAT:
			cleared = elapsed
			exit_state = g.state
			armour_out = float(g.player.armour)
			shield_out = float(g.player.shield)
			break
		if g.state == BattleGame.State.RETREAT or elapsed > 240.0: break
		previous_state = g.state
	var status := "retreat" if exit_state == BattleGame.State.RETREAT or g.state == BattleGame.State.RETREAT else "clear" if cleared >= 0 else "timeout"
	var row := {"case":label,"stage":stage,"point":point,"status":status,"combat_s":snapped(cleared-entered,0.01) if cleared>=0 else -1,"prebattle_iron":iron_budget,"spent_iron":spent,"reactor":reactor_level,"armour_in":armour_in,"armour_out":armour_out,"shield_in":shield_in,"shield_out":shield_out,"shield_hit_frames":hit_times.size(),"recovery_frames":recovery_frames,"native_session":native_seen}
	print("APPROVED_POINT ", JSON.stringify(row))
	if status == "timeout" or entered < 0: failures += 1

func run() -> void:
	for point in [5, 6]:
		one("3-" + str(point) + "-missile4-armour3", 3, point, "missile", 4, "armour", 3, 3, true)
		one("3-" + str(point) + "-missile4-shield3", 3, point, "missile", 4, "shield", 3, 3, true)
	for weapon in ["cannon", "longLaser"]:
		one("6-8-" + weapon + "14-shield14", 6, 8, weapon, 14, "shield", 14, 7, true, 100000.0)
		one("7-8-" + weapon + "17-shield17", 7, 8, weapon, 17, "shield", 17, 11, true, 100000.0)
	print("THIRD_FOLLOWUP_COMPARE ", failures)
	quit(1 if failures else 0)
