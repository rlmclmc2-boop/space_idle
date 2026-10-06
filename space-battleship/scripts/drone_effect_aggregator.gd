extends RefCounted
## One static equipped projection. No inventory scan in attack/hit loops.
const N=preload("res://scripts/growth_number.gd")
static func empty() -> Dictionary:
	return {"affixes":{},"hangings":{},"legendary":{},"damage":1.0,"critical_chance":0.0,"critical_damage":1.0,"repeat_chance":0.0,"attack_speed":1.0,"defence":1.0,"armour":1.0,"shield":1.0,"chain_count":0,"weapon_damage":{"laser":1.0,"missile":1.0,"cannon":1.0,"longLaser":1.0}}
static func affix_value(a: Dictionary,d: Dictionary,c: Dictionary) -> float:
	return float(a.value)*(pow(1.0+float(c.amplification_rate),int(d.level)-int(c.amplification_start_level)) if c.affixes[a.key].amplified else 1.0)
static func project(g) -> Dictionary:
	var result:=empty()
	if not g.profile.has("hyperspace"):return result
	var s: Dictionary=g.profile.hyperspace;var c: Dictionary=g.hyperspace.config
	for id in s.inventory.equipped:
		if s.inventory.sealed.has(id) or g.drone_combat.disabled.has(id):continue
		var d: Dictionary=s.inventory.drones[id]
		var affixes: Array=d.affixes+[d.ultimate_affix] if d.ultimate else d.affixes
		for a in affixes:
			var value: float=affix_value(a,d,c)
			result.affixes[a.key]=float(result.affixes.get(a.key,0))+value
		for key in d.hangings:
			var progress: Dictionary=s.hanging_modules[key]
			if not progress.unlocked or int(g.profile.highestLevel)<int(c.hanging_modules[key].unlock_stage):continue
			# Each installed copy contributes the grown system bonus; same type adds.
			var bonus:=pow(1.0+float(c.hanging_modules[key].effect_growth),int(progress.level))-1.0
			result.hangings[key]=float(result.hangings.get(key,0))+bonus
		if d.legendary:
			var effect: Dictionary=d.legendary_effect;var key: String=effect.effect_id
			var score:=0.0
			if not effect.parameters.is_empty():score=float(effect.parameters[effect.parameters.keys()[0]])
			var old: Dictionary=result.legendary.get(key,{})
			if old.is_empty() or score>float(old.score) or (score==float(old.score) and str(id)<str(old.drone_id)):
				result.legendary[key]={"drone_id":id,"score":score,"parameters":effect.parameters.duplicate(),"constants":c.legendary_effects[key].constants.duplicate()}
	var a: Dictionary=result.affixes
	result.damage=1.0+float(a.get("global_damage",0));result.critical_chance=float(a.get("critical_chance",0));result.critical_damage=1.0+float(a.get("global_critical_damage",0))
	result.repeat_chance=float(a.get("repeat_chance",0));result.attack_speed=1.0+float(a.get("attack_speed",0));result.chain_count=int(a.get("chain_count",0))
	result.damage*=1.0+g.drone_combat.rebuild_bonus
	result.defence=(1.0+float(a.get("global_defence",0)))*(1.0+g.drone_combat.rebuild_bonus);result.armour=1.0+float(a.get("armour_capacity",0));result.shield=1.0+float(a.get("shield_capacity",0))
	for weapon in result.weapon_damage:result.weapon_damage[weapon]=1.0+float(a.get("damage_"+str(weapon),0))
	return result
static func weapon_bonus(d: Dictionary,c: Dictionary) -> int:
	if d.ultimate:return int(c.ultimate_weapon_bonus)
	if d.blue_source_bonus:return int(c.weapon_level_bonuses.blue)
	return int(c.weapon_level_bonuses.legendary if d.legendary else c.weapon_level_bonuses[d.origin_quality])
