extends RefCounted
const C=preload("res://scripts/hyperspace_config.gd")
const R=preload("res://scripts/hyperspace_random.gd")

static func empty_reward() -> Dictionary:
	return {"drone":{},"materials":{},"ultimate_cores":0,"hanging_rewards":{}}

static func material_amount(c: Dictionary,level: int) -> int:
	var base:=int(c.material_base_reward)+maxi(0,level-int(c.material_reward_start_level))/int(c.material_reward_level_step)
	var amount:=float(base)*float(c.get("material_reward_multiplier",1.0))*float(c.get("material_unit_scale",10))
	return floori(amount) if C.number(amount) and amount>=0 else -1

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
		parameters[parameter]=R.quantized(rng,c.legendary_effects[key].parameters[parameter],C.parameter_precision(c,key,parameter))
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

# Luck uses a receipt-owned stream, leaving quality/count/type and forge seeds untouched.
static func lucky_tier(rng:RandomNumberGenerator,weights:Dictionary,extra:int)->int:
	var tiers:Array=weights.keys();tiers.sort_custom(func(a,b):return int(a)<int(b))
	var total:=0.0
	for tier in tiers:total+=float(weights[tier])
	var draw:=rng.randf();var remaining:=total
	for tier in tiers:
		var before:=pow(remaining/total,extra)
		remaining=maxf(0.0,remaining-float(weights[tier]))
		var chance:=before-pow(remaining/total,extra)
		draw-=chance
		if draw<0:return int(tier)
	return int(tiers.back())

static func apply_luck(drone:Dictionary,c:Dictionary,luck:float,state:String)->void:
	if luck<=0 or drone.is_empty():return
	var rng:=R.restore(state)
	for entry in drone.affixes:
		var extra:=floori(luck/100.0)
		var remainder:=fposmod(luck,100.0)/100.0
		if remainder>0 and rng.randf()<remainder:extra+=1
		if extra==0:continue
		var weights:Dictionary={}
		for tier in c.tier_weights:
			if c.affixes[entry.key].ranges.has(tier):weights[tier]=c.tier_weights[tier]
		var tier:=mini(int(entry.tier),lucky_tier(rng,weights,extra))
		if tier==int(entry.tier):continue
		entry.tier=tier
		entry.value=R.quantized(rng,c.affixes[entry.key].ranges[str(tier)],float(c.value_precision))

static func quality_weights(c:Dictionary)->Dictionary:
	var probability:=float(c.get("ultimate_core_probability",0.002))
	if not C.number(probability) or probability<0 or probability>1:return {}
	var weights:Dictionary=c.quality_weights.duplicate();var total:=0.0
	for key in weights:
		if key!="ultimate_core":total+=float(weights[key])
	if total<=0:return {}
	for key in weights:
		if key!="ultimate_core":weights[key]=(1.0-probability)*float(weights[key])/total
	weights.ultimate_core=probability
	return weights

static func generate(s: Dictionary,c: Dictionary,request: Dictionary,planet_id: String) -> Dictionary:
	if c.policies.core_reward not in ["exclusive","additional"]:return {"error":"core_reward_policy_required"}
	var rng:=R.restore(s.random_state)
	var normalized:=quality_weights(c)
	if normalized.is_empty():return {"error":"invalid_core_probability"}
	var outcome:=R.weighted(rng,normalized)
	var reward:=empty_reward()
	if outcome=="ultimate_core":
		reward.ultimate_cores=1
		if c.policies.core_reward=="additional":
			var weights: Dictionary=c.quality_weights.duplicate();weights.erase("ultimate_core")
			outcome=R.weighted(rng,weights)
	if outcome!="ultimate_core":
		reward.drone=create_drone(rng,c,"space:%d:%d"%[int(request.round_id),int(request.run_id)],outcome,c.routes[request.route].weapon,int(request.level),planet_id)
	apply_luck(reward.drone,c,float(request.get("luck",0.0)),str(request.get("luck_state","0")))
	var amount:=material_amount(c,int(request.level))
	if amount<0:return {"error":"material_value_limit"}
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
	return {"materials":{c.routes[route].material:amount*int(c.get("material_unit_scale",10))},"hanging_rewards":drops}

static func module_progress(c: Dictionary) -> Dictionary:
	var result: Dictionary={}
	for key in c.hanging_modules:result[key]={"unlocked":false,"level":0,"exp":0}
	return result

# Only modules already obtained receive the minimum useful level; idempotent on reload.
static func normalize_unlocked_modules(s:Dictionary) -> void:
	for progress in s.hanging_modules.values():
		if bool(progress.unlocked) and int(progress.level)==0:progress.level=1
		progress.exp=int(progress.exp)

# One repeat is enough for the first upgrade; level2 onward keeps the original curve.
static func module_required_exp(row:Dictionary,level:int) -> int:
	var raw:float=float(row.base_exp)*pow(1.0+float(row.exp_growth),0 if level==1 else level)
	if not is_finite(raw) or raw<=0 or raw>=9.0e15:return -1
	return ceili(raw)

static func credit_modules(s: Dictionary,c: Dictionary,drops: Dictionary,outcomes: Dictionary={}) -> bool:
	for key in drops:
		var row: Dictionary=c.hanging_modules[key]
		var progress: Dictionary=s.hanging_modules[key]
		var copies:=int(drops[key])
		var newly_unlocked: bool=not progress.unlocked
		if copies<=0:continue
		if not progress.unlocked:progress.unlocked=true;progress.level=0
		elif int(progress.level)==0:progress.level=1
		var gained:float=float(copies)*float(row.base_exp)
		if not C.integer(gained):return false
		var experience_added:int=int(gained)
		var accumulated:float=float(progress.exp)+float(experience_added)
		if not C.integer(accumulated):return false
		progress.exp=int(accumulated)
		var needed:=module_required_exp(row,int(progress.level))
		if needed<=0:return false
		while int(progress.exp)>=needed:
			progress.exp=int(progress.exp)-needed;progress.level+=1
			needed=module_required_exp(row,int(progress.level))
			if needed<=0:return false
		outcomes[key]={"copies":int(drops[key]),"newly_unlocked":newly_unlocked,"experience_added":experience_added,"level":int(progress.level)}
	return true
