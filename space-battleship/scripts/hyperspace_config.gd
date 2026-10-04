extends RefCounted
## Independent configuration; no changes to production economic tables.
static func load_config() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/hyperspace_config.json"))

static func valid(c: Dictionary) -> bool:
	if c.get("version")!=1:return false
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
		if not q is Dictionary or not integer(q.get("affixes")) or not integer(q.get("hangings")) or q.affixes<0 or q.affixes>3 or q.hangings<0 or q.hangings>4:return false
	return true

static func number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and absf(float(value))<9.0e15

static func integer(value: Variant) -> bool:
	return number(value) and float(value)==floorf(float(value))
