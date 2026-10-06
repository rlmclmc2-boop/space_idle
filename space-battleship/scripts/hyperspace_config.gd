extends RefCounted
## Independent configuration; no changes to production economic tables.
static func load_config() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/hyperspace_config.json"))

static func valid(c: Dictionary) -> bool:
	if c.get("version")!=2:return false
	for key in ["energy_rate","energy_cap","ticket","minimum_duration"]:
		if not number(c.get(key)) or float(c[key])<=0:return false
	for key in ["unlock_stage","minimum_level","warehouse_capacity","overflow_capacity","reforge_capacity_gain","retention_capacity_gain","maximum_equipped","maximum_legendary","maximum_ultimate","completion_budget"]:
		if not integer(c.get(key)) or int(c[key])<=0:return false
	if not integer(c.get("initial_retention_capacity")) or int(c.initial_retention_capacity)<0:return false
	if c.maximum_equipped>5 or c.maximum_legendary>2 or c.maximum_ultimate>1 or c.overflow_capacity!=10:return false
	if not c.get("routes") is Dictionary or c.routes.size()!=4:return false
	for route in c.routes.values():
		if not route is Dictionary or not route.get("weapon") in ["laser","missile","cannon","longLaser"] or not route.get("material") is String:return false
	if not c.get("quality_limits") is Dictionary:return false
	for key in ["white","blue","gold","legendary"]:
		var q=c.quality_limits.get(key)
		if not q is Dictionary or not integer(q.get("affixes")) or not integer(q.get("hangings")) or q.affixes<0 or q.affixes>int({"white":0,"blue":2,"gold":3,"legendary":3}[key]) or q.hangings<0 or q.hangings>int({"white":4,"blue":2,"gold":1,"legendary":0}[key]):return false
	for key in ["hull_capacities","quality_weights","weapon_level_bonuses","tier_weights","affixes","hanging_modules","legendary_effects","forge_costs","policies"]:
		if not c.get(key) is Dictionary or c[key].is_empty():return false
	for weight in c.quality_weights.values():
		if not number(weight) or weight<0:return false
	if c.quality_weights.keys().any(func(key):return key not in ["white","blue","gold","legendary","ultimate_core"]) or c.quality_weights.values().reduce(func(a,b):return float(a)+float(b),0.0)<=0:return false
	for id in ["Frigate","Destroyer","Cruiser","Battleship","Heavy_Battleship"]:
		if not integer(c.hull_capacities.get(id)) or c.hull_capacities[id]<1 or c.hull_capacities[id]>5:return false
	for key in ["affix_initial_probability","hanging_initial_probability","additional_probability_factor"]:
		if not number(c.get(key)) or c[key]<0 or c[key]>1:return false
	for key in ["material_base_reward","material_reward_start_level","material_reward_level_step"]:
		if not integer(c.get(key)) or c[key]<1:return false
	if c.has("late_supply_unlock_stage"):
		if not integer(c.late_supply_unlock_stage) or c.late_supply_unlock_stage<1:return false
		if not number(c.get("late_energy_rate_multiplier")) or c.late_energy_rate_multiplier<=0:return false
		if not integer(c.get("late_material_reward_multiplier")) or c.late_material_reward_multiplier<1:return false
		if c.has("late_supply_ramp_seconds") and (not number(c.late_supply_ramp_seconds) or c.late_supply_ramp_seconds<=0):return false
	for tier in range(1,6):
		if not number(c.tier_weights.get(str(tier))) or c.tier_weights[str(tier)]<=0:return false
	for key in c.affixes:
		var row=c.affixes[key]
		if not row is Dictionary or not row.get("ranges") is Dictionary or row.ranges.is_empty() or not row.get("amplified") is bool or not row.get("weapon") is String:return false
		for tier in row.ranges:
			if not str(tier).is_valid_int() or int(tier)<1 or int(tier)>5 or not range_valid(row.ranges[tier]):return false
	for row in c.legendary_effects.values():
		if not row is Dictionary or not row.get("weapon") is String or not row.get("parameters") is Dictionary or not row.get("constants") is Dictionary:return false
		for bounds in row.parameters.values():
			if not range_valid(bounds):return false
	for row in c.hanging_modules.values():
		if not row is Dictionary:return false
		for key in ["base_exp","exp_growth","effect_growth"]:
			if not number(row.get(key)) or row[key]<0:return false
		if row.base_exp<=0 or not integer(row.get("unlock_stage")) or row.unlock_stage<0:return false
	for cost in c.forge_costs.values():
		if not cost is Dictionary:return false
		for value in cost.values():
			if not integer(value) or value<0:return false
	for key in ["value_precision","amplification_rate","lock_cost_multiplier","reroll_guarantee_multiplier","modernization_cost_base","modernization_level_step"]:
		if not number(c.get(key)) or c[key]<=0:return false
	for key in ["maximum_filter_conditions","maximum_filter_string_length","maximum_forecast_attempts"]:
		if not integer(c.get(key)) or c[key]<=0:return false
	if c.maximum_filter_conditions>5:return false
	return true

static func range_valid(value: Variant) -> bool:
	return value is Array and value.size()==2 and number(value[0]) and number(value[1]) and value[0]<=value[1]

static func number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and absf(float(value))<9.0e15

static func integer(value: Variant) -> bool:
	return number(value) and float(value)==floorf(float(value))
