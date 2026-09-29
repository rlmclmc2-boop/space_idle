extends RefCounted
## Every saved fleet is placed by the minimum real module-upgrade delta.
const Runner := preload("res://scripts/fleet_battle_runner.gd")
const EnemyGenerator := preload("res://scripts/enemy_fleet_simulator.gd")
const PlayerGenerator := preload("res://scripts/player_loadout_generator.gd")
const MonGroupXlsx := preload("res://scripts/mon_group_xlsx.gd")
var database: ShipDatabase
var policy: Dictionary
var runner: RefCounted
var source_directory := ""
var output_directory := ""
var inputs: Dictionary={}
var candidates: Array=[]
var evaluated: Array=[]
var levels: Array=[]
var group_rows: Array=[]
var loadouts: Array=[]
var previous_pairs: Dictionary={}
var mon_names: Dictionary={}
var candidate_index := 0
var loadout_index := 0
var module_delta := 0
var spent := 0
var status := "idle"
var error := ""
var current: Dictionary={}

func _init(source: ShipDatabase) -> void:
	database=source
	policy=JSON.parse_string(FileAccess.get_file_as_string("res://data/auto_level_generation.json"))

func busy() -> bool:return status=="running"

func start_fleets(enemy_rows: Array,options: Dictionary={}) -> String:
	if busy():return "already_running"
	if enemy_rows.is_empty():return fail("empty_selection")
	var mon_table: Dictionary=MonGroupXlsx.read_mon_names()
	if mon_table.has("error"):return fail(str(mon_table.error))
	mon_names=mon_table.names
	var base: String=ProjectSettings.globalize_path(str(ProjectSettings.get_setting("application/config/battle_results_directory","res://../test/work/fleet_battles")))
	var directory: String=base.path_join("level_run_%s_%s" % [str(Time.get_unix_time_from_system()).replace(".","_"),Time.get_ticks_usec()])
	if DirAccess.make_dir_recursive_absolute(directory)!=OK:return fail("output_error")
	var file:=FileAccess.open(directory.path_join("inputs.json"),FileAccess.WRITE)
	if file==null:return fail("output_error")
	var names: Dictionary={"equipment":{}}
	for key in database.equipment:names.equipment[str(key)]=UIText.data_text("equipment",str(key),"name")
	file.store_string(JSON.stringify({"enemy_fleets":enemy_rows.duplicate(true),"player_loadouts":[],"display_names":names,"data_sha256":JSON.stringify(database.data).sha256_text()},"  "))
	file.flush()
	if file.get_error()!=OK:return fail("output_error")
	return start(directory,options)

