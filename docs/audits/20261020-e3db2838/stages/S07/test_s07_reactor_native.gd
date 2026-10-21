extends SceneTree

var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", label)

func fixture() -> BattleGame:
	var db := ShipDatabase.new()
	db.equipment.shield[0].para2 = 0.0
	var g: BattleGame = preload("res://scripts/presented_battle_game.gd").new(db, false)
	g.profile.unlocked = BattleGame.EQUIPMENT.duplicate()
	g.profile.resources = {"1": 1e30, "2": 1e30}
	g.profile.cleared = range(1, 61)
	g.profile.highestLevel = 61
	g.rebuild_unlocks()
	g.profile.planets["1"].conquered = true
	g.profile.loadout.weapons[0].key = "missile"
	g.profile.loadout.defence = [{"key":"shield","level":1},{"key":"armour","level":1},{"key":"shield","level":1},{"key":"armour","level":1}]
	g.stat_cache_enabled = true
	g.invalidate_stat_cache()
	g.enable_compiled_combat_rules()
	g.reset_player()
	g.state = BattleGame.State.COMBAT
	g.enemies.assign([{"uid":100,"slot":4,"x":286.0,"y":150.0,"hp":1e8,"max_hp":1e8,"armourType":1,"shieldType":0,"shield":0.0,"max_shield":0.0,"equipment":[],"cooldowns":[],"drops":[],"res_ratio":1.0}])
	g.cooldowns[g.slot_id("weapons", 0)] = 0.0
	check(g.admit_native_compiled_execution("native_low_contract"), "native class and admission")
	return g

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	check(ClassDB.class_exists("SpaceCombatKernel"), "actual native extension loaded")
	if failures > 0:
		print("S07 NATIVE: ", checks, " checks, ", failures, " failures")
		quit(1)
		return
	var g := fixture()
	if g.native_execution == null:
		print("S07 NATIVE: ", checks, " checks, ", failures, " failures")
		quit(1)
		return
	var events: Array[String] = []
	g.event.connect(func(kind, _info): events.append(kind))
	var old_value = g.equipment_stat("laser", 1)
	var old_revision := g.stat_cache_revision
	var old_builds: int = g.compiled_combat_rules.builds
	check(g.upgrade_reactor(1), "native reactor upgrade accepted")
	check(g.native_execution == null and g.native_handoff_count == 1, "one native handoff")
	check(g.stat_cache_revision == old_revision + 1 and g.compiled_combat_rules.builds == old_builds + 1, "one invalidation and compile after handoff")
	check(events.count("reactor_changed") == 1 and events.count("resources_changed") == 1 and events.count("native_execution_handoff") == 1, "one event of each kind")
	var cached = g.equipment_stat("laser", 1)
	g.stat_cache_enabled = false
	check(g.N.compare(cached, g.equipment_stat("laser", 1)) == 0 and g.N.compare(cached, old_value) > 0, "post native cached value equals fresh")
	g.begin_retreat()
	g = fixture()
	if g.native_execution != null:
		events = []
		g.event.connect(func(kind, _info): events.append(kind))
		g.equipment_stat("laser", 1)
		var level := int(g.profile.reactorLevel)
		old_revision = g.stat_cache_revision
		old_builds = g.compiled_combat_rules.builds
		g.native_execution.kernel.cancel()
		check(not g.upgrade_reactor(1), "cancelled native owner rejects upgrade")
		check(g.profile.reactorLevel == level and g.stat_cache_revision == old_revision and g.compiled_combat_rules.builds == old_builds, "rejection leaves level and caches intact")
		check(events.count("reactor_changed") == 0 and events.count("resources_changed") == 0, "rejection has no mutation events")
	print("S07 NATIVE: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
