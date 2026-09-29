extends SceneTree
const Sampling := preload("res://scripts/fleet_battle_sampling.gd")
const Runner := preload("res://scripts/fleet_battle_runner.gd")
var failed := 0
func check(ok: bool,label: String) -> void:
	if not ok:failed+=1;printerr("FAIL: ",label)
func _initialize() -> void:call_deferred("run")
func record(scheduler: RefCounted,index: int,win: bool,time := 2.0,hp := 0.9) -> void:
	var pair: Dictionary=scheduler.pairs[index]
	if pair.summary.is_empty():pair.summary=Runner.empty_aggregate()
	var row := {"status":"win" if win else "loss","win":win,"battle_time":time,"player_hp_ratio":hp if win else 0.0,"enemy_hp_ratio":0.0 if win else hp}
	Runner.update_aggregate(pair.summary,row)
	scheduler.observe(pair,row)
func run() -> void:
	var policy: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/enemy_fleet_analysis.json")).batch
	var config: Dictionary=policy.defaults.duplicate(true)
	config.max_total=30
	config.max_per_pair=8
	var enemies: Array=[]
	var players: Array=[]
	for i in range(5000):
		enemies.append({"signature":str(i),"primary_tags":["enemy"+str(i%5)],"feature_scores":{"armor":0.5}})
		players.append({"signature":str(i),"tags":["player"+str(i%4)],"feature_scores":{"survival":0.5},"stats":{"armour":1000},"weapons":[{"key":"laser"}],"generation_type":"mono"})
	var started := Time.get_ticks_usec()
	var sample := Sampling.new(policy.sampling,config)
	sample.build(enemies,players)
	print("SAMPLING 25M theoretical ms=",(Time.get_ticks_usec()-started)/1000.0," report=",sample.report())
	check(sample.theoretical==25000000 and sample.pairs.size()<=30,"bounded pair sampling, no Cartesian materialization")
	check(sample.representatives.enemy.size()==5 and sample.representatives.player.size()==4 and sample.similar_skipped==9991,"same-tag duplicates suppressed with all strata represented")
	var replay := Sampling.new(policy.sampling,config)
	replay.build(enemies,players)
	check(sample.pairs==replay.pairs,"deterministic representative and pair selection")
	for repeat_index in range(3):record(sample,0,true)
	check(sample.pairs[0].stable and sample.choose()!=0,"consistent dominance stops early")
	for win in [true,false,true]:record(sample,1,win,2,0.3)
	check(sample.reasons(sample.pairs[1]).has("boundary") and sample.reasons(sample.pairs[1]).has("outcome_variance"),"boundary and variance trigger")
	for time in [1.0,10.0,2.0]:record(sample,2,true,time,0.2)
	check(sample.reasons(sample.pairs[2]).has("time_anomaly"),"battle-time variability triggers")
	check(sample.choose() not in [0,1,2],"uncovered tags before boundary retests")
	var pair: Dictionary=sample.pairs[3]
	pair.enemy_tags=sample.pairs[1].enemy_tags
	pair.player_tags=["different"]
	for repeat_index in range(3):record(sample,3,false,2,0.2)
	check(sample.reasons(sample.pairs[3]).has("tag_difference"),"opposing tag group difference triggers")
	config.focus_pairs=[{"enemy_index":4999,"player_index":4999}]
	var focus := Sampling.new(policy.sampling,config)
	focus.build(enemies,players)
	check(focus.choose()==0 and focus.pairs[0].enemy_index==4999,"manual focus survives similarity suppression and ranks first")
	for repeat_index in range(8):record(focus,0,true)
	check(not focus.pairs[0].stable and focus.choose()!=0 and focus.pairs[0].stop_reason=="pair_budget","manual focus obeys pair budget")
	# Exercise actual runner budget, reproducibility and persisted schedule metadata.
	var db := ShipDatabase.new()
	var es: Array=preload("res://scripts/enemy_fleet_simulator.gd").new(db).generate({"count":2,"min_count":1,"max_count":2,"available_enemies":[db.enemies.keys()[0]],"seed":12,"min_strength":0,"max_strength":1000000}).results
	var gen := preload("res://scripts/player_loadout_generator.gd").new(db)
	var options: Dictionary=gen.default_options()
	options.count=2
	options.module_level=10
	var ps: Array=gen.generate(options).results
	var runner := Runner.new(db)
	var request := {"max_total":5,"max_per_pair":4,"runs":3,"seed":33,"focus_pairs":[{"enemy_index":1,"player_index":1}]}
	check(runner.start(es,ps,request)=="","budgeted runner starts")
	while runner.busy():runner.process(10000)
	check(runner.status=="budget_reached" and runner.completed==5,"total budget exactly enforced")
	check(runner.results[0].enemy_index==1 and runner.results[0].player_index==1 and runner.results[0].test_reasons.has("manual"),"manual priority in real battle")
	check(runner.sampling.pairs.all(func(p):return int(p.summary.get("attempted_count",0))<=4),"all pair budgets respected")
	var first: Array=runner.results.duplicate(true)
	runner.start(es,ps,request)
	while runner.busy():runner.process(10000)
	check(first==runner.results,"adaptive schedule and battles replay")
	var report: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(runner.directory.path_join("summary.json")))
	check(report.remaining_budget==0 and report.sampling.theoretical_pairs==4,"sampling and budget persisted")
	print("FLEET SAMPLING failures=",failed)
	quit(1 if failed else 0)
