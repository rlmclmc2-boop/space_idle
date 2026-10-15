extends SceneTree

var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", label)

func fixture(level: int = 10, armour_only: bool = false) -> BattleGame:
	var db := ShipDatabase.new()
	for key in ["armour", "shield"]:
		db.equipment[key][0].para1 = 100
		db.equipment[key][0]["para2" if key == "armour" else "para4"] = 0
	db.equipment.shield[0].para2 = 0
	db.config.dmgReduce = 0
	# Isolate Memory from Adaptation's incoming-history maximum growth.
	db.data.enhance_config.threshold_2.value = 1000
	db.data.enhance_config.threshold_3.value = 2000
	var g: BattleGame = load("res://scripts/presented_battle_game.gd").new(db, false)
	g.profile.grantedUnlocks = [db.unlock_id("feature", "jewels")]
	g.profile.unlocked = BattleGame.EQUIPMENT.duplicate()
	g.profile.enhancementLevel = level
	g.profile.enhancementOrder.defence = ["memory_material", "adaptation", "delayed_damage"]
	g.profile.loadout = {"weapons": [], "defence": [{"key": "armour", "level": 1}] if armour_only else [{"key": "armour", "level": 1}, {"key": "shield", "level": 1}]}
	g.reset_player()
	g.state = BattleGame.State.COMBAT
	return g

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var g := fixture()
	var interval := g.enhancement_parameter("memory_interval")
	var fraction := g.enhancement_parameter("memory_heal_fraction")
	var cap_fraction := g.enhancement_parameter("memory_buffer_fraction")
	check(is_equal_approx(interval, 0.2) and is_equal_approx(fraction, 0.0005) and is_equal_approx(cap_fraction, 0.05), "live workbook values are loaded")
	g.player.armour = 20
	g.sync_jewel_defence_damage()
	g.advance_jewel_repair(10)
	check(is_equal_approx(float(g.player.armour), 45.0), "10 seconds restores 25% of one module, not another")
	check(is_equal_approx(float(g.memory_buffer(0)), 0.0) and is_equal_approx(float(g.memory_buffer(1)), 25.0), "only full module charges protection")
	g.advance_jewel_repair(10)
	check(is_equal_approx(float(g.player.armour), 70.0) and is_equal_approx(float(g.memory_buffer(1)), 50.0), "20 seconds restores 50% deficit and caps full module at 50% protection")
	g.advance_jewel_repair(12)
	check(is_equal_approx(float(g.player.armour), 100.0) and is_equal_approx(float(g.memory_buffer(0)), 0.0), "damaged module repairs before charging")
	g.advance_jewel_repair(20)
	check(is_equal_approx(float(g.memory_buffer(0)), 50.0) and is_equal_approx(float(g.memory_buffer(1)), 50.0), "each module reaches its own cap without recursive growth")
	g.hit_player(120, 0)
	check(is_equal_approx(float(g.enhancement_protection_current()), 0.0) and is_equal_approx(float(g.player.shield), 80.0), "100 points of stored protection exhaust before body loss")

	g = fixture(10, true)
	g.advance_jewel_repair(20)
	for tick in 50:
		g.hit_player(2, 0)
		g.advance_jewel_repair(0.2)
	check(float(g.player.armour) >= 70.0 and float(g.player.armour) <= 80.0 and is_equal_approx(float(g.enhancement_protection_current()), 0.0), "10% per second incoming pressure exhausts stored protection and damages body; armour=" + str(g.player.armour) + " buffer=" + str(g.enhancement_protection_current()))

	for level in [10, 20, 30]:
		g = fixture(level, true)
		g.player.armour = 20
		g.sync_jewel_defence_damage()
		g.advance_jewel_repair(1)
		check(is_equal_approx(float(g.player.armour), 20.0 + 100.0 * fraction * level / interval), "unbranched one-second recovery at level " + str(level))

	g = fixture(10, true)
	var compiled := preload("res://scripts/native_execution_compiler.gd").new().compile(g, "native_low_contract")
	check(not compiled.has("error"), "native compiler accepts unbranched recovery")
	if not compiled.has("error"):
		check(is_equal_approx(float(compiled.defences[0].memory_heal), fraction * 10) and is_equal_approx(float(compiled.defences[0].memory_cap), cap_fraction * 10), "native descriptor uses same workbook coefficients")

	print("MEMORY RECOVERY PACING: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