func start(directory: String,options: Dictionary={}) -> String:
	if busy():return "already_running"
	status="idle"
	error=""
	var mon_table: Dictionary=MonGroupXlsx.read_mon_names()
	if mon_table.has("error"):return fail(str(mon_table.error))
	mon_names=mon_table.names
	spent=0
	runner=null
	candidates=[]
	evaluated=[]
	levels=[]
	group_rows=[]
	loadouts=[]
	previous_pairs={}
	candidate_index=0
	loadout_index=0
	module_delta=0
	source_directory=directory.replace("\\","/").trim_suffix("/")
	var request: Dictionary=policy.duplicate(true)
	request.merge(options,true)
	for key in ["max_loadouts","max_level","max_total_battles","max_per_level","coarse_runs","max_seconds","seed"]:
		var value=request.get(key)
		if not (value is int or value is float) or not is_finite(float(value)) or value!=floorf(value):return fail("invalid_input")
	var pass_rate=request.get("pass_winrate")
	if not (pass_rate is int or pass_rate is float) or not is_finite(float(pass_rate)) or pass_rate<=0 or pass_rate>1:return fail("invalid_input")
	if request.max_loadouts<1 or request.max_loadouts>32 or request.max_level<0 or request.max_level>100 or request.max_total_battles<1 or request.max_total_battles>100000 or request.coarse_runs<1 or request.max_per_level<request.coarse_runs or request.max_per_level>1000 or request.max_seconds<1 or request.seed<0 or request.seed>2147483647:return fail("invalid_input")
	var final_wave: Variant=request.get("final_wave")
	if not final_wave is Dictionary:return fail("invalid_input")
	for key in ["max_ship_count","min_ship_size","max_waves_per_level"]:
		var value: Variant=final_wave.get(key)
		if not (value is int or value is float) or not is_finite(float(value)) or value!=floorf(value):return fail("invalid_input")
	if final_wave.max_ship_count<1 or final_wave.max_ship_count>10 or final_wave.min_ship_size<1 or final_wave.max_waves_per_level<2 or final_wave.max_waves_per_level>10:return fail("invalid_input")
	policy=request
	var loaded=JSON.parse_string(FileAccess.get_file_as_string(source_directory.path_join("inputs.json")))
	if not loaded is Dictionary or not loaded.get("enemy_fleets") is Array:return fail("invalid_batch")
	inputs=loaded
	if str(inputs.get("data_sha256",""))!=JSON.stringify(database.data).sha256_text():return fail("config_mismatch")
	var enemy_maker:=EnemyGenerator.new(database)
	for row in inputs.enemy_fleets:
		if not row is Dictionary or str(row.get("config_fingerprint",""))!=enemy_maker.fingerprint:return fail("generation_policy_changed")
		if enemy_maker.replay(row).has("error"):return fail("invalid_enemy_fleet")
		for id in row.get("composition",{}):
			if not mon_names.has(str(id)):return fail("invalid_mon_table")
	var maker:=PlayerGenerator.new(database)
	var player_options: Dictionary=maker.default_options()
	if policy.has("available_ships"):player_options.available_ships=policy.available_ships.duplicate()
	if policy.has("base_module_level"):player_options.module_level=int(policy.base_module_level)
	if policy.has("cleared_through"):player_options.cleared_through=int(policy.cleared_through)
	if inputs.get("player_loadouts",[]) is Array and not inputs.player_loadouts.is_empty():
		var source: Dictionary=inputs.player_loadouts[0]
		if source.get("generation_options") is Dictionary:
			for key in ["cleared_through","module_level","seed"]:
				if source.generation_options.has(key):player_options[key]=source.generation_options[key]
		var allowed: Array=[]
		for player in inputs.player_loadouts:
			if player is Dictionary and player.has("ship") and not allowed.has(player.ship):allowed.append(player.ship)
		if policy.has("available_ships"):allowed=allowed.filter(func(ship):return policy.available_ships.has(ship))
		if not allowed.is_empty():player_options.available_ships=allowed
		elif policy.has("available_ships"):return fail("no_legal_loadouts")
	player_options.seed=int(policy.seed)
	policy.available_ships=player_options.available_ships.duplicate()
	policy.base_module_level=int(player_options.module_level)
	policy.cleared_through=int(player_options.cleared_through)
	var canonical: Dictionary=maker.generate_canonical(player_options,int(policy.max_loadouts))
	if canonical.results.is_empty():return fail(str(canonical.status))
	loadouts=canonical.results
	candidates=inputs.enemy_fleets.duplicate(true)
	if not candidates.any(func(row):return final_wave_eligible(row)):return fail("no_final_wave_candidate")
	output_directory=source_directory.path_join("generated_levels")
	read_existing_pairs()
	status="running"
	advance()
	return error

func read_existing_pairs() -> void:
	var source_players: Array=inputs.get("player_loadouts",[])
	var lookup: Dictionary={}
	for index in range(source_players.size()):
		for canonical_index in range(loadouts.size()):
			if compatible_loadout(source_players[index],loadouts[canonical_index]):
				lookup[index]=canonical_index
	var batch_config: Dictionary=inputs.get("config",{})
	if float(batch_config.get("power_multiplier",1.0))!=1.0 or int(batch_config.get("module_delta",0))!=0:return
	var file:=FileAccess.open(source_directory.path_join("pairs.jsonl"),FileAccess.READ)
	if file==null:return
	while not file.eof_reached():
		var line=file.get_line()
		if line.is_empty():continue
		var row=JSON.parse_string(line)
		if not row is Dictionary or not lookup.has(int(row.get("player_index",-1))):continue
		var enemy_index: int=int(row.get("enemy_index",-1))
		var player_index: int=int(row.get("player_index",-1))
		if enemy_index<0 or enemy_index>=candidates.size() or player_index<0 or player_index>=source_players.size():continue
		var expected_enemy: String="enemy_"+str(candidates[enemy_index].get("signature","")).sha256_text()
		if row.has("enemy_fleet_id") and row.enemy_fleet_id!=expected_enemy:continue
		if row.has("player_loadout_id") and row.player_loadout_id!=source_players[player_index].get("loadout_id",""):continue
		if not (row.get("wins") is int or row.get("wins") is float) or int(row.wins)<0 or int(row.wins)>int(row.get("battle_count",0)):continue
		if not (row.get("avg_battle_time") is int or row.get("avg_battle_time") is float) or not is_finite(float(row.avg_battle_time)):continue
		if int(row.get("errors",0))>0 or int(row.get("timeouts",0))>0 or int(row.get("battle_count",0))<int(policy.coarse_runs):continue
		var key: String="%d:%d" % [enemy_index,int(lookup[player_index])]
		if previous_pairs.has(key):continue
		previous_pairs[key]={"module_delta":0,"tests":int(row.battle_count),"wins":int(row.get("wins",0)),"win_rate":float(row.get("wins",0))/int(row.battle_count),"battle_time":row.get("avg_battle_time"),"remaining_hp":row.get("avg_player_hp_ratio"),"source":"existing_batch"}

