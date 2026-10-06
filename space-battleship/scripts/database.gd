class_name ShipDatabase
extends RefCounted
const MonGroupXlsx := preload("res://scripts/mon_group_xlsx.gd")
const N := preload("res://scripts/growth_number.gd")

var data: Dictionary
var equipment: Dictionary
var enemies: Dictionary
var groups: Dictionary
var levels: Array
var config: Dictionary
var defaults: Dictionary
var ships: Dictionary
var mon_source_error := ""
var unlock_lookup: Dictionary = {}

func _init() -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string("res://data/game_data.json"))
	if FileAccess.file_exists("res://analyzer-package.json"):
		var mon_table: Dictionary=MonGroupXlsx.read_mon_enemies()
		if mon_table.has("error"):
			mon_source_error=str(mon_table.error)
			data.enemies={}
		else:
			data.enemies=mon_table.enemies
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
				result.para1 = equipment_combat_growth(float(row.para1), float(row.get("para2" if key == "armour" else "para4", 0)), level)
			elif row.get("dmgMulti") != null and row.get("dmg") != null:
				result.dmg = equipment_combat_growth(float(row.dmg), float(row.dmgMulti), level)
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

func equipment_growth(base: float, multiplier: float, level: int) -> float:
	var value := base * pow(1.0 + multiplier, level - 1)
	if not is_finite(value) or value <= 0.0:
		return value
	if value < 100.0:
		return floorf(value / 10.0) * 10.0 + 5.0
	var step := pow(10.0, floorf(log(value) / log(10.0) + 1e-12) - 1.0)
	return floorf(value / step + 0.5) * step

func equipment_combat_growth(base: float, multiplier: float, level: int) -> Variant:
	# Preserve the ordinary authored rounding exactly; only overflowing combat
	# values use the existing mantissa/exponent representation. Costs are separate.
	var ordinary := equipment_growth(base,multiplier,level)
	if is_finite(ordinary) or base<=0 or multiplier<=-1:return ordinary
	var large = N.multiply(base,N.power(1.0+multiplier,level-1))
	var parts := N.parts(large)
	return N.make(floorf(float(parts[0])*10.0+0.5)/10.0,float(parts[1]))

func max_equipment_level(key: String) -> int:
	# Integer storage boundary only; legacy row count is not a gameplay cap.
	return 2147483647 if equipment.has(key) else 1

func weapon_motion_value(key: String, fallback: float) -> float:
	return float(data.get("weapon_motion",{}).get(key,{}).get("value",fallback))

func projectile_pixels_per_unit(hostile := false) -> float:
	return weapon_motion_value("enemy_projectile_pixels_per_unit" if hostile else "player_projectile_pixels_per_unit",float(defaults.get("projectilePixelsPerUnit",28.0)))

func enemy_weapon(key: String) -> Dictionary:
	var row := equip(key, 1).duplicate(true)
	var base_key := key.replace("_mon", "").replace("-mon", "")
	var fallback := equip(base_key, 1).duplicate(true)
	var enemy_base: Dictionary=data.get("enemy_weapon_base",{}).get(base_key,{})
	for field in ["dmg","cd","dmgtype","para1","para2","para3"]:
		if enemy_base.has(field):fallback[field]=enemy_base[field]
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
	# Cache only identities, never gate levels or availability. Validate the live
	# row on each hit so table replacement/removal does not retain a stale ID.
	var lookups: Dictionary = unlock_lookup.get(kind,{})
	var cached := str(lookups.get(key,""))
	var current: Dictionary = data.get("unlock",{}).get(cached,{})
	if current.get("type","")==kind and current.get("target","")==key:return cached
	lookups.erase(key)
	for id in data.get("unlock", {}):
		var row: Dictionary = data.unlock[id]
		if row.type == kind and row.target == key:
			# Unknown queries are not retained; authoring reloads stay bounded.
			if lookups.size()>=128:lookups.clear()
			lookups[key]=str(id);unlock_lookup[kind]=lookups
			return str(id)
	return ""

func unlock_row(kind: String, key: String) -> Dictionary:
	return data.get("unlock", {}).get(unlock_id(kind, key), {})

func ratio(level: int, battle_point_index: int, kind: String) -> float:
	var previous := 1.0 if level == 1 else float(levels[level - 2][kind])
	var entry_key := "entryAtkRatio" if kind == "atkRatio" else "entryLifeRatio" if kind == "lifeRatio" else ""
	var entry: Variant = levels[level - 1].get(entry_key)
	if entry_key != "" and entry != null and entry != "":
		previous = float(entry)
	var point_count: int = levels[level - 1].groups.size()
	var progress: float = 1.0 if point_count <= 1 else clampf(float(battle_point_index) / float(point_count - 1), 0.0, 1.0)
	return lerpf(previous, float(levels[level - 1][kind]), progress)
