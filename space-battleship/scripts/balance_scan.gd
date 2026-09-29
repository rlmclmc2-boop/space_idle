extends RefCounted
## Paths address the real database; only each run's private copy is modified.
const MAX_POINTS := 101
const MAX_RUNS := 10000
const STRATEGIES := ["BALANCED","DAMAGE_FIRST","DEFENSE_FIRST","ECONOMY_FIRST","RANDOM_VALID"]
# Extend these lists with authored numeric fields, never a parallel combat formula.
const EQUIPMENT_FIELDS := ["dmg","dmgMulti","cd","cost_1","cost_2","cost_multi_1","cost_multi_2","costMulti_1","costMulti_2","para1","para2","para3","para4"]
const LEVEL_FIELDS := ["lifeRatio","atkRatio","resRatio","jewelRatio"]

static func parameters(data: Dictionary) -> Array:
	var result := []
	for section in ["config","defaults"]:
		for key in data[section]:
			if data[section][key] is float or data[section][key] is int:result.append([section,str(key)])
	for index in data.levels.size():
		for field in LEVEL_FIELDS:result.append(["levels",index,field])
	for key in BattleGame.EQUIPMENT:
		for index in data.equipment.get(key,[]).size():
			if int(data.equipment[key][index].get("level",0)) != 1:continue
			for field in EQUIPMENT_FIELDS:
				if data.equipment[key][index].get(field) is float or data.equipment[key][index].get(field) is int:result.append(["equipment",key,index,field])
	for section in ["jewel","hightech","enemies"]:
		for key in data.get(section,{}):
			var fields: Array = ["para_2","para_3","para_4","para_5","para_6","para_7"] if section == "jewel" else ["para1","para2","para3"] if section == "hightech" else ["health","dmgMultiple"]
			for field in fields:
				var value: Variant = data[section][key].get(field)
				if value is int or value is float:result.append([section,str(key),field])
	return result

static func identifier(path: Array) -> String:
	var parts := PackedStringArray()
	for key in path:parts.append(str(key))
	return "/".join(parts)

static func valid_value(path: Array, value: float) -> bool:
	if not is_finite(value) or value < 0:return false
	var field := str(path.back())
	if field == "cd" or path[0] == "levels":return value > 0
	# Zero flight speed creates stationary projectiles that cannot reach a
	# target or leave the arena. A stalled encounter then accumulates them forever.
	# Beam para1 is a ramp duration, not a flight speed, and may still be zero.
	if path[0] == "defaults" and field == "projectilePixelsPerUnit":return value > 0
	if path[0] == "equipment" and ((path[1] in ["laser","cannon"] and field == "para1") or (path[1] == "missile" and field == "para2")):return value > 0
	if path[0] == "config" and field.begins_with("reactor") and field != "reactorUraniumId":return value > 0
	if path[0] == "hightech" and field == "para1":return value > 0
	if field == "dmgReduce":return value < 1
	if field == "autoCollectReduce":return value <= 1
	return true

static func read(data: Dictionary, path: Array) -> float:
	var value: Variant = data
	for key in path:value = value[key]
	return float(value)

static func apply(data: Dictionary, path: Array, value: float) -> void:
	var target: Variant = data
	for index in path.size()-1:target = target[path[index]]
	target[path.back()] = value

static func jobs(config: Dictionary, data: Dictionary) -> Dictionary:
	var duration := float(config.get("duration",3600))
	var repeats := int(config.get("runs",1))
	if not is_finite(duration) or duration <= 0 or duration > 31536000 or repeats < 1 or repeats > 100:return {"error":"invalid_configuration"}
	var seed_value := float(config.get("seed",1))
	if not is_finite(seed_value) or seed_value != floorf(seed_value) or absf(seed_value) > 2147483647:return {"error":"invalid_seed"}
	var strategies: Array = config.get("strategies",["BALANCED"])
	if strategies.is_empty() or strategies.size() > STRATEGIES.size():return {"error":"invalid_strategy"}
	var seen := {}
	for strategy in strategies:
		if strategy not in STRATEGIES or seen.has(strategy):return {"error":"invalid_strategy"}
		seen[strategy] = true
	var sweeps: Array = config.get("sweeps",[]).duplicate(true)
	if sweeps.is_empty() and not config.get("scan",{}).is_empty():sweeps.append(config.scan)
	if sweeps.is_empty():sweeps.append({})
	if sweeps.size() > 20:return {"error":"scan_too_large"}
	var result := []
	var catalog := parameters(data)
	seen.clear()
	for scan in sweeps:
		if scan.is_empty():
			for strategy in strategies:
				for index in repeats:result.append({"seed":int(seed_value)+index,"value":null,"path":[],"parameter_id":"","strategy":strategy})
			continue
		if not catalog.has(scan.get("path",[])):return {"error":"invalid_parameter"}
		var id := identifier(scan.path)
		if seen.has(id):return {"error":"duplicate_parameter"}
		seen[id] = true
		var start := float(scan.get("start",0))
		var end := float(scan.get("end",0))
		var step := float(scan.get("step",0))
		if not valid_value(scan.path,start) or not valid_value(scan.path,end) or not is_finite(step) or end < start or step <= 0:return {"error":"invalid_scan"}
		var intervals := (end-start)/step
		if not is_finite(intervals) or intervals > MAX_POINTS-1+0.0000001:return {"error":"scan_too_large"}
		var count := floori(intervals+0.0000001)+1
		if result.size()+count*repeats*strategies.size() > MAX_RUNS:return {"error":"scan_too_large"}
		for point in count:
			var value := start+point*step
			for strategy in strategies:
				for index in repeats:result.append({"seed":int(seed_value)+index,"value":value,"path":scan.path,"parameter_id":id,"strategy":strategy})
	return {"jobs":result}
