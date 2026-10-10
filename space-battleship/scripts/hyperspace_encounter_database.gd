extends "res://scripts/database.gd"
## Disposable database view; main registry, selected combat ratios and latest-cleared ordinary-resource ratio and enemy tiers stay intact.
var source: ShipDatabase
var selected_level:=1
func _init() -> void:
	pass # configure binds existing tables; do not reload the full mainline JSON.
func configure(base: ShipDatabase,level: int,ids: Array,registry: Dictionary={}) -> void:
	source=base;selected_level=level
	data=base.data.duplicate();equipment=base.equipment;enemies=base.enemies;groups=base.groups.duplicate();config=base.config;defaults=base.defaults;ships=base.ships;unlock_lookup=base.unlock_lookup
	if not registry.is_empty():enemies=registry.enemies;groups=registry.groups.duplicate()
	data.enemies=enemies;data.groups=groups;mon_source_error=base.mon_source_error
	levels=base.levels.duplicate();var row: Dictionary=levels[level-1].duplicate();row.groups=[];row.rewardReferenceGroups=registry.get("rewardReferenceGroups",row.get("rewardReferenceGroups",[])).duplicate(true)
	var resource_level:int=int(registry.get("resource_reference_level",level))
	row.resRatio=float(base.levels[resource_level-1].resRatio)
	row.jewelRatio=float(base.levels[resource_level-1].jewelRatio)
	for id in ids:groups[str(int(id))]=groups[str(int(id))].duplicate(true)
	for i in ids.size():row.groups.append({"id":int(ids[i]),"position":float(i+1)/ids.size()})
	levels[level-1]=row;data.levels=levels
func ratio(_level: int,_battle_point_index: int,kind: String) -> float:
	return float(levels[selected_level-1][kind])
