extends RefCounted
const C=preload("res://scripts/hyperspace_config.gd")
const R=preload("res://scripts/hyperspace_random.gd")

static func affix_limit(d: Dictionary,c: Dictionary) -> int:
	return int(c.quality_limits.legendary.affixes) if d.legendary else int(c.quality_limits[d.origin_quality].affixes)

static func hanging_limit(d: Dictionary,c: Dictionary) -> int:
	return maxi(int(c.quality_limits.legendary.hangings),int(d.preserved_hanging_slots)) if d.legendary else int(c.quality_limits[d.origin_quality].hangings)

static func fresh() -> Dictionary:
	return {"drones":{},"warehouse":[],"overflow":[],"equipped":[],"favorites":[],"presets":[],"sealed":{},"reforge_count":0,"generation":0}

static func capacity(bag: Dictionary,c: Dictionary) -> int:
	return int(c.warehouse_capacity)+int(bag.reforge_count)*int(c.reforge_capacity_gain)

static func retention_capacity(bag: Dictionary,c: Dictionary) -> int:
	return int(c.initial_retention_capacity)+int(bag.reforge_count)*int(c.retention_capacity_gain)

static func has_space(bag: Dictionary,c: Dictionary) -> bool:
	return bag.warehouse.size()<capacity(bag,c) or bag.overflow.size()<int(c.overflow_capacity)

static func valid_drone(d: Dictionary,c: Dictionary) -> bool:
	if not d.get("id") is String or d.id.is_empty() or d.id.length()>96:return false
	if not d.get("origin_quality") in c.quality_limits or not d.get("weapon") in ["laser","missile","cannon","longLaser"]:return false
	if not C.integer(d.get("level")) or d.level<1:return false
	if not d.get("legendary") is bool or not d.get("ultimate") is bool or not d.get("blue_source_bonus") is bool:return false
	if d.blue_source_bonus and d.origin_quality!="blue":return false
	if d.origin_quality=="legendary" and not d.legendary:return false
	if not d.get("planet_id") is String or d.planet_id.is_empty():return false
	if not d.get("omen") is bool or not R.valid_state(d.get("forge_rng_state")):return false
	for key in ["hanging_slots","preserved_hanging_slots","forge_revision"]:
		if not C.integer(d.get(key)) or d[key]<0:return false
	if d.preserved_hanging_slots>int(c.quality_limits[d.origin_quality].hangings):return false
	if not d.get("legendary_effect") is Dictionary or not d.get("ultimate_affix") is Dictionary:return false
	if not d.legendary and not d.legendary_effect.is_empty():return false
	if d.ultimate and d.ultimate_affix.is_empty():return false
	if not d.get("affixes") is Array or not d.get("hangings") is Array:return false
	# Transmutation preserves source limits and every existing hanging/affix.
	if d.affixes.size()>affix_limit(d,c) or d.hanging_slots>hanging_limit(d,c) or d.hangings.size()>int(d.hanging_slots):return false
	for a in d.affixes:
		if not valid_affix(a) or not affix_matches(a,d.weapon,c):return false
	if not d.ultimate_affix.is_empty() and (not valid_affix(d.ultimate_affix) or not affix_matches(d.ultimate_affix,d.weapon,c)):return false
	if d.legendary:
		var effect: Dictionary=d.legendary_effect
		if not c.legendary_effects.has(effect.get("effect_id")) or not effect.get("parameters") is Dictionary:return false
		var row: Dictionary=c.legendary_effects[effect.effect_id]
		if not row.weapon.is_empty() and row.weapon!=d.weapon:return false
		if effect.parameters.size()!=row.parameters.size():return false
		for key in effect.parameters:
			if not row.parameters.has(key) or not C.number(effect.parameters[key]):return false
			var value: float = float(effect.parameters[key])
			if effect.effect_id=="drone_master" and key=="maximum_reduction":
				var precision:=C.parameter_precision(c,str(effect.effect_id),str(key))
				# This approved eleven-outcome rule supersedes historical master values.
				if value<float(row.parameters[key][0]) or value>float(row.parameters[key][1]) or absf(value/precision-roundf(value/precision))>0.0000001:return false
			var current: Array = row.parameters[key]
			var stored: Array = row.get("stored_parameter_ranges",{}).get(key,current)
			if not (value>=float(current[0]) and value<=float(current[1])) and not (value>=float(stored[0]) and value<=float(stored[1])):return false
	var seen: Dictionary={}
	for h in d.hangings:
		if not h is String or not c.hanging_modules.has(h) or seen.has(h):return false
		seen[h]=true
	return true

static func valid_affix(a: Variant) -> bool:
	return a is Dictionary and a.get("key") is String and not a.key.is_empty() and C.integer(a.get("tier")) and a.tier>=1 and a.tier<=5 and C.number(a.get("value")) and a.get("locked") is bool

static func affix_matches(a: Dictionary,weapon: String,c: Dictionary) -> bool:
	var row: Dictionary=c.affixes.get(a.key,{})
	if row.is_empty() or (not row.weapon.is_empty() and row.weapon!=weapon) or not row.ranges.has(str(int(a.tier))):return false
	var bounds: Array=row.ranges[str(int(a.tier))]
	return a.value>=bounds[0]-0.0000001 and a.value<=bounds[1]+0.0000001