func compatible_loadout(saved: Variant,canonical: Dictionary) -> bool:
	if not saved is Dictionary or saved.get("ship")!=canonical.ship:return false
	if not saved.get("generation_options") is Dictionary:return false
	if int(saved.generation_options.get("cleared_through",-1))!=int(canonical.generation_options.cleared_through):return false
	return PlayerGenerator.same_record(saved.get("equipment",{}),canonical.equipment)

func advance() -> void:
	while status=="running":
		if candidate_index>=candidates.size():
			finish()
			return
		if current.is_empty():
			var enemy: Dictionary=candidates[candidate_index]
			current={"enemy_index":candidate_index,"enemy_id":"enemy_"+str(enemy.get("signature","")).sha256_text(),"enemy_group":enemy.duplicate(true),"enemy_tags":enemy.get("primary_tags",[])+enemy.get("secondary_tags",[]),"composition":enemy.get("composition",{}).duplicate(true),"loadout_results":[],"source_simulation_id":source_directory.get_file()}
			loadout_index=0
			module_delta=0
		if loadout_index>=loadouts.size():
			complete_enemy()
			continue
		if spent>=int(policy.max_total_battles):
			mark_remaining("budget")
			finish()
			return
		if module_delta>int(policy.max_level):
			complete_loadout(null,"unbeatable")
			continue
		var key: String="%d:%d" % [candidate_index,loadout_index]
		if module_delta==0 and previous_pairs.has(key):
			accept_test(previous_pairs[key])
			continue
		var remaining: int=int(policy.max_total_battles)-spent
		if remaining<int(policy.coarse_runs):
			mark_remaining("budget")
			finish()
			return
		var cap: int=mini(remaining,int(policy.max_per_level))
		runner=Runner.new(database)
		var seed: int=int(policy.seed)+candidate_index*1009+loadout_index*97+module_delta*1000003
		var settings: Dictionary={"runs":int(policy.coarse_runs),"seed":seed,"max_seconds":int(policy.max_seconds),"mode":"fast","max_total":cap,"max_per_pair":cap,"samples_per_tag":1,"focus_stable_stop":true,"module_delta":module_delta,"directory":output_directory}
		var failure: String=runner.start([candidates[candidate_index]],[loadouts[loadout_index]],settings)
		if not failure.is_empty():
			current.loadout_results.append(result_row(null,"error",[],failure))
			loadout_index+=1
			module_delta=0
			runner=null
			continue
		return

func process(budget_usec := -1) -> void:
	if not busy() or runner==null:return
	if runner.busy():runner.process(budget_usec)
	if runner.busy():return
	spent+=runner.completed
	var aggregate: Dictionary=runner.aggregate
	var test: Dictionary={"module_delta":module_delta,"tests":int(aggregate.battle_count),"wins":int(aggregate.wins),"win_rate":aggregate.win_rate,"battle_time":aggregate.avg_battle_time,"remaining_hp":aggregate.avg_player_hp_ratio,"source":runner.directory,"stable_stopped":runner.sampling.stable_count}
	if runner.status=="error" or test.tests==0:
		current.loadout_results.append(result_row(null,"error",[test],runner.error))
		loadout_index+=1
		module_delta=0
	else:
		accept_test(test)
	runner=null
	advance()

