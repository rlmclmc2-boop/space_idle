extends RefCounted
## Read-only analysis of ShipDatabase groups. Never constructs BattleGame or entities.

const POLICY_PATH := "res://data/enemy_fleet_analysis.json"
const FEATURES := ["mobility", "durability", "armor", "shield", "range", "burst", "sustained", "aoe", "single_target", "fleet_size"]
const GENERATION_DEFAULTS := {
	"size_thresholds":{"medium":3.0,"large":4.0,"superlarge":6.0},
	"count_caps":{"small":10,"medium":8,"large":5,"superlarge":3},
	"type_caps":{"small":5,"medium":5,"large":3,"superlarge":2},
	"high_power_ratio":0.55,"max_high_power_ships":1,
	"escort_power_ratio":{"large":0.5,"superlarge":0.25},
	"superlarge_solo_weight":6.0,"superlarge_escort_weight":0.25,
	"small_solo_weight":0.1,
	"max_ship_difficulty_weight":1.0,"structure_weight":0.6,
	"dominant_share":0.6,"type_count_breaks":[6,10],"type_caps_by_count":[2,3,4],
	"unrelated_family_cap":2,"unrelated_role_cap":2,"core_power_ratio":1.5,
	"medium_escort_power_ratio":0.5,"medium_mixed_escort_chance":0.25,
	"attempts_per_plan":200,
	"archetype_weights":{"solo":1.0,"swarm":3.0,"paired":1.0,"rows":1.0,"squad":3.0,"core_escort":2.0}
}
var db: ShipDatabase
var policy: Dictionary
var projections := {}
var reference := {"durability":0.0, "burst":0.0, "sustained":0.0, "hull":0.0}
var slot_count := 0
var fingerprint := ""
var error := ""

func _init(database: ShipDatabase, settings: Dictionary = {}) -> void:
	db = database
	policy = settings.duplicate(true) if not settings.is_empty() else JSON.parse_string(FileAccess.get_file_as_string(POLICY_PATH))
	var generation: Dictionary=policy.get("generation",{}).duplicate(true)
	for key in GENERATION_DEFAULTS:
		if not generation.has(key):generation[key]=GENERATION_DEFAULTS[key]
		elif GENERATION_DEFAULTS[key] is Dictionary and generation[key] is Dictionary:
			for part in GENERATION_DEFAULTS[key]:
				if not generation[key].has(part):generation[key][part]=GENERATION_DEFAULTS[key][part]
	policy.generation=generation
	# The existing group slots remain the combat input; formation coordinates are analysis metadata.
	for group in db.groups.values():
		slot_count = maxi(slot_count, group.slots.size())
	var ids := db.enemies.keys()
	ids.sort()
	for id in ids:
		var row: Dictionary = db.enemies[id]
		var stats := {"durability":float(row.health), "burst":0.0, "sustained":0.0, "hull":float(row.size), "armor":0.0, "single_target":0.0}
		var families: Array[String]=[]
		if int(row.armourType) > 0:
			stats.armor = clampf(float(db.config.dmgReduce), 0, 1)
		for entry in row.equipment:
			var family:=str(entry.name).trim_suffix("_mon").trim_suffix("-mon")
			if not families.has(family):families.append(family)
			var weapon := db.enemy_weapon(str(entry.name))
			if weapon.is_empty() or weapon.get("cd") == null or float(weapon.cd) <= 0 or weapon.get("dmg") == null:
				error = "invalid_weapon"
				continue
			var damage := ceilf(float(weapon.dmg) * float(row.dmgMultiple))
			var peak := damage
			if str(entry.name).replace("_mon", "").replace("-mon", "") == "longLaser":
				# Hostile beam uses the same resolved parameters; no player missile salvo.
				peak *= float(weapon.para2)
				if float(weapon.para1) <= 0:
					damage = peak
			stats.burst += damage
			stats.sustained += peak / float(weapon.cd)
			stats.single_target = 1.0
		stats.strength = (stats.durability * float(policy.strength.health_weight) + stats.sustained * float(policy.strength.firepower_seconds)) / float(policy.strength.unit)
		families.sort()
		stats.family="+".join(families)
		reference.strength=maxf(float(reference.get("strength",0.0)),float(stats.strength))
		for key in reference:
			reference[key] = maxf(reference[key], stats[key])
		projections[str(id)] = stats
	fingerprint = JSON.stringify({"enemies":db.enemies,"equipment":db.equipment,"config":db.config,"slots":slot_count,"policy":policy}).sha256_text()

