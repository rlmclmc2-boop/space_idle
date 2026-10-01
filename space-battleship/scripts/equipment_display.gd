extends RefCounted
## Read-only module presentation. Combat continues to own every random roll.
const N := preload("res://scripts/growth_number.gd")

static func snapshot(g, entry: Dictionary, level := -1) -> Dictionary:
	var base = g.jewel_equipment_stat(entry,level)
	if not BattleGame.WEAPON_KEYS.has(str(entry.get("key",""))):return {"base":base,"expected":base}
	var projected: Dictionary=entry
	if level>=0:
		projected=entry.duplicate()
		projected.level=level
	var critical: Vector2=g.jewel_critical(projected)
	var guaranteed: bool=g.enhancement_branches.active(g,projected,"critical",3,"B")
	var underlying: float=g.enhancement_branches.underlying_critical_rate(g,projected) if guaranteed or level>=0 else critical.x
	# A next-level preview keeps the live module's transient stacks, just as its
	# ordinary stat projection does. Copies are not live slot identities.
	if level>=0 and g.enhancement_branches.active(g,projected,"critical",2,"B"):
		var index: int=g.weapon_entries().find_custom(func(candidate):return is_same(candidate,entry))
		var live: Dictionary=g.enhancement_branches.weapons.get(index,{})
		underlying=clampf(underlying+int(live.get("stacks",0))*g.enhancement_parameter("critical_b2_probability"),0,1)
	var trigger: float=critical.x if guaranteed else underlying
	# Ordinary combat probabilities pass through Vector2's engine precision.
	if not guaranteed and level>=0:trigger=Vector2(trigger,0.0).x
	var bonus_chance: float=underlying if guaranteed else 1.0
	var bonus_probability: float=trigger*bonus_chance
	return {"base":base,"expected":N.multiply(base,1.0+bonus_probability*(critical.y-1.0)),"trigger":trigger,"bonus_probability":bonus_probability,"critical_multiplier":critical.y,"guaranteed":guaranteed}
