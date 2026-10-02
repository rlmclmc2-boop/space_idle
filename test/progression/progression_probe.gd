extends SceneTree
const BasicGame = preload("res://scripts/balance_game.gd")
const FormalGame = preload("res://qa/presented_balance_game.gd")
const Database = preload("res://scripts/balance_database.gd")
const Policy = preload("res://qa/sparse_policy.gd")
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
var in_visit := false
var encounter := {}
var completed_waves := 0
var reached := {}
var reforges := []
var current_reforge := -1
var galaxy_completion := -1.0
var scene_driver = null
func _initialize() -> void: call_deferred("run")
func write_json(name: String, value) -> void:
	var f := FileAccess.open(output+"/"+name,FileAccess.WRITE)
	f.store_string(JSON.stringify(value,"\t")); f.close()
func snapshot(label: String) -> void:
	var projection:Dictionary={"armour":game.stat("armour"),"shield":game.stat("shield"),"reactor_weapons":game.reactor_multiplier("weapons"),"reactor_defence":game.reactor_multiplier("defence"),"reactor_smelting":game.reactor_multiplier("smelting"),"weapons":[]}
	for entry in game.weapon_entries():
		projection.weapons.append({"key":entry.key,"actual_level":entry.level,"effective_level":game.effective_equipment_level(int(entry.level)),"equipment_damage":0 if str(entry.key).is_empty() else game.equipment_stat(str(entry.key),int(entry.level))})
	write_json("save_"+label+".json", {"x1_seconds":game.simulated_time,"save":game.portable_save_data(),"combat_projection":projection,"projection_scope":"Current ordinary capacities/damage; excludes per-hit critical/channel counters","rng_state":str(game.rng.state),"policy":{"random_state":str(policy.random.state),"last_refit":policy.last_refit,"unlocked_count":policy.unlocked_count,"farm":policy.farm,"best_won":policy.best_won,"deaths_seen":policy.deaths_seen},"state":int(game.state),"metrics_income":metrics.income,"metrics_spending":metrics.spending,"data_sha256":FileAccess.get_sha256("res://data/game_data.json"),"combat_engine":str(options.get("engine","formal")),"code_fingerprint":JSON.parse_string(FileAccess.get_file_as_string("res://qa-manifest.json")).fingerprint})
func observe(kind: String, payload: Dictionary) -> void:
	if kind=="encounter":
		encounter={"start":game.simulated_time,"stage":game.stage,"node":game.group_index,"group":game.db.levels[game.stage-1].groups[game.group_index-1].id,"loadout":game.profile.loadout.duplicate(true),"initial_income":metrics.income.duplicate(true)}
	elif not encounter.is_empty() and ((kind=="explode" and not game.has_alive_enemy()) or kind=="retreat"):
		encounter.end=game.simulated_time;encounter.seconds=game.simulated_time-float(encounter.start);encounter.status="win" if kind=="explode" else "loss"
		if encounter.status=="win":policy.best_won[str(encounter.stage)]=maxi(int(policy.best_won.get(str(encounter.stage),0)),int(encounter.node))
		trace.store_line(JSON.stringify({"kind":"wave_result","wave":encounter}));trace.flush();completed_waves+=1;encounter={}

	if kind=="planet_reforged":
		reforges.append({"planet":payload.get("id",""),"start":game.simulated_time,"return34":null,"clear_wall_stage":null,"clear_next_planet":null})
		current_reforge=reforges.size()-1
		snapshot("reforge_"+str(payload.get("id","")))
	if kind in ["upgrade","upgrades_completed","module_changed","ship_changed","scientists_changed","reactor_changed","enhancement_changed","planet_changed","planet_reforged","crew_changed"]:
		if in_visit and not (kind=="upgrade" and payload.get("batch",false)):actions += 1
		trace.store_line(JSON.stringify({"x1_seconds":game.simulated_time,"kind":kind,"actor":"visit" if in_visit else "automatic","stage":game.stage,"payload":payload})); trace.flush()
	if kind == "state" and game.state == BattleGame.State.LEVEL_CLEAR:
		if current_reforge>=0:
			var phase:Dictionary=reforges[current_reforge]
			var planet:int=int(phase.planet)
			if game.stage==34+5*(planet-1) and phase.clear_wall_stage==null:
				phase.clear_wall_stage=game.simulated_time;snapshot("reforge_clear_wall_"+str(planet))
			if game.stage==35+5*(planet-1) and phase.clear_next_planet==null:
				phase.clear_next_planet=game.simulated_time;snapshot("reforge_clear_"+str(planet))
		if not clears.has(str(game.stage)):
			clears[str(game.stage)] = game.simulated_time
			print("CLEAR stage=",game.stage," x1_seconds=",game.simulated_time)
			if game.stage in [5,10,20,30,32,34,35,40,45,50,55,60]:snapshot(str(game.stage))
