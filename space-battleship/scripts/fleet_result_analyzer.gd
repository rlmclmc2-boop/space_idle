extends RefCounted
## Consumes frozen batch aggregates only. No dependency on combat or generators.
var policy: Dictionary
var report := {}
var error := ""
var warnings: Array = []

func _init() -> void:
	policy=JSON.parse_string(FileAccess.get_file_as_string("res://data/battle_result_analysis.json"))

func read_json(path: String) -> Variant:
	var file := FileAccess.open(path,FileAccess.READ)
	if file==null or file.get_length()>int(policy.max_input_bytes):return null
	return JSON.parse_string(file.get_as_text())

func analyze(directory: String) -> Dictionary:
	error=""
	warnings=[]
	report={}
	var inputs=read_json(directory.path_join("inputs.json"))
	var summary=read_json(directory.path_join("summary.json"))
	if not inputs is Dictionary or not summary is Dictionary or not inputs.get("enemy_fleets") is Array or not inputs.get("player_loadouts") is Array:
		return fail("invalid_batch")
	var file := FileAccess.open(directory.path_join("pairs.jsonl"),FileAccess.READ)
	if file==null or file.get_length()>int(policy.max_input_bytes):return fail("missing_pairs")
	var pairs: Array=[]
	var seen := {}
	var line := 0
	while not file.eof_reached():
		var text := file.get_line()
		line+=1
		if text.strip_edges().is_empty():continue
		var raw=JSON.parse_string(text)
		var row := normalize(raw,inputs)
		if row.is_empty():return fail("invalid_pair_line_"+str(line))
		if seen.has(row.id):return fail("duplicate_pair_line_"+str(line))
		seen[row.id]=true
		pairs.append(row)
		if pairs.size()>int(policy.max_pairs):return fail("too_many_pairs")
	if pairs.is_empty():return fail("missing_pairs")
	var enemies := {}
	var enemy_pairs := {}
	for enemy_index in range(inputs.enemy_fleets.size()):
		var source_enemy: Dictionary=inputs.enemy_fleets[enemy_index]
		var identity: String="enemy_"+str(source_enemy.get("signature","invalid_"+str(enemy_index))).sha256_text()
		enemies[identity]={"id":identity,"enemy_id":identity,"enemy_index":enemy_index,"tests":0,"wins":0,"attempts":0,"excluded":0,"avg_battle_time":null,"avg_player_hp":null,"avg_enemy_hp":null,"time_m2":0.0,"pair_ids":[],"tags":unique_tags(source_enemy.get("primary_tags",[])+source_enemy.get("secondary_tags",[])),"weapons":[],"composition":source_enemy.get("composition",{}).duplicate(true)}
		enemy_pairs[identity]=[]
	var players := {}
	var enemy_tags := {}
	var player_tags := {}
	var weapons := {}
	var actual_tests := 0
	var attempts := 0
	for row in pairs:
		if not enemy_pairs.has(row.enemy_id):enemy_pairs[row.enemy_id]=[]
		enemy_pairs[row.enemy_id].append(row)
		actual_tests+=row.tests
		attempts+=row.attempts
		add_group(enemies,row.enemy_id,row,{"enemy_id":row.enemy_id,"enemy_index":row.enemy_index,"tags":row.enemy_tags,"composition":row.composition})
		add_group(players,row.player_id,row,{"player_id":row.player_id,"tags":row.player_tags,"ship":row.ship})
		for tag in row.enemy_tags:add_group(enemy_tags,str(tag),row,{"tags":[tag]})
		for tag in row.player_tags:add_group(player_tags,str(tag),row,{"tags":[tag]})
		var kinds: Array=[{"kind":"combination","weapon":row.weapon_combination}]
		for weapon in row.weapons:kinds.append({"kind":"weapon","weapon":weapon})
		for kind in kinds:
			var scopes: Array=[{"scope":"all","target":""},{"scope":"enemy","target":row.enemy_id}]
			for tag in row.enemy_tags:scopes.append({"scope":"enemy_tag","target":tag})
			for scope in scopes:
				var metadata: Dictionary=kind.duplicate()
				metadata.merge(scope)
				add_group(weapons,JSON.stringify([kind.kind,kind.weapon,scope.scope,scope.target]),row,metadata)
	if actual_tests!=int(summary.get("aggregate",{}).get("battle_count",actual_tests)):return fail("summary_mismatch")
	if attempts!=int(summary.get("completed_count",attempts)):return fail("summary_mismatch")
	var candidates: Array=[]
	for collection in [enemies,players,enemy_tags,player_tags,weapons]:
		for value in collection.values():finish_stats(value)
	for enemy in enemies.values():
		enemy.available_configurations=inputs.player_loadouts.size()
		enemy.tested_configurations=enemy_pairs[enemy.id].filter(func(row):return row.tests>0).size()
		enemy.configuration_coverage=float(enemy.tested_configurations)/maxi(1,int(enemy.available_configurations))
		var comparisons: Array=[]
		for row in enemy_pairs[enemy.id]:
			if row.confidence!="low":comparisons.append(row)
		var rates: Array=comparisons.map(func(row):return row.win_rate)
		enemy.eligible_configurations=comparisons.size()
		enemy.configuration_win_rate=null if rates.is_empty() else rates.reduce(func(a,b):return a+b,0.0)/rates.size()
		enemy.discrimination=null if rates.size()<int(policy.min_configurations) else float(rates.max())-float(rates.min())
		enemy.discrimination_label="insufficient" if enemy.discrimination==null else "high" if enemy.discrimination>=float(policy.discrimination_high) else "general" if enemy.discrimination<=float(policy.discrimination_low) else "medium"
		enemy.strengths=[]
		enemy.weaknesses=[]
		for row in comparisons:
			var brief := {"pair_id":row.id,"player_id":row.player_id,"weapons":row.weapon_combination,"tests":row.tests,"win_rate":row.win_rate,"confidence":row.confidence}
			if row.findings.has("good"):enemy.strengths.append(brief)
			if row.findings.has("bad"):enemy.weaknesses.append(brief)
		enemy.test_focus=enemy.tags.duplicate()
		for row in comparisons:
			for tag in row.player_tags:
				if not enemy.test_focus.has(tag):enemy.test_focus.append(tag)
		enemy.candidate_reasons=[]
		enemy.candidate=true
		enemy.candidate_score=null
		add_design_fields(enemy,comparisons)
		candidates.append(enemy.duplicate(true))
	candidates.sort_custom(func(a,b):return int(a.enemy_index)<int(b.enemy_index))
	report={"schema_version":1,"source":directory,"batch_status":summary.get("status","unknown"),"policy":policy.duplicate(true),"sampling":summary.get("sampling",{}),"warnings":warnings,"interpretation":["observational_sample_only","adaptive_sampling_not_population_win_rate","weapons_cooccur_not_isolated_effect","hp_ratios_exclude_shield","wilson_is_descriptive_under_adaptive_stopping"],"tests":actual_tests,"attempts":attempts,"enemy_analysis":enemies.values(),"player_analysis":players.values(),"enemy_tags":enemy_tags.values(),"player_tags":player_tags.values(),"weapon_analysis":weapons.values(),"pair_analysis":pairs,"level_candidates":candidates}
	report.display_names=inputs.get("display_names",{}).duplicate(true)
	return report

