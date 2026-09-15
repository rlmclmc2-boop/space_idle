extends SceneTree

var checks := 0
var failures := 0
var evidence := {}

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",label)

func snapshot(game: BattleGame) -> Dictionary:
	return {"profile":game.profile.duplicate(true),"cooldowns":game.cooldowns.duplicate(true),"player":game.player.duplicate(true)}

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
	game.rng.seed=1701
	game.profile.unlocked=BattleGame.EQUIPMENT.duplicate()
	check(game.equip_slot("weapons",1,"laser"),"Install duplicate weapon")
	check(game.equip_slot("defence",1,"shield"),"Install shield")
	game.profile.resources={"1":1000000.0,"2":1000000.0}
	var original_resources: Dictionary=game.profile.resources.duplicate(true)
	check(game.upgrade_slot("weapons",0,2),"Upgrade first duplicate to level three")
	check(game.upgrade_slot("weapons",1),"Upgrade second duplicate to level two")
	check(game.slot_entry("weapons",0).level==3 and game.slot_entry("weapons",1).level==2,"Duplicate levels independent")
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
	game.change_state(BattleGame.State.TRAVEL)
	var cd := float(db.equip("laser",2).cd)
	check(is_equal_approx(game.cooldowns.weapons_1,cd),"Travel resets remaining slot to its full cooldown")
	game.tick(0.01)
	check(is_equal_approx(game.cooldowns.weapons_1,cd),"Travel does not count down cooldown")
	game.player.shield=100
	var max_before := game.max_shield()
	check(game.upgrade_slot("defence",1),"Upgrade shield")
	check(game.player.shield==100+game.max_shield()-max_before,"Shield upgrade preserves absolute missing capacity")
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
	restored=BattleGame.new(db)
	restored.save_enabled=false
	restored.start(1,false)
	check(restored.profile.loadout==first_load.profile.loadout and restored.player==first_load.player and restored.profile.resources==first_load.profile.resources,"Repeated load preserves equipment health and resources")
	var reads := BattleGame.new(db,false)
	before=snapshot(reads)
	reads.stat("laser")
	evidence.fresh_stat_mutates=snapshot(reads)!=before
	reads.profile.levels.laser=4
	before=snapshot(reads)
	reads.weapon_entries()
	evidence.legacy_read_mutates=snapshot(reads)!=before
	# Record current read impurity; a later migration must replace this with a
	# strict pre/post equality gate, never whitelist profile writes as caching.
	var file := FileAccess.open("res://state-ownership-baseline.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(evidence,"\t"))
	file.close()
	print("State ownership baseline: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
