extends RefCounted
## Bounded, deterministic sampling and explainable scheduling; no combat rules.
var policy: Dictionary
var config: Dictionary
var pairs: Array = []
var covered := {}
var random := RandomNumberGenerator.new()
var theoretical := 0
var similar_skipped := 0
var quota_skipped := 0
var stable_count := 0
var tested_pairs := 0
var representatives := {"enemy":[],"player":[]}

func _init(rules: Dictionary, options: Dictionary) -> void:
	policy=rules
	config=options
	random.seed=int(config.seed)

func labels(row: Variant, side: String) -> Array:
	if not row is Dictionary:return ["invalid"]
	var raw=row.get("primary_tags",[]) if side=="enemy" else row.get("tags",[])
	var tags: Array=[]
	if raw is Array:
		for tag in raw:
			if tag is String:tags.append(tag)
	if side=="player":
		tags.append("type:"+str(row.get("generation_type","unknown")))
		var weapons := {}
		var raw_weapons=row.get("weapons",[])
		if raw_weapons is Array:
			for weapon in raw_weapons:
				if weapon is Dictionary:weapons[str(weapon.get("key","invalid"))]=true
		var keys: Array=weapons.keys()
		keys.sort()
		tags.append("weapons:"+",".join(keys))
	if tags.is_empty():tags.append("untagged")
	tags.sort()
	return tags

func similar(a: Variant,b: Variant) -> bool:
	if not a is Dictionary or not b is Dictionary:return false
	if a.get("signature","")==b.get("signature","") and a.has("signature"):return true
	if not a.get("feature_scores",{}) is Dictionary or not b.get("feature_scores",{}) is Dictionary or not a.get("stats",{}) is Dictionary or not b.get("stats",{}) is Dictionary:return false
	var scores: Dictionary=a.get("feature_scores",{})
	if scores.is_empty():return false
	for key in scores:
		if not (scores[key] is int or scores[key] is float) or not (b.get("feature_scores",{}).get(key,0) is int or b.get("feature_scores",{}).get(key,0) is float):return false
		if absf(float(scores[key])-float(b.get("feature_scores",{}).get(key,0)))>float(policy.similarity):return false
	for key in a.get("stats",{}):
		if not (a.stats[key] is int or a.stats[key] is float) or not (b.get("stats",{}).get(key,0) is int or b.get("stats",{}).get(key,0) is float):return false
		var x := float(a.stats[key])
		var y := float(b.get("stats",{}).get(key,0))
		if absf(x-y)/maxf(1,maxf(absf(x),absf(y)))>float(policy.stat_similarity):return false
	return true

func sample(rows: Array,side: String) -> Array:
	var buckets := {}
	for index in range(rows.size()):
		var key := JSON.stringify(labels(rows[index],side))
		if not buckets.has(key):buckets[key]=[]
		buckets[key].append(index)
	var keys: Array=buckets.keys()
	keys.sort()
	shuffle(keys)
	var selected: Array=[]
	for key in keys:
		var pool: Array=buckets[key]
		shuffle(pool)
		var kept: Array=[]
		for index in pool:
			if kept.any(func(other):return similar(rows[index],rows[other])):
				similar_skipped+=1
			elif kept.size()<int(config.samples_per_tag):kept.append(index)
			else:quota_skipped+=1
		buckets[key]=kept
	# Round-robin strata ensures each gets a first representative before extras.
	for round_index in range(int(config.samples_per_tag)):
		for key in keys:
			if buckets[key].size()>round_index:selected.append(buckets[key][round_index])
	return selected

func shuffle(values: Array) -> void:
	for i in range(values.size()-1,0,-1):
		var j := random.randi_range(0,i)
		var value=values[i]
		values[i]=values[j]
		values[j]=value

func build(enemies: Array,players: Array) -> void:
	theoretical=enemies.size()*players.size()
	if config.has("explicit_pairs"):
		var explicit_seen := {}
		for entry in config.explicit_pairs:
			add_pair(int(entry.enemy_index),int(entry.player_index),false,enemies,players,explicit_seen,int(policy.max_pairs))
			pairs[-1].target_runs=int(entry.runs)
		return
	representatives.enemy=sample(enemies,"enemy")
	representatives.player=sample(players,"player")
	var seen := {}
	var limit := mini(int(policy.max_pairs),int(config.max_total))
	for focus in config.get("focus_pairs",[]):add_pair(int(focus.enemy_index),int(focus.player_index),true,enemies,players,seen,limit)
	var es: Array=representatives.enemy
	var ps: Array=representatives.player
	if es.is_empty() or ps.is_empty():return
	# Cover each representative once without materializing their Cartesian product.
	for i in range(mini(limit,maxi(es.size(),ps.size()))):add_pair(es[i%es.size()],ps[i%ps.size()],false,enemies,players,seen,limit)
	var attempts := 0
	while pairs.size()<mini(limit,es.size()*ps.size()) and attempts<limit*int(policy.candidate_attempts):
		attempts+=1
		add_pair(es[random.randi_range(0,es.size()-1)],ps[random.randi_range(0,ps.size()-1)],false,enemies,players,seen,limit)

