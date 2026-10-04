extends "res://scripts/database.gd"
## Disposable database view; main registry, selected-stage ratios and enemy tiers stay intact.
var source: ShipDatabase
var selected_level:=1
func configure(base: ShipDatabase,level: int,ids: Array) -> void:
	source=base;selected_level=level
	data=base.data.duplicate();equipment=base.equipment;enemies=base.enemies;groups=base.groups.duplicate();config=base.config;defaults=base.defaults;ships=base.ships;unlock_lookup=base.unlock_lookup
	levels=base.levels.duplicate();var row: Dictionary=levels[level-1].duplicate();row.groups=[]
	for id in ids:groups[str(int(id))]=base.groups[str(int(id))].duplicate(true)
	for i in ids.size():row.groups.append({"id":int(ids[i]),"position":float(i+1)/ids.size()})
	levels[level-1]=row;data.levels=levels
func ratio(_level: int,_battle_point_index: int,kind: String) -> float:
	return float(levels[selected_level-1][kind])
