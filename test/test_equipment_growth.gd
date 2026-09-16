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
	check(db.equipment.armour.size() == 1, "Projection contains only base rows")
	check(db.equip("armour", 3).para1 == 1400, "Armour rounds two significant digits")
	check(db.equip("shield", 3).para1 == 720, "Shield uses para4")
	check(db.equip("laser", 3).dmg == 140, "Weapon damage growth")
	check(db.equip("laser", 2).cost_1 == 65, "Cost 60 rounds to 65")
	check(db.equip("missile", 1).dmg == 30, "Level one is unchanged")
	check(db.equip("missile", 2).dmg == 35, "Small damage ends in five")
	for value in [60.0, 62.0, 68.0]:
		check(db.equipment_growth(value, 0, 2) == 65, "Confirmed low rounding %s" % value)
	check(db.equipment_growth(0, 0.2, 2) == 0, "Zero remains zero")
	check(db.equipment_growth(995, 0, 2) == 1000, "Rounding carries into next magnitude")
	var original: Dictionary = db.equipment.shield[0].duplicate(true)
	var derived := db.equip("shield", 150)
	for field in ["para2", "para3", "cd", "unlock", "dmgtype", "des"]:
		check(derived[field] == original[field], "Static field inherited: " + field)
	check(db.equipment.shield[0] == original, "Read does not mutate source")
	db.equipment.laser.append({"level":2, "dmg":999999})
	check(db.equip("laser", 2).dmg == 120, "Legacy higher rows ignored")
	db.equipment.laser[0].res_3 = 3
	db.equipment.laser[0].cost_3 = 100
	db.equipment.laser[0].cost_multi_3 = 0.5
	check(db.equip("laser", 2).cost_3 == 150, "Dynamic cost suffix and snake case alias")
	var game := BattleGame.new(db, false)
	game.profile.resources = {"1":1e30, "2":1e30, "3":1e30}
	game.first_equipment_entry("laser").level = 120
	check(game.upgrade("laser", 10), "Upgrade beyond former table cap")
	check(game.first_equipment_entry("laser").level == 130, "Calculated target level")
	game.first_equipment_entry("laser").level = 300
	check(game.upgrade_costs("laser", 10)["1"] > 9.22e18, "Large costs do not overflow int64")
	game.first_equipment_entry("laser").level = 1
	var budget := game.upgrade_costs("laser", 10)
	game.profile.resources = budget.duplicate()
	check(game.max_upgrade_amount("laser") == 10, "MAX uses rounded per-level costs")
	check(game.upgrade("laser", 10), "Batch purchase")
	game.refund_equipment("laser", 11)
	check(game.profile.resources == budget, "Refund equals purchase")
	print("Equipment growth: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