static func valid(bag: Dictionary,c: Dictionary) -> bool:
	if not C.integer(bag.get("reforge_count")) or bag.reforge_count<0 or not C.integer(bag.get("generation")) or bag.generation<0:return false
	if not bag.get("drones") is Dictionary or not bag.get("sealed") is Dictionary:return false
	for key in ["warehouse","overflow","equipped","favorites","presets"]:
		if not bag.get(key) is Array:return false
	if bag.warehouse.size()>capacity(bag,c) or bag.overflow.size()>int(c.overflow_capacity) or bag.presets.size()>3:return false
	var stored: Dictionary={}
	for id in bag.warehouse+bag.overflow:
		if not id is String or stored.has(id) or not bag.drones.has(id):return false
		stored[id]=true
	if stored.size()!=bag.drones.size():return false
	for id in bag.drones:
		if not bag.drones[id] is Dictionary or bag.drones[id].get("id")!=id or not valid_drone(bag.drones[id],c):return false
	for ids in [bag.equipped,bag.favorites]:
		if not references_valid(ids,bag):return false
	if not equipment_valid(bag,bag.equipped,int(c.maximum_equipped),c):return false
	for id in bag.sealed:
		if not stored.has(id) or not C.integer(bag.sealed[id]) or bag.sealed[id]<1 or bag.equipped.has(id):return false
	for preset in bag.presets:
		if not preset is Dictionary or not preset.get("name") is String or preset.name.length()>96 or not preset.get("drone_ids") is Array or preset.drone_ids.size()>int(c.maximum_equipped):return false
		var refs: Dictionary={}
		for id in preset.drone_ids:
			if not id is String or id.is_empty() or refs.has(id):return false
			refs[id]=true
		if not preset.get("hanging_loadouts") is Dictionary:return false
		for id in preset.hanging_loadouts:
			if not preset.drone_ids.has(id) or not preset.hanging_loadouts[id] is Array:return false
			if not preset.hanging_loadouts[id].all(func(key):return key is String and c.hanging_modules.has(key)):return false
			if not bag.drones.has(id):continue
			var d: Dictionary=bag.drones[id].duplicate(true);d.hangings=preset.hanging_loadouts[id]
			if not valid_drone(d,c):return false
	return true

static func references_valid(ids: Array,bag: Dictionary) -> bool:
	var seen: Dictionary={}
	for id in ids:
		if not id is String or not bag.drones.has(id) or seen.has(id):return false
		seen[id]=true
	return true

static func equipment_valid(bag: Dictionary,ids: Array,hull_capacity: int,c: Dictionary) -> bool:
	if ids.size()>mini(hull_capacity,int(c.maximum_equipped)) or not references_valid(ids,bag):return false
	var legendary:=0;var ultimate:=0
	for id in ids:
		if bag.sealed.has(id) or not bag.warehouse.has(id):return false
		legendary+=int(bag.drones[id].legendary);ultimate+=int(bag.drones[id].ultimate)
	return legendary<=int(c.maximum_legendary) and ultimate<=int(c.maximum_ultimate)

static func protected(bag: Dictionary,id: String) -> bool:
	return bag.equipped.has(id) or bag.favorites.has(id) or bag.sealed.has(id) or bag.presets.any(func(p):return p.drone_ids.has(id))

static func insert(bag: Dictionary,drone: Dictionary,c: Dictionary) -> bool:
	if not valid_drone(drone,c) or bag.drones.has(drone.id) or not has_space(bag,c):return false
	bag.drones[drone.id]=drone.duplicate(true)
	if bag.warehouse.size()<capacity(bag,c):bag.warehouse.append(drone.id)
	else:bag.overflow.append(drone.id)
	bag.generation+=1
	return true

static func remove(bag: Dictionary,id: String) -> bool:
	# Removal is the shared protection boundary. Dismantling rewards belong to Forge.
	if not bag.drones.has(id) or protected(bag,id):return false
	bag.drones.erase(id);bag.warehouse.erase(id);bag.overflow.erase(id);bag.generation+=1
	return true

static func organize(bag: Dictionary,c: Dictionary) -> void:
	while not bag.overflow.is_empty() and bag.warehouse.size()<capacity(bag,c):
		bag.warehouse.append(bag.overflow.pop_front());bag.generation+=1

static func reforge(bag: Dictionary,keep_ids: Array,claim_stages: Dictionary,c: Dictionary) -> Dictionary:
	# The upcoming reforge adds ten retention slots; choose explicitly before committing.
	if keep_ids.size()>retention_capacity(bag,c)+int(c.retention_capacity_gain) or not references_valid(keep_ids,bag):return {}
	var next:=fresh();next.reforge_count=int(bag.reforge_count)+1;next.generation=int(bag.generation)+1
	for id in keep_ids:
		if not C.integer(claim_stages.get(id)) or claim_stages[id]<1:return {}
		next.drones[id]=bag.drones[id].duplicate(true);next.warehouse.append(id);next.sealed[id]=int(claim_stages[id])
		if bag.favorites.has(id):next.favorites.append(id)
	return next
