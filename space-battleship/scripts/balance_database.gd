extends ShipDatabase
## Each runner job owns a fixed, private configuration. Only pure database
## projections are cached; live bonuses, counters and combat stats remain live.
## Call clear_derived_cache after editing this instance's source data in a test.
const ROW_LIMIT := 256
var equipment_rows := {}
var enemy_rows := {}
var effect_names := {}
var unlock_ids := {}

func clear_derived_cache() -> void:
	equipment_rows.clear()
	enemy_rows.clear()
	effect_names.clear()
	unlock_ids.clear()

func unlock_id(kind: String, key: String) -> String:
	var id := kind+":"+key
	if not unlock_ids.has(id):
		if unlock_ids.size() >= ROW_LIMIT:unlock_ids.clear()
		unlock_ids[id] = super.unlock_id(kind,key)
	return str(unlock_ids[id])

func equip(key: String, level: int) -> Dictionary:
	var id := key+":"+str(level)
	if not equipment_rows.has(id):
		if equipment_rows.size() >= ROW_LIMIT:equipment_rows.clear()
		equipment_rows[id] = super.equip(key,level)
	# Preserve ShipDatabase's ownership contract: callers may edit the result.
	return equipment_rows[id].duplicate(true)

func enemy_weapon(key: String) -> Dictionary:
	if not enemy_rows.has(key):
		if enemy_rows.size() >= ROW_LIMIT:enemy_rows.clear()
		enemy_rows[key] = super.enemy_weapon(key)
	return enemy_rows[key].duplicate(true)

func jewel_effect(id: String) -> String:
	if not effect_names.has(id):effect_names[id] = super.jewel_effect(id)
	return str(effect_names[id])
