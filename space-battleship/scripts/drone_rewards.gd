extends RefCounted
const C=preload("res://scripts/hyperspace_config.gd")
const R=preload("res://scripts/hyperspace_random.gd")

static func empty_reward() -> Dictionary:
	return {"drone":{},"materials":{},"ultimate_cores":0,"hanging_rewards":{}}

static func material_amount(c: Dictionary,level: int) -> int:
	var base:=int(c.material_base_reward)+maxi(0,level-int(c.material_reward_start_level))/int(c.material_reward_level_step)
	return floori(float(base)*float(c.get("material_reward_multiplier",1.0)))

static func affix(rng: RandomNumberGenerator,c: Dictionary,weapon: String,forced_key: String="") -> Dictionary:
	var weights: Dictionary={}
	for tier in c.tier_weights:
		if c.affixes.values().any(func(row):return (row.weapon.is_empty() or row.weapon==weapon) and row.ranges.has(tier)):
			if forced_key.is_empty() or c.affixes[forced_key].ranges.has(tier):weights[tier]=c.tier_weights[tier]
	var tier:=R.weighted(rng,weights)
	var keys: Array=c.affixes.keys().filter(func(key):return (c.affixes[key].weapon.is_empty() or c.affixes[key].weapon==weapon) and c.affixes[key].ranges.has(tier))
	var key: String=forced_key if not forced_key.is_empty() else str(keys[rng.randi_range(0,keys.size()-1)])
	return {"key":key,"tier":int(tier),"value":R.quantized(rng,c.affixes[key].ranges[tier],float(c.value_precision)),"locked":false}

static func legendary(rng: RandomNumberGenerator,c: Dictionary,weapon: String) -> Dictionary:
	var keys: Array=c.legendary_effects.keys().filter(func(key):return c.legendary_effects[key].weapon.is_empty() or c.legendary_effects[key].weapon==weapon)
	var key: String=keys[rng.randi_range(0,keys.size()-1)]
	var parameters: Dictionary={}
	for parameter in c.legendary_effects[key].parameters:
		parameters[parameter]=R.quantized(rng,c.legendary_effects[key].parameters[parameter],float(c.value_precision))
	return {"effect_id":key,"parameters":parameters}

static func count_slots(rng: RandomNumberGenerator,maximum: int,chance: float,factor: float) -> int:
	var count:=0
	for _i in maximum:
		if rng.randf()<chance:count+=1
		chance*=factor
	return count

static func create_drone(rng: RandomNumberGenerator,c: Dictionary,id: String,quality: String,weapon: String,level: int,planet_id: String) -> Dictionary:
	var limits: Dictionary=c.quality_limits[quality]
	var d: Dictionary={"id":id,"origin_quality":quality,"weapon":weapon,"level":level,"planet_id":planet_id,"legendary":quality=="legendary","ultimate":false,"blue_source_bonus":quality=="blue","legendary_effect":{},"ultimate_affix":{},"affixes":[],"hangings":[],"hanging_slots":count_slots(rng,int(limits.hangings),float(c.hanging_initial_probability),float(c.additional_probability_factor)),"preserved_hanging_slots":0,"omen":false,"forge_revision":0,"forge_rng_state":"0"}
	var count:=count_slots(rng,int(limits.affixes),float(c.affix_initial_probability),float(c.additional_probability_factor))
	for _i in count:d.affixes.append(affix(rng,c,weapon))
	if d.legendary:d.legendary_effect=legendary(rng,c,weapon)
	# Seed the per-drone stream without consuming the shared combat RNG.
	var private_rng:=RandomNumberGenerator.new();private_rng.seed=rng.randi()
	d.forge_rng_state=str(private_rng.state)
	return d

static func generate(s: Dictionary,c: Dictionary,request: Dictionary,planet_id: String) -> Dictionary:
	if c.policies.core_reward not in ["exclusive","additional"]:return {"error":"core_reward_policy_required"}
	var rng:=R.restore(s.random_state)
	var outcome:=R.weighted(rng,c.quality_weights)
	var reward:=empty_reward()
	if outcome=="ultimate_core":
		reward.ultimate_cores=1
		if c.policies.core_reward=="additional":
			var weights: Dictionary=c.quality_weights.duplicate();weights.erase("ultimate_core")
			outcome=R.weighted(rng,weights)
	if outcome!="ultimate_core":
		reward.drone=create_drone(rng,c,"space:%d:%d"%[int(request.round_id),int(request.run_id)],outcome,c.routes[request.route].weapon,int(request.level),planet_id)
	var amount:=material_amount(c,int(request.level))
	reward.materials[c.routes[request.route].material]=int(amount)
	return {"error":"","reward":reward,"random_state":str(rng.state)}

static func dismantle(d: Dictionary,c: Dictionary,rng: RandomNumberGenerator) -> Dictionary:
	var quality: String="legendary" if d.legendary else str(d.origin_quality)
	var amount:=int(c.dismantle_amounts[quality])
	var drops: Dictionary={}
	var keys: Array=c.hanging_modules.keys()
	for _i in amount:
		var key: String=keys[rng.randi_range(0,keys.size()-1)]
		drops[key]=int(drops.get(key,0))+1
	var route: String=c.routes.keys().filter(func(key):return c.routes[key].weapon==d.weapon)[0]
	return {"materials":{c.routes[route].material:amount},"hanging_rewards":drops}

static func module_progress(c: Dictionary) -> Dictionary:
	var result: Dictionary={}
	for key in c.hanging_modules:result[key]={"unlocked":false,"level":0,"exp":0.0}
	return result

static func credit_modules(s: Dictionary,c: Dictionary,drops: Dictionary) -> bool:
	for key in drops:
		var row: Dictionary=c.hanging_modules[key]
		var progress: Dictionary=s.hanging_modules[key]
		var copies:=int(drops[key])
		if not progress.unlocked:progress.unlocked=true;copies-=1
		progress.exp+=copies*float(row.base_exp)
		var needed:=float(row.base_exp)*pow(1.0+float(row.exp_growth),int(progress.level))
		if not is_finite(needed):return false
		while progress.exp+0.000000001>=needed:
			progress.exp=maxf(0.0,float(progress.exp)-needed);progress.level+=1
			needed=float(row.base_exp)*pow(1.0+float(row.exp_growth),int(progress.level))
			if not is_finite(needed):return false
	return true
