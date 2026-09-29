extends SceneTree
const Generator := preload("res://scripts/player_loadout_generator.gd")
const Enemy := preload("res://scripts/enemy_fleet_simulator.gd")
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: ",label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var db := ShipDatabase.new()
	var before := JSON.stringify(db.data)
	var gen := Generator.new(db)
	var options := gen.default_options()
	check(options.available_ships.size()==1,"default selects one ship")
	options.available_ships=db.ships.keys()
	options.count=2000
	var started := Time.get_ticks_usec()
	var batch := gen.generate(options)
	print("PLAYER GENERATE count=",batch.results.size()," ms=",float(Time.get_ticks_usec()-started)/1000.0," attempts=",batch.attempts)
	check(batch.results.size()==2000 and batch.status=="complete","thousands of unique loadouts")
	check(batch.coverage.size()==4,"four representative generation types")
	check(batch==gen.generate(options),"batch seed reproduces all records")
	var replayed := gen.replay(batch.results[0])
	check(replayed==batch.results[0],"single seed replay")
	var seen := {}
	var valid := true
	var archetypes := true
	for row in batch.results:
		valid=valid and gen.rules.valid_loadout(row.ship,row.equipment) and not seen.has(row.signature)
		valid=valid and row.weapons==row.equipment.weapons and row.stats.armour>0
		valid=valid and row.equipment.defence.size()==gen.rules.active_slot_count("defence",row.ship)
		valid=valid and row.equipment.defence.all(func(entry):return BattleGame.DEFENSE_KEYS.has(entry.key) and entry.level==options.module_level)
		seen[row.signature]=true
		var counts := {}
		for entry in row.weapons:counts[entry.key]=int(counts.get(entry.key,0))+1
		if row.generation_type=="mono":archetypes=archetypes and counts.size()==1
		if row.generation_type=="dual":archetypes=archetypes and counts.size()==2
		if row.generation_type=="balanced":archetypes=archetypes and counts.size()>=3 and counts.values().max()-counts.values().min()<=1
		for score in row.feature_scores.values():valid=valid and is_finite(score) and score>=0 and score<=1
	check(valid,"all rows original-rule legal, healthy, unique and bounded")
	check(archetypes,"labels correspond to actual archetype mixtures")
	var selected := options.duplicate(true)
	selected.count=40
	selected.available_ships=["Frigate","Destroyer"]
	var restricted := gen.generate(selected)
	check(restricted.results.size()==40 and restricted.results.all(func(row):return selected.available_ships.has(row.ship)),"only selected ships generated")
	check(gen.replay(restricted.results[0])==restricted.results[0],"whitelist saved for replay")
	selected.available_ships.reverse()
	check(gen.generate(selected).results.map(func(row):return row.signature)==restricted.results.map(func(row):return row.signature),"selection order does not alter samples")
	selected.available_ships=[]
	check(gen.generate(selected).status=="invalid_input","empty selection rejected")
	selected.available_ships=["missing_ship"]
	check(gen.generate(selected).status=="invalid_input","unknown ship rejected")
	selected.available_ships=["Destroyer"]
	selected.cleared_through=0
	check(gen.generate(selected).status=="no_legal_loadouts","selection cannot bypass unlocks")
	var low := options.duplicate(true)
	low.cleared_through=0
	low.count=100
	var limited := gen.generate(low)
	check(limited.results.size()==1 and limited.status=="attempt_limit","starter universe returns partial without fake permutations")
	check(limited.unavailable_types==["dual","balanced"],"ineligible archetypes explicitly reported")
	check(limited.results[0].ship==gen.rules.first_ship() and limited.results[0].weapons.all(func(e):return e.key=="laser"),"locked ships and weapons excluded")
	var first: Dictionary=limited.results[0]
	check(first.stats.armour==2000 and first.stats.shield==0 and first.stats.burst==300 and first.stats.sustained==600,"stats reuse current starter attributes")
	low.module_level=5
	var grown: Dictionary = gen.generate(low).results[0]
	check(grown.stats.armour==2*db.equip("armour",5).para1 and grown.stats.burst==3*db.equip("laser",5).dmg,"level growth follows database rounding")
	check(grown.signature!=first.signature,"module levels enter signature")
	check(not first.tags.has("aoe") and not first.tags.has("long_range") and not first.tags.has("short_range"),"no invented range or AOE tags")
	check(Generator.matches_filter(first,"laser","single_target") and not Generator.matches_filter(first,"missile",""),"weapon and tag filters")
	low.count=0
	check(gen.generate(low).status=="invalid_input","invalid count rejected")
	low.count=1
	low.module_level=gen.policy.max_module_level+1
	check(gen.generate(low).status=="invalid_input","analysis level budget enforced")
	var enemy_gen := Enemy.new(db)
	var enemy_options := {"count":4,"min_count":2,"max_count":4,"min_strength":0,"max_strength":1000,"seed":12345,"available_enemies":db.enemies.keys()}
	var enemies: Array = enemy_gen.generate(enemy_options).results
	var pairs := gen.pair_by_index(enemies,batch.results,91)
	check(pairs.size()==4 and pairs[0].enemy_fleet==enemies[0] and pairs[0].player_loadout==batch.results[0],"linear one-to-one pairing without Cartesian product")
	var source_before := JSON.stringify(pairs[0])
	var prepared := gen.create_battle(pairs[0])
	check(prepared.has("game"),"pair can enter existing battle logic")
	if prepared.has("game"):
		var game: BattleGame=prepared.game
		check(not game.save_enabled and game.state==BattleGame.State.COMBAT and game.enemies.size()==enemies[0].count,"isolated battle starts through normal spawn path")
		check(game.profile.loadout==batch.results[0].equipment and game.stat("armour")==batch.results[0].stats.armour and game.max_shield()==batch.results[0].stats.shield,"loaded state agrees with saved test stats")
		check(game.profile.loadout.defence==batch.results[0].equipment.defence and not game.profile.loadout.defence.is_empty(),"defence slots loaded intact into battle")
		var valid_health := true
		for enemy in game.enemies:valid_health=valid_health and enemy.hp==db.enemies[str(int(enemy.id))].health
		check(valid_health and game.ratio("atkRatio")==1,"enemy baseline scaling preserved")
		game.tick(1.0/60.0)
		check(JSON.stringify(pairs[0])==source_before,"combat does not mutate paired snapshots")
	var parsed: Dictionary=JSON.parse_string(JSON.stringify(pairs[0]))
	check(gen.create_battle(parsed).has("game"),"copied JSON pair can be loaded")
	var changed: Dictionary=pairs[0].duplicate(true)
	changed.player_loadout.equipment.weapons[0].key="invalid"
	check(gen.create_battle(changed).get("error")=="invalid_player_loadout","modified equipment rejected at battle boundary")
	changed=pairs[0].duplicate(true)
	changed.enemy_fleet.slots[0]=99999
	check(gen.create_battle(changed).get("error")=="invalid_enemy_fleet","modified enemy fleet rejected")
	check(JSON.stringify(db.data)==before,"formal database untouched")
	check(gen.rules.enemies.is_empty() and gen.rules.projectiles.is_empty(),"generation never starts encounter or projectiles")
	print("PLAYER LOADOUT checks=",checks," failures=",failures)
	quit(1 if failures else 0)
