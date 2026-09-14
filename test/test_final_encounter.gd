extends SceneTree

var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1

func _initialize() -> void:
	var db := ShipDatabase.new()
	var normal: Dictionary = db.enemies.values().filter(func(e): return e.size == 1)[0].duplicate(true)
	var large: Dictionary = normal.duplicate(true)
	normal.id = 991
	normal.des = "Final small ship"
	normal.equipment = []
	large.id = 992
	large.des = "Early large ship"
	large.size = 3
	large.equipment = []
	db.enemies["991"] = normal
	db.enemies["992"] = large
	db.groups["991"] = {"slots":[992,null,null,null,null,null,null,null,null,null]}
	db.groups["992"] = {"slots":[991,991,null,null,null,null,null,null,null,null]}
	db.levels[0].groups = [{"id":991,"position":0.2},{"id":991,"position":0.5},{"id":992,"position":0.9}]
	db.levels[0].length = 1000
	var g := BattleGame.new(db, false)
	g.start(1, false)
	g.profile.unlocked = []
	var events: Array = []
	g.event.connect(func(kind, info):
		if kind == "encounter": events.append(info.boss))
	for i in range(2):
		g.spawn_group()
		check(not g.is_boss_encounter() and g.enemies[0].boss, "Early large hull is not final battle")
		check(g.boss_info() == "？？？", "Early large hull does not reveal final battle")
		g.fire(g.enemies[0], g.player, db.equip("laser",1), 1, true, "laser_mon")
		g.hit_enemy(g.enemies[0], 1e20, 1)
		check(not g.projectiles.is_empty(), "Early large hull death preserves projectiles")
		g.tick(0)
		check(g.state == BattleGame.State.TRAVEL and not g.profile.cleared.has(1), "Early battle continues without clear")
		g.projectiles.clear()
	g.spawn_group()
	check(g.is_boss_encounter() and not g.enemies[0].boss, "Final small-ship group is boss battle")
	check(g.boss_info() == "Final small ship", "Boss information describes final group only")
	check(events == [false, false, true], "Encounter notifications follow position")
	g.fire(g.enemies[0], g.player, db.equip("laser",1), 1, true, "laser_mon")
	g.hit_enemy(g.enemies[0], 1e20, 1)
	g.tick(0)
	check(g.state == BattleGame.State.COMBAT and not g.projectiles.is_empty(), "Partial final group defeat does not clear battle or shots")
	g.hit_enemy(g.enemies[1], 1e20, 1)
	check(g.projectiles.is_empty(), "Last small ship death immediately clears shots")
	g.tick(0)
	check(g.state == BattleGame.State.LEVEL_CLEAR and g.profile.cleared.has(1), "Final group defeat clears level")
	# Landing beyond an earlier large hull must not replay it; landing beyond
	# the final small-ship battle must replay that battle at the landing point.
	g.profile.highestLevel = 2
	db.config.backRange = 300
	g.start(2, false)
	g.distance = 100
	g.begin_retreat()
	g.tick(2)
	check(g.stage == 1 and g.distance == 800 and not g.retreat_boss_pending and g.group_index == 2, "Retreat after early hull waits for final battle")
	g.start(2, false)
	g.distance = 250
	g.begin_retreat()
	g.tick(2)
	g.tick(0)
	check(g.stage == 1 and g.distance == 950 and g.state == BattleGame.State.COMBAT and g.is_boss_encounter(), "Retreat after final battle replays small-ship boss group")
	db.levels[0].groups = [{"id":992,"position":0.3}]
	g.start(1, false)
	g.spawn_group()
	check(g.is_boss_encounter(), "Single battle is final battle")
	for enemy in g.enemies: g.hit_enemy(enemy, 1e20, 1)
	g.tick(0)
	check(g.state == BattleGame.State.LEVEL_CLEAR, "Single small-ship battle clears")
	print("Final encounter: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
