extends SceneTree
const Game = preload("res://scripts/balance_game.gd")
const Database = preload("res://scripts/balance_database.gd")
const Policy = preload("res://scripts/balance_autoplayer.gd")
const Metrics = preload("res://scripts/balance_metrics.gd")
const STEP = 1.0 / 60.0
var game
var policy = Policy.new()
var metrics = Metrics.new()
var output: String
var trace: FileAccess
var clears := {}
var action_sessions := 0
var actions := 0
var last_action := 0.0
var action_gaps: Array = []
var next_visit := 0.0
var options := {}
var wave_start := 0.0
var wave_key := ""
var wave_rows: Array = []
var last_heartbeat := 0
func _initialize() -> void: call_deferred("run")
func write_json(name: String, value) -> void:
	var f := FileAccess.open(output+"/"+name,FileAccess.WRITE)
	f.store_string(JSON.stringify(value,"\t")); f.close()
func snapshot(label: String) -> void:
	write_json("save_"+label+".json", {"x1_seconds":game.simulated_time,"save":game.portable_save_data(),"rng_state":str(game.rng.state),"state":int(game.state),"metrics_income":metrics.income,"metrics_spending":metrics.spending,"data_sha256":FileAccess.get_sha256("res://data/game_data.json")})
func observe(kind: String, payload: Dictionary) -> void:
	if kind in ["upgrade","module_changed","ship_changed","scientist_generated","reactor_changed","enhancement_changed","planet_changed","planet_reforged"]:
		actions += 1
		trace.store_line(JSON.stringify({"x1_seconds":game.simulated_time,"kind":kind,"stage":game.stage,"payload":payload})); trace.flush()
	if kind == "state" and game.state == BattleGame.State.LEVEL_CLEAR:
		if not clears.has(str(game.stage)):
			clears[str(game.stage)] = game.simulated_time
			print("CLEAR stage=",game.stage," x1_seconds=",game.simulated_time)
			if game.stage in [5,10,20,30,32,34,35,40,45,50,55,60]:snapshot(str(game.stage))
func visit() -> void:
	var before: int = actions
	var pending: Array = game.pending_unlocks.duplicate()
	# Manual collection only while actually visiting; auto losses remain between visits.
	for drop in game.drops.duplicate():game.collect(drop,true)
	policy.act(game,game.simulated_time)
	if not pending.is_empty():
		actions += pending.size()
		trace.store_line(JSON.stringify({"x1_seconds":game.simulated_time,"kind":"acknowledge_unlocks","count":pending.size(),"ids":pending}))
	if actions > before:
		action_sessions += 1
		action_gaps.append(game.simulated_time-last_action)
		last_action = game.simulated_time
	trace.store_line(JSON.stringify({"x1_seconds":game.simulated_time,"kind":"visit","actions":actions-before,"stage":game.stage,"resources":game.profile.resources,"loadout":game.profile.loadout}));trace.flush()
func run() -> void:
	options = {"duration":10800,"stop_clear":10,"seed":20261002,"visit_seconds":120,"teaching_seconds":10,"strategy":"BALANCED"}
	var raw_options := OS.get_environment("PROGRESSION_OPTIONS")
	var custom = JSON.parse_string(raw_options) if not raw_options.is_empty() else {}
	if custom is Dictionary:options.merge(custom,true)
	output = ProjectSettings.globalize_path("res://results/"+str(options.get("label","baseline")))
	DirAccess.make_dir_recursive_absolute(output)
	trace = FileAccess.open(output+"/actions.jsonl",FileAccess.WRITE)
	game = Game.new(Database.new());game.rng.seed=int(options.seed)
	game.metrics=metrics;metrics.initialize(game)
	game.event.connect(observe)
	policy.configure(str(options.strategy),int(options.seed))
	write_json("run.json",{"options":options,"engine":Engine.get_version_info(),"step_seconds":STEP,"mode":"exact","initial_state":"fresh","qa_manifest":JSON.parse_string(FileAccess.get_file_as_string("res://qa-manifest.json"))})
	snapshot("0")
	var started := Time.get_ticks_usec()
	var steps := 0
	while steps*STEP < float(options.duration):
		if game.simulated_time+0.000001 >= next_visit:
			visit()
			next_visit=game.simulated_time+(float(options.teaching_seconds) if int(game.profile.highestLevel)<=5 else float(options.visit_seconds))
		game.tick(STEP);steps+=1
		var current := str(game.stage)+":"+str(game.group_index)+":"+str(game.state)
		if current!=wave_key:
			if not wave_key.is_empty():wave_rows.append({"key":wave_key,"seconds":game.simulated_time-wave_start,"end_x1_seconds":game.simulated_time})
			wave_key=current;wave_start=game.simulated_time
		if steps%3600==0:
			metrics.sample(game,60,false)
			write_json("heartbeat.json",{"x1_seconds":game.simulated_time,"stage":game.stage,"highest":game.profile.highestLevel,"deaths":metrics.deaths,"wall_seconds":(Time.get_ticks_usec()-started)/1e6})
			if game.simulated_time-last_heartbeat>=600:
				last_heartbeat=int(game.simulated_time);print("HEARTBEAT x1_seconds=",game.simulated_time," stage=",game.stage," deaths=",metrics.deaths)
		if clears.has(str(options.stop_clear)):break
	snapshot("end")
	write_json("summary.json",{"options":options,"x1_seconds":game.simulated_time,"steps":steps,"clears":clears,"highest":game.profile.highestLevel,"deaths":metrics.deaths,"action_sessions":action_sessions,"action_events":actions,"action_intervals":action_gaps,"metrics":metrics.report(game),"wall_seconds":(Time.get_ticks_usec()-started)/1e6,"profile":game.profile,"waves":wave_rows})
	trace.close();print("RESULT ",output," clears=",clears," deaths=",metrics.deaths," sessions=",action_sessions)
	quit()
