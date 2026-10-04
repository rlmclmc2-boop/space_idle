extends RefCounted
const C=preload("res://scripts/hyperspace_config.gd")

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
	if not C.integer(d.get("level")) or d.level<int(c.minimum_level):return false
	if not d.get("legendary") is bool or not d.get("ultimate") is bool or not d.get("blue_source_bonus") is bool:return false
	if d.blue_source_bonus and d.origin_quality!="blue":return false
	if d.origin_quality=="legendary" and not d.legendary:return false
	if not d.get("legendary_effect") is Dictionary or not d.get("ultimate_affix") is Dictionary:return false
	if not d.legendary and not d.legendary_effect.is_empty():return false
	if not d.ultimate and not d.ultimate_affix.is_empty():return false
	if not d.get("affixes") is Array or not d.get("hangings") is Array:return false
	# Transmutation preserves source limits and every existing hanging/affix.
	var limits: Dictionary=c.quality_limits[d.origin_quality]
	if d.affixes.size()>int(limits.affixes) or d.hangings.size()>int(limits.hangings):return false
	for a in d.affixes:
		if not valid_affix(a):return false
	if not d.ultimate_affix.is_empty() and not valid_affix(d.ultimate_affix):return false
	if not d.legendary_effect.is_empty():
		if not d.legendary_effect.get("effect_id") is String or not C.number(d.legendary_effect.get("value")):return false
	var seen: Dictionary={}
	for h in d.hangings:
		if not h is String or h.is_empty() or h.length()>96 or seen.has(h):return false
		seen[h]=true
	return true

static func valid_affix(a: Variant) -> bool:
	return a is Dictionary and a.get("key") is String and not a.key.is_empty() and C.integer(a.get("tier")) and a.tier>=1 and a.tier<=5 and C.number(a.get("value")) and a.get("locked") is bool

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
		if not preset is Dictionary or not preset.get("name") is String or preset.name.length()>96 or not preset.get("drone_ids") is Array or not references_valid(preset.drone_ids,bag):return false
		if not preset.get("hanging_loadouts") is Dictionary:return false
		for id in preset.hanging_loadouts:
			if not preset.drone_ids.has(id) or not preset.hanging_loadouts[id] is Array:return false
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