func validate(options: Dictionary) -> String:
	if not error.is_empty():return error
	for key in ["count", "min_count", "max_count", "seed", "min_strength", "max_strength"]:
		var value = options.get(key)
		if not (value is int or value is float) or not is_finite(float(value)):return "invalid_input"
	for key in ["count", "min_count", "max_count", "seed"]:
		if float(options[key]) != floorf(float(options[key])):return "invalid_input"
	if options.count < 1 or options.count > policy.limits.max_results:return "invalid_input"
	if options.min_count < 1 or options.max_count > slot_count or options.min_count > options.max_count:return "invalid_input"
	if options.min_strength < 0 or options.min_strength > options.max_strength:return "invalid_input"
	if absf(float(options.seed)) > float(policy.limits.max_seed):return "invalid_input"
	if not options.get("available_enemies") is Array or options.available_enemies.is_empty():return "empty_pool"
	for id in options.available_enemies:
		if not projections.has(str(id)):return "invalid_enemy"
	return ""

func generate(options: Dictionary) -> Dictionary:
	var result := {"results":[], "attempts":0, "status":"complete", "requested":options.get("count",0), "batch_seed":options.get("seed",0), "config_fingerprint":fingerprint}
	var invalid := validate(options)
	if not invalid.is_empty():
		result.status = invalid
		return result
	var pool: Array = []
	for id in options.available_enemies:
		if not pool.has(str(id)):pool.append(str(id))
	pool.sort()
	var minimum := INF
	var maximum := 0.0
	for id in pool:
		minimum = minf(minimum, projections[id].strength)
		maximum = maxf(maximum, projections[id].strength)
	var counts: Array[int] = []
	for count in range(int(options.min_count), int(options.max_count) + 1):
		if (count+float(policy.generation.max_ship_difficulty_weight))*minimum <= options.max_strength and (count+float(policy.generation.max_ship_difficulty_weight))*maximum >= options.min_strength:
			counts.append(count)
	if counts.is_empty():
		result.status = "infeasible"
		return result
	var plans:=build_plans(pool,counts)
	if plans.is_empty():
		result.status="infeasible"
		return result
	var random := RandomNumberGenerator.new()
	random.seed = int(options.seed)
	var seen := {}
	var budget := mini(mini(int(policy.limits.max_attempts),int(options.count)*int(policy.limits.attempts_per_result)),plans.size()*int(policy.generation.attempts_per_plan))
	while result.results.size() < int(options.count) and result.attempts < budget:
		result.attempts += 1
		# Each candidate has its own saved seed. It can be replayed independently.
		var candidate_seed := int(random.randi())
		var group := sample(candidate_seed, pool, counts, plans)
		if group.is_empty():continue
		var signature := signature_for(group)
		if seen.has(signature):continue
		var strength := 0.0
		for id in group.slots:
			if id != null:strength += float(projections[str(int(id))].strength)
		var max_power := 0.0
		for id in group.slots:
			if id != null:max_power=maxf(max_power,float(projections[str(int(id))].strength))
		var difficulty := strength+max_power*float(policy.generation.max_ship_difficulty_weight)
		if difficulty < float(options.min_strength) or difficulty > float(options.max_strength):continue
		var analyzed := analyze(group)
		if float(analyzed.get("formation_score",0)) < float(policy.formation.min_score):continue
		seen[signature] = true
		analyzed.merge({"seed":candidate_seed, "batch_seed":int(options.seed), "generation_options":options.duplicate(true)})
		result.results.append(analyzed)
	if result.results.size() < int(options.count):result.status = "attempt_limit"
	return result

func template_kinds(archetype: String) -> Array:
	if policy.formation.templates.size()==1:return [str(policy.formation.templates[0].id)]
	match archetype:
		"swarm":return ["paired","formation_rows","loose_symmetric","double_wings"]
		"squad":return ["paired","front_back","loose_symmetric"]
		"rows":return ["formation_rows","front_back"]
		"paired":return ["paired","symmetric"]
		"core_escort":return ["core_wings","heavy_guard","front_back"]
	return ["symmetric"]

