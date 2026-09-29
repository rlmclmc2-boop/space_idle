extends SceneTree
const Runner := preload("res://scripts/fleet_battle_runner.gd")
const Enemy := preload("res://scripts/enemy_fleet_simulator.gd")
const Player := preload("res://scripts/player_loadout_generator.gd")
var failures := 0
func check(ok: bool,label: String) -> void:
	if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize() -> void:call_deferred("run")
func finish(runner: RefCounted) -> void:
	var deadline := Time.get_ticks_msec()+20000
	while runner.busy() and Time.get_ticks_msec()<deadline:runner.process(10000)
	check(not runner.busy(),"bounded execution")
func run() -> void:
	var db := ShipDatabase.new()
	var original := JSON.stringify(db.data)
	var enemies: Array=Enemy.new(db).generate({"count":2,"min_count":1,"max_count":2,"available_enemies":[db.enemies.keys()[0]],"seed":12,"min_strength":0,"max_strength":1000000}).results
	var gen := Player.new(db)
	var options := gen.default_options()
	options.count=2
	options.module_level=10
	var players: Array=gen.generate(options).results
	check(enemies.size()==2 and players.size()==2,"fixtures")
	var guard_snapshots: Array=[]
	for skip_empty in [false,true]:
		var guard_db := ShipDatabase.new()
		var guard_game = Player.start_validated_battle(guard_db,enemies[0],players[0],22,"fast")
		guard_game.skip_empty_batch_research=skip_empty
		for _step in range(1800):
			if guard_game.state!=BattleGame.State.COMBAT:break
			guard_game.tick(1.0/60.0)
		guard_snapshots.append({"state":guard_game.state,"armour":guard_game.player.armour,"shield":guard_game.player.shield,"rng":guard_game.rng.state,"time":guard_game.simulated_time})
	check(guard_snapshots[0]==guard_snapshots[1],"empty batch research skip preserves combat and RNG")
	var baseline_game=Player.start_validated_battle(ShipDatabase.new(),enemies[0],players[0],99,"fast",{},1.0)
	var double_game=Player.start_validated_battle(ShipDatabase.new(),enemies[0],players[0],99,"fast",{},2.0)
	var triple_game=Player.start_validated_battle(ShipDatabase.new(),enemies[0],players[0],99,"fast",{},3.0)
	check(is_equal_approx(double_game.stat("armour"),2*baseline_game.stat("armour")) and is_equal_approx(triple_game.stat("shield"),3*baseline_game.stat("shield")),"private growth scales player defence")
	check(is_equal_approx(double_game.jewel_attack(0).damage,2*baseline_game.jewel_attack(0).damage) and is_equal_approx(triple_game.jewel_attack(0).damage,3*baseline_game.jewel_attack(0).damage),"private growth scales original weapon attack")
	check(JSON.stringify(db.data)==original,"growth does not alter shared config")
	var runner := Runner.new(db)
	# Keep original small-fixture combat assertions fixed-count via equal budgets.
	runner.policy.defaults.max_per_pair=2
	check(runner.start(enemies,players,{"runs":2,"seed":22,"max_seconds":30})=="","start Cartesian batch")
	finish(runner)
	print("BATCH ",runner.status," ",runner.aggregate)
	check(runner.completed==8 and runner.aggregate.battle_count==8,"all pairs and repetitions decisive")
	for row in runner.results:
		var hp := 0.0
		for id in enemies[int(row.enemy_index)].slots:
			if id!=null:hp+=float(db.enemies[str(int(id))].health)
		var dealt := 0.0
		for value in row.damage_by_weapon.values():dealt+=float(value)
		check(is_equal_approx(dealt,hp*(1-row.enemy_hp_ratio)),"weapon damage reconciles actual enemy HP removed")
	var first: Array=runner.results.duplicate(true)
	runner.start(enemies,players,{"runs":2,"seed":22,"max_seconds":30,"mode":"exact"})
	finish(runner)
	var exact: Array=runner.results.duplicate(true)
	for row in exact:row.simulation_mode="fast"
	check(first==exact,"FAST agrees with original projectile path on fixtures")
	check(runner.start(enemies,players,{"runs":2,"seed":22,"max_seconds":30})=="","repeat start")
	finish(runner)
	check(first==runner.results,"same seeds reproduce every outcome")
	var json_enemies: Array=JSON.parse_string(JSON.stringify(enemies))
	var json_players: Array=JSON.parse_string(JSON.stringify(players))
	runner.start(json_enemies,json_players,{"runs":2,"seed":22,"max_seconds":30})
	finish(runner)
	check(first==runner.results,"persisted JSON inputs reproduce battles")
	check(FileAccess.file_exists(runner.directory.path_join("summary.json")),"results persisted")
	var lines := FileAccess.get_file_as_string(runner.directory.path_join("battles.jsonl")).strip_edges().split("\n")
	check(lines.size()==8,"all trial records persisted")
	check(FileAccess.get_file_as_string(runner.directory.path_join("pairs.jsonl")).strip_edges().split("\n").size()==4,"per-pair aggregates")
	var malformed: Array=enemies.duplicate(true)
	runner.policy.defaults.max_per_pair=1
	malformed[0].slots=[]
	runner.start(malformed,players,{"runs":1,"seed":22,"max_seconds":30})
	finish(runner)
	check(runner.completed==4 and runner.aggregate.errors==2 and runner.aggregate.battle_count==2,"bad input records errors and continues")
	runner.start(enemies,players,{"runs":1,"max_seconds":0.01})
	finish(runner)
	check(runner.aggregate.timeouts==4 and runner.aggregate.battle_count==0 and runner.aggregate.win_rate==null,"timeouts excluded from win rate")
	runner.start(enemies,players,{"runs":3,"max_per_pair":100,"max_seconds":30})
	while runner.status=="validating":runner.validate_next()
	runner.begin_battle()
	runner.stop()
	check(runner.status=="stopped" and runner.completed==1 and runner.aggregate.stopped==1 and runner.game==null,"stop releases fight and saves partial result")
	check(JSON.stringify(db.data)==original,"source database untouched")
	var strong: Array=Enemy.new(db).generate({"count":1,"min_count":10,"max_count":10,"available_enemies":[db.enemies.keys()[-1]],"seed":12,"min_strength":0,"max_strength":1000000}).results
	options.module_level=1
	options.cleared_through=0
	options.count=1
	var weak: Array=gen.generate(options).results
	runner.start(strong,weak,{"runs":1,"max_seconds":60})
	finish(runner)
	check(runner.results[0].status=="loss" and runner.results[0].player_deaths==1 and runner.results[0].enemy_hp_ratio>0,"defeat retains surviving enemy HP")
	options=gen.default_options()
	options.count=100
	options.module_level=10
	var varied: Array=gen.generate(options).results
	for weapon in ["laser","cannon","missile","longLaser"]:
		var candidates: Array=varied.filter(func(row):return row.weapons.all(func(entry):return entry.key==weapon))
		check(not candidates.is_empty(),"weapon fixture "+weapon)
		if candidates.is_empty():continue
		runner.start(enemies,[candidates[0]],{"runs":1,"seed":123,"max_seconds":30})
		finish(runner)
		var fast: Array=runner.results.duplicate(true)
		runner.start(enemies,[candidates[0]],{"runs":1,"seed":123,"max_seconds":30,"mode":"exact"})
		finish(runner)
		var baseline: Array=runner.results.duplicate(true)
		for row in baseline:row.simulation_mode="fast"
		check(fast==baseline and fast[0].damage_by_weapon[weapon]>0,"weapon tracking and FAST fallback parity "+weapon)
	# Opt-in stress: same pair in equal blocks exposes accumulation rather than changing workload.
	if "--stress" in OS.get_cmdline_user_args():
		var timings: Array=[]
		var memory: Array=[]
		runner.start([enemies[0]],[players[0]],{"runs":1000,"max_per_pair":1000,"max_seconds":30})
		var started := Time.get_ticks_usec()
		var mark := started
		while runner.busy():
			runner.process(1000)
			if runner.completed>=(timings.size()+1)*200:
				timings.append((Time.get_ticks_usec()-mark)/1000.0)
				memory.append(OS.get_static_memory_usage())
				mark=Time.get_ticks_usec()
		print("STRESS 1000 ms=",(Time.get_ticks_usec()-started)/1000.0," blocks=",timings," memory=",memory)
		check(runner.completed==1000 and runner.aggregate.battle_count==1000 and runner.results.size()==200,"thousand decisive battles with bounded retention")
		check(memory[-1]-memory[1]<2000000,"no growing per-battle retained memory")
	runner.reset()
	check(runner.results.is_empty() and runner.status=="idle","reset")
	print("FLEET BATCH failures=",failures)
	quit(1 if failures else 0)
