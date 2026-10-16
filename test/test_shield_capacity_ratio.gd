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
	var armour_base: Dictionary = db.equipment.armour[0]
	var shield_base: Dictionary = db.equipment.shield[0]
	check(shield_base.para1 == 750 and armour_base.para1 == 1000, "Excel projection has 75% shield base")
	check(shield_base.dmgtype == 1 and shield_base.para2 == 0.3 and shield_base.para3 == 2 and shield_base.para4 == armour_base.para2, "Resistance and recovery unchanged")
	for level in [1, 2, 3, 4, 10, 100, 1000]:
		var armour = db.equip("armour", level).para1
		var shield = db.equip("shield", level).para1
		check(GrowthNumber.valid(shield) and GrowthNumber.compare(shield, GrowthNumber.multiply(armour, 0.75)) == 0, "Base ratio at level %d" % level)
		check(GrowthNumber.compare(game.equipment_stat("shield", level), shield) == 0, "Game reads shield projection at level %d" % level)
	print("Shield ratio: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