func add_pair(e: int,p: int,focus: bool,enemies: Array,players: Array,seen: Dictionary,limit: int) -> void:
	var key := "%d:%d" % [e,p]
	if seen.has(key):
		if focus:pairs[int(seen[key])].focus=true
		return
	if pairs.size()>=limit:return
	seen[key]=pairs.size()
	var et := labels(enemies[e],"enemy")
	var pt := labels(players[p],"player")
	var coverage: Array=[]
	for tag in et:coverage.append("enemy:"+str(tag))
	for tag in pt:coverage.append("player:"+str(tag))
	# Opposing tag combinations are also coverage targets, not just individual tags.
	coverage.append("pair:"+JSON.stringify([et,pt]))
	pairs.append({"enemy_index":e,"player_index":p,"enemy_tags":et,"player_tags":pt,"coverage":coverage,"focus":focus,"summary":{},"streak":0,"last_win":null,"time_mean":0.0,"time_m2":0.0,"reasons":[],"stop_reason":"","stable":false})

func time_cv(pair: Dictionary) -> float:
	var n := int(pair.summary.get("battle_count",0))
	return sqrt(maxf(0,float(pair.time_m2)/maxi(1,n-1)))/maxf(0.000001,float(pair.time_mean))

func reasons(pair: Dictionary) -> Array:
	var summary: Dictionary=pair.summary
	var result: Array=[]
	if pair.has("target_runs"):
		return ["coarse"] if int(summary.get("attempted_count",0))<int(pair.target_runs) else []
	if pair.focus and not config.get("focus_stable_stop",false):result.append("manual")
	if int(summary.get("attempted_count",0))<int(config.runs):return result+["coarse"]
	if int(summary.get("timeouts",0))>0:result.append("time_anomaly")
	if int(summary.get("battle_count",0))==0:return result
	var rate := float(summary.win_rate)
	if rate>=float(policy.boundary_low) and rate<=float(policy.boundary_high):result.append("boundary")
	if rate*(1-rate)>=float(policy.variance):result.append("outcome_variance")
	if time_cv(pair)>=float(policy.time_cv) or float(summary.avg_battle_time)<float(policy.short_seconds) or float(summary.avg_battle_time)>float(policy.long_seconds):result.append("time_anomaly")
	for other in pairs:
		if other==pair or int(other.summary.get("battle_count",0))<int(config.runs):continue
		if (other.enemy_tags==pair.enemy_tags and other.player_tags!=pair.player_tags) or (other.player_tags==pair.player_tags and other.enemy_tags!=pair.enemy_tags):
			if absf(float(other.summary.win_rate)-rate)>=float(policy.tag_difference):
				result.append("tag_difference")
				break
	return result

func choose() -> int:
	var best := -1
	var rank := 99
	var runs := 2147483647
	stable_count=0
	for i in range(pairs.size()):
		var pair: Dictionary=pairs[i]
		var count := int(pair.summary.get("attempted_count",0))
		if pair.stable:stable_count+=1
		if pair.stop_reason=="error" or pair.stable:continue
		if count>=int(config.max_per_pair):
			pair.stop_reason="pair_budget"
			continue
		pair.reasons=reasons(pair)
		if pair.reasons.is_empty():pair.stop_reason="coarse_complete";continue
		pair.stop_reason=""
		var uncovered: bool=pair.coverage.any(func(key):return not covered.has(key))
		var priority := 0 if pair.focus else 1 if uncovered else 2 if not pair.reasons.has("coarse") else 3
		if priority<rank or (priority==rank and count<runs):best=i;rank=priority;runs=count
	return best

func observe(pair: Dictionary,row: Dictionary) -> void:
	if int(pair.summary.attempted_count)==1:tested_pairs+=1
	if row.status=="error":pair.stop_reason="error";return
	if row.status not in ["win","loss"]:return
	for key in pair.coverage:covered[key]=true
	pair.streak=int(pair.streak)+1 if pair.last_win==row.win else 1
	pair.last_win=row.win
	var delta := float(row.battle_time)-float(pair.time_mean)
	pair.time_mean+=delta/int(pair.summary.battle_count)
	pair.time_m2+=delta*(float(row.battle_time)-float(pair.time_mean))
	var s: Dictionary=pair.summary
	var extreme: bool=float(s.win_rate)<=float(policy.stable_low) or float(s.win_rate)>=float(policy.stable_high)
	var margin: float=s.avg_player_hp_ratio if row.win else s.avg_enemy_hp_ratio
	pair.stable=not pair.has("target_runs") and (not pair.focus or config.get("focus_stable_stop",false)) and int(s.attempted_count)>=int(config.runs) and int(pair.streak)>=int(policy.stable_streak) and extreme and margin>=float(policy.stable_hp) and time_cv(pair)<=float(policy.stable_time_cv) and int(s.timeouts)==0 and float(s.avg_battle_time)>=float(policy.short_seconds) and float(s.avg_battle_time)<=float(policy.long_seconds)
	if pair.stable:pair.stop_reason="stable"

func report() -> Dictionary:
	return {"theoretical_pairs":theoretical,"sampled_pairs":pairs.size(),"tested_pairs":tested_pairs,"stable_stopped":pairs.filter(func(pair):return pair.stable).size(),"similar_skipped":similar_skipped,"quota_skipped":quota_skipped,"covered_tags":covered.keys(),"representatives":representatives}
