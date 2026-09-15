extends SceneTree

var failures := 0
var checks := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(label)

func _initialize() -> void:
	var db := ShipDatabase.new()
	var game := BattleGame.new(db,false)
	game.profile.unlocked = ["laser","cannon","missile","armour","shield"]
	for ship in db.ships:
		game.profile.selectedShip = ship
		game.profile.loadout = {"weapons":[],"defence":[]}
		for category in ["weapons","defence"]:
			for i in range(8):
				game.profile.loadout[category].append({"key":"","level":1})
		game.ensure_loadout()
		for key in ["laser","armour"]:
			var category := "weapons" if key == "laser" else "defence"
			var slots: int = game.profile.loadout[category].size()
			var limit := game.equipment_limit()
			for index in range(mini(limit,slots)):
				check(game.equip_slot(category,index,key), ship+" within limit")
			if slots > limit:
				var before: Dictionary = game.profile.resources.duplicate()
				check(not game.equip_slot(category,limit,key),ship+" rejects excess")
				check(game.profile.resources == before, "reject is nonmutating")
			check(game.unequip_slot(category,0), "removal frees count")
			check(game.equip_slot(category,0,key), "can re-equip")
			check(game.slot_entry(category,0).level == 1, "new instance level one")
	# Existing over-limit saves remain intact; only new installations are rejected.
	db.ships[game.first_ship()].sameEquipmentLimit = 1
	var old := BattleGame.new(db,false)
	old.profile.loadout.weapons[1] = {"key":"laser","level":2}
	var file := FileAccess.open(BattleGame.SAVE_PATH,FileAccess.WRITE)
	file.store_string(JSON.stringify(old.profile))
	file.close()
	var restored := BattleGame.new(db,false)
	restored.load_progress()
	check(restored.equipment_count("laser")==2 and restored.slot_entry("weapons",1).level==2,"Legacy excess instances are not silently removed")
	var before: Dictionary = restored.profile.duplicate(true)
	check(not restored.equip_slot("weapons",2,"laser") and restored.profile==before,"Legacy excess cannot add another instance")
	print("Equipment limits: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
