extends RefCounted
## Pure command planning on a private working copy. Caller commits cost/RNG/result together.
const C=preload("res://scripts/hyperspace_config.gd")
const R=preload("res://scripts/hyperspace_random.gd")
const Rewards=preload("res://scripts/drone_rewards.gd")
const Bag=preload("res://scripts/drone_inventory.gd")
const Permission=preload("res://scripts/hyperspace_permissions.gd")

static func eligible_indices(d: Dictionary,c: Dictionary) -> Array:
	var indices: Array=[]
	for i in d.affixes.size():
		if not d.affixes[i].locked:indices.append(i)
	if d.omen and c.policies.omen_scope=="drone" and not indices.is_empty():
		var worst:=0
		for i in indices:worst=maxi(worst,int(d.affixes[i].tier))
		indices=indices.filter(func(i):return int(d.affixes[i].tier)==worst)
	return indices

static func can_pay(s: Dictionary,cost: Dictionary) -> bool:
	for key in cost:
		if not C.integer(cost[key]) or cost[key]<0:return false
		var available: int=int(s.ultimate_cores) if key=="ultimate_cores" else int(s.materials.get(key,0))
		if available<int(cost[key]):return false
	return true

static func debit(s: Dictionary,cost: Dictionary) -> void:
	for key in cost:
		if key=="ultimate_cores":s.ultimate_cores-=int(cost[key])
		else:s.materials[key]-=int(cost[key])

static func restore_result(encoded: String) -> Dictionary:
	var result: Dictionary=JSON.parse_string(encoded)
	for key in ["draws","index"]:
		if result.has(key):result[key]=int(result[key])
	for key in result.get("cost",{}):result.cost[key]=int(result.cost[key])
	return result

static func error(reason: String) -> Dictionary:
	return {"error":reason,"applied":false}