func visit() -> void:
	in_visit=true
	var before: int = actions
	var pending: Array = game.pending_unlocks.duplicate()
	# Manual collection only while actually visiting; auto losses remain between visits.
	for drop in game.drops.duplicate():
		game.collect(drop,true);actions+=1
		trace.store_line(JSON.stringify({"x1_seconds":game.simulated_time,"kind":"manual_collect","id":drop.id}))
	policy.act(game,game.simulated_time)
	var acknowledged: Array=pending.filter(func(id):return not game.pending_unlocks.has(id))
	if not acknowledged.is_empty():
		actions += acknowledged.size()
		trace.store_line(JSON.stringify({"x1_seconds":game.simulated_time,"kind":"acknowledge_unlocks","count":acknowledged.size(),"ids":acknowledged}))
	in_visit=false
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
	game = (BasicGame if str(options.get("engine","formal"))=="basic" else FormalGame).new(Database.new());game.rng.seed=int(options.seed)
	game.stat_cache_enabled=bool(options.get("stat_cache",true))
	game.metrics=metrics;metrics.initialize(game)
	policy.configure(str(options.strategy),int(options.seed))
	policy.thematic=bool(options.get("thematic",false))
	policy.allow_reforge=bool(options.get("allow_reforge",true))
	policy.use_bulk=bool(options.get("bulk",false))
	policy.cap_stage=60 if bool(options.get("stop_galaxy",false)) else 0
	policy.journal=func(kind, extra):
		if kind in ["travel_to_farm_point","begin_farm_guard","resume_push"]:actions+=1
		trace.store_line(JSON.stringify({"x1_seconds":game.simulated_time,"kind":kind,"stage":game.stage,"payload":extra}));trace.flush()
	var initial_scope := "fresh"
	if not str(options.get("resume","")).is_empty():
		var checkpoint=JSON.parse_string(FileAccess.get_file_as_string(str(options.resume)))
		if not checkpoint is Dictionary or not checkpoint.get("save") is Dictionary:
			printerr("Invalid diagnostic checkpoint");quit(2);return
		if (checkpoint.get("data_sha256","")!=FileAccess.get_sha256("res://data/game_data.json") or checkpoint.get("combat_engine","basic")!=str(options.get("engine","formal"))) and not bool(options.get("allow_version_change",false)):
			printerr("Checkpoint data differs: explicitly allow diagnostic version change");quit(2);return
		initial_scope="checkpoint diagnostic; formal journey reload; no full fresh acceptance"
		game.simulated_time=float(checkpoint.x1_seconds)
		var raw:Dictionary=checkpoint.save.duplicate(true)
		raw.chronoSavedAt=Time.get_unix_time_from_system()
		game.load_progress_data(raw)
		game.profile.chronoParticles=float(raw.get("chronoParticles",0));game.login_chrono_particles=0
		game.resume_progress();game.rng.state=int(str(checkpoint.rng_state))
		var old:Dictionary=checkpoint.get("policy",{})
		if old.has("random_state"):policy.random.state=int(str(old.random_state))
		for field in ["last_refit","unlocked_count","farm","best_won","deaths_seen"]:
			if old.has(field):policy.set(field,old[field])
		next_visit=game.simulated_time
	game.event.connect(observe)
	if bool(options.get("scene",false)):
		scene_driver=load("res://qa/scene_driver.gd").new()
		scene_driver.setup(self,game)
	write_json("run.json",{"options":options,"engine":Engine.get_version_info(),"step_seconds":STEP,"mode":"exact","combat_engine":str(options.get("engine","formal")),"geometry_scope":"Formal scene providers" if bool(options.get("scene",false)) else "Logical default launch/targets only","initial_state":initial_scope,"qa_manifest":JSON.parse_string(FileAccess.get_file_as_string("res://qa-manifest.json"))})
	snapshot("0")
	var started := Time.get_ticks_usec()
	var steps := 0
	while steps*STEP < float(options.duration):
		if game.simulated_time+0.000001 >= next_visit:
			visit()
			next_visit=game.simulated_time+(float(options.teaching_seconds) if int(game.profile.highestLevel)<=5 else float(options.visit_seconds))
		if scene_driver!=null:scene_driver.before_tick(STEP)
		game.tick(STEP);steps+=1
		if scene_driver!=null:scene_driver.after_tick(STEP)
		if current_reforge>=0:
			var phase:Dictionary=reforges[current_reforge]
			var planet:int=int(phase.planet)
			if game.stage>=34+5*(planet-1) and phase.return34==null:
				phase.return34=game.simulated_time;snapshot("reforge_return_"+str(planet))
		if game.stage in [30,32,34,35,40,45,50,55,60] and not reached.has(str(game.stage)):
			reached[str(game.stage)]=game.simulated_time;snapshot("reach_"+str(game.stage))
		if game.galaxy.regions.has("galaxy_1") and game.galaxy.regions.galaxy_1.is_complete() and galaxy_completion<0:
			galaxy_completion=game.simulated_time;snapshot("galaxy_all_max")
		if bool(options.get("stop_galaxy",false)) and galaxy_completion>=0:break
		if int(options.get("stop_reach",0))>0 and game.stage>=int(options.stop_reach):break
		var current := str(game.stage)+":"+str(game.group_index)+":"+str(game.state)
		if current!=wave_key:
			if not wave_key.is_empty():
				var row := {"key":wave_key,"seconds":game.simulated_time-wave_start,"end_x1_seconds":game.simulated_time}
				wave_rows.append(row)
				trace.store_line(JSON.stringify({"kind":"state_interval","row":row}));trace.flush()
			wave_key=current;wave_start=game.simulated_time
		if steps%3600==0:
			metrics.sample(game,60,false)
			write_json("heartbeat.json",{"x1_seconds":game.simulated_time,"stage":game.stage,"highest":game.profile.highestLevel,"deaths":metrics.deaths,"wall_seconds":(Time.get_ticks_usec()-started)/1e6})
			if game.simulated_time-last_heartbeat>=600:
				last_heartbeat=int(game.simulated_time);print("HEARTBEAT x1_seconds=",game.simulated_time," stage=",game.stage," deaths=",metrics.deaths)
		if clears.has(str(int(options.stop_clear))):break
	snapshot("end")
	write_json("summary.json",{"options":options,"x1_seconds":game.simulated_time,"steps":steps,"clears":clears,"highest":game.profile.highestLevel,"deaths":metrics.deaths,"action_sessions":action_sessions,"action_events":actions,"action_intervals":action_gaps,"completed_waves":completed_waves,"reached":reached,"reforges":reforges,"galaxy_all_max_seconds":galaxy_completion,"operation_scope":"Observed API domain events; batch upgrades counted once, explicit manual collects included. Not literal mouse clicks.","metrics":metrics.report(game),"wall_seconds":(Time.get_ticks_usec()-started)/1e6,"profile":game.profile,"waves":wave_rows})
	if scene_driver!=null:scene_driver.close()
	trace.close();print("RESULT ",output," clears=",clears," deaths=",metrics.deaths," sessions=",action_sessions)
	quit()
