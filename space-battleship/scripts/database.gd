class_name ShipDatabase
extends RefCounted

var data: Dictionary
var equipment: Dictionary
var enemies: Dictionary
var groups: Dictionary
var levels: Array
var config: Dictionary
var defaults: Dictionary
var ships: Dictionary

func _init() -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string("res://data/game_data.json"))
	equipment = data.equipment
	enemies = data.enemies
	groups = data.groups
	levels = data.levels
	config = data.config
	defaults = data.defaults
	ships = data.get("ship", {})

func equip(key: String, level: int) -> Dictionary:
	if level < 1:
		return {}
	for row in equipment.get(key, []):
		if int(row.get("level", 0)) == 1:
			var result: Dictionary = row.duplicate(true)
			result.level = level
			if level == 1:
				return result
			if key in ["armour", "shield"]:
				result.para1 = equipment_growth(float(row.para1), float(row.get("para2" if key == "armour" else "para4", 0)), level)
			elif row.get("dmgMulti") != null and row.get("dmg") != null:
				result.dmg = equipment_growth(float(row.dmg), float(row.dmgMulti), level)
			for field in row:
				var suffix := str(field).trim_prefix("cost_")
				if str(field).begins_with("cost_") and suffix.is_valid_int() and row[field] != null:
					var multiplier = row.get("cost_multi_" + suffix, row.get("costMulti_" + suffix))
					if multiplier != null:
						result[field] = equipment_growth(float(row[field]), float(multiplier), level)
			return result
	return {}

func ship(key: String) -> Dictionary:
	return ships.get(key, {})

func equipment_cost(key: String, level: int) -> Dictionary:
	# Same cost projection as equip(), without copying/growing unrelated combat fields.
	if level<1:return {}
	for row in equipment.get(key,[]):
		if int(row.get("level",0))!=1:continue
		var result := {}
		for field in row:
			if not str(field).begins_with("res_") or row[field]==null:continue
			var suffix := str(field).trim_prefix("res_")
			var amount = row.get("cost_"+suffix)
			if amount==null:continue
			var multiplier = row.get("cost_multi_"+suffix,row.get("costMulti_"+suffix))
			if level>1 and suffix.is_valid_int() and multiplier!=null:
				amount=equipment_growth(float(amount),float(multiplier),level)
			result[str(int(row[field]))]=ceilf(float(amount))
		return result
	return {}

func jewel(id: String) -> Dictionary:
	return data.get("jewel", {}).get(id, {})

func jewel_parameter(id: String, index: int) -> float:
	var row := jewel(id)
	var value = row.get("para_%d" % index, row.get("para%d" % index, 0))
	return float(value) if value is float or value is int else 0.0

func jewel_max_level(id: String) -> int:
	return int(jewel(id).get("maxLevel", 0))

func jewel_effect(id: String) -> String:
	# func is authored prose, not executable code. Adapt its declared behavior,
	# independently of IDs/names; unsupported definitions never execute as code.
	var definition := str(jewel(id).get("func", ""))
	for pair in [["历史攻击次数", "proficiency"], ["受到过的伤害次数", "adaptation"], ["额外*(1+", "iron"], ["电子干扰", "interference"], ["连续para4秒", "repair"], ["额外发射", "repeat"], ["固定增加该武器para2暴击", "critical"], ["CD立即结束", "charge"], ["该伤害-", "resistance"], ["不会因受到伤害而打断", "tenacity"]]:
		if definition.contains(pair[0]):
			return pair[1]
	return ""

func equipment_growth(base: float, multiplier: float, level: int) -> float:
	var value := base * pow(1.0 + multiplier, level - 1)
	if not is_finite(value) or value <= 0.0:
		return value
	if value < 100.0:
		return floorf(value / 10.0) * 10.0 + 5.0
	var step := pow(10.0, floorf(log(value) / log(10.0) + 1e-12) - 1.0)
	return floorf(value / step + 0.5) * step

func max_equipment_level(key: String) -> int:
	# Integer storage boundary only; legacy row count is not a gameplay cap.
	return 2147483647 if equipment.has(key) else 1

func enemy_weapon(key: String) -> Dictionary:
	var row := equip(key, 1).duplicate(true)
	var base_key := key.replace("_mon", "").replace("-mon", "")
	var fallback := equip(base_key, 1)
	if row.is_empty():
		return fallback.duplicate(true)
	for field in ["dmg", "cd", "dmgtype", "para1", "para2"]:
		if row.get(field) == null:
			row[field] = fallback.get(field)
	if base_key == "longLaser" and row.get("para3") == null:
		row["para3"] = fallback.get("para3")
	return row

func unlock_level(key: String) -> int:
	return int(unlock_row("equipment", key).get("level", -1))

func unlock_id(kind: String, key: String) -> String:
	for id in data.get("unlock", {}):
		var row: Dictionary = data.unlock[id]
		if row.type == kind and row.target == key:
			return str(id)
	return ""

func unlock_row(kind: String, key: String) -> Dictionary:
	return data.get("unlock", {}).get(unlock_id(kind, key), {})

func ratio(level: int, progress: float, kind: String) -> float:
	var previous := 1.0 if level == 1 else float(levels[level - 2][kind])
	return lerpf(previous, float(levels[level - 1][kind]), clampf(progress, 0, 1))