static func plan(s: Dictionary,c: Dictionary,request: Dictionary,g) -> Dictionary:
	var op:=str(request.get("operation",""));var id:=str(request.get("drone_id",""))
	var args: Dictionary=request.get("args",{}) if request.get("args",{}) is Dictionary else {}
	if not s.inventory.drones.has(id) or s.inventory.sealed.has(id):return error("unavailable_drone")
	var d: Dictionary=s.inventory.drones[id]
	if request.has("expected_revision") and request.expected_revision!=d.forge_revision:return error("stale_drone")
	if d.ultimate and op!="restore_ultimate" and op!="dismantle":return error("ultimate_modification_forbidden")
	if op=="dismantle" and Bag.protected(s.inventory,id):return error("protected_drone")
	var cost: Dictionary=c.forge_costs.get(op,{}).duplicate()
	var rng:=R.restore(d.forge_rng_state)
	var indices:=eligible_indices(d,c)
	var index: int=-1;var draws:=1;var outcome:=true
	var mutation:=false
	match op:
		"add_affix":
			if d.affixes.size()>=Bag.affix_limit(d,c):return error("affix_limit")
			d.affixes.append(Rewards.affix(rng,c,d.weapon));mutation=true
		"replace_affix":
			if indices.is_empty():return error("no_unlocked_affix")
			var wanted:=str(args.get("guaranteed_key",""))
			if not wanted.is_empty() and (not c.affixes.has(wanted) or (not c.affixes[wanted].weapon.is_empty() and c.affixes[wanted].weapon!=d.weapon)):return error("invalid_affix")
			index=int(indices[rng.randi_range(0,indices.size()-1)])
			var replacement:=Rewards.affix(rng,c,d.weapon)
			d.affixes[index]=replacement
			while not wanted.is_empty() and replacement.key!=wanted:
				if draws>=int(c.maximum_forecast_attempts):return error("forecast_limit")
				draws+=1;indices=eligible_indices(d,c)
				index=int(indices[rng.randi_range(0,indices.size()-1)])
				replacement=Rewards.affix(rng,c,d.weapon);d.affixes[index]=replacement
			cost.degenerate_matter=int(cost.degenerate_matter)*draws
			d.affixes[index]=replacement;mutation=true
		"add_hanging_slot":
			if int(d.hanging_slots)>=Bag.hanging_limit(d,c):return error("hanging_limit")
			d.hanging_slots+=1
		"lock_affix":
			if indices.is_empty():return error("no_unlocked_affix")
			var locks: int=d.affixes.filter(func(a):return a.locked).size()
			cost.glueball=float(cost.glueball)*pow(float(c.lock_cost_multiplier),locks)
			index=int(indices[rng.randi_range(0,indices.size()-1)]);d.affixes[index].locked=true;mutation=true
		"promote_affix":
			if c.policies.promotion_success!="weighted_draw_stronger":return error("promotion_policy_required")
			if indices.is_empty():return error("no_unlocked_affix")
			index=int(indices[rng.randi_range(0,indices.size()-1)])
			var a: Dictionary=d.affixes[index]
			if int(a.tier)<=1:return error("already_highest_tier")
			var proposed:=int(R.weighted(rng,c.tier_weights))
			outcome=proposed<int(a.tier)
			if outcome:
				a.tier=int(a.tier)-1;a.value=R.quantized(rng,c.affixes[a.key].ranges[str(a.tier)],float(c.value_precision));mutation=true
		"reroll_values":
			var unlocked: Array=d.affixes.filter(func(a):return not a.locked)
			if unlocked.is_empty() and d.legendary_effect.is_empty():return error("no_unlocked_values")
			var maximum: bool=args.get("guaranteed_max",false)==true
			var expectation:=1.0
			for a in unlocked:
				var bounds: Array=c.affixes[a.key].ranges[str(int(a.tier))]
				expectation*=float(roundi((float(bounds[1])-float(bounds[0]))/float(c.value_precision))+1)
				a.value=float(bounds[1]) if maximum else R.quantized(rng,bounds,float(c.value_precision))
			if d.legendary:
				var ranges: Dictionary=c.legendary_effects[d.legendary_effect.effect_id].parameters
				for key in ranges:
					var bounds: Array=ranges[key]
					expectation*=float(roundi((float(bounds[1])-float(bounds[0]))/float(c.value_precision))+1)
					d.legendary_effect.parameters[key]=float(bounds[1]) if maximum else R.quantized(rng,bounds,float(c.value_precision))
			if maximum:cost.antiproton=ceilf(float(cost.antiproton)*expectation*float(c.reroll_guarantee_multiplier))
			mutation=true
		"enable_omen":
			if c.policies.omen_scope!="drone":return error("omen_policy_required")
			if d.omen:return error("omen_already_enabled")
			d.omen=true
		"disable_omen":
			d.omen=false
		"legendary":
			if d.legendary and c.policies.legendary_repeat_action!="reroll_effect":return error("legendary_repeat_policy_required")
			var wanted:=str(args.get("guaranteed_effect",""))
			if not wanted.is_empty() and not s.legendary_collection.has(wanted):return error("legendary_not_collected")
			if not wanted.is_empty() and not c.legendary_effects[wanted].weapon.is_empty() and c.legendary_effects[wanted].weapon!=d.weapon:return error("invalid_legendary")
			var effect:=Rewards.legendary(rng,c,d.weapon)
			while not wanted.is_empty() and effect.effect_id!=wanted:
				if draws>=int(c.maximum_forecast_attempts):return error("forecast_limit")
				draws+=1;effect=Rewards.legendary(rng,c,d.weapon)
			cost.zero_point_energy=int(cost.zero_point_energy)*draws
			if not d.legendary:d.preserved_hanging_slots=int(d.hanging_slots)
			d.legendary=true;d.legendary_effect=effect;mutation=true
			if not s.legendary_seen.has(effect.effect_id):s.legendary_seen.append(effect.effect_id)
		"modernize":
			var route: String=c.routes.keys().filter(func(key):return c.routes[key].weapon==d.weapon)[0]
			var target:=0
			for key in s.history.get(route,{}):
				if int(key)<=int(g.profile.highestLevel):target=maxi(target,int(key))
			if target<=int(d.level):return error("no_new_record")
			if args.has("target_level") and args.target_level!=target:return error("stale_modernization_target")
			var coefficient:=0.0
			for a in d.affixes:coefficient+=float(c.modernization_tier_weights[str(int(a.tier))])
			var raw:=float(c.modernization_cost_base)*(1.0+float(target-int(c.material_reward_start_level))/float(c.modernization_level_step))*coefficient*(float(c.modernization_legendary_multiplier) if d.legendary else 1.0)
			cost={c.routes[route].material:roundf(raw/float(c.modernization_cost_base))*float(c.modernization_cost_base)}
			d.level=target;d.planet_id=Permission.planet_for_level(g.db.data,target)
		"ultimate":
			if d.ultimate:return error("already_ultimate")
			d.ultimate=true
			if d.ultimate_affix.is_empty():d.ultimate_affix=Rewards.affix(rng,c,d.weapon)
		"restore_ultimate":
			if not d.ultimate:return error("not_ultimate")
			d.ultimate=false # Keep the original extra affix for a future ultimate conversion.
		"dismantle":
			var drops:=Rewards.dismantle(d,c,rng)
			for key in drops.materials:s.materials[key]+=int(drops.materials[key])
			var module_outcomes: Dictionary={}
			if not Rewards.credit_modules(s,c,drops.hanging_rewards,module_outcomes):return error("module_value_limit")
			Bag.remove(s.inventory,id);Bag.organize(s.inventory,c)
			return {"error":"","applied":true,"outcome":true,"cost":{},"draws":1,"drone_id":id,"operation":op,"rewards":{"materials":drops.materials.duplicate(true),"modules":module_outcomes}}
		_:return error("unknown_operation")
	for value in cost.values():
		if not C.integer(value) or value<0:return error("cost_limit")
	if not can_pay(s,cost):return {"error":"insufficient_materials","applied":false,"cost":cost,"draws":draws}
	debit(s,cost)
	d.forge_rng_state=str(rng.state)
	d.forge_revision+=draws
	s.inventory.generation+=1
	return {"error":"","applied":true,"outcome":outcome,"cost":cost,"draws":draws,"index":index,"drone_id":id,"operation":op,"affixes_changed":mutation}
