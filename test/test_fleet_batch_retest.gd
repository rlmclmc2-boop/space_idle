extends SceneTree
const EnemyGenerator := preload("res://scripts/enemy_fleet_simulator.gd")
const PlayerGenerator := preload("res://scripts/player_loadout_generator.gd")
const Runner := preload("res://scripts/fleet_battle_runner.gd")
const Analyzer := preload("res://scripts/fleet_result_analyzer.gd")
const Retest := preload("res://scripts/fleet_batch_retest.gd")
var failures := 0
func check(ok: bool,label: String) -> void:
	if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var db := ShipDatabase.new()
	var enemies: Array=EnemyGenerator.new(db).generate({"count":2,"min_count":1,"max_count":2,"available_enemies":[db.enemies.keys()[0]],"seed":76,"min_strength":0,"max_strength":1000000}).results
	var generator := PlayerGenerator.new(db)
	var options: Dictionary=generator.default_options()
	options.count=2
	options.module_level=10
	var players: Array=generator.generate(options).results
	var original := Runner.new(db)
	check(original.start(enemies,players,{"max_total":4,"max_per_pair":1,"runs":1,"seed":72})=="","baseline starts")
	while original.busy():original.process(10000)
	var analyzer := Analyzer.new()
	var first: Dictionary=analyzer.analyze(original.directory)
	check(not first.has("error") and first.tests>0,"baseline analysis")
	var inputs: Dictionary=Retest.read_json(original.directory.path_join("inputs.json"))
	var plan: Dictionary=Retest.plan(first,inputs,2,4,3,512)
	check(plan.battles>0 and plan.battles<=4 and not plan.pairs.is_empty(),"focused bounded plan")
	var additional := Runner.new(db)
	check(additional.start(enemies,players,{"max_total":plan.battles,"max_per_pair":2,"runs":1,"seed":73,"explicit_pairs":plan.pairs})=="","focused retest starts")
	while additional.busy():additional.process(10000)
	check(additional.completed==plan.battles and additional.sampling.pairs.size()==plan.pairs.size(),"only selected pairs run")
	var combined: Dictionary=Retest.combine(original.directory,additional.directory)
	check(not combined.has("error"),"batches combine")
	if not combined.has("error"):
		var updated: Dictionary=analyzer.analyze(combined.directory)
		check(not updated.has("error") and updated.tests==first.tests+additional.aggregate.battle_count,"merged statistics pass analyzer")
		check(Retest.read_json(original.directory.path_join("summary.json")).completed_count==original.completed,"source batch preserved")
		check(updated.attempts==original.completed+additional.completed,"all attempts retained")
		check(FileAccess.file_exists(combined.directory.path_join("battles.jsonl")),"trials retained")
	var pooled := Retest.merge_pair({"battle_count":2,"attempted_count":2,"wins":1,"avg_battle_time":10.0,"avg_player_hp_ratio":0.5,"avg_enemy_hp_ratio":0.5,"time_m2":2.0},{"battle_count":2,"attempted_count":2,"wins":2,"avg_battle_time":20.0,"avg_player_hp_ratio":0.8,"avg_enemy_hp_ratio":0.2,"time_m2":2.0})
	check(pooled.battle_count==4 and is_equal_approx(pooled.avg_battle_time,15.0) and is_equal_approx(pooled.time_m2,104.0),"weighted mean and pooled time variance")
	var legacy: Array=enemies.duplicate(true)
	legacy[0].config_fingerprint="previous_formation_policy"
	var validator := EnemyGenerator.new(db)
	check(Runner.valid_enemy_snapshot(legacy[0],validator),"old formation policy can reuse unchanged combat slots")
	var tampered: Dictionary=legacy[0].duplicate(true)
	tampered.slots[0]=999999
	check(not Runner.valid_enemy_snapshot(tampered,validator),"saved group rejects unknown enemy")
	var compatible := Runner.new(db)
	check(compatible.start(legacy,players,{"max_total":1,"max_per_pair":1,"runs":1,"explicit_pairs":[{"enemy_index":0,"player_index":0,"runs":1}],"retest_saved_inputs":true,"data_sha256":JSON.stringify(db.data).sha256_text()})=="","legacy batch retest starts")
	while compatible.busy():compatible.process(10000)
	check(compatible.aggregate.battle_count==1 and compatible.aggregate.errors==0,"legacy formation snapshot executes original combat")
	print("FLEET BATCH RETEST failures=",failures)
	quit(1 if failures else 0)
