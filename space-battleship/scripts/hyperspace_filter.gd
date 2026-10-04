extends RefCounted
const C=preload("res://scripts/hyperspace_config.gd")
const PREFIX:="SPACE-FILTER-v1:"

static func fresh() -> Dictionary:
	return {"version":1,"enabled":false,"mode":"all","conditions":[]}

static func valid(f: Dictionary,c: Dictionary) -> bool:
	if f.get("version")!=1 or not f.get("enabled") is bool or f.get("mode") not in ["all","any"] or not f.get("conditions") is Array or f.conditions.size()>int(c.maximum_filter_conditions):return false
	for condition in f.conditions:
		if not condition is Dictionary:return false
		match condition.get("field"):
			"weapon":
				if condition.get("value") not in ["laser","missile","cannon","longLaser"]:return false
			"quality":
				if condition.get("value") not in ["white","blue","gold","legendary","ultimate"]:return false
			"minimum_level":
				if not C.integer(condition.get("value")) or condition.value<0:return false
			"affix":
				if not c.affixes.has(condition.get("key")) or not C.integer(condition.get("tier")) or condition.tier<1 or condition.tier>5:return false
			"legendary_effect":
				if not c.legendary_effects.has(condition.get("value")):return false
			_:return false
	return true

static func matches(d: Dictionary,f: Dictionary) -> bool:
	if not f.enabled or f.conditions.is_empty():return true
	for condition in f.conditions:
		var ok:=false
		match condition.field:
			"weapon":ok=d.weapon==condition.value
			"quality":ok=d.ultimate if condition.value=="ultimate" else d.legendary if condition.value=="legendary" else (not d.legendary and d.origin_quality==condition.value)
			"minimum_level":ok=int(d.level)>=int(condition.value)
			"affix":
				var affixes: Array=d.affixes+[d.ultimate_affix] if d.ultimate and not d.ultimate_affix.is_empty() else d.affixes
				ok=affixes.any(func(a):return a.key==condition.key and int(a.tier)<=int(condition.tier))
			"legendary_effect":ok=d.legendary and d.legendary_effect.get("effect_id")==condition.value
		if f.mode=="any" and ok:return true
		if f.mode=="all" and not ok:return false
	return f.mode=="all"

static func export_string(f: Dictionary,c: Dictionary) -> String:
	return PREFIX+Marshalls.utf8_to_base64(JSON.stringify(f,"",true)) if valid(f,c) else ""

static func import_string(value: String,c: Dictionary) -> Dictionary:
	if value.length()>int(c.maximum_filter_string_length) or not value.begins_with(PREFIX):return {}
	var payload:=value.trim_prefix(PREFIX)
	if payload.is_empty() or payload.length()%4!=0:return {}
	var pattern:=RegEx.new();pattern.compile("^[A-Za-z0-9+/]*={0,2}$")
	if pattern.search(payload)==null:return {}
	var decoded:=Marshalls.base64_to_utf8(payload)
	# Reject malformed/noncanonical base64 before parsing; never evaluate input.
	if Marshalls.utf8_to_base64(decoded)!=payload:return {}
	var f=JSON.parse_string(decoded)
	return f if f is Dictionary and valid(f,c) else {}
