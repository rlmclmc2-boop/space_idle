extends RefCounted
## Plans focused follow-up battles and combines their aggregates with a completed batch.
static func read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))

static func plan(report: Dictionary,inputs: Dictionary,target_tests: int,budget: int,max_configurations: int,max_pairs: int,enemy_index := -1) -> Dictionary:
	var groups := {}
	var existing := {}
	for enemy in report.get("level_candidates",[]):
		if enemy_index>=0 and int(enemy.enemy_index)!=enemy_index:continue
		if enemy_index<0 and enemy.design_category!="insufficient":continue
		groups[int(enemy.enemy_index)]=[]
		existing[int(enemy.enemy_index)]=[]
	for pair in report.get("pair_analysis",[]):
		if not groups.has(int(pair.enemy_index)):continue
		existing[int(pair.enemy_index)].append(pair)
		if int(pair.tests)<target_tests:groups[int(pair.enemy_index)].append(pair)
	var rounds := []
	var indices: Array=groups.keys()
	indices.sort()
	for index in indices:
		var rows: Array=groups[index]
		rows.sort_custom(func(a,b):
			if (a.tests>0)!=(b.tests>0):return a.tests>0
			if a.tests!=b.tests:return a.tests>b.tests
			return a.player_index<b.player_index)
		var chosen := []
		var weapons := {}
		var used_players := {}
		var reliable := 0
		for row in existing[index]:
			used_players[int(row.player_index)]=true
			if row.confidence!="low" and int(row.tests)>=target_tests:
				reliable+=1
				weapons[row.weapon_combination]=true
		for row in rows:
			if weapons.has(row.weapon_combination):continue
			chosen.append(row)
			weapons[row.weapon_combination]=true
			if chosen.size()+reliable>=max_configurations:break
		if chosen.size()+reliable<max_configurations:
			for player_index in range(inputs.player_loadouts.size()):
				if used_players.has(player_index):continue
				var player=inputs.player_loadouts[player_index]
				if not player is Dictionary or not player.get("weapons") is Array:continue
				var kinds := {}
				for weapon in player.weapons:
					if weapon is Dictionary:kinds[str(weapon.get("key",""))]=true
				var keys: Array=kinds.keys()
				keys.sort()
				var combination := " + ".join(keys)
				if weapons.has(combination):continue
				chosen.append({"enemy_index":index,"player_index":player_index,"tests":0,"weapon_combination":combination})
				weapons[combination]=true
				if chosen.size()+reliable>=max_configurations:break
		for row in rows:
			if chosen.size()+reliable>=max_configurations:break
			if not chosen.has(row):chosen.append(row)
		for i in range(chosen.size()):
			while rounds.size()<=i:rounds.append([])
			rounds[i].append(chosen[i])
	var selected := []
	var needed := 0
	var skipped := 0
	for round_rows in rounds:
		for row in round_rows:
			var count: int=target_tests-int(row.tests)
			if needed+count>budget or selected.size()>=max_pairs:
				skipped+=1
				continue
			selected.append({"enemy_index":int(row.enemy_index),"player_index":int(row.player_index),"runs":count})
			needed+=count
	return {"pairs":selected,"battles":needed,"skipped":skipped,"enemies":indices.size()}

static func merge_aggregate(left: Dictionary,right: Dictionary) -> Dictionary:
	var result: Dictionary=left.duplicate(true)
	var a := int(left.get("battle_count",0))
	var b := int(right.get("battle_count",0))
	for key in ["attempted_count","battle_count","wins","errors","timeouts","stopped"]:
		result[key]=int(left.get(key,0))+int(right.get(key,0))
	result.win_rate=float(result.wins)/result.battle_count if result.battle_count>0 else null
	for key in ["avg_battle_time","avg_player_hp_ratio","avg_enemy_hp_ratio"]:
		result[key]=(float(left.get(key,0.0) if left.get(key)!=null else 0.0)*a+float(right.get(key,0.0) if right.get(key)!=null else 0.0)*b)/(a+b) if a+b>0 else null
	return result

static func merge_pair(left: Dictionary,right: Dictionary) -> Dictionary:
	var result := merge_aggregate(left,right)
	var a := int(left.get("battle_count",0))
	var b := int(right.get("battle_count",0))
	var variance_a=left.get("time_m2")
	var variance_b=right.get("time_m2")
	if a>0 and b>0 and (variance_a==null or variance_b==null):result.time_m2=null
	elif a+b==0:result.time_m2=0.0
	elif a==0:result.time_m2=variance_b
	elif b==0:result.time_m2=variance_a
	else:
		var difference := float(right.avg_battle_time)-float(left.avg_battle_time)
		result.time_m2=float(variance_a)+float(variance_b)+difference*difference*a*b/(a+b)
	for key in ["enemy_index","player_index","enemy_fleet_id","player_loadout_id","enemy_tags","player_tags","weapons"]:
		if left.has(key):result[key]=left[key]
		elif right.has(key):result[key]=right[key]
	result.focus=bool(left.get("focus",false)) or bool(right.get("focus",false))
	result.test_reasons=left.get("test_reasons",[])+right.get("test_reasons",[])
	result.stop_reason="retested"
	return result

