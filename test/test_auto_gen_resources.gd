extends SceneTree

var checks := 0
var failures := 0

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var db := ShipDatabase.new()
	# Production values may change; mechanics below use an explicit isolated fixture.
	db.config.autoGenRes = "1,2,10,40"
	db.config.autoCollectReduce = 0.5
	var g := BattleGame.new(db, false)
	g.rng.seed = 7
	g.start(1, false)
	g.group_index = db.levels[0].groups.size()
	g.distance = db.levels[0].length
	db.levels[0].resRatio = 1.25
	g.tick(1.0)
	check(g.drops.size() == 1, "Configured interval generates one resource")
	var generated: Dictionary = g.drops[0]
	check(generated.id == "2" and generated.amount == 13 and generated.auto_gen and generated.speed == 40, "Generated resource uses ID, multiplier, and speed")
	g.tick(2.0)
	check(is_equal_approx(generated.y, 80.0), "Generated resource flies down at configured speed")
	g.drops.clear()
	g.profile.resources["2"] = 0
	generated.x = 500
	generated.y = 405
	g.drops.append(generated)
	g.collect_near(Vector2(500, 405))
	check(g.profile.resources["2"] == 13 and g.drops.is_empty(), "Mouse crossing collects generated resource in full")
	var passed_ship := {"uid":999,"x":g.player.x,"y":g.player.y-1.0,"age":0.0,"id":"2","amount":13.0,"speed":40.0,"auto_gen":true}
	g.drops.append(passed_ship)
	g.profile.resources["2"] = 0
	g.tick(0.1)
	check(g.profile.resources["2"] == 7 and g.drops.is_empty(), "Reaching ship applies automatic pickup loss")
	var timed := {"uid":1000,"x":g.player.x,"y":100.0,"age":float(db.defaults.autoCollectDelay),"id":"2","amount":13.0,"speed":1.0,"auto_gen":true}
	g.drops.append(timed)
	g.tick(0.1)
	check(g.drops.has(timed), "Generated resource does not use timed pickup")
	print("Auto resources: %d checks, %d failures" % [checks,failures])
	quit(1 if failures > 0 else 0)
