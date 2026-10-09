extends RefCounted
## Independent configuration; reject invalid packs before creating player state.
const Entity=preload("res://scripts/hyperspace_entity_validation.gd")
static func load_config() -> Dictionary:
	var parsed=JSON.parse_string(FileAccess.get_file_as_string("res://data/hyperspace_config.json"))
	if not parsed is Dictionary or not valid(parsed):
		push_error("Invalid hyperspace configuration; import both authoritative entity workbooks")
		return {}
	return parsed

static func parameter_precision(c: Dictionary,effect_id: String,key: String) -> float:
	return float(c.legendary_effects.drone_master.constants.reduction_precision) if effect_id=="drone_master" and key=="maximum_reduction" else float(c.value_precision)

static func valid(c: Dictionary) -> bool:
	if not Entity.output_valid("hyperspace_config.json",c) or c.get("version")!=2:return false
	for key in ["energy_rate","energy_cap","ticket","minimum_duration","modernization_base_coefficient","auto_duration_crew_base","auto_ticket_crew_base","modernization_legendary_multiplier"]:
		if not number(c.get(key)) or float(c[key])<=0:return false
	for key in ["unlock_stage","minimum_level","warehouse_capacity","overflow_capacity","reforge_capacity_gain","retention_capacity_gain","maximum_equipped","maximum_legendary","maximum_ultimate","completion_budget","amplification_start_level"]:
		if not integer(c.get(key)) or int(c[key])<=0:return false
	if not integer(c.get("initial_retention_capacity")) or int(c.initial_retention_capacity)<0:return false
	if c.has("material_unit_scale") and (not integer(c.material_unit_scale) or c.material_unit_scale<=0):return false
	if c.has("ultimate_core_probability") and (not number(c.ultimate_core_probability) or c.ultimate_core_probability<0 or c.ultimate_core_probability>1):return false
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
		if not number(c.modernization_tier_weights.get(str(tier))) or c.modernization_tier_weights[str(tier)]<0:return false
	for quality in c.dismantle_amounts:
		if not integer(c.dismantle_amounts[quality]) or c.dismantle_amounts[quality]<1 or not integer(c.weapon_level_bonuses[quality]) or c.weapon_level_bonuses[quality]<0:return false
	if not integer(c.ultimate_weapon_bonus) or c.ultimate_weapon_bonus<0:return false
	for key in c.affixes:
		var row=c.affixes[key]
		if not row is Dictionary or not row.get("ranges") is Dictionary or row.ranges.is_empty() or not row.get("amplified") is bool or not row.get("weapon") in ["","laser","missile","cannon","longLaser"]:return false
		for tier in row.ranges:
			if not str(tier).is_valid_int() or int(tier)<1 or int(tier)>5 or not quantized_range(row.ranges[tier],float(c.value_precision)):return false
	for effect_id in c.legendary_effects:
		var row=c.legendary_effects[effect_id]
		if not row is Dictionary or not row.get("weapon") is String or not row.get("parameters") is Dictionary or not row.get("constants") is Dictionary:return false
		for key in row.parameters:
			var precision=row.constants.get("reduction_precision",c.value_precision) if effect_id=="drone_master" and key=="maximum_reduction" else c.value_precision
			if not number(precision) or float(precision)<=0 or not quantized_range(row.parameters[key],float(precision)):return false
		if row.has("stored_parameter_ranges"):
			if not row.stored_parameter_ranges is Dictionary:return false
			for key in row.stored_parameter_ranges:
				if not row.parameters.has(key) or not range_valid(row.stored_parameter_ranges[key]):return false
	for id in c.legendary_effects:
		var constants:Dictionary=c.legendary_effects[id].constants
		for key in constants:
			var value=constants[key]
			if key=="reduction_precision" and (not number(value) or value<=0 or value>1):return false
			if key in ["delay","cooldown","period","absorption_duration"] and (not number(value) or value<=0):return false
			if key in ["spawn_probability","blast_fraction"] and (not number(value) or value<0 or value>1):return false
			if key in ["kill_spawns","nearby_targets","maximum_stacks","attack_period","maximum_cannon_sources","stack_limit"] and (not integer(value) or value<0):return false
		if c.legendary_effects[id].parameters.has("maximum_dodge") and c.legendary_effects[id].parameters.maximum_dodge[1]>1:return false
		if id=="black_hole" and constants.period<constants.absorption_duration:return false
	var command:Dictionary=c.legendary_effects.drone_master
	var ratios:Dictionary=command.constants.quality_ratios
	if not number(ratios.ultimate) or ratios.ultimate<=0 or command.parameters.maximum_reduction[1]>1:return false
	for value in ratios.values():
		if not number(value) or value<0 or value>ratios.ultimate:return false

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

