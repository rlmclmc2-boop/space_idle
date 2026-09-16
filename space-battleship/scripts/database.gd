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
	return row

func unlock_level(key: String) -> int:
	var v = equip(key, 1).get("unlock")
	return 0 if v == null else int(v)

func ratio(level: int, progress: float, kind: String) -> float:
	var previous := 1.0 if level == 1 else float(levels[level - 2][kind])
	return lerpf(previous, float(levels[level - 1][kind]), clampf(progress, 0, 1))
