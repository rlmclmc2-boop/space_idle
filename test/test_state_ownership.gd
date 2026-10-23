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
	trace.append({"step":label,"loadout":game.equipment.save_data().loadout,"resources":game.economy.resources(),"player":game.player.duplicate(true),"cooldowns":slots,"state":game.state,"events":events.duplicate(true)})

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",label)

func snapshot(game: BattleGame) -> Dictionary:
	return {"profile":game.profile.duplicate(true),"equipment":game.equipment.save_data(),"economy":game.economy.save_data(),"research":game.research.save_data(),"reactor":game.reactor.save_data(),"crew":game.crew.save_data(),"planets":game.planets.save_data(),"galaxy":game.galaxy.save_data(),"hyperspace":game.hyperspace.save_data(),"enhancement":game.enhancement_growth.save_data(),"cooldowns":game.cooldowns.duplicate(true),"player":game.player.duplicate(true)}

func check_reads(game: BattleGame, label: String) -> void:
	var readers := {"weapons":game.weapon_entries,"defence":game.defense_entries,"shield":game.max_shield,"movement":game.ship_movement,"name":game.ship_name,"limit":game.equipment_limit,"tech slots":game.hightech_slots,"income":game.resource_minute_total.bind("1")}
	readers["research snapshot"]=game.tech_tree_snapshot
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
	readers["reactor/energy"]=game.reactor_energy
	readers["reactor/cost"]=game.reactor_upgrade_cost
	readers["reactor/max"]=game.reactor_max_upgrades
	readers["reactor/allocated"]=game.reactor_allocated
	for key in game.reactor_modules():readers["reactor/multiplier/"+key]=game.reactor_multiplier.bind(key)
	for name in readers:
		var before := snapshot(game)
		var weapons: Array = game.equipment.entries("weapons")
		readers[name].call()
		check(snapshot(game)==before,"Read purity: "+label+" / "+name)
		check(is_same(weapons,game.equipment.entries("weapons")),"Read preserves slot array identity: "+label+" / "+name)

