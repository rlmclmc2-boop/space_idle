extends RefCounted
## Ordered attribute composition for gameplay, previews and native descriptors.
## Cached values depend on domain contribution versions, never elapsed work or UI events.
const N=preload("res://scripts/growth_number.gd")
const DroneEffects=preload("res://scripts/drone_effect_aggregator.gd")
var enabled=true
var _cache:Dictionary={}
var builds:Dictionary={}
var _configuration_inputs:Array=[]
var _configuration_version=0
var _sources:Array=[]
var _source_inputs:Array=[]
func configuration_inputs(g)->Array:
	return [g.db.get_instance_id(),g.configuration_revision,g.unlock_revision,g.equipment.contribution_revision,g.reactor.revision,g.research.contribution_revision,g.crew.contribution_revision,g.planets.contribution_revision,g.galaxy.effect_generation,g.hyperspace.contribution_revision,g.drone_combat.contribution_revision,g.enhancement_growth.configuration_revision]
func configuration_version(g)->int:
	var inputs=configuration_inputs(g)
	if inputs!=_configuration_inputs:_configuration_inputs=inputs;_configuration_version+=1
	return _configuration_version
func rule_inputs(g)->Array:
	return [g.db.get_instance_id(),g.configuration_revision,g.unlock_revision,g.equipment.contribution_revision,g.enhancement_growth.configuration_revision,g.planets.contribution_revision,g.hyperspace.contribution_revision,g.drone_combat.contribution_revision]
func stat_inputs(g,key:String)->Array:
	var inputs=configuration_inputs(g)
	inputs.append(g.enhancement_growth.attacks() if key in g.WEAPON_KEYS else g.enhancement_growth.hits())
	inputs.append(int(g.enhancement_branches.weapon_revisions.get(key,0)))
	return inputs
func slot(key:String,inputs:Array,retain=true)->Dictionary:
	if not enabled or not retain:return {}
	var item:Dictionary=_cache.get(key,{})
	if item.is_empty() or item.inputs!=inputs:
		item={"inputs":inputs};_cache[key]=item
		builds[key]=int(builds.get(key,0))+1
	return item
func permanent_modifiers(g)->Dictionary:
	var item=slot("planet_modifiers",[g.db.get_instance_id(),g.configuration_revision,g.planets.contribution_revision])
	if not item.has("value"):item.value=g.planet_buffs.totals(g)
	return item.value
func hyperspace_totals(g)->Dictionary:
	var item=slot("hyperspace_totals",[g.db.get_instance_id(),g.configuration_revision,g.unlock_revision,g.hyperspace.contribution_revision,g.drone_combat.contribution_revision])
	if not item.has("value"):item.value=DroneEffects.project(g)
	return item.value
func planet_equipment_multiplier(g)->Variant:
	var item=slot("planet_equipment",[g.db.get_instance_id(),g.configuration_revision,g.planets.contribution_revision])
	if not item.has("value"):item.value=g.planet_buildings.multiplier(g,"equipment")
	return item.value
func planet_resource_multiplier(g)->Variant:
	var item=slot("planet_refinery",[g.db.get_instance_id(),g.configuration_revision,g.unlock_revision,g.planets.contribution_revision,g.hyperspace.contribution_revision,g.drone_combat.contribution_revision])
	if not item.has("value"):item.value=N.multiply(g.planet_buildings.multiplier(g,"refinery"),1.0+float(hyperspace_totals(g).hangings.get("resource_collector",0)))
	return item.value
func crew_equipment(g)->float:
	var item=slot("crew_equipment",[g.db.get_instance_id(),g.configuration_revision,g.unlock_revision,g.crew.contribution_revision])
	if not item.has("value"):item.value=g.crew.system_effect(g,"equip_bonus")
	return float(item.value)
func external_factors(g,entry:Dictionary,totals:Dictionary,galaxy_equipment:float=-1.0)->Array:
	var attack:bool=entry.key in g.WEAPON_KEYS
	return [planet_equipment_multiplier(g),crew_equipment(g),g.galaxy.multiplier("equipment_value") if galaxy_equipment<0 else galaxy_equipment,float(totals.damage if attack else totals.defence)*float(totals.weapon_damage.get(str(entry.key),1.0) if attack else totals.get(str(entry.key),1.0))]
func apply_external(value:Variant,factors:Array)->Variant:
	# Preserve grouping and rounding: planet, crew, galaxy, then the combined drone factor.
	for factor in factors:value=N.multiply(value,factor)
	return value