func build_plans(pool: Array,counts: Array[int]) -> Array:
	var plans: Array=[]
	for anchor_value in pool:
		var anchor:=str(anchor_value)
		var scale:=scale_for(anchor)
		var same_tier: Array=[]
		var weak_escorts: Array=[]
		for value in pool:
			var id:=str(value)
			if float(projections[id].hull)==float(projections[anchor].hull):same_tier.append(id)
			var ratio:=float(policy.generation.escort_power_ratio[scale]) if policy.generation.escort_power_ratio.has(scale) else float(policy.generation.medium_escort_power_ratio)
			if id!=anchor and scale_rank(scale_for(id))<scale_rank(scale) and float(projections[id].strength)<=float(projections[anchor].strength)*ratio:weak_escorts.append(id)
		var archetypes: Array=["solo"]
		if scale=="small":archetypes.append_array(["swarm","paired","rows"])
		elif scale=="medium":archetypes.append_array(["squad","paired","rows","core_escort"])
		else:archetypes.append("core_escort")
		for archetype in archetypes:
			var allowed: Array=weak_escorts if archetype=="core_escort" else [anchor] if archetype=="swarm" or archetype=="solo" else same_tier
			if archetype=="core_escort" and allowed.is_empty():continue
			var valid_counts: Array[int]=[]
			for count in counts:
				if count>int(policy.generation.count_caps[scale]):continue
				if archetype=="solo" and count!=1:continue
				if archetype!="solo" and count<2:continue
				if archetype=="rows" and count<4:continue
				if archetype=="core_escort" and (count<3 or count%2==0):continue
				var fits:=false
				for entry in policy.formation.templates:
					if template_kinds(archetype).has(str(entry.id)) and count>=int(entry.min_count):fits=true;break
				if fits:valid_counts.append(count)
			if valid_counts.is_empty():continue
			var weight: float=float(policy.generation.archetype_weights.get(archetype,1.0))
			if scale=="small" and archetype=="solo" and counts.size()>1:weight*=float(policy.generation.small_solo_weight)
			if scale=="superlarge":weight*=float(policy.generation.superlarge_solo_weight) if archetype=="solo" else float(policy.generation.superlarge_escort_weight)
			plans.append({"anchor":anchor,"scale":scale,"archetype":archetype,"pool":allowed,"counts":valid_counts,"weight":weight})
	return plans

func sample(candidate_seed: int,pool: Array,counts: Array[int],prepared_plans: Array=[]) -> Dictionary:
	var plans: Array=prepared_plans if not prepared_plans.is_empty() else build_plans(pool,counts)
	if plans.is_empty():return {}
	var random:=RandomNumberGenerator.new()
	random.seed=candidate_seed
	var total:=0.0
	for plan in plans:total+=float(plan.weight)
	var roll:=random.randf()*total
	var chosen_plan: Dictionary=plans.back()
	for plan in plans:
		roll-=float(plan.weight)
		if roll<=0:chosen_plan=plan;break
	var anchor: String=str(chosen_plan.anchor)
	var archetype: String=str(chosen_plan.archetype)
	var count: int=chosen_plan.counts[random.randi_range(0,chosen_plan.counts.size()-1)]
	var members: Array[String]=[]
	if archetype=="core_escort":
		members.append(anchor)
		var escort: String=str(chosen_plan.pool[random.randi_range(0,chosen_plan.pool.size()-1)])
		for i in range(count-1):members.append(escort)
		if chosen_plan.scale=="medium" and count>=5 and random.randf()<float(policy.generation.medium_mixed_escort_chance):
			var alternatives: Array=[]
			for value in chosen_plan.pool:
				if str(value)!=escort and str(projections[str(value)].family)!=str(projections[escort].family):alternatives.append(str(value))
			if not alternatives.is_empty():
				var other: String=str(alternatives[random.randi_range(0,alternatives.size()-1)])
				members[count-1]=other
				members[count-2]=other
	else:
		var secondary: Array=[]
		for value in chosen_plan.pool:
			if str(value)!=anchor and str(projections[str(value)].family)!=str(projections[anchor].family):secondary.append(str(value))
		var minority:=0
		if not secondary.is_empty():minority=random.randi_range(0,count-ceili(float(count)*float(policy.generation.dominant_share)))
		for i in range(count-minority):members.append(anchor)
		if minority>0:
			var other: String=str(secondary[random.randi_range(0,secondary.size()-1)])
			for i in range(minority):members.append(other)
	if not valid_composition(members,chosen_plan):return {}
	var template:=choose_template(count,random,template_kinds(archetype))
	if template.is_empty():return {}
	var placements:=layout_positions(count,str(template.id),random)
	var remaining: Dictionary={}
	for id in members:remaining[id]=int(remaining.get(id,0))+1
	for placement in placements:
		if placement.get("center",false):placement.id=int(anchor);remaining[anchor]-=1
	for pair in range(count/2):
		var left: Dictionary=placements[pair*2]
		var right: Dictionary=placements[pair*2+1]
		var first:=take_grouped(remaining)
		if first.is_empty():return {}
		left.id=int(first)
		remaining[first]-=1
		var second:=take_grouped(remaining)
		if second.is_empty():return {}
		right.id=int(second)
		remaining[second]-=1
	placements.sort_custom(func(a,b):return a.x<b.x if a.x!=b.x else a.y<b.y)
	var slots: Array=[]
	slots.resize(slot_count)
	var positions: Array=[]
	for i in range(placements.size()):
		var slot:=mini(slot_count-1,int(floor((i+0.5)*slot_count/count)))
		var placement: Dictionary=placements[i]
		slots[slot]=placement.id
		positions.append({"slot":slot,"id":placement.id,"x":placement.x,"y":placement.y,"pair":placement.get("pair",-1),"role":placement.role})
	return {"description":"","slots":slots,"formation_type":template.id,"formation_positions":positions}