func _initialize() -> void:
	var db := ShipDatabase.new()
	db.config.offlineMax=0
	db.config.equipmentSwitchCooldownSeconds=0
	# Pin capacities for ownership checks, independent of production opening hull.
	for ship in db.ships.values():
		ship.weaponSlots=5
		ship.defenseSlots=3
	db.config.autoGenRes=""
	db.ships[db.ships.keys()[0]].sameEquipmentLimit=2
	var game := BattleGame.new(db,false)
	check_reads(game,"fresh")
	game.event.connect(func(kind,payload):events.append({"kind":kind,"payload":payload.duplicate(true)}))
	game.rng.seed=1701
	game.profile.unlocked=BattleGame.EQUIPMENT.duplicate()
	check(game.equip_slot("weapons",1,"laser"),"Install duplicate weapon")
	check(game.equip_slot("defence",1,"shield"),"Install shield")
	game.economy.credit_many({"1":1000000.0,"2":1000000.0})
	var original_resources: Dictionary=game.economy.resources()
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
	var resources_before_removal: Dictionary = game.economy.resources()
	check(game.unequip_slot("weapons",0),"Remove first duplicate")
	check(game.slot_entry("weapons",0).key=="" and game.slot_entry("weapons",1).level==2,"First removal preserves empty slot and remaining level")
	for id in original_resources:
		check(game.economy.balance(id)==resources_before_removal[id],"Removing equipment does not refund module investment: "+id)
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
	var max_before: Variant = game.max_shield()
	check(game.upgrade_slot("defence",1),"Upgrade shield")
	check(game.player.shield==100+game.max_shield()-max_before,"Shield upgrade preserves absolute missing capacity")
	record(game,"shield upgrade")
	game.profile.cleared=[10]
	check(game.switch_ship("Destroyer"),"Switch unlocked ship")
	check(game.slot_entry("weapons",1).level==2 and game.slot_entry("defence",1).level==2,"Switch preserves module levels")
	record(game,"switch ship")
	check(game.equip_slot("weapons",0,"laser"),"Reinstall first duplicate before snapshot")
	check(game.slot_entry("weapons",0).level==3 and game.slot_entry("weapons",1).level==2,"Snapshot fixture has same-name slots at distinct levels")
	# Current-format snapshots exercise owner precedence and repeatable installation.
	# No new historical-save continuity contract is introduced by this fixture.
	var saved := game.portable_save_data()
	check(saved.loadout.weapons[0].key=="laser" and saved.loadout.weapons[1].key=="laser" and saved.loadout.weapons[0].level==3 and saved.loadout.weapons[1].level==2,"Export preserves both same-name slot investments")
	saved.levels={"laser":999,"armour":999}
	var restored := BattleGame.new(db,false)
	restored.load_progress_data(saved)
	check(restored.hyperspace.last_error.is_empty(),"Current snapshot accepted")
	check(restored.equipment.save_data()==game.equipment.save_data(),"Derived legacy map cannot override owned modules")
	check(restored.economy.resources()==game.economy.resources(),"Load preserves owned balances")
	var first_load := snapshot(restored)
	restored.load_progress_data(saved)
	check(snapshot(restored)==first_load,"Repeated current load preserves domain state and health")
	check(restored.slot_entry("weapons",0).key=="laser" and restored.slot_entry("weapons",1).key=="laser" and restored.slot_entry("weapons",0).level==3 and restored.slot_entry("weapons",1).level==2,"Repeated load preserves different levels of same-name slots")
	var exported := restored.portable_save_data()
	check(exported.version==BattleGame.SAVE_VERSION and exported.levels.laser==3 and exported.loadout.weapons[0].level==3 and exported.loadout.weapons[1].level==2,"Export derives first matching level and preserves independent slots")
	check_reads(restored,"reloaded")
	check(not exported.has("cooldowns") and not restored.profile.has("cooldowns"),"Cooldowns remain transient")
	var empty_save := saved.duplicate(true)
	empty_save.loadout=restored.empty_loadout(restored.equipment.selected_ship())
	empty_save.equipmentSwitchUntil={}
	var migrated := BattleGame.new(db,false)
	migrated.load_progress_data(empty_save)
	migrated.reset_player()
	check(migrated.hyperspace.last_error.is_empty(),"Current empty snapshot accepted")
	check(migrated.weapon_entries().all(func(entry):return entry.key=="") and migrated.defense_entries().all(func(entry):return entry.key==""),"Explicit empty slots never install derived legacy levels")
	check(migrated.player.armour==0 and migrated.player.shield==0,"Empty defence retains zero capacities")
	check_reads(migrated,"empty current snapshot")
	var same_load := snapshot(migrated)
	migrated.load_progress_data(empty_save)
	migrated.reset_player()
	check(snapshot(migrated)==same_load,"Repeated empty load preserves equipment, resources and life")
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
	for index in shield_game.jewel_defence_times:shield_game.jewel_defence_times[index]=float(shield_row.para3)
	shield_game.tick(1)
	check(is_equal_approx(shield_game.player.shield,minf(shield_game.max_shield(),shield_game.max_shield()*float(shield_row.para2))),"Shield regenerates at configured capacity rate")
	shield_game.hit_player(1,1)
	var shield_after_hit := float(shield_game.player.shield)
	shield_game.tick(maxf(0,float(shield_row.para3)-0.1))
	check(shield_game.player.shield==shield_after_hit,"Hit restarts shield delay")
	shield_game.player.shield=shield_game.max_shield()-0.01
	shield_game.since_hit=float(shield_row.para3)
	for index in shield_game.jewel_defence_times:shield_game.jewel_defence_times[index]=float(shield_row.para3)
	shield_game.tick(1)
	check(shield_game.player.shield==shield_game.max_shield(),"Shield recovery caps at maximum")
	var reads := BattleGame.new(db,false)
	before=snapshot(reads)
	reads.stat("laser")
	evidence.fresh_stat_mutates=snapshot(reads)!=before
	check(snapshot(reads)==before,"Fresh stat read cannot create reactor state")
	reads.profile["levels"]={"laser":4}
	before=snapshot(reads)
	reads.weapon_entries()
	evidence.legacy_read_mutates=snapshot(reads)!=before
	check(snapshot(reads)==before and reads.slot_entry("weapons",0).level==1,"Stale legacy levels cannot mutate runtime slots")
	check(not restored.profile.has("levels"),"Legacy export never installs a second runtime level source")
	check_reads(reads,"stale legacy input")
	reads.resource_samples=[{"time":reads.economy_time(),"production_time":reads.production_time(),"id":"1","amount":150.0,"origin":"drop"}]
	check_reads(reads,"unsettled income sample and research snapshot")
	before=snapshot(reads)
	var proposal: Dictionary=reads.research.income_peak_proposal(reads,"1")
	check(not proposal.is_empty() and snapshot(reads)==before,"Income peak proposal reads current history without committing research")
	var file := FileAccess.open("res://state-ownership-baseline.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(evidence,"\t"))
	file.close()
	file = FileAccess.open("res://state-ownership-trace.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(trace,"\t"))
	file.close()
	print("State ownership baseline: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
