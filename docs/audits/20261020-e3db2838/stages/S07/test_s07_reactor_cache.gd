extends SceneTree

var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", label)

func fixture(free_charge: bool) -> BattleGame:
	var g := BattleGame.new(ShipDatabase.new(), false)
	g.profile.cleared = range(1, 61)
	g.profile.highestLevel = 61
	g.rebuild_unlocks()
	g.profile.resources[str(int(g.db.config.reactorUraniumId))] = 1000000.0
	if free_charge:
		g.profile.planets["1"].conquered = true
	g.stat_cache_enabled = true
	g.invalidate_stat_cache()
	g.enable_compiled_combat_rules()
	return g

func exercise(free_charge: bool) -> void:
	var g := fixture(free_charge)
	var events: Array[String] = []
	g.event.connect(func(kind, _info): events.append(kind))
	var before = g.equipment_stat("laser", 1)
	var old_capacity := g.reactor_capacity()
	var old_revision := g.stat_cache_revision
	var old_builds: int = g.compiled_combat_rules.builds
	var old_level := int(g.profile.reactorLevel)
	check(g.stat_cache.has("equipment_bases"), "preview warmed")
	check((g.charge_free_ratio() > 0.0) == free_charge, "reward fixture")
	check(g.upgrade_reactor(1), "upgrade accepted")
	check(g.profile.reactorLevel == old_level + 1 and g.reactor_capacity() > old_capacity, "level and capacity committed")
	check(g.stat_cache_revision == old_revision + 1, "one cache revision")
	check(g.compiled_combat_rules.builds == old_builds + 1, "one compiled configuration rebuild")
	check(events.count("reactor_changed") == 1 and events.count("resources_changed") == 1, "one notification of each kind")
	var cached = g.equipment_stat("laser", 1)
	g.stat_cache_enabled = false
	var fresh = g.equipment_stat("laser", 1)
	check(g.N.compare(cached, fresh) == 0, "cached equals fresh after upgrade")
	check(g.N.compare(cached, before) > 0 if free_charge else g.N.compare(cached, before) == 0, "reward dependent value")
	check(g.stat_cache_revision == old_revision + 1 and g.compiled_combat_rules.builds == old_builds + 1, "reads do not repeat invalidation")
	print("S07 CASE free_charge=", free_charge, " capacity=", old_capacity, "->", g.reactor_capacity(), " value=", before, "->", cached, " revision=", old_revision, "->", g.stat_cache_revision)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	exercise(true)
	exercise(false)
	print("S07 REACTOR CACHE: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
