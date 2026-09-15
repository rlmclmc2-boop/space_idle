extends SceneTree

func _initialize() -> void:
	var db := ShipDatabase.new()
	var game := BattleGame.new(db,false)
	assert(db.ships.size() == 5, "ship table has five player ships")
	assert(game.weapon_entries().size() == 3 and game.defense_entries().size() == 2, "frigate slot counts")
	game.profile.unlocked = ["armour", "shield", "laser", "cannon", "missile"]
	game.ensure_loadout()
	game.equip_slot("weapons", 1, "laser")
	game.profile.resources["1"] = 10000
	assert(game.upgrade_slot("weapons", 0), "first laser upgrades")
	assert(game.slot_entry("weapons", 0).level == 2 and game.slot_entry("weapons", 1).level == 1, "duplicate weapons upgrade independently")
	game.profile.cleared = [10]
	game.profile.highestLevel = 11
	game.profile.techPoints["keep"] = 7
	var before := float(game.profile.resources["1"])
	assert(game.switch_ship("Destroyer"), "unlocked ship switches")
	assert(game.stage == 1 and game.profile.selectedShip == "Destroyer", "ship switch restarts at level one")
	assert(game.profile.cleared.has(10) and game.profile.techPoints["keep"] == 7, "other progress retained")
	assert(float(game.profile.resources["1"]) > before, "equipment investment refunded")
	for entry in game.weapon_entries() + game.defense_entries():
		assert(int(entry.level) == 1, "ship switch resets equipment levels")
	print("Ships: passed")
	quit()
