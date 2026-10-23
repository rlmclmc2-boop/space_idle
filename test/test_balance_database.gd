extends SceneTree
const RunDatabase = preload("res://scripts/balance_database.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var original := ShipDatabase.new()
	var cached := RunDatabase.new()
	for key in original.equipment:
		for level in [-1,1,2,40,200,1000]:
			check(original.equip(key,level) == cached.equip(key,level),"real equipment projection %s/%d" % [key,level])
		check(original.enemy_weapon(key) == cached.enemy_weapon(key),"enemy fallback projection "+key)
	for unlock in original.data.unlock.values():
		check(cached.unlock_id(unlock.type,unlock.target) == original.unlock_id(unlock.type,unlock.target),"fixed config unlock lookup")
	for index in 600:cached.unlock_id("missing",str(index))
	check(cached.unlock_ids.size() <= cached.ROW_LIMIT,"unlock lookup is bounded even for missing IDs")
	var first_id: String = str(cached.data.unlock.keys()[0])
	var first: Dictionary = cached.data.unlock[first_id]
	cached.unlock_id(first.type,first.target)
	cached.data.unlock.erase(first_id)
	cached.clear_derived_cache()
	check(cached.unlock_id(first.type,first.target).is_empty(),"unlock source edits invalidate lookup")
	var row := cached.equip("laser",40)
	row.dmg = -123
	check(cached.equip("laser",40) == original.equip("laser",40),"returned equipment row has independent ownership")
	row = cached.enemy_weapon("laser-mon")
	row.cd = -123
	check(cached.enemy_weapon("laser-mon") == original.enemy_weapon("laser-mon"),"returned enemy row has independent ownership")
	for level in 600:cached.equip("laser",level+1)
	check(cached.equipment_rows.size() <= cached.ROW_LIMIT,"equipment cache stays bounded")
	for database in [original,cached]:
		for source in database.equipment.laser:
			if int(source.level) == 1:source.dmg *= 2
	cached.clear_derived_cache()
	check(cached.equip("laser",40) == original.equip("laser",40),"explicit source edit invalidation")
	check(cached.enemy_weapon("laser-mon") == original.enemy_weapon("laser-mon"),"fallback invalidation after source edit")
	# Lab adapter must preserve the shared numeric and current Research owners.
	var live := BattleGame.new(ShipDatabase.new(),false)
	var lab = preload("res://scripts/balance_game.gd").new(RunDatabase.new())
	for subject in [live,lab]:
		subject.profile.cleared = [3,4]
		subject.rebuild_unlocks()
		check(subject.select_tech("weapon_accuracy"),"current research selected")
		subject.advance_hightech(5.0)
	check(lab.research.progress("weapon_accuracy")>0,"Lab advances current research without legacy profile fields")
	check(live.research.save_data()==lab.research.save_data(),"Lab research uses shared advancement")
	var huge = GrowthNumber.make(2.0,400.0)
	lab.player_power_multiplier = 3.0
	for subject in [live,lab]:
		var equipment: Dictionary = subject.equipment.save_data()
		for entry in equipment.loadout.defence:entry.level = 6000
		check(subject.equipment.install_snapshot(equipment,subject.db),"large defence fixture installs")
		subject.configuration_committed()
	check(lab.stat("armour") is Dictionary and GrowthNumber.compare(lab.stat("armour"),GrowthNumber.multiply(live.stat("armour"),3.0))==0,"Lab stat preserves large value and multiplier")
	for subject in [live,lab]:
		var equipment: Dictionary = subject.equipment.save_data()
		equipment.loadout.weapons[0].level = 6000
		check(subject.equipment.install_snapshot(equipment,subject.db),"large attack fixture installs")
		subject.configuration_committed()
		subject.rng.seed = 44
	var live_attack: Dictionary = live.jewel_attack(0)
	var lab_attack: Dictionary = lab.jewel_attack(0)
	check(lab_attack.damage is Dictionary and GrowthNumber.compare(lab_attack.damage,GrowthNumber.multiply(live_attack.damage,3.0))==0,"Lab attack preserves large value and multiplier")
	lab.start(1,false)
	lab.spawn_group()
	var target: Dictionary = lab.enemies[0]
	lab.fire(lab.player,target,lab.db.equip("laser",1),huge,false,"laser")
	check(GrowthNumber.compare(lab.projectiles.back().damage,huge)==0,"Lab projectile preserves large raw damage")
	var auto_game = preload("res://scripts/balance_game.gd").new(RunDatabase.new())
	auto_game.profile.cleared = [3,4]
	auto_game.rebuild_unlocks()
	var expected_choice: String = auto_game.research.shortest_available(auto_game)
	var auto = preload("res://scripts/balance_autoplayer.gd").new()
	auto.act(auto_game,0.0)
	check(not expected_choice.is_empty() and auto_game.research.selected()==expected_choice,"Lab automatic selection reuses current Research choice")
	auto_game.advance_hightech(1.0)
	check(auto_game.research.progress(expected_choice)>0,"automatic Lab research actually advances")
	var base := BattleGame.new(ShipDatabase.new(),false)
	base.economy.credit("1",huge)
	base.economy.credit("2",huge)
	var saved: Dictionary = base.portable_save_data()
	var upgraded: Dictionary = preload("res://scripts/player_loadout_generator.gd").upgraded_profile(base.db,{"ship":saved.selectedShip,"equipment":saved.loadout},saved,1)
	check(not upgraded.has("error") and int(upgraded.loadout.weapons[0].level)==2 and GrowthNumber.compare(upgraded.resources["1"],huge)==0,"Lab upgrade funding preserves out-of-precision large balances")
	var timings := []
	for database in [original,cached]:
		var started := Time.get_ticks_usec()
		for index in 10000:database.equip("shield",40+index%3)
		timings.append(Time.get_ticks_usec()-started)
	print("ROW_PROJECTION_USEC=",timings)
	print("Balance Database: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
