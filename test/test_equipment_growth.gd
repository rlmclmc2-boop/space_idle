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
	for key in db.equipment:
		for level in [-1,1,2,10,100,1000]:
			check(db.equipment_cost(key,level)==reference_cost(db,key,level),"Cost projection matches full row %s/%s" % [key,level])
	var edge := ShipDatabase.new()
	edge.equipment.probe=[{"level":1,"res_1":1,"cost_1":12.2,"costMulti_1":0.1,"res_2":2,"cost_2":99.5,"cost_multi_2":-0.1,"res_3":3,"cost_3":0.0,"res_4":null,"cost_4":100,"res_5":5,"cost_5":null,"res_6":6,"cost_6":2.5}]
	for level in [0,1,2,10,100]:
		check(edge.equipment_cost("probe",level)==reference_cost(edge,"probe",level),"Cost aliases, nulls, rounding and zero at "+str(level))
	check(edge.equipment_cost("missing",1).is_empty(),"Missing cost configuration stays empty")
	check(db.equipment.armour.size() == 1, "Projection contains only base rows")
	check(db.equip("armour", 3).para1 == 1400, "Armour rounds two significant digits")
	check(db.equip("shield", 3).para1 == 720, "Shield uses para4")
	check(db.equip("laser", 3).dmg == 140, "Weapon damage growth")
	check(db.equip("laser", 2).cost_1 == 65, "Cost 60 rounds to 65")
	# Explicit rounding fixture; the authored base damage may change independently.
	db.equipment.missile[0].dmg = 30
	check(db.equip("missile", 1).dmg == 30, "Level one is unchanged")
	check(db.equip("missile", 2).dmg == 35, "Small damage ends in five")
	for value in [60.0, 62.0, 68.0]:
		check(db.equipment_growth(value, 0, 2) == 65, "Confirmed low rounding %s" % value)
	check(db.equipment_growth(0, 0.2, 2) == 0, "Zero remains zero")
	check(db.equipment_growth(995, 0, 2) == 1000, "Rounding carries into next magnitude")
	var large = db.equipment_combat_growth(1.0,1.0,1025)
	check(GrowthNumber.valid(large) and large=={"m":1.8,"e":308.0}, "Overflowing 2^1024 retains two significant digits")
	check(db.equipment_combat_growth(9.96,9.0,310)=={"m":1.0,"e":310.0}, "Large combat rounding carries into next exponent")
	var original: Dictionary = db.equipment.shield[0].duplicate(true)
	var derived := db.equip("shield", 150)
	for field in ["para2", "para3", "cd", "dmgtype", "des"]:
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

func reference_cost(db: ShipDatabase, key: String, level: int) -> Dictionary:
	var row := db.equip(key,level)
	var costs := {}
	for field in row:
		if str(field).begins_with("res_") and row[field]!=null:
			var amount = row.get("cost_"+str(field).trim_prefix("res_"))
			if amount!=null:costs[str(int(row[field]))]=ceilf(float(amount))
	return costs