func accept_test(test: Dictionary) -> void:
	var previous: Array=[]
	if not current.loadout_results.is_empty() and current.loadout_results.back().get("pending",false):
		previous=current.loadout_results.pop_back().tests
	previous.append(test)
	if float(test.win_rate)>=float(policy.pass_winrate):
		current.loadout_results.append(result_row(module_delta,"pass",previous))
		loadout_index+=1
		module_delta=0
	elif module_delta>=int(policy.max_level):
		current.loadout_results.append(result_row(null,"unbeatable",previous))
		loadout_index+=1
		module_delta=0
	else:
		current.loadout_results.append({"pending":true,"tests":previous})
		module_delta+=1

func complete_loadout(level: Variant,kind: String) -> void:
	var previous: Array=[]
	if not current.loadout_results.is_empty() and current.loadout_results.back().get("pending",false):previous=current.loadout_results.pop_back().tests
	current.loadout_results.append(result_row(level,kind,previous))
	loadout_index+=1
	module_delta=0

func result_row(level: Variant,kind: String,tests: Array,message := "") -> Dictionary:
	var player: Dictionary=loadouts[loadout_index]
	var latest: Dictionary=tests.back() if not tests.is_empty() else {}
	var weapon_keys: Array=[]
	for entry in player.weapons:
		if not weapon_keys.has(entry.key):weapon_keys.append(entry.key)
	return {"player_loadout_id":player.loadout_id,"ship":player.ship,"weapons":weapon_keys,"tags":player.tags,"required_level":level,"status":kind,"winrate_at_level":latest.get("win_rate"),"battle_time":latest.get("battle_time"),"sample_count":latest.get("tests",0),"tests":tests,"error":message}

func complete_enemy() -> void:
	var feasible: Array=[]
	var placement: Array=[]
	for row in current.loadout_results:
		if row.required_level!=null:
			feasible.append(int(row.required_level))
			placement.append(int(row.required_level))
		elif row.status=="unbeatable":placement.append(int(policy.max_level)+1)
	feasible.sort()
	placement.sort()
	var recommended: Variant=null
	if not placement.is_empty() and int(placement[placement.size()/2])<=int(policy.max_level):recommended=placement[placement.size()/2]
	var best: Array=[]
	var worst: Array=[]
	var spread: Variant=null
	if not feasible.is_empty() and not placement.is_empty():
		spread=int(placement.back())-int(placement.front())
	if not feasible.is_empty():
		for row in current.loadout_results:
			if row.required_level==feasible.front():best.append(row.duplicate(true))
			if row.required_level==feasible.back() or row.required_level==null and row.status=="unbeatable":worst.append(row.duplicate(true))
	current.recommended_level=recommended
	current.required_level_spread=spread
	current.spread_is_lower_bound=not feasible.is_empty() and placement.has(int(policy.max_level)+1)
	current.no_difference=spread==0 and feasible.size()==loadouts.size()
	current.best_loadouts=best
	current.worst_loadouts=worst
	current.status="unbeatable" if feasible.is_empty() and not placement.is_empty() else "measured" if recommended!=null else "partial"
	evaluated.append(current.duplicate(true))
	current={}
	candidate_index+=1

func mark_remaining(reason: String) -> void:
	if not current.is_empty():
		var partial: Array=[]
		if not current.loadout_results.is_empty() and current.loadout_results.back().get("pending",false):partial=current.loadout_results.pop_back().tests
		if not partial.is_empty():
			current.loadout_results.append(result_row(null,reason,partial))
			loadout_index+=1
		while loadout_index<loadouts.size():
			current.loadout_results.append(result_row(null,reason,[]))
			loadout_index+=1
		complete_enemy()
	while candidate_index<candidates.size():
		current={"enemy_index":candidate_index,"enemy_id":"enemy_"+str(candidates[candidate_index].get("signature","")).sha256_text(),"enemy_group":candidates[candidate_index].duplicate(true),"enemy_tags":candidates[candidate_index].get("primary_tags",[])+candidates[candidate_index].get("secondary_tags",[]),"composition":candidates[candidate_index].get("composition",{}).duplicate(true),"loadout_results":[],"source_simulation_id":source_directory.get_file()}
		loadout_index=0
		while loadout_index<loadouts.size():
			current.loadout_results.append(result_row(null,reason,[]))
			loadout_index+=1
		complete_enemy()

func finish() -> void:
	status="completed"
	build_levels()
	write_output()