func take_grouped(remaining: Dictionary) -> String:
	var best: String=""
	var amount:=0
	for id in remaining:
		if int(remaining[id])>amount:best=str(id);amount=int(remaining[id])
	return best

func choose_template(count: int,random: RandomNumberGenerator,allowed: Array=[]) -> Dictionary:
	var eligible: Array=[]
	var total:=0.0
	for entry in policy.formation.templates:
		if count<int(entry.min_count) or not allowed.has(str(entry.id)):continue
		total+=float(entry.weight)
		eligible.append(entry)
	if eligible.is_empty():return {}
	var roll:=random.randf()*total
	for entry in eligible:
		roll-=float(entry.weight)
		if roll<=0:return entry
	return eligible.back()

func layout_positions(count: int,kind: String,random: RandomNumberGenerator) -> Array:
	var placements: Array=[]
	for pair in range(count/2):
		var x:=float(pair+1)
		var y:=1.0
		var role:="any"
		match kind:
			"core_wings":
				y=1.0 if pair==0 else 0.0
				role="guard" if pair==0 else "wing"
			"front_back":
				x=float(1+int(pair/2))
				y=2.0 if pair%2==0 else 0.0
				role="front" if pair%2==0 else "back"
			"double_wings":
				x=float(3+int(pair/2))
				y=1.0 if pair%2==0 else 0.0
				role="wing"
			"heavy_guard":
				y=2.0 if pair<2 else 0.0
				role="guard" if pair<2 else "wing"
			"formation_rows":
				x=float(1+int(pair/3))
				y=2.0-float(pair%3)
				role="front" if y==2.0 else "back" if y==0.0 else "any"
			"loose_symmetric":
				y=float(pair%3)
				role="wing" if pair>=2 else "any"
		var jitter: float=float(policy.formation.position_jitter)
		var left: Dictionary={"x":-x+random.randf_range(-jitter,jitter),"y":y,"role":role,"side":"left","pair":pair}
		var right: Dictionary={"x":x+random.randf_range(-jitter,jitter),"y":y,"role":role,"side":"right","pair":pair}
		if kind=="loose_symmetric" and random.randf()<float(policy.formation.row_shift_chance):right.y=clampf(right.y+random.randf_range(-0.35,0.35),0,2)
		placements.append(left)
		placements.append(right)
	if count%2==1:
		placements.append({"x":0.0,"y":2.0 if kind=="heavy_guard" or kind=="front_back" else 1.0,"role":"core","center":true,"side":"center","pair":-1})
	return placements