static func read_pairs(path: String) -> Variant:
	var file := FileAccess.open(path,FileAccess.READ)
	if file==null:return null
	var rows := {}
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.is_empty():continue
		var row=JSON.parse_string(line)
		if not row is Dictionary or not row.has("enemy_index") or not row.has("player_index"):return null
		var key := "%d:%d" % [int(row.enemy_index),int(row.player_index)]
		if rows.has(key):return null
		rows[key]=row
	return rows

static func save_json(path: String,value: Variant) -> bool:
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file==null:return false
	file.store_string(JSON.stringify(value,"  "))
	file.flush()
	return file.get_error()==OK

static func append_battles(target: FileAccess,path: String,sequence_offset: int) -> bool:
	var source := FileAccess.open(path,FileAccess.READ)
	if source==null:return false
	while not source.eof_reached():
		var line := source.get_line().strip_edges()
		if line.is_empty():continue
		if sequence_offset>0:
			var row=JSON.parse_string(line)
			if not row is Dictionary:return false
			row.sequence=int(row.get("sequence",0))+sequence_offset
			line=JSON.stringify(row)
		target.store_line(line)
	return target.get_error()==OK

static func combine(base: String,followup: String) -> Dictionary:
	var original=read_json(base.path_join("inputs.json"))
	var additional=read_json(followup.path_join("inputs.json"))
	var previous=read_json(base.path_join("summary.json"))
	var recent=read_json(followup.path_join("summary.json"))
	if not original is Dictionary or not additional is Dictionary or not previous is Dictionary or not recent is Dictionary:return {"error":"invalid_batch"}
	if JSON.stringify(original.get("enemy_fleets"))!=JSON.stringify(additional.get("enemy_fleets")) or JSON.stringify(original.get("player_loadouts"))!=JSON.stringify(additional.get("player_loadouts")) or original.get("data_sha256")!=additional.get("data_sha256"):return {"error":"input_mismatch"}
	var pairs=read_pairs(base.path_join("pairs.jsonl"))
	var new_pairs=read_pairs(followup.path_join("pairs.jsonl"))
	if not pairs is Dictionary or not new_pairs is Dictionary:return {"error":"invalid_pairs"}
	for key in new_pairs:
		pairs[key]=merge_pair(pairs[key],new_pairs[key]) if pairs.has(key) else new_pairs[key]
	var combined: Dictionary=previous.duplicate(true)
	combined.status="retested"
	combined.completed_count=int(previous.get("completed_count",0))+int(recent.get("completed_count",0))
	combined.budget=int(previous.get("budget",0))+int(recent.get("budget",0))
	combined.remaining_budget=int(previous.get("remaining_budget",0))+int(recent.get("remaining_budget",0))
	combined.aggregate=merge_aggregate(previous.get("aggregate",{}),recent.get("aggregate",{}))
	combined.retest={"source":base,"followup":followup,"new_battles":int(recent.get("completed_count",0))}
	combined.retest.config=recent.get("config",{}).duplicate(true)
	var sampling: Dictionary=previous.get("sampling",{}).duplicate(true)
	sampling.sampled_pairs=pairs.size()
	sampling.tested_pairs=pairs.values().filter(func(row):return int(row.get("attempted_count",0))>0).size()
	sampling.retest=recent.get("sampling",{}).duplicate(true)
	combined.sampling=sampling
	var output := base.get_base_dir().path_join("batch_retest_%s_%s" % [str(Time.get_unix_time_from_system()).replace(".","_"),Time.get_ticks_usec()])
	if DirAccess.make_dir_recursive_absolute(output)!=OK:return {"error":"write_failed"}
	var inputs: Dictionary=original.duplicate(true)
	inputs.retest=combined.retest
	if not save_json(output.path_join("inputs.json"),inputs) or not save_json(output.path_join("summary.json"),combined):return {"error":"write_failed"}
	var pair_file := FileAccess.open(output.path_join("pairs.jsonl"),FileAccess.WRITE)
	if pair_file==null:return {"error":"write_failed"}
	var keys: Array=pairs.keys()
	keys.sort()
	for key in keys:pair_file.store_line(JSON.stringify(pairs[key]))
	pair_file.flush()
	if pair_file.get_error()!=OK:return {"error":"write_failed"}
	var battle_file := FileAccess.open(output.path_join("battles.jsonl"),FileAccess.WRITE)
	if battle_file==null:return {"error":"write_failed"}
	if not append_battles(battle_file,base.path_join("battles.jsonl"),0) or not append_battles(battle_file,followup.path_join("battles.jsonl"),int(previous.get("completed_count",0))):return {"error":"write_failed"}
	battle_file.flush()
	if battle_file.get_error()!=OK:return {"error":"write_failed"}
	return {"directory":output}
