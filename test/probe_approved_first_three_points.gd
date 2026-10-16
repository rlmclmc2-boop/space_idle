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
	var row := {"case":label,"stage":stage,"point":point,"status":status,"combat_s":snapped(cleared-entered,0.01) if cleared>=0 else -1,"prebattle_iron":iron_budget,"spent_iron":spent,"reactor":reactor_level,"armour_in":armour_in,"armour_out":armour_out,"shield_in":shield_in,"shield_out":shield_out,"shield_damage_times":hit_times,"recovery_frames":recovery_frames,"native_session":native_seen}
	print("APPROVED_POINT ", JSON.stringify(row))
	if status == "timeout" or entered < 0: failures += 1

func run() -> void:
	if OS.get_environment("FIRST_THREE_STAGE3_APPROVED") == "1":
		one("3-1-low-missile1-shield1-reactor1", 3, 1, "missile", 1, "shield", 1, 1, true, 0.0)
		one("3-1-auto-missile3-shield3-reactor1", 3, 1, "missile", 3, "shield", 3, 1, true, 280.0)
		one("3-2-low-missile1-shield1-reactor1", 3, 2, "missile", 1, "shield", 1, 1, true, 0.0)
		one("3-2-auto-missile3-shield3-reactor1", 3, 2, "missile", 3, "shield", 3, 1, true, 280.0)
		one("3-4-low-missile1-shield1-reactor1", 3, 4, "missile", 1, "shield", 1, 1, true, 0.0)
		one("3-4-low-cannon1-shield1-reactor1", 3, 4, "cannon", 1, "shield", 1, 1, true, 0.0)
		one("3-4-auto-missile4-shield3-reactor1", 3, 4, "missile", 4, "shield", 3, 1, true, 365.0)
		one("3-4-auto-cannon4-shield3-reactor1", 3, 4, "cannon", 4, "shield", 3, 1, true, 365.0)
		one("3-6-low-missile1-shield1-reactor1", 3, 6, "missile", 1, "shield", 1, 1, true, 0.0)
		one("3-6-low-cannon1-shield1-reactor1", 3, 6, "cannon", 1, "shield", 1, 1, true, 0.0)
		one("3-6-auto-missile4-shield4-reactor1", 3, 6, "missile", 4, "shield", 4, 1, true, 450.0)
		one("3-6-auto-cannon4-shield4-reactor1", 3, 6, "cannon", 4, "shield", 4, 1, true, 450.0)
		print("APPROVED_STAGE3_SUMMARY 12 cases ", failures, " invalid")
		quit(1 if failures else 0)
		return
	if OS.get_environment("FIRST_THREE_SAME_WEAPON") == "1":
		one("2-6-missile1-armour1-reactor1", 2, 6, "missile", 1, "armour", 1, 1, true)
		one("2-6-auto-missile3-armour2-reactor1", 2, 6, "missile", 3, "armour", 2, 1, true)
		one("3-7-missile1-armour1-reactor1", 3, 7, "missile", 1, "armour", 1, 1, true)
		one("3-7-auto-missile4-armour4-reactor1", 3, 7, "missile", 4, "armour", 4, 1, true)
		print("APPROVED_SAME_WEAPON_SUMMARY 4 cases ", failures, " invalid")
		quit(1 if failures else 0)
		return
	one("1-5-base", 1, 5, "laser", 1, "armour", 1, 1)
	one("1-5-grown", 1, 5, "laser", 2, "armour", 2, 1)
	one("2-1-laser-base", 2, 1, "laser", 1, "armour", 1, 1)
	one("2-1-missile-base", 2, 1, "missile", 1, "armour", 1, 1)
	one("2-6-base", 2, 6, "laser", 1, "armour", 1, 1)
	one("2-6-grown", 2, 6, "missile", 4, "armour", 3, 2)
	one("3-3-armour-base", 3, 3, "laser", 1, "armour", 1, 1)
	one("3-3-shield-base", 3, 3, "laser", 1, "shield", 1, 1)
	one("3-5-shield-grown-native", 3, 5, "missile", 3, "shield", 3, 2, true)
	one("3-3-shield-base-native", 3, 3, "laser", 1, "shield", 1, 1, true)
	one("3-7-armour-base", 3, 7, "laser", 1, "armour", 1, 1)
	one("3-7-armour-grown", 3, 7, "missile", 4, "armour", 4, 2)
	print("APPROVED_POINT_SUMMARY 12 cases ", failures, " invalid")
	quit(1 if failures else 0)
