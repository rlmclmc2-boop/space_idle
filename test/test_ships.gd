extends SceneTree

func _initialize() -> void:
	var db := ShipDatabase.new()
	db.config.equipmentSwitchCooldownSeconds=0.0
	var game := BattleGame.new(db,false)
	game.rng.seed = 1701
	for key in db.ships:
		var empty := game.empty_loadout(key)
		var default_equipment := game.default_loadout(key,["armour","shield","laser","cannon","missile"])
		assert(empty.weapons.size()==int(db.ship(key).weaponSlots) and empty.defence.size()==int(db.ship(key).defenseSlots),"Empty layout matches ship slots")
		assert(empty.weapons.all(func(entry):return entry.key=="" and entry.level==1) and empty.defence.all(func(entry):return entry.key=="" and entry.level==1),"Empty layout stays empty")
		assert(default_equipment.weapons.slice(0,3).map(func(entry):return entry.key)==["laser","cannon","missile"].slice(0,mini(3,int(db.ship(key).weaponSlots))),"Default weapons preserve input order")
		assert(default_equipment.defence.slice(0,2).map(func(entry):return entry.key)==["armour","shield"].slice(0,mini(2,int(db.ship(key).defenseSlots))),"Default defence preserves input order")
		empty.weapons[0].level=9
		assert((empty.weapons.size()<2 or empty.weapons[1].level==1) and default_equipment.weapons[0].level==1 and game.empty_loadout(key).weapons[0].level==1,"Layouts and individual slots never share mutable entries")
	assert(db.ships.size() == 5, "ship table has five player ships")
	assert(game.weapon_entries().size()==int(db.ship("Frigate").weaponSlots) and game.defense_entries().size()==int(db.ship("Frigate").defenseSlots),"Initial active slots follow the current hull table")
	# Two independent module investments require a hull with two active slots.
	game.profile.selectedShip="Destroyer"
	game.ensure_loadout()
	game.reset_player()
	game.profile.unlocked = ["armour", "shield", "laser", "cannon", "missile"]
	game.ensure_loadout()
	game.equip_slot("weapons", 1, "laser")
	game.profile.resources["1"] = 10000
	assert(game.upgrade_slot("weapons", 0), "first laser upgrades")
	assert(game.slot_entry("weapons", 0).level == 2 and game.slot_entry("weapons", 1).level == 1, "duplicate weapons upgrade independently")
	game.profile.cleared = range(1,60)
	game.profile.highestLevel = 11
	game.profile.aiTechProgress.singularity=7.0
	var before := float(game.profile.resources["1"])
	assert(game.switch_ship("Cruiser"), "unlocked ship switches")
	assert(game.stage == 1 and game.profile.selectedShip == "Cruiser", "ship switch retains the current stage")
	assert(game.profile.cleared.has(10) and game.profile.aiTechProgress.singularity==7.0, "other progress retained")
	assert(float(game.profile.resources["1"])==before,"Ship switch does not refund module investment")
	assert(game.slot_entry("weapons",0).level==2 and game.slot_entry("weapons",1).level==1,"Ship switch preserves independent module investments")
	# Runtime fixtures write the authoritative slot; raw legacy input is tested below.
	var legacy := BattleGame.new(db,false)
	legacy.first_equipment_entry("laser").level=3
	assert(legacy.weapon_entries()[0].level==3,"Slot level is visible through weapon reads")
	legacy.start(1,false)
	legacy.cooldowns.weapons_0=0.5
	legacy.spawn_group()
	legacy.enemies[0].equipment=[]
	legacy.paused=true
	legacy.tick(0.1)
	assert(legacy.cooldowns.weapons_0==0.5,"Pause preserves slot cooldown")
	legacy.paused=false
	legacy.tick(0.1)
	assert(is_equal_approx(legacy.cooldowns.weapons_0,0.4),"Slot cooldown counts down independently")
	var file := FileAccess.open(BattleGame.SAVE_PATH,FileAccess.WRITE)
	file.store_string(JSON.stringify({"version":BattleGame.SAVE_VERSION,"levels":{"laser":3},"resources":{"1":123,"2":7}}))
	file.close()
	var restored := BattleGame.new(db,false)
	restored.load_progress()
	assert(restored.slot_entry("weapons",0).level==3 and restored.profile.resources=={"1":123.0,"2":7.0},"Old levels-only save migrates without changing resources")
	print("Ships: passed")
	quit()