static func quantized_range(value:Variant,precision:float)->bool:
	return range_valid(value) and precision>0 and value[0]>=0 and ceilf(float(value[0])/precision-0.0000001)<=floorf(float(value[1])/precision+0.0000001)

static func pack_valid(g)->bool:
	if not valid(g.hyperspace.config) or not Entity.frozen_valid():return false
	var outputs:Dictionary={}
	for name in ["space_enemy_candidates.json","space_enemy_routes.json","space_enemy_reward_recipes.json","space_enemy_reward_catalog.json"]:
		var parsed=JSON.parse_string(FileAccess.get_file_as_string("res://data/"+name))
		if not parsed is Dictionary or not Entity.output_valid(name,parsed):return false
		outputs[name]=parsed
	var candidate:Dictionary=outputs["space_enemy_candidates.json"]
	for enemy in candidate.enemies.values():
		if enemy.shield<0 or enemy.shieldRecovery<0 or enemy.shieldDelay<0 or int(enemy.shieldType) not in [0,1,2] or int(enemy.armourType) not in [0,1,2]:return false
	var loader=preload("res://scripts/hyperspace_route_loader.gd").new()
	var prepared:Dictionary=loader.prepare(g,outputs["space_enemy_routes.json"],candidate)
	if prepared.is_empty():return false
	var session=preload("res://scripts/hyperspace_manual_session.gd").new()
	if not session.configure(g,prepared.routes,prepared):return false
	var binder=preload("res://scripts/hyperspace_reward_binding.gd").new()
	if not binder.load_contract():return false
	for ref in binder.catalog.values():
		var design:Dictionary=g.db.groups.get(str(int(ref.source_design_group_id)),{})
		var level:int=int(ref.late_reference_actual_level_id)
		if design.is_empty() or design.slots.filter(func(v):return v!=null).size()!=int(ref.reference_member_count) or level<1 or level>g.db.levels.size():return false
		if not g.db.levels[level-1].groups.any(func(point):return int(point.id)==int(ref.late_reference_actual_group_id)):return false
	var origin:Dictionary=Entity.definition().sources_origin
	var source_data=JSON.parse_string(FileAccess.get_file_as_string("res://data/space_enemy_reward_sources.json"))
	if not source_data is Dictionary or source_data.get("source_sha256")!=origin.sha256 or binder.sources.size()!=int(origin.verified_wave_count):return false
	for wave in binder.sources:
		var stage:int=int(wave.stage);var node:int=int(wave.node)
		if stage<1 or stage>g.db.levels.size() or node<1 or node>g.db.levels[stage-1].groups.size() or int(g.db.levels[stage-1].groups[node-1].id)!=int(wave.group) or not g.db.groups.has(str(int(wave.group))) or not g.db.groups.has(str(int(wave.source_group))):return false
	for ref in binder.catalog.values():
		var count:int=int(ref.reference_member_count)
		if ref.late_drop_blocks!=mainline_blocks(g.db,int(ref.late_reference_actual_group_id)):return false
		if not ref.early_existing_encounters.is_empty():
			for source in ref.early_existing_encounters:
				var stage:int=int(source.level_id)
				if stage<1 or stage>g.db.levels.size() or not g.db.levels[stage-1].groups.any(func(point):return int(point.id)==int(source.group_id)) or mainline_blocks(g.db,int(source.group_id)).size()!=count:return false
			if ref.early_drop_blocks!=mainline_blocks(g.db,int(ref.early_existing_encounters[0].group_id)):return false
		for blocks in [ref.early_drop_blocks,ref.late_drop_blocks]:
			if blocks.size()!=count:return false
			for block in blocks:
				for drop in block:
					if not integer(drop.get("resourceId")) or not g.db.data.resources.has(str(int(drop.resourceId))) or not number(drop.get("amount")) or drop.amount<0 or not number(drop.get("chance")) or drop.chance<0 or drop.chance>1:return false
	return not binder.bind(g.db,prepared,int(g.hyperspace.config.unlock_stage),1).is_empty()

static func mainline_blocks(db,gid:int)->Array:
	var group:Dictionary=db.groups.get(str(gid),{})
	var blocks:Array=[]
	for id in group.get("slots",[]):
		if id!=null:
			if not db.enemies.has(str(int(id))):return []
			blocks.append(db.enemies[str(int(id))].drops)
	return blocks
