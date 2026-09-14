class_name ShipDatabase
extends RefCounted

var data: Dictionary
var equipment: Dictionary
var enemies: Dictionary
var groups: Dictionary
var levels: Array
var config: Dictionary
var defaults: Dictionary

func _init() -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string("res://data/game_data.json"))
	equipment = data.equipment
	enemies = data.enemies
	groups = data.groups
	levels = data.levels
	config = data.config
	defaults = data.defaults

func equip(key: String, level: int) -> Dictionary:
	for row in equipment.get(key, []):
		if int(row.level) == level:
			return row
	return {}

func max_equipment_level(key: String) -> int:
	var highest := 1
	for row in equipment.get(key, []):
		highest = maxi(highest, int(row.level))
	return highest

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