func build_levels() -> void:
	levels=[]
	group_rows=[]
	var pool: Array=evaluated.duplicate(true)
	pool.sort_custom(func(a,b):return order_value(a)<order_value(b) if order_value(a)!=order_value(b) else int(a.enemy_index)<int(b.enemy_index))
	var ordered: Array=[]
	while not pool.is_empty():
		var index:=different_next(pool,ordered)
		ordered.append(pool.pop_at(index))
	var level_id:=0
	var group_id:=0
	for row in database.levels:level_id=maxi(level_id,int(row.get("id",0)))
	for key in database.groups:group_id=maxi(group_id,int(key))
	var group_by_index: Dictionary={}
	for row in ordered:
		group_id+=1
		var group: Dictionary=row.enemy_group.duplicate(true)
		var name: String=MonGroupXlsx.group_name_from_slots(group.slots,mon_names)
		var prefix:=fitting_weapon_prefix(row.best_loadouts)
		if not prefix.is_empty():name=prefix+"-"+name
		group.description=name
		var record: Dictionary={"enemy_group":group_id,"group_data":group,"name":name}
		group_rows.append(record)
		group_by_index[int(row.enemy_index)]=record
	var finales: Array=[]
	var preliminary: Array=[]
	for row in ordered:
		if final_wave_eligible(row.enemy_group):finales.append(row)
		else:preliminary.append(row)
	if finales.is_empty():return
	var plans: Array=[]
	var used_finales: Dictionary={}
	var capacity: int=int(policy.final_wave.max_waves_per_level)-1
	for start_index in range(0,preliminary.size(),capacity):
		var waves: Array=preliminary.slice(start_index,mini(start_index+capacity,preliminary.size()))
		var finale: Dictionary=choose_finale(finales,used_finales,order_value(waves.back()))
		used_finales[int(finale.enemy_index)]=int(used_finales.get(int(finale.enemy_index),0))+1
		waves.append(finale)
		plans.append(waves)
	for finale in finales:
		if not used_finales.has(int(finale.enemy_index)):plans.append([finale])
	plans.sort_custom(func(a,b):
		var a_level: int=plan_level(a)
		var b_level: int=plan_level(b)
		return a_level<b_level if a_level!=b_level else int(a.back().enemy_index)<int(b.back().enemy_index))
	var sorted_plans: Array=plans
	plans=[]
	while not sorted_plans.is_empty():
		var selected:=0
		if not plans.is_empty():
			var same_level: int=plan_level(sorted_plans[0])
			for index in range(sorted_plans.size()):
				if plan_level(sorted_plans[index])!=same_level:break
				if not similar_enemy(plans.back().back().enemy_group,sorted_plans[index].back().enemy_group):
					selected=index
					break
		plans.append(sorted_plans.pop_at(selected))
	for waves in plans:
		level_id+=1
		var finale: Dictionary=waves.back()
		var finale_record: Dictionary=group_by_index[int(finale.enemy_index)]
		var encounters: Array=[]
		var group_refs: Array=[]
		var refs:=PackedStringArray()
		var recommended: Variant=0
		for wave_index in range(waves.size()):
			var wave: Dictionary=waves[wave_index]
			var record: Dictionary=group_by_index[int(wave.enemy_index)]
			var position: float=float(policy.group_position)*float(wave_index+1)/float(waves.size())
			group_refs.append({"id":record.enemy_group,"position":position})
			refs.append("%d|%s" % [int(record.enemy_group),str(position)])
			encounters.append({"enemy_group":record.enemy_group,"name":record.name,"position":position,"composition":wave.composition,"enemy_tags":wave.enemy_tags,"recommended_level":wave.recommended_level})
			if wave.recommended_level==null:recommended=null
			elif recommended!=null:recommended=maxi(int(recommended),int(wave.recommended_level))
		levels.append({"id":level_id,"name":finale_record.name,"length":float(database.levels[0].get("length",1000)),"monGroup":"{%s}" % ",".join(refs),"atkRatio":1,"lifeRatio":1,"resRatio":1,"jewelRatio":1,"planetExpRatio":0,"groups":group_refs,"encounters":encounters,"enemy_group":finale_record.enemy_group,"group_data":finale_record.group_data,"enemy_index":finale.enemy_index,"enemy_id":finale.enemy_id,"composition":finale.composition,"enemy_tags":finale.enemy_tags,"level_type":finale.status,"recommended_level":recommended,"loadout_results":finale.loadout_results,"best_loadouts":finale.best_loadouts,"worst_loadouts":finale.worst_loadouts,"required_level_spread":finale.required_level_spread,"spread_is_lower_bound":finale.spread_is_lower_bound,"no_difference":finale.no_difference,"source_simulation_id":finale.source_simulation_id})

