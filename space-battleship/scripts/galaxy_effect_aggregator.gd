extends RefCounted
## The only Galaxy effect projection. Consumers never sum building levels.
const MULTIPLIERS := ["crew_exp","equipment_value","charge_max","gem_fragment"]
const RESOURCES := ["iron_auto_ratio","uranium_auto_ratio"]
var cache := {}
var totals := {}
var generation := -1

func building_detail(region, slot: Dictionary) -> Dictionary:
	var definition: Dictionary=region.builds[slot.type]
	return {"type":definition.effect_type,"amount":float(definition.base_effect)*int(slot.level) if slot.status in ["active","upgrading"] else 0.0}

func invalidate() -> void:
	generation=-1

func region_effects(region)->Dictionary:
	var values:Dictionary={}
	for effect in MULTIPLIERS+RESOURCES:values[effect]=0.0
	for slot in region.slots:
		if not slot.status in ["active","upgrading"]:continue
		var detail:=building_detail(region,slot)
		values[detail.type]+=detail.amount
	for effect in MULTIPLIERS:values[effect]+=1.0
	return values

func projected_multipliers(system, key:String, predicted)->Dictionary:
	var result:Dictionary={}
	for effect in MULTIPLIERS:result[effect]=1.0
	for region_key in system.regions:
		var region=predicted if region_key==key else system.regions[region_key]
		var values:=region_effects(region)
		for effect in MULTIPLIERS:result[effect]*=values[effect]
	return result

func refresh(system) -> void:
	if generation==system.effect_generation:return
	cache.clear()
	totals.clear()
	for key in MULTIPLIERS:totals[key]=1.0
	for key in RESOURCES:totals[key]=0.0
	for key in system.regions:
		var region=system.regions[key]
		var effects:=region_effects(region)
		for effect in MULTIPLIERS:
			totals[effect]*=effects[effect]
		for effect in RESOURCES:totals[effect]+=effects[effect]
		cache[key]=effects
	generation=system.effect_generation

func multiplier(system, effect: String) -> float:
	refresh(system)
	return float(totals.get(effect,1.0))

func rates(g, system, key := "") -> Dictionary:
	refresh(system)
	var effects: Dictionary=totals if key.is_empty() else cache.get(key,{})
	var iron=g.income_history.production_total(str(int(system.setting(g,"iron_resource_id"))),g.production_time(),g.economy_time(),g.production_time())
	var uranium=g.income_history.production_total(str(int(g.db.config.reactorUraniumId)),g.production_time(),g.economy_time(),g.production_time())
	return {"iron":g.N.multiply(iron,float(effects.get("iron_auto_ratio",0))),"uranium":g.N.multiply(uranium,float(effects.get("uranium_auto_ratio",0)))}
