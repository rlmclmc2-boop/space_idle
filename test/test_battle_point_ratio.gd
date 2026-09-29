extends SceneTree

var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", label)

func _initialize() -> void:
	var db := ShipDatabase.new()
	var game := BattleGame.new(db, false)
	var point_count: int = db.levels[1].groups.size()
	check(point_count >= 2, "Level has enough battle points to interpolate endpoints")
	var middle_point: int = int((point_count - 1) / 2)
	var middle_progress := float(middle_point) / float(point_count - 1)
	for kind in ["atkRatio", "lifeRatio", "resRatio"]:
		db.levels[0][kind] = 1.1
		db.levels[1][kind] = 1.3
		var middle_ratio := lerpf(1.1, 1.3, middle_progress)
		check(is_equal_approx(db.ratio(2, 0, kind), 1.1), kind + " first battle point inherits the previous level endpoint")
		check(is_equal_approx(db.ratio(2, middle_point, kind), middle_ratio), kind + " middle battle point is linearly assigned")
		check(is_equal_approx(db.ratio(2, point_count - 1, kind), 1.3), kind + " last battle point reaches its level multiplier")
		check(is_equal_approx(db.ratio(2, -1, kind), 1.1) and is_equal_approx(db.ratio(2, point_count, kind), 1.3), kind + " battle point index clamps to endpoints")
		check(is_equal_approx(db.ratio(1, 0, kind), 1.0) and is_equal_approx(db.ratio(1, point_count - 1, kind), 1.1), kind + " first level ramps from base multiplier one")
	game.stage = 2
	game.group_index = 1
	check(is_equal_approx(game.ratio("lifeRatio"), 1.1), "First encounter uses the first battle point multiplier")
	game.group_index = middle_point + 1
	check(is_equal_approx(game.ratio("lifeRatio"), lerpf(1.1, 1.3, middle_progress)), "Active encounter uses its battle point multiplier")
	game.group_index = point_count
	check(is_equal_approx(game.ratio("lifeRatio"), 1.3), "Last encounter uses the configured level multiplier")
	print("Battle point ratios: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
