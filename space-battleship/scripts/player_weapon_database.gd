extends "res://scripts/database.gd"
## Player equipment projection; hostile lookups retain the unmodified source,
## including missing-row and null-field fallbacks in enemy_weapon().
var enemy_source:ShipDatabase
func _init(source:ShipDatabase)->void:
	enemy_source=source.get_meta("prototype_enemy_source",source)
	set_meta("prototype_enemy_source",enemy_source)
	data=enemy_source.data.duplicate(true)
	equipment=data.equipment
	enemies=data.enemies
	groups=data.groups
	levels=data.levels
	config=data.config
	defaults=data.defaults
	ships=data.get("ship",{})
	mon_source_error=enemy_source.mon_source_error
func enemy_weapon(key:String)->Dictionary:
	return enemy_source.enemy_weapon(key)

func combat_enemy_weapon(key:String)->Dictionary:
	return enemy_source.combat_enemy_weapon(key)
