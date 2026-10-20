extends RefCounted
## Reserved slot/mount contract only. No runtime loadout, cooldown or damage mutation.
const IDENTITY=preload("res://scripts/enemy_visual_identity.gd")
static func describe(enemy:Dictionary,visual_config:Dictionary)->Dictionary:
	var contract:Dictionary=visual_config.get("enemy_weapon_interface",{})
	if contract.is_empty():return {}
	var rank:=IDENTITY.visual_rank(enemy)
	if rank.is_empty():rank="normal"
	var count:=int(contract.get("slot_counts",{}).get(rank,0))
	var defaults:Dictionary=contract.get("defaults",{})
	var archetype:Dictionary=contract.get("archetypes",{}).get(str(enemy.get("archetype_id","")),{})
	var points:Array=archetype.get(rank,defaults.get(rank,[]))
	if count<=0 or points.size()!=count:return {}
	return {"rank":rank,"slot_count":count,"coordinate_space":str(contract.get("coordinate_space","")),"hardpoints":points.duplicate(true),"slot_map":range(count)}