func final_wave_eligible(group: Dictionary) -> bool:
	var composition: Dictionary=group.get("composition",{})
	var count:=0
	for id in composition:
		var amount: int=int(composition[id])
		if amount<1 or not database.enemies.has(str(id)) or float(database.enemies[str(id)].get("size",0))<float(policy.final_wave.min_ship_size):return false
		count+=amount
	return count>=1 and count<=int(policy.final_wave.max_ship_count)

func choose_finale(finales: Array,used: Dictionary,minimum_level: int) -> Dictionary:
	var best: Dictionary={}
	var best_rank: Array=[]
	for row in finales:
		var level: int=order_value(row)
		var rank: Array=[1 if level<minimum_level else 0,int(used.get(int(row.enemy_index),0)),absi(level-minimum_level),int(row.enemy_index)]
		if best.is_empty() or rank_less(rank,best_rank):
			best=row
			best_rank=rank
	return best

func rank_less(a: Array,b: Array) -> bool:
	for index in range(a.size()):
		if a[index]!=b[index]:return int(a[index])<int(b[index])
	return false

func plan_level(waves: Array) -> int:
	var result:=0
	for wave in waves:result=maxi(result,order_value(wave))
	return result

func fitting_weapon_prefix(best_loadouts: Array) -> String:
	if best_loadouts.is_empty():return ""
	var energy_type: int=int(database.equip("laser",1).get("dmgtype",-1))
	var physical_type: int=int(database.equip("cannon",1).get("dmgtype",-2))
	var styles: Dictionary={}
	for loadout in best_loadouts:
		for key in loadout.weapons:
			var weapon: Dictionary=database.equip(str(key),1)
			var damage_type: int=int(weapon.get("dmgtype",0))
			if damage_type==energy_type:styles["能量"]=true
			elif damage_type==physical_type:styles["物理"]=true
			else:styles["混合"]=true
	if styles.is_empty():return ""
	return str(styles.keys()[0]) if styles.size()==1 else "混合"

func order_value(row: Dictionary) -> int:
	return int(row.recommended_level) if row.recommended_level!=null else int(policy.max_level)+1

func different_next(pool: Array,ordered: Array) -> int:
	if ordered.is_empty():return 0
	var last: Dictionary=ordered.back()
	var first_value:=order_value(pool[0])
	for index in range(pool.size()):
		if order_value(pool[index])!=first_value:break
		if not similar_enemy(last.enemy_group,pool[index].enemy_group):return index
	return 0

func similar_enemy(a: Dictionary,b: Dictionary) -> bool:
	if str(a.get("signature",""))==str(b.get("signature","")):return true
	if int(a.get("count",0))!=int(b.get("count",0)):return false
	var scores: Dictionary=a.get("feature_scores",{})
	for key in scores:
		if absf(float(scores[key])-float(b.get("feature_scores",{}).get(key,0)))>float(policy.similarity):return false
	return not scores.is_empty()

func stop() -> void:
	if not busy():return
	if runner!=null and runner.busy():runner.stop();spent+=runner.completed
	mark_remaining("stopped")
	status="stopped"
	build_levels()
	write_output()

func write_output() -> void:
	if DirAccess.make_dir_recursive_absolute(output_directory)!=OK:error="output_error";status="error";return
	var xlsx_error: String=MonGroupXlsx.export_groups(group_rows,output_directory.path_join("monGroup.xlsx"),database.enemies,mon_names)
	if not xlsx_error.is_empty():error=xlsx_error;status="error";return
	var file:=FileAccess.open(output_directory.path_join("generated_levels.json"),FileAccess.WRITE)
	if file==null:error="output_error";status="error";return
	var groups: Dictionary={}
	for group in group_rows:groups[str(group.enemy_group)]=group.group_data.duplicate(true)
	file.store_string(JSON.stringify({"schema_version":2,"source_batch":source_directory,"source_simulation_id":source_directory.get_file(),"data_sha256":str(inputs.get("data_sha256","")),"config":policy,"status":status,"supplement_battles":spent,"candidate_count":candidates.size(),"canonical_loadouts":loadouts,"evaluated":evaluated,"groups":groups,"levels":levels},"  "))
	file.flush()
	if file.get_error()!=OK:error="output_error";status="error"

func fail(message: String) -> String:
	error=message
	status="error"
	return message