func scale_for(id: String) -> String:
	var size:=float(projections[id].hull)
	if size>=float(policy.generation.size_thresholds.superlarge):return "superlarge"
	if size>=float(policy.generation.size_thresholds.large):return "large"
	if size>=float(policy.generation.size_thresholds.medium):return "medium"
	return "small"

func scale_rank(scale: String) -> int:
	return ["small","medium","large","superlarge"].find(scale)

func role_for(id: String) -> String:
	var scale:=scale_for(id)
	if scale=="large" or scale=="superlarge":return "core"
	if scale=="small":return "wing"
	return "front" if float(projections[id].armor)>0 else "line"

func type_cap_for(count: int,archetype: String,scale: String) -> int:
	var breaks: Array=policy.generation.type_count_breaks
	var caps: Array=policy.generation.type_caps_by_count
	var cap: int=int(caps[0]) if count<=int(breaks[0]) else int(caps[1]) if count<=int(breaks[1]) else int(caps[2])
	if archetype=="core_escort" and scale=="medium":cap+=1
	if scale=="large" or scale=="superlarge":cap=mini(cap,2)
	return mini(cap,int(policy.generation.type_caps[scale]))

func valid_composition(members: Array[String],plan: Dictionary) -> bool:
	var count:=members.size()
	var archetype:=str(plan.archetype)
	if not ["solo","swarm","paired","rows","squad","core_escort"].has(archetype):return false
	if (archetype=="solo")!=(count==1):return false
	if archetype=="rows" and count<4:return false
	if archetype=="core_escort" and (count<3 or count%2==0):return false
	if count<1 or count>int(policy.generation.count_caps[plan.scale]):return false
	var composition: Dictionary={}
	var families: Dictionary={}
	var roles: Dictionary={}
	var scales: Dictionary={}
	var variants: Dictionary={}
	var high_count:=0
	for id in members:
		if not projections.has(id):return false
		composition[id]=int(composition.get(id,0))+1
		var family:=str(projections[id].family)
		families[family]=int(families.get(family,0))+1
		if not variants.has(family):variants[family]={}
		variants[family][id]=true
		var role:=role_for(id)
		roles[role]=int(roles.get(role,0))+1
		var scale:=scale_for(id)
		scales[scale]=int(scales.get(scale,0))+1
		if float(projections[id].strength)>=float(reference.strength)*float(policy.generation.high_power_ratio):high_count+=1
	if composition.size()>type_cap_for(count,str(plan.archetype),str(plan.scale)):return false
	if archetype=="swarm" and composition.size()!=1:return false
	if families.size()>int(policy.generation.unrelated_family_cap) or roles.size()>int(policy.generation.unrelated_role_cap):return false
	if high_count>int(policy.generation.max_high_power_ships):return false
	var dominant:=0
	for buckets in [families,roles,scales]:
		for amount in buckets.values():dominant=maxi(dominant,int(amount))
	if float(dominant)/float(count)<float(policy.generation.dominant_share):return false
	var anchor:=str(plan.anchor)
	if archetype=="core_escort":
		if int(composition.get(anchor,0))!=1:return false
		var escort_types:=composition.size()-1
		if (plan.scale=="large" or plan.scale=="superlarge") and escort_types>1:return false
		for id in composition:
			if id==anchor:continue
			if float(projections[anchor].strength)<float(projections[id].strength)*float(policy.generation.core_power_ratio):return false
			if (plan.scale=="large" or plan.scale=="superlarge") and float(projections[id].strength)>float(projections[anchor].strength)*float(policy.generation.escort_power_ratio[plan.scale]):return false
	else:
		for id in composition:
			if float(projections[id].hull)!=float(projections[anchor].hull):return false
	for family in variants:
		if variants[family].size()<2:continue
		if archetype!="core_escort" or not variants[family].has(anchor):return false
		if variants[family].size()>2:return false
	return true