func add_design_fields(enemy: Dictionary,comparisons: Array) -> void:
	var rules: Dictionary=policy.design
	var category := "ordinary"
	var enough: bool=enemy.confidence!="low" and comparisons.size()>=int(policy.min_configurations)
	if not enough:category="insufficient"
	elif enemy.findings.any(func(key):return key in ["long","short","excluded_results","time_variation"]):category="anomaly"
	# Sufficient time instability is an anomaly, not a claim of difficult combat.
	if enemy.tests>=int(policy.min_tests) and enemy.findings.any(func(key):return key in ["long","short","excluded_results","time_variation"]):category="anomaly"
	enemy.design_category=category
	enemy.design_confidence="low" if not enough else enemy.confidence
	enemy.design_conclusion=category if category!="ordinary" else "different" if enemy.discrimination_label=="high" else "general" if enemy.discrimination_label=="general" else "ordinary"
	enemy.design_use="loadout" if category=="ordinary" and enemy.discrimination_label=="high" else "general" if category=="ordinary" and enemy.discrimination_label=="general" else "observe"
	enemy.design_best=[]
	enemy.design_worst=[]
	if enough and enemy.discrimination!=null and enemy.discrimination>0:
		var ordered := comparisons.duplicate()
		ordered.sort_custom(func(a,b):return a.win_rate>b.win_rate if a.win_rate!=b.win_rate else a.player_index<b.player_index)
		# Disjoint ranks: don't describe one configuration as both strongest and weakest.
		var limit := mini(int(rules.top_configurations),ordered.size()/2)
		for row in ordered.slice(0,limit):enemy.design_best.append(design_configuration(row))
		ordered.reverse()
		for row in ordered.slice(0,limit):enemy.design_worst.append(design_configuration(row))

func design_configuration(row: Dictionary) -> Dictionary:
	return {"player_index":row.player_index,"weapons":row.weapons.duplicate(),"win_rate":row.win_rate,"tests":row.tests,"ship":row.ship,"pair_id":row.id}

func fail(message: String) -> Dictionary:
	error=message
	report={}
	return {"error":message}

func number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

