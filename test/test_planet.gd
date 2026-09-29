extends SceneTree

var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(label)

func _initialize() -> void:
	var db := ShipDatabase.new()
	# This scenario exercises the duration curve independently of live balance edits.
	db.data.planet["1"].baseTime = 100
	db.config.offlineMax = 0
	var g := BattleGame.new(db, false)
	var id := "1"
	check(not g.planet_unlocked(id), "Planet locked before level 30 clear")
	check(not g.start_planet_exploration(id, "navigator"), "Locked planet rejects exploration")
	check(is_equal_approx(g.planet_duration(id), 100.0), "Initial exploration lasts 100 seconds")
	check(is_equal_approx(g.planet_equipment_multiplier(), 1.0), "Initial equipment multiplier")
	g.profile.cleared = range(1, 31)
	g.profile.highestLevel = 30
	check(g.planet_unlocked(id), "Level 30 clear unlocks planet")
	check(is_equal_approx(g.planet_exp_multiplier(), 1.0), "Level 30 experience coefficient")
	check(is_equal_approx(float(db.levels[31].planetExpRatio), 1.44), "Level 32 coefficient rounds to two decimals")
	check(is_equal_approx(float(db.levels[33].planetExpRatio), 2.08), "Each level grows from previous rounded coefficient")
	var weapon: Dictionary = g.weapon_entries()[0]
	var before = g.jewel_equipment_stat(weapon)
	var baseline := {}
	for key in ["laser", "cannon", "missile", "longLaser", "armour", "shield"]:
		baseline[key] = g.jewel_equipment_stat({"key":key, "level":1, "sockets":[]})
	check(g.start_planet_exploration(id, "navigator"), "Idle crew starts exploration")
	check(not g.assign_crew("navigator", "equipment_upgrade", "equipment"), "Exploring crew cannot take assignment")
	check(not g.start_planet_exploration(id, "engineer"), "Planet accepts only one crew")
	g.paused = true
	g.tick(99.0)
	check(is_equal_approx(float(g.planet_progress(id).elapsed), 0.0), "Pause freezes exploration")
	g.paused = false
	g.advance_planets(99.0)
	check(int(g.planet_progress(id).degree) == 0, "No early completion")
	g.advance_planets(1.0)
	check(int(g.planet_progress(id).degree) == 1 and str(g.planet_progress(id).crewId).is_empty(), "Completion releases crew and adds exploration")
	check(int(g.crew.entry(g, "navigator").level) == 1, "100 experience upgrades crew from level zero")
	check(is_equal_approx(g.planet_duration(id), 10000.0 / 101.0), "Duration uses squared base time")
	check(is_equal_approx(g.jewel_equipment_stat(weapon), before), "Exploration alone does not improve weapon")
	for key in baseline:
		check(is_equal_approx(g.jewel_equipment_stat({"key":key, "level":1, "sockets":[]}), float(baseline[key])), "No inherent exploration bonus on " + key)
	g.profile.planets[id].degree = 4
	check(is_equal_approx(g.planet_equipment_multiplier(), 1.0), "Degree alone grants no multiplier")
	g.profile.planets[id].degree = 100000000
	check(is_equal_approx(g.planet_duration(id), 5.0), "Duration floors at configured five seconds")
	check(is_equal_approx(g.planet_duration_from({"baseTime":100,"minTime":8},1e100),8.0),"Duration floor follows per-planet configuration")
	check(is_equal_approx(g.planet_duration_from({"baseTime":100},1e100),5.0),"Missing duration floor uses safe default")
	g.profile.planets[id].degree = 1
	g.profile.highestLevel = 31
	check(is_equal_approx(g.planet_exp_multiplier(), 1.2), "Next level experience coefficient")
	check(g.start_planet_exploration(id, "navigator"), "Crew can explore again")
	g.advance_planets(10.0)
	g.save_enabled = true
	g.save_progress()
	var restored := BattleGame.new(db, false)
	restored.load_progress()
	check(int(restored.planet_progress(id).degree) == 1 and str(restored.planet_progress(id).crewId) == "navigator" and is_equal_approx(float(restored.planet_progress(id).elapsed), 10.0), "Exploration progress survives save and load")
	g.advance_planets(g.planet_duration(id) - 10.0)
	check(int(g.crew.entry(g, "navigator").level) == 2, "Second reward uses current highest level and growth cost")
	check(g.assign_crew("navigator", "equipment_upgrade", "equipment"), "Completed crew can take assignment")
	db.levels[30].planetExpRatio=1.235
	check(is_equal_approx(g.planet_exp_reward(id),124),"Exploration preview rounds fractional reward")
	var emitted_reward := [-1.0]
	g.event.connect(func(kind, payload):
		if kind=="planet_changed" and payload.has("reward"):emitted_reward[0]=float(payload.reward))
	check(g.start_planet_exploration(id,"engineer"),"Idle crew starts integer reward check")
	g.advance_planets(g.planet_duration(id))
	check(g.crew.entry(g,"engineer").level==1 and is_equal_approx(g.crew.entry(g,"engineer").exp,24) and is_equal_approx(emitted_reward[0],124),"Credited and emitted experience match integer preview")
	print("PLANET: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