func replay(record: Dictionary) -> Dictionary:
	if record.get("config_fingerprint", "") != fingerprint:return {"error":"config_changed"}
	var options: Dictionary = record.get("generation_options", {})
	var invalid := validate(options)
	if not invalid.is_empty():return {"error":invalid}
	var pool: Array = []
	for id in options.available_enemies:
		if not pool.has(str(id)):pool.append(str(id))
	pool.sort()
	var minimum := INF
	var maximum := 0.0
	for id in pool:
		minimum = minf(minimum, projections[id].strength)
		maximum = maxf(maximum, projections[id].strength)
	var counts: Array[int] = []
	for count in range(int(options.min_count),int(options.max_count)+1):
		if (count+float(policy.generation.max_ship_difficulty_weight))*minimum<=options.max_strength and (count+float(policy.generation.max_ship_difficulty_weight))*maximum>=options.min_strength:counts.append(count)
	if counts.is_empty():return {"error":"infeasible"}
	var result := analyze(sample(int(record.seed),pool,counts))
	result.merge({"seed":int(record.seed),"batch_seed":int(options.seed),"generation_options":options.duplicate(true)})
	return result

func signature_for(group: Dictionary) -> String:
	var ids: Array[int] = []
	for id in group.slots:
		if id != null:ids.append(int(id))
	ids.sort()
	return JSON.stringify(ids)

func analyze(group: Dictionary) -> Dictionary:
	var result := group.duplicate(true)
	var totals := {"durability":0.0, "burst":0.0, "sustained":0.0, "armor":0.0, "single_target":0.0, "hull":0.0, "strength":0.0}
	var composition := {}
	var hull_counts := {}
	var count := 0
	var max_power:=0.0
	var ship_powers: Dictionary={}
	var largest_scale:="small"
	for value in group.slots:
		if value == null:continue
		var id := str(int(value))
		if not projections.has(id):return {"error":"invalid_enemy"}
		composition[id] = int(composition.get(id,0)) + 1
		var stats: Dictionary = projections[id]
		ship_powers[id]=float(stats.strength)
		max_power=maxf(max_power,float(stats.strength))
		if scale_rank(scale_for(id))>scale_rank(largest_scale):largest_scale=scale_for(id)
		for key in totals:totals[key] += float(stats[key])
		hull_counts[stats.hull] = int(hull_counts.get(stats.hull,0)) + 1
		count += 1
	if count == 0:return {"error":"empty_pool"}
	var scores := {}
	for key in FEATURES:scores[key] = 0.0
	for key in ["durability", "burst", "sustained"]:
		scores[key] = clampf(totals[key] / count / maxf(float(reference[key]), 0.000001), 0, 1)
	scores.armor = totals.armor / count
	scores.single_target = totals.single_target / count
	scores.fleet_size = float(count) / slot_count
	var hull: float = totals.hull / count / maxf(reference.hull, 0.000001)
	var mixed := 1.0 - float(hull_counts.values().max()) / count
	var facts: Dictionary = scores.duplicate()
	facts.merge({"hull":hull, "mixed":mixed})
	var tags := tags_for(facts)
	var kind: String=str(group.get("formation_type","symmetric"))
	var canonical_formation: String="rows" if kind=="formation_rows" else "core_wings" if kind=="double_wings" or kind=="heavy_guard" else kind
	var all_tags: Array=[]
	for tag in tags.primary+tags.secondary:
		if not all_tags.has(tag):all_tags.append(tag)
	var difficulty: float=float(totals.strength)+max_power*float(policy.generation.max_ship_difficulty_weight)
	result.merge({"count":count, "strength":difficulty, "composition":composition, "feature_scores":scores, "raw_totals":totals, "hull_score":hull, "mixed_score":mixed, "primary_tags":tags.primary, "secondary_tags":tags.secondary, "signature":signature_for(group), "config_fingerprint":fingerprint, "analysis_version":policy.version, "feature_notes":policy.feature_notes.duplicate(true), "ship_power":ship_powers, "fleet_power":totals.strength, "max_ship_power":max_power, "ship_count":count, "type_count":composition.size(), "scale":largest_scale, "formation":canonical_formation, "tags":all_tags})
	if group.get("formation_positions") is Array:
		var formation: Dictionary=formation_analysis(group)
		result.merge(formation)
		for tag in formation.formation_tags:
			if not result.tags.has(tag):result.tags.append(tag)
	return result