func normalize(raw: Variant,inputs: Dictionary) -> Dictionary:
	if not raw is Dictionary:return {}
	for key in ["enemy_index","player_index"]:
		if not number(raw.get(key)) or raw[key]!=floorf(raw[key]) or raw[key]<0:return {}
	var ei := int(raw.enemy_index)
	var pi := int(raw.player_index)
	if ei>=inputs.enemy_fleets.size() or pi>=inputs.player_loadouts.size():return {}
	var enemy=inputs.enemy_fleets[ei]
	var player=inputs.player_loadouts[pi]
	# Invalid input records from the executor remain excluded diagnostics.
	if not enemy is Dictionary:enemy={}
	if not player is Dictionary:player={}
	var n=raw.get("battle_count",0)
	var wins=raw.get("wins",0)
	var attempts=raw.get("attempted_count",n)
	for value in [n,wins,attempts]:
		if not number(value) or value<0 or value!=floorf(value):return {}
	if wins>n or attempts<n:return {}
	var enemy_id := "enemy_"+str(enemy.get("signature","invalid_"+str(ei))).sha256_text()
	var player_id := str(player.get("loadout_id","invalid_"+str(pi)))
	if n>0 and raw.has("enemy_fleet_id") and raw.enemy_fleet_id!=enemy_id:return {}
	if n>0 and raw.has("player_loadout_id") and raw.player_loadout_id!=player_id:return {}
	if n==0:
		enemy_id=str(raw.get("enemy_fleet_id",enemy_id))
		player_id=str(raw.get("player_loadout_id",player_id))
	var counts := {}
	var entries=player.get("weapons",[])
	if not entries is Array:return {}
	for weapon in entries:
		if not weapon is Dictionary or not weapon.get("key") is String:return {}
		counts[weapon.key]=int(counts.get(weapon.key,0))+1
	var keys: Array=counts.keys()
	keys.sort()
	for tags in [enemy.get("primary_tags",[]),enemy.get("secondary_tags",[]),player.get("tags",[])]:
		if not tags is Array:return {}
	var et: Array=unique_tags(enemy.get("primary_tags",[])+enemy.get("secondary_tags",[]))
	var pt: Array=unique_tags(player.get("tags",[]))
	var row := {"id":enemy_id+"/"+player_id,"enemy_id":enemy_id,"player_id":player_id,"enemy_index":ei,"player_index":pi,"enemy_tags":et,"player_tags":pt,"tags":unique_tags(et+pt),"weapons":keys,"weapon_counts":counts,"weapon_combination":" + ".join(keys),"ship":player.get("ship",""),"equipment":player.get("equipment",{}),"stats":player.get("stats",{}),"composition":enemy.get("composition",{}),"tests":int(n),"wins":int(wins),"attempts":int(attempts),"excluded":int(attempts-n),"errors":raw.get("errors",0),"timeouts":raw.get("timeouts",0),"stopped":raw.get("stopped",0),"pair_ids":[],"time_m2":raw.get("time_m2",null),"test_reasons":raw.get("test_reasons",[]),"stop_reason":raw.get("stop_reason","")}
	row.pair_ids=[row.id]
	for key in ["battle_time","player_hp","enemy_hp"]:
		var original: String={"battle_time":"avg_battle_time","player_hp":"avg_player_hp_ratio","enemy_hp":"avg_enemy_hp_ratio"}[key]
		var value=raw.get(original)
		if n>0 and (not number(value) or value<0 or (key!="battle_time" and value>1)):return {}
		row["avg_"+key]=value if n>0 else null
	if row.time_m2!=null and (not number(row.time_m2) or row.time_m2<0):return {}
	if row.time_m2==null and not warnings.has("legacy_time_variance_unknown"):warnings.append("legacy_time_variance_unknown")
	finish_stats(row)
	return row

func unique_tags(values: Array) -> Array:
	var tags: Array=[]
	for value in values:
		if value is String and not tags.has(value):tags.append(value)
	tags.sort()
	return tags

func add_group(groups: Dictionary,key: String,row: Dictionary,metadata: Dictionary) -> void:
	if not groups.has(key):
		groups[key]={"id":key,"tests":0,"wins":0,"attempts":0,"excluded":0,"avg_battle_time":null,"avg_player_hp":null,"avg_enemy_hp":null,"time_m2":0.0,"pair_ids":[],"tags":[],"weapons":[]}
		groups[key].merge(metadata,true)
	var group: Dictionary=groups[key]
	var old := int(group.tests)
	group.tests+=row.tests
	group.wins+=row.wins
	group.attempts+=row.attempts
	group.excluded+=row.excluded
	group.pair_ids.append(row.id)
	group.tags=unique_tags(group.tags+metadata.get("tags",row.tags))
	group.weapons=unique_tags(group.weapons+row.weapons)
	if row.tests==0:return
	if group.time_m2==null or row.time_m2==null:group.time_m2=null
	else:
		var delta := float(row.avg_battle_time)-(float(group.avg_battle_time) if old>0 else 0.0)
		group.time_m2+=float(row.time_m2)+delta*delta*old*int(row.tests)/int(group.tests)
	for metric in ["avg_battle_time","avg_player_hp","avg_enemy_hp"]:
		group[metric]=((float(group[metric])*old if old>0 else 0.0)+float(row[metric])*int(row.tests))/int(group.tests)

