extends RefCounted
## Read-only module presentation. Combat continues to own every random roll.
const N := preload("res://scripts/growth_number.gd")

static func snapshot(g, entry: Dictionary, level := -1, replacement_owner: Dictionary = {}) -> Dictionary:
	var base = g.jewel_equipment_stat(entry,level,null,false)
	if not BattleGame.WEAPON_KEYS.has(str(entry.get("key",""))):return {"base":base,"expected":base}
	var projected: Dictionary=entry
	if level>=0:
		projected=entry.duplicate()
		projected.level=level
	var critical: Vector2=g.jewel_critical(projected,null,false)
	var guaranteed: bool=g.enhancement_branches.active(g,projected,"critical",3,"B")
	var underlying: float=g.enhancement_branches.underlying_critical_rate(g,projected,false) if guaranteed or level>=0 else critical.x
	# Timed dwell/critical stacks affect combat, never module cards or previews.
	var trigger: float=critical.x if guaranteed else underlying
	# Ordinary combat probabilities pass through Vector2's engine precision.
	if not guaranteed and level>=0:trigger=Vector2(trigger,0.0).x
	var bonus_chance: float=underlying if guaranteed else 1.0
	var bonus_probability: float=trigger*bonus_chance
	var result := {"base":base,"expected":N.multiply(base,1.0+bonus_probability*(critical.y-1.0)),"trigger":trigger,"bonus_probability":bonus_probability,"critical_multiplier":critical.y,"guaranteed":guaranteed}
	result.rate=_throughput(g,entry if replacement_owner.is_empty() else replacement_owner,projected,result)
	return result

## Replace one logical source for count/strongest-source rules, never the live loadout.
static func refit_snapshot(g, owner: Dictionary, key: String) -> Dictionary:
	var candidate := owner.duplicate(true)
	candidate.key=key
	return snapshot(g,candidate,-1,owner)

## Static single-target presentation. No attack execution, random rolls or time stepping.
static func throughput(g, entry: Dictionary, level := -1) -> Dictionary:
	return snapshot(g,entry,level).get("rate",{})

static func displayed_value(values: Dictionary):
	return values.rate.start if values.has("rate") else values.expected

static func _throughput(g, owner: Dictionary, entry: Dictionary, values: Dictionary) -> Dictionary:
	var key:=str(entry.key)
	var row: Dictionary=g.player_weapon_row(entry)
	var interval:=float(row.cd)
	var reasons:Array[String]=[]
	var totals:Dictionary=g.hyperspace_totals()
	var legendary:Dictionary=totals.get("legendary",{})
	# A level preview retains logical source identity; only the strongest beam gets Endless.
	var endless:Dictionary=legendary.get("endless_beam",{})
	if key=="longLaser" and not endless.is_empty() and not is_same(owner,entry):
		var best:Dictionary={}
		for candidate in g.weapon_entries():
			var projected:Dictionary=entry if is_same(candidate,owner) else candidate
			if projected.key=="longLaser" and (best.is_empty() or int(projected.level)>int(best.level)):best=projected
		if is_same(best,entry):row.para2=float(row.para2)+float(endless.parameters.maximum_multiplier_bonus)
	if not is_finite(interval) or interval<=0:
		return {"valid":false,"start":0.0,"end":0.0,"beam":key=="longLaser","conditional":true,"reasons":["interval"],"interval":interval}
	var fixed:=1.0
	if key=="cannon" and legendary.has("higgs_cannon"):fixed*=1.0+float(legendary.higgs_cannon.parameters.damage_bonus)
	if key=="laser":
		if legendary.has("scatter_pulse"):
			fixed*=1.0+float(legendary.scatter_pulse.parameters.single_target_bonus)
			reasons.append("targets")
		if legendary.has("laser_charge"):
			var charge:Dictionary=legendary.laser_charge
			var count:=0
			for source in g.combat_weapon_entries():
				var replacement: Dictionary=entry if is_same(source,owner) else source
				if replacement.key=="laser":count+=1
			fixed*=1.0+minf(float(charge.parameters.maximum_bonus),float(charge.constants.bonus_per_laser)*count)
	var effects:Array=g.jewel_effects(entry)
	var repeats:=0.0
	var found_repeat:=false
	for effect in effects:
		if effect.kind in ["proficiency","adaptation"] and float(effect.get("p2",0))*int(effect.level)!=0:reasons.append("history")
		if effect.kind=="repeat":
			found_repeat=true
			repeats+=g.enhancement_branches.repeat_probability(g,entry)*(1.0+float(effect.p4)*int(effect.level))
	if not found_repeat:repeats=clampf(float(totals.repeat_chance),0,1)
	for pair in [["proficiency",1],["critical",1],["critical",2]]:
		if g.enhancement_branches.active(g,entry,pair[0],pair[1],"B") and not reasons.has("history"):reasons.append("history")
	if g.enhancement_branches.active(g,entry,"repeat",1,"B") or g.enhancement_branches.active(g,entry,"repeat",3,"B") or int(totals.chain_count)>0:reasons.append("targets")
	if g.enhancement_branches.global_active(g,"memory_material",3,"B"):reasons.append("incoming")
	if key=="missile" and legendary.has("wild_missile"):reasons.append("shared")
	if key=="missile" and legendary.has("precise_guidance"):reasons.append("target_stacks")
	if key=="longLaser" and legendary.has("prism_tower"):reasons.append("beam_owner")
	if legendary.has("dodge_counter") or legendary.has("black_hole") or legendary.has("drone_rebuild"):reasons.append("incoming")
	# Non-kill Strange Matter spawn chance is determined; kill-only extras remain conditional.
	var extra:=0.0
	if key=="cannon" and legendary.has("strange_matter"):
		var strange:Dictionary=legendary.strange_matter
		extra=float(strange.constants.spawn_probability)*float(strange.parameters.damage_multiplier)
		reasons.append("kills")
	var single=N.multiply(values.expected,fixed)
	var salvo:=int(row.para1) if key=="missile" else 1
	var rate=N.multiply(single,float(salvo)*(1.0+repeats+extra)/interval)
	var result:Dictionary={"valid":true,"key":key,"beam":key=="longLaser","interval":interval,"single":single,"salvo":salvo,"repeat_factor":1.0+repeats,"start":rate,"end":rate,"first_hit":interval,"stage_time":interval,"conditional":not reasons.is_empty(),"reasons":reasons}
	if key=="longLaser":
		if repeats>0:
			reasons.append("beam_repeat") # Delayed independent ramp cannot be presented as the root's first tick.
			result.conditional=true
		var explicit_charge:=row.get("para3")!=null
		var first:=maxf(0,float(row.para3)) if explicit_charge else interval
		var age:=0.0 if explicit_charge else interval
		var ramp:=maxf(0,float(row.para1))
		var initial:float=g.long_laser_multiplier(row,age)
		var periods:=0 if initial>=float(row.para2) else ceili(maxf(0,ramp-age)/interval)
		if periods>0 and g.long_laser_multiplier(row,age+float(periods-1)*interval)>=float(row.para2):periods-=1
		if g.long_laser_multiplier(row,age+float(periods)*interval)<float(row.para2):periods+=1
		result.charge=maxf(0,float(row.para3)) if explicit_charge else 0.0
		result.first_hit=first
		result.stage_time=first+float(periods)*interval
		result.start=N.multiply(single,initial/interval)
		result.end=N.multiply(single,float(row.para2)/interval)
	return result