func formation_analysis(group: Dictionary) -> Dictionary:
	var positions: Array=group.formation_positions
	var pairs: Dictionary={}
	var rows: Dictionary={}
	var center_count:=0
	for unit in positions:
		rows[int(round(float(unit.y)))]=true
		var pair:=int(unit.pair)
		if pair<0:center_count+=1;continue
		if not pairs.has(pair):pairs[pair]=[]
		pairs[pair].append(unit)
	var symmetry:=float(center_count)
	var grouping:=float(center_count)
	for members in pairs.values():
		if members.size()!=2:continue
		var left: Dictionary=members[0]
		var right: Dictionary=members[1]
		var positional:=clampf(1.0-absf(absf(float(left.x))-absf(float(right.x)))/2.0-absf(float(left.y)-float(right.y))/2.0,0,1)
		var same: bool=int(left.id)==int(right.id)
		var identity:=1.0 if same else 0.7 if near_roles(str(left.id),str(right.id)) else 0.0
		symmetry+=2.0*(0.7*positional+0.3*identity)
		grouping+=2.0*identity
	symmetry=clampf(symmetry/maxi(1,positions.size()),0,1)
	grouping=clampf(grouping/maxi(1,positions.size()),0,1)
	var layering:=0.75 if rows.size()==1 else 0.9 if rows.size()==2 else 1.0
	var spacing:=1.0
	for i in range(positions.size()):
		for j in range(i+1,positions.size()):
			var a: Dictionary=positions[i]
			var b: Dictionary=positions[j]
			spacing=minf(spacing,clampf(Vector2(float(a.x)-float(b.x),float(a.y)-float(b.y)).length(),0,1))
	var metrics: Dictionary={"symmetry":symmetry,"grouping":grouping,"layering":layering,"spacing":spacing}
	var structure:=0.55*grouping+0.2*layering+0.25*spacing
	var structure_weight:=float(policy.generation.structure_weight)
	var score:=structure_weight*structure+(1.0-structure_weight)*symmetry
	var kind: String=str(group.get("formation_type","symmetric"))
	var structure_tags: Array=[]
	for template in policy.formation.templates:
		if template.id==kind:structure_tags.append(str(template.tag));break
	if symmetry>=0.8 and kind!="loose_symmetric" and not structure_tags.has("symmetric"):structure_tags.append("symmetric")
	if pairs.size()>0 and grouping>=0.7 and not structure_tags.has("paired"):structure_tags.append("paired")
	if rows.size()>1 and not structure_tags.has("formation_rows"):structure_tags.append("formation_rows")
	return {"formation_score":clampf(score,0,1),"formation_metrics":metrics,"formation_tags":structure_tags}

func near_roles(left: String,right: String) -> bool:
	var a: Dictionary=projections[left]
	var b: Dictionary=projections[right]
	var distance:=0.0
	for key in ["durability","burst","sustained","hull","armor"]:
		distance+=absf(float(a[key])-float(b[key]))/maxf(1,float(reference.get(key,1)))
	return distance/5.0<=float(policy.formation.pair_stat_similarity)

func tags_for(facts: Dictionary) -> Dictionary:
	var candidates: Array = []
	for rule in policy.tags:
		var matches := true
		var confidence := 1.0
		for key in rule.get("min", {}):
			matches = matches and facts.get(key, 0.0) >= float(rule.min[key])
			confidence = minf(confidence, float(facts.get(key,0.0)))
		for key in rule.get("max", {}):
			matches = matches and facts.get(key, 0.0) <= float(rule.max[key])
			confidence = minf(confidence, 1.0 - float(facts.get(key,0.0)))
		if matches:candidates.append({"rule":rule, "confidence":confidence})
	candidates.sort_custom(func(a,b):
		if a.rule.priority != b.rule.priority:return a.rule.priority > b.rule.priority
		if a.confidence != b.confidence:return a.confidence > b.confidence
		return str(a.rule.id) < str(b.rule.id))
	var result := {"primary":[], "secondary":[]}
	for candidate in candidates:
		if candidate.rule.get("primary", true) and result.primary.size() < mini(2,int(policy.primary_limit)):
			result.primary.append(candidate.rule.id)
		elif result.secondary.size() < mini(3,int(policy.secondary_limit)):
			result.secondary.append(candidate.rule.id)
	return result

static func matches_filter(row: Dictionary, tag: String, min_strength: float, max_strength: float, min_count: int, max_count: int) -> bool:
	return row.strength >= min_strength and row.strength <= max_strength and row.count >= min_count and row.count <= max_count and (tag.is_empty() or row.primary_tags.has(tag) or row.secondary_tags.has(tag) or row.get("formation_tags",[]).has(tag))