func finish_stats(row: Dictionary) -> void:
	var n := int(row.tests)
	row.win_rate=null if n==0 else float(row.wins)/n
	row.interval_low=null
	row.interval_high=null
	row.time_cv=null
	row.outcome_variance=null
	row.confidence="low"
	row.findings=[]
	if n==0:row.findings=["insufficient"];return
	var p := float(row.win_rate)
	var z2 := float(policy.wilson_z)*float(policy.wilson_z)
	var center := (p+z2/(2*n))/(1+z2/n)
	var half := sqrt(p*(1-p)/n+z2/(4*n*n))*float(policy.wilson_z)/(1+z2/n)
	row.interval_low=maxf(0,center-half)
	row.interval_high=minf(1,center+half)
	row.outcome_variance=p*(1-p)
	if row.time_m2!=null and n>1:row.time_cv=sqrt(maxf(0,float(row.time_m2)/(n-1)))/maxf(0.000001,float(row.avg_battle_time))
	var excluded_ratio := float(row.excluded)/maxi(1,int(row.attempts))
	if n>=int(policy.min_tests) and 2*half<=float(policy.max_interval_width) and excluded_ratio<=float(policy.max_excluded_ratio):row.confidence="high" if n>=int(policy.high_tests) else "medium"
	if row.confidence=="low":row.findings.append("insufficient")
	else:
		if p>=float(policy.good_rate) and row.interval_low>0.5:row.findings.append("good")
		if p<=float(policy.bad_rate) and row.interval_high<0.5:row.findings.append("bad")
		if p>=float(policy.boundary_low) and p<=float(policy.boundary_high):row.findings.append("boundary")
		if p>=float(policy.dominant_rate):row.findings.append("dominant")
		if p<=float(policy.hopeless_rate):row.findings.append("hopeless")
	if row.outcome_variance>=float(policy.outcome_variance):row.findings.append("outcome_variation")
	if row.time_cv!=null and row.time_cv>=float(policy.time_cv):row.findings.append("time_variation");row.confidence="low"
	if row.avg_battle_time<float(policy.short_seconds):row.findings.append("short")
	if row.avg_battle_time>float(policy.long_seconds):row.findings.append("long")
	if excluded_ratio>float(policy.max_excluded_ratio):row.findings.append("excluded_results")
	if row.confidence=="low":
		row.findings=row.findings.filter(func(key):return key not in ["good","bad","dominant","hopeless","boundary"])
		if not row.findings.has("insufficient"):row.findings.append("insufficient")

func export_files(directory: String) -> String:
	if report.is_empty():return "no_report"
	# Outputs belong to this batch; source inputs, trials and summaries stay untouched.
	var json := FileAccess.open(directory.path_join("analysis_summary.json"),FileAccess.WRITE)
	if json==null:return "write_failed"
	json.store_string(JSON.stringify(report,"  "))
	json.flush()
	if json.get_error()!=OK:return "write_failed"
	for name in ["enemy_analysis","player_analysis","weapon_analysis","pair_analysis","level_candidates"]:
		var file := FileAccess.open(directory.path_join(name+".csv"),FileAccess.WRITE)
		if file==null:return "write_failed"
		var columns: Array=["id","enemy_id","player_id","enemy_index","scope","target","kind","weapon","tags","weapons","weapon_combination","weapon_counts","ship","equipment","composition","tests","wins","attempts","excluded","win_rate","avg_battle_time","avg_player_hp","avg_enemy_hp","confidence","interval_low","interval_high","findings","configuration_win_rate","configuration_coverage","discrimination","discrimination_label","eligible_configurations","candidate","candidate_score","candidate_reasons","strengths","weaknesses","test_focus","pair_ids"]
		file.store_csv_line(PackedStringArray(columns))
		for row in report[name]:
			var values := PackedStringArray()
			for key in columns:
				var value=row.get(key)
				var text := "" if value==null else JSON.stringify(value) if value is Array or value is Dictionary else str(value)
				if text.begins_with("=") or text.begins_with("+") or text.begins_with("-") or text.begins_with("@"):text="'"+text
				values.append(text)
			file.store_csv_line(values)
		file.flush()
		if file.get_error()!=OK:return "write_failed"
	return ""
