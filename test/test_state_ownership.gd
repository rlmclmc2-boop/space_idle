extends SceneTree

var checks := 0
var failures := 0
var evidence := {}
var events: Array = []
var trace: Array = []

func record(game: BattleGame, label: String) -> void:
	var slots := {}
	for id in game.cooldowns:
		if str(id).begins_with("weapons_"):
			slots[id] = game.cooldowns[id]
	trace.append({"step":label,"loadout":game.profile.loadout.duplicate(true),"resources":game.profile.resources.duplicate(true),"player":game.player.duplicate(true),"cooldowns":slots,"state":game.state,"events":events.duplicate(true)})

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",label)

func snapshot(game: BattleGame) -> Dictionary:
	return {"profile":game.profile.duplicate(true),"cooldowns":game.cooldowns.duplicate(true),"player":game.player.duplicate(true)}

func check_reads(game: BattleGame, label: String) -> void:
	var readers := {"weapons":game.weapon_entries,"defence":game.defense_entries,"shield":game.max_shield,"movement":game.ship_movement,"name":game.ship_name,"limit":game.equipment_limit,"tech slots":game.hightech_slots,"furnace peak":game.furnace_income_peak,"income":game.resource_minute_total.bind("1")}
	for key in game.db.data.get("hightech",{}):
		readers["tech description/"+key]=game.hightech_description.bind(key)
	for key in BattleGame.EQUIPMENT:
		readers["stat/"+key]=game.stat.bind(key)
		readers["entry/"+key]=game.first_equipment_entry.bind(key)
		readers["count/"+key]=game.equipment_count.bind(key)
		readers["cost/"+key]=game.upgrade_cost.bind(key)
		readers["can/"+key]=game.can_upgrade.bind(key)
		readers["max/"+key]=game.max_upgrade_amount.bind(key)
	for category in ["weapons","defence"]:
		for index in range(game.loadout_entries(category).size()):
			var id := game.slot_id(category,index)
			readers["slot/"+id]=game.slot_entry.bind(category,index)
			readers["cost/"+id]=game.slot_upgrade_cost.bind(category,index,10)
			readers["can/"+id]=game.can_upgrade_slot.bind(category,index,10)
			readers["max/"+id]=game.max_upgrade_amount_slot.bind(category,index)
	for key in game.db.data.get("charge",{}):
		readers["charge/"+key]=game.charge_job.bind(key)
		readers["required/"+key]=game.charge_required.bind(key)
		readers["multiplier/"+key]=game.charge_multiplier.bind(key)
		readers["rate/"+key]=game.charge_resource_rate.bind(key)
		readers["description/"+key]=game.charge_description.bind(key)
	for name in readers:
		var before := snapshot(game)
		var weapons: Array = game.profile.loadout.weapons
		readers[name].call()
		check(snapshot(game)==before,"Read purity: "+label+" / "+name)
		check(is_same(weapons,game.profile.loadout.weapons),"Read preserves slot array identity: "+label+" / "+name)

func write_save(raw: Dictionary) -> void:
	var file := FileAccess.open(BattleGame.SAVE_PATH,FileAccess.WRITE)
	file.store_string(JSON.stringify(raw))
	file.close()