func stat(g,key: String) -> Variant:
	var item=slot("stat:"+key,stat_inputs(g,key))
	if item.has("value"):return item.value
	var total = 0.0
	for category in ["weapons", "defence"]:
		for entry in g.loadout_entries(category):
			if str(entry.get("key", "")) == key:
				total = N.add(total,g.jewel_equipment_stat(entry))
	item.value=total
	return total

func equipment_stat(g,key: String, level: int, galaxy_charge = -1.0) -> Variant:
	var item=slot("equipment_bases",[g.db.get_instance_id(),g.configuration_revision,g.unlock_revision,g.research.contribution_revision,g.reactor.revision,g.crew.contribution_revision,g.galaxy.effect_generation,g.planets.contribution_revision,g.hyperspace.contribution_revision,g.drone_combat.contribution_revision],galaxy_charge<0)
	if not item.has("levels"):item.levels={}
	var levels:Dictionary=item.levels.get(key,{})
	if levels.has(level):return levels[level]
	# Only the ordinary damage/capacity projection reads the effective level.
	var effective_level=g.effective_equipment_level(level)
	var row = g.combat_equipment_row(key, effective_level)
	var value = row.para1 if key in ["armour", "shield"] else row.dmg
	# Virtual level bonuses keep ordinary growth, but only paid slot levels grant evolution.
	if effective_level!=level:
		value=N.multiply(value,N.divide(g.db.evolution_factor(level),g.db.evolution_factor(effective_level)))
	var tech_factor = g.research.combat_factor(g,"equipment_durability" if key in ["armour", "shield"] else "weapon_damage")
	if N.compare(tech_factor,1.0) != 0:
		value = N.ceiling(N.multiply(value,tech_factor))
	var reactor_bonus: Variant=g.reactor_multiplier("defence" if key in ["armour", "shield"] else "weapons",galaxy_charge)
	if N.compare(reactor_bonus,1.0)!=0:
		value = N.ceiling(N.multiply(value,reactor_bonus))
	if levels.size()>=32:levels.clear()
	levels[level]=value;item.levels[key]=levels
	return value

func jewel_equipment_stat(g,entry: Dictionary, level = -1, effects: Variant = null, include_timed_buffs = true, galaxy_equipment = -1.0, galaxy_charge = -1.0) -> Variant:
	if str(entry.get("key", "")).is_empty():
		return 0
	var value = equipment_stat(g,str(entry.key), int(entry.level) if level < 0 else level,galaxy_charge)
	var projected = entry
	if level>=0:
		projected=entry.duplicate()
		projected.level=level
	for effect in (g.jewel_effects(projected) if effects == null else effects):
		if effect.kind in ["proficiency", "adaptation"]:
			value = N.ceiling(N.multiply(value,g.enhancement_growth.history_multiplier(g.db,effect.kind,int(effect.level),float(effect.p2))))
	value=N.multiply(value,g.enhancement_branches.weapon_multiplier(g,projected,entry,include_timed_buffs) if g.WEAPON_KEYS.has(str(entry.key)) else g.enhancement_branches.capacity_multiplier(g,projected))
	return apply_external(value,external_factors(g,entry,g.hyperspace_totals(),galaxy_equipment))

func jewel_critical(g,entry: Dictionary, effects: Variant = null, include_timed_buffs = true, drone_totals: Dictionary = {}) -> Vector2:
	var row = g.combat_equipment_row(str(entry.key), int(entry.level))
	var rate = g.enhancement_branches.underlying_critical_rate(g,entry,include_timed_buffs)
	if g.enhancement_branches.active(g,entry,"critical",3,"B"):rate=g.enhancement_parameter("critical_b3_guaranteed_rate")
	var damage = g.enhancement_parameter("base_critical_multiplier") + float(row.get("criDmg",0))
	for effect in (g.jewel_effects(entry) if effects == null else effects):
		if effect.kind=="critical":damage+=float(effect.p4)*int(effect.level)
	var drones=g.hyperspace_totals() if drone_totals.is_empty() else drone_totals
	return Vector2(clampf(rate+float(drones.critical_chance),0,1),maxf(0,damage)*float(drones.critical_damage))

func player_weapon_row(g,entry: Dictionary, drone_totals: Dictionary = {}, endless_selected:Variant=null) -> Dictionary:
	var weapon = g.combat_equipment_row(str(entry.key),int(entry.level)).duplicate()
	var drones=g.hyperspace_totals() if drone_totals.is_empty() else drone_totals
	weapon.cd=float(weapon.cd)*g.enhancement_branches.cooldown_multiplier(g,entry)/float(drones.attack_speed)
	if entry.key=="longLaser":
		var endless: Dictionary=drones.legendary.get("endless_beam",{})
		if not endless.is_empty() and (g.same_module(entry,g.endless_source()) if endless_selected==null else bool(endless_selected)):weapon.para2=float(weapon.para2)+float(endless.parameters.maximum_multiplier_bonus)
	return weapon

func _jewel_defence_capacity(g,key: String) -> Dictionary:
	# Memory capacity depends on the same equipment, counters, crew, planet and
	# branch selections as the existing defence cache, not live buffers/timers.
	var item=slot("defence:"+key,stat_inputs(g,key))
	var capacity:Dictionary=item.get("value",{})
	if capacity.is_empty():
		var indices: Array = []
		var maxima = {}
		var effects_by_index = {}
		var protection_caps = {}
		var total = 0.0
		for index in g.defense_entries().size():
			var entry = g.slot_entry("defence", index)
			if entry.key != key:
				continue
			indices.append(index)
			var effects = g.jewel_effects(entry)
			var maximum = g.jewel_equipment_stat(entry, -1, effects)
			maxima[index] = maximum
			effects_by_index[index] = effects
			protection_caps[index]=memory_capacity(g,entry,effects,maximum)
			total = N.add(total,maximum)
		capacity = {"indices":indices,"maxima":maxima,"effects":effects_by_index,"total":total,"protection_caps":protection_caps}
		if enabled:
			item.value=capacity
	return capacity

func endless_source(g) -> Dictionary:
	var item=slot("endless_source",[g.equipment.contribution_revision])
	if item.has("value"):return item.value
	var index:int=g.endless_source_slot()
	item.value=g.weapon_entries()[index] if index>=0 else {}
	return item.value

func combat_weapon_entries(g) -> Array:
	if g.hyperspace.state.inventory.equipped.is_empty():return g.weapon_entries()
	var inputs:Array=[g.db.get_instance_id(),g.configuration_revision,g.equipment.contribution_revision,g.hyperspace.contribution_revision,g.drone_combat.contribution_revision]
	if inputs==_source_inputs:return _sources
	var previous: Dictionary={}
	for entry in _sources:
		if entry.has("drone_id"):previous[entry.drone_id]=entry
	_sources=g.weapon_entries().duplicate()
	for id in g.hyperspace.state.inventory.equipped:
		if g.hyperspace.state.inventory.sealed.has(id) or g.drone_combat.disabled.has(id):continue
		var d: Dictionary=g.hyperspace.state.inventory.drones[id]
		var projected=g.drone_weapon_entry(d)
		var old: Dictionary=previous.get(id,{})
		_sources.append(old if old.get("key")==projected.key and old.get("level")==projected.level else projected)
	_source_inputs=inputs
	return _sources

func drone_weapon_entry(g,d: Dictionary, weapon_levels:Dictionary={}) -> Dictionary:
	var maximum=1
	var entries=g.module_entries("weapons")
	for index in entries.size():
		var entry:Dictionary=entries[index]
		if entry.key==d.weapon:maximum=maxi(maximum,int(weapon_levels.get(index,entry.level)))
	return {"key":d.weapon,"level":maximum+DroneEffects.weapon_bonus(d,g.hyperspace.config),"drone_id":str(d.id)}

func reactor_contributions(g,galaxy_charge = -1.0) -> Array:
	return [float(g.crew.system_effect(g,"charge_bonus")), float(g.galaxy.multiplier("charge_max")) if galaxy_charge < 0 else galaxy_charge, 1.0 + float(g.hyperspace_totals().hangings.get("extra_storage",0))]

func memory_capacity(g,entry:Dictionary,effects:Array,maximum:Variant)->Variant:
	for effect in effects:
		if effect.kind=="memory_material":return N.multiply(maximum,float(effect.p4)*int(effect.level)*g.enhancement_branches.memory_cap_multiplier(g,entry))
	return 0.0

func reactor_energy(g,level := -1, galaxy_charge := -1.0) -> Variant:
	return g.reactor.energy(g.db.config, g.reactor_contributions(galaxy_charge), level)

func reactor_capacity(g,galaxy_charge := -1.0) -> Variant:
	return g.reactor.capacity(g.db.config, g.reactor_contributions(galaxy_charge))

func reactor_effective_ratio(g,key: String) -> Variant:
	if not g.reactor_unlocked() or not g.reactor_module_unlocked(key):return 0.0
	return g.reactor.effective_ratio(key, g.reactor_capacity(), g.charge_free_ratio())

func reactor_multiplier(g,key: String, galaxy_charge := -1.0) -> Variant:
	if not g.reactor_module_unlocked(key):return 1.0
	return g.reactor.multiplier(key, g.reactor_capacity(galaxy_charge), g.charge_free_ratio() if g.reactor_unlocked() else 0.0, g.db.config)