func _initialize() -> void:
	var db := ShipDatabase.new()
	db.config.offlineMax=0
	db.config.autoGenRes=""
	db.ships[db.ships.keys()[0]].sameEquipmentLimit=2
	var game := BattleGame.new(db,false)
	check_reads(game,"fresh")
	game.event.connect(func(kind,payload):events.append({"kind":kind,"payload":payload.duplicate(true)}))
	game.rng.seed=1701
	game.profile.unlocked=BattleGame.EQUIPMENT.duplicate()
	check(game.equip_slot("weapons",1,"laser"),"Install duplicate weapon")
	check(game.equip_slot("defence",1,"shield"),"Install shield")
	game.profile.resources={"1":1000000.0,"2":1000000.0}
	var original_resources: Dictionary=game.profile.resources.duplicate(true)
	check(game.upgrade_slot("weapons",0,2),"Upgrade first duplicate to level three")
	check(game.upgrade_slot("weapons",1),"Upgrade second duplicate to level two")
	check(game.slot_entry("weapons",0).level==3 and game.slot_entry("weapons",1).level==2,"Duplicate levels independent")
	check_reads(game,"duplicate levels")
	record(game,"upgrades")
	game.start(1,false)
	game.spawn_group()
	for enemy in game.enemies:
		enemy.hp=1000000
		enemy.equipment=[]
	game.cooldowns.weapons_0=0.8
	game.cooldowns.weapons_1=0.3
	# Stale external name keys must never override slot cooldowns.
	game.cooldowns.laser=0.8
	game.paused=true
	var before := snapshot(game)
	game.tick(0.1)
	check(snapshot(game)==before,"Pause preserves equipment and cooldowns")
	game.paused=false
	game.tick(0.1)
	check(is_equal_approx(game.cooldowns.weapons_0,0.7) and is_equal_approx(game.cooldowns.weapons_1,0.2),"Installed duplicates count down independently")
	evidence.before_unequip=game.cooldowns.duplicate(true)
	var second_cost := game.upgrade_costs_for_level("laser",1,1)
	check(game.unequip_slot("weapons",0),"Remove first duplicate")
	check(game.slot_entry("weapons",0).key=="" and game.slot_entry("weapons",1).level==2,"First removal preserves empty slot and remaining level")
	for id in original_resources:
		check(game.profile.resources[id]==original_resources[id]-float(second_cost.get(id,0)),"First removal refunds exactly its own investment: "+id)
	evidence.after_unequip=game.cooldowns.duplicate(true)
	game.tick(0.05)
	evidence.after_next_tick=game.cooldowns.duplicate(true)
	check(is_equal_approx(game.cooldowns.weapons_1,0.15),"First removal must not overwrite the surviving slot cooldown")
	check_reads(game,"removed first")
	record(game,"first removal")
	game.change_state(BattleGame.State.TRAVEL)
	var cd := float(db.equip("laser",2).cd)
	check(is_equal_approx(game.cooldowns.weapons_1,cd),"Travel resets remaining slot to its full cooldown")
	game.tick(0.01)
	check(is_equal_approx(game.cooldowns.weapons_1,cd),"Travel does not count down cooldown")
	game.player.shield=100
	var max_before := game.max_shield()
	check(game.upgrade_slot("defence",1),"Upgrade shield")
	check(game.player.shield==100+game.max_shield()-max_before,"Shield upgrade preserves absolute missing capacity")
	record(game,"shield upgrade")
	game.profile.cleared=[10]
	check(game.switch_ship("Destroyer"),"Switch unlocked ship")
	check(game.weapon_entries().all(func(entry):return entry.level==1) and game.defense_entries().all(func(entry):return entry.level==1),"Switch resets all slot levels")
	record(game,"switch ship")
	var saved := {"version":1,"levels":{"laser":3,"armour":2},"resources":{"1":123,"2":7}}
	write_save(saved)
	var restored := BattleGame.new(db)
	restored.save_enabled=false
	restored.start(1,false)
	check(restored.slot_entry("weapons",0).level==3 and restored.slot_entry("defence",0).level==2,"Missing loadout migrates old levels")
	check(restored.profile.resources=={"1":123.0,"2":7.0},"Migration preserves resources")
	var contradictory := saved.duplicate(true)
	contradictory.loadout={"weapons":[{"key":"laser","level":8},{"key":"laser","level":5},{"key":"","level":1}],"defence":[{"key":"armour","level":7},{"key":"","level":1}]}
	write_save(contradictory)
	restored=BattleGame.new(db)
	restored.save_enabled=false
	restored.start(1,false)
	evidence.conflicting_levels=restored.profile.loadout.duplicate(true)
	check(restored.slot_entry("weapons",0).level==3 and restored.slot_entry("weapons",1).level==5 and restored.slot_entry("defence",0).level==2,"Legacy conflicting levels override only first same-name slot")
	var first_load := snapshot(restored)
	restored.save_enabled=true
	restored.save_progress()
	var exported = JSON.parse_string(FileAccess.get_file_as_string(BattleGame.SAVE_PATH))
	check(exported.version==1 and exported.levels.laser==3 and exported.loadout.weapons[1].level==5,"Version one exports derived first level and independent duplicate")
	restored=BattleGame.new(db)
	restored.save_enabled=false
	restored.start(1,false)
	check(restored.profile.loadout==first_load.profile.loadout and restored.player==first_load.player and restored.profile.resources==first_load.profile.resources,"Repeated load preserves equipment health and resources")
	check_reads(restored,"reloaded")
	check(not exported.has("cooldowns") and not restored.profile.has("cooldowns"),"Cooldowns remain transient across version one saves")
	var without_levels := contradictory.duplicate(true)
	without_levels.erase("levels")
	write_save(without_levels)
	var migrated := BattleGame.new(db)
	migrated.save_enabled=false
	check(migrated.slot_entry("weapons",0).level==1 and migrated.slot_entry("weapons",1).level==5,"Missing legacy levels keep historical first-slot default precedence")
	var empty_save := saved.duplicate(true)
	empty_save.loadout = migrated.empty_loadout(migrated.profile.selectedShip)
	write_save(empty_save)
	# Keep exactly the same input for both loads; the persisting constructor
	# would replace the legacy input with a compatibility export after loading.
	migrated = BattleGame.new(db,false)
	migrated.load_progress()
	migrated.reset_player()
	check(migrated.weapon_entries().all(func(entry):return entry.key=="") and migrated.defense_entries().all(func(entry):return entry.key==""),"Explicit empty old slots never auto-install from legacy levels")
	check(migrated.player.armour==0 and migrated.player.shield==0,"Empty old defence retains zero capacities")
	check_reads(migrated,"empty old save")
	var same_load := snapshot(migrated)
	migrated.load_progress()
	check(snapshot(migrated)==same_load,"Loading the same empty save again does not mutate equipment, resources or life")
	var shield_game := BattleGame.new(db,false)
	shield_game.profile.unlocked=BattleGame.EQUIPMENT.duplicate()
	shield_game.equip_slot("defence",1,"shield")
	shield_game.start(1,false)
	shield_game.group_index=db.levels[0].groups.size()
	shield_game.player.shield=0
	shield_game.since_hit=0
	var shield_row := db.equip("shield",1)
	shield_game.tick(maxf(0,float(shield_row.para3)-0.1))
	check(shield_game.player.shield==0,"Shield waits for configured delay")
	shield_game.since_hit=float(shield_row.para3)
	shield_game.tick(1)
	check(is_equal_approx(shield_game.player.shield,minf(shield_game.max_shield(),shield_game.max_shield()*float(shield_row.para2))),"Shield regenerates at configured capacity rate")
	shield_game.hit_player(1,1)
	var shield_after_hit := float(shield_game.player.shield)
	shield_game.tick(maxf(0,float(shield_row.para3)-0.1))
	check(shield_game.player.shield==shield_after_hit,"Hit restarts shield delay")
	shield_game.player.shield=shield_game.max_shield()-0.01
	shield_game.since_hit=float(shield_row.para3)
	shield_game.tick(1)
	check(shield_game.player.shield==shield_game.max_shield(),"Shield recovery caps at maximum")
	var reads := BattleGame.new(db,false)
	before=snapshot(reads)
	reads.stat("laser")
	evidence.fresh_stat_mutates=snapshot(reads)!=before
	check(snapshot(reads)==before,"Fresh stat read cannot create charge state")
	reads.profile["levels"]={"laser":4}
	before=snapshot(reads)
	reads.weapon_entries()
	evidence.legacy_read_mutates=snapshot(reads)!=before
	check(snapshot(reads)==before and reads.slot_entry("weapons",0).level==1,"Stale legacy levels cannot mutate runtime slots")
	check(not restored.profile.has("levels"),"Legacy export never installs a second runtime level source")
	check_reads(reads,"stale legacy input")
	reads.profile.hightechLevels[BattleGame.FURNACE]=1
	reads.resource_samples=[{"time":Time.get_unix_time_from_system(),"id":"1","amount":150.0,"origin":"drop"}]
	check_reads(reads,"unsettled sample and furnace description")
	check(reads.furnace_income_peak()==150 and reads.profile.furnaceIncomePeak==0,"Peak query computes without committing historical state")
	var file := FileAccess.open("res://state-ownership-baseline.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(evidence,"\t"))
	file.close()
	file = FileAccess.open("res://state-ownership-trace.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(trace,"\t"))
	file.close()
	print("State ownership baseline: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
