extends RefCounted
## Battle-only timers/state. No save economy or visual nodes.
const N=preload("res://scripts/growth_number.gd")
const CC=preload("res://scripts/combat_context.gd")
var delayed: Array=[]
var disabled: Array=[]
var rebuild_bonus:=0.0
var rebuild_stacks:=0
var dodge_cooldown:=0.0
var black_hole_elapsed:=0.0
var black_hole_remaining:=0.0
var black_hole_damage=0.0
var black_hole_source:=""
var missile_attacks:=0
func reset() -> void:
	delayed.clear();disabled.clear();rebuild_bonus=0.0;rebuild_stacks=0;dodge_cooldown=0.0
	black_hole_elapsed=0.0;black_hole_remaining=0.0;black_hole_damage=0.0;black_hole_source="";missile_attacks=0
func restore_disabled(g,reason: String) -> void:
	if disabled.is_empty():return
	var restored: Array=disabled.duplicate()
	disabled.clear()
	# Only availability ends here; existing rebuild bonuses/stacks keep their rule.
	g.invalidate_stat_cache()
	g.event.emit("hyperspace_drone_restored",{"drone_ids":restored,"reason":reason})
func effect(g,key: String) -> Dictionary:
	if g.profile.hyperspace.inventory.equipped.is_empty():return {}
	return g.hyperspace_totals().legendary.get(key,{})
func weapon_multiplier(g,key: String) -> float:
	var multiplier:=1.0
	if key=="cannon":
		var higgs:=effect(g,"higgs_cannon")
		if not higgs.is_empty():multiplier*=1.0+float(higgs.parameters.damage_bonus)
	if key=="laser":
		var scatter:=effect(g,"scatter_pulse")
		if not scatter.is_empty() and g.targets().size()==1:multiplier*=1.0+float(scatter.parameters.single_target_bonus)
		var charge:=effect(g,"laser_charge")
		if not charge.is_empty():
			var count: int=g.combat_weapon_view().filter(func(e):return e.key=="laser").size()
			multiplier*=1.0+minf(float(charge.parameters.maximum_bonus),float(charge.constants.bonus_per_laser)*count)
	return multiplier
func absorb(g,raw,hostile: bool) -> bool:
	if black_hole_remaining<=0:return false
	if not hostile:black_hole_damage=N.add(black_hole_damage,raw)
	g.event.emit("hyperspace_absorb",{"hostile":hostile,"amount":raw})
	return true
func next_is_wild(g) -> bool:
	var wild:=effect(g,"wild_missile")
	return not wild.is_empty() and missile_attacks%(int(wild.constants.attack_period)+1)==int(wild.constants.attack_period)

func on_hit(g,enemy: Dictionary,raw,context: Dictionary) -> void:
	if context.get("wild_missile",false) and not context.get("wild_used",false):
		context.wild_used=true
		for target in g.enemies.duplicate():
			if N.compare(target.hp,0)>0:g.hit_enemy(target,N.multiply(raw,float(context.blast_fraction)),int(g.db.equip("missile",1).dmgtype),[],false,context)
	if not CC.can_trigger(context):return
	if context.get("weapon")=="cannon":
		var strange:=effect(g,"strange_matter")
		if not strange.is_empty():
			var count:=int(strange.constants.kill_spawns) if N.compare(enemy.hp,0)<=0 else (1 if g.rng.randf()<float(strange.constants.spawn_probability) else 0)
			for i in count:delayed.append({"remaining":float(strange.constants.delay),"damage":N.multiply(raw,float(strange.parameters.damage_multiplier)),"type":int(g.db.equip("cannon",1).dmgtype),"context":CC.derive(context,"strange_matter")})
func master_reduction(g,master:Dictionary={}) -> float:
	if master.is_empty():master=effect(g,"drone_master")
	if master.is_empty():return 0.0
	var quality_ratio:=0.0
	for id in g.profile.hyperspace.inventory.equipped:
		if disabled.has(id):continue
		var d: Dictionary=g.profile.hyperspace.inventory.drones[id]
		var q: String="ultimate" if d.ultimate else "legendary" if d.legendary else d.origin_quality
		quality_ratio=maxf(quality_ratio,float(master.constants.quality_ratios[q]))
	var raw:=float(master.parameters.maximum_reduction)*quality_ratio/float(master.constants.quality_ratios.ultimate)
	var precision:=float(master.constants.get("reduction_precision",0.01))
	return snappedf(raw,precision)
func incoming(g,raw,context: Dictionary) -> Dictionary:
	if absorb(g,raw,true):return {"absorbed":true,"damage":0.0}
	var dodge:=effect(g,"dodge_counter")
	if not dodge.is_empty() and CC.can_trigger(context):
		var rate:=0.0
		for entry in g.combat_weapon_view():rate=maxf(rate,g.jewel_critical(entry).x)
		if g.rng.randf()<minf(rate,float(dodge.parameters.maximum_dodge)):
			if dodge_cooldown<=0:
				dodge_cooldown=float(dodge.constants.cooldown)
				var indices: Array=[]
				for i in g.combat_weapon_view().size():
					if not str(g.combat_entry(i).key).is_empty():indices.append(i)
				if not indices.is_empty():g.fire_drone_counter(int(indices[g.rng.randi_range(0,indices.size()-1)]),1.0+float(dodge.parameters.counter_damage_bonus))
			g.event.emit("hyperspace_dodge",{});return {"absorbed":true,"damage":0.0}
	var master:=effect(g,"drone_master")
	if not master.is_empty():raw=N.multiply(raw,1.0-master_reduction(g,master))
	return {"absorbed":false,"damage":raw}
func try_rebuild(g) -> bool:
	var rebuild:=effect(g,"drone_rebuild")
	if rebuild.is_empty() or rebuild_stacks>=int(rebuild.constants.maximum_stacks):return false
	var ids: Array=g.profile.hyperspace.inventory.equipped.filter(func(id):return not disabled.has(id) and not g.profile.hyperspace.inventory.sealed.has(id))
	if ids.is_empty():return false
	var rank: Dictionary={"white":0,"blue":1,"gold":2,"legendary":3,"ultimate":4}
	ids.sort_custom(func(a,b):
		var da: Dictionary=g.profile.hyperspace.inventory.drones[a];var db: Dictionary=g.profile.hyperspace.inventory.drones[b]
		var qa: String="ultimate" if da.ultimate else "legendary" if da.legendary else da.origin_quality
		var qb: String="ultimate" if db.ultimate else "legendary" if db.legendary else db.origin_quality
		return str(a)<str(b) if rank[qa]==rank[qb] else rank[qa]<rank[qb])
	disabled.append(ids[0]);rebuild_stacks+=1;rebuild_bonus+=float(rebuild.parameters.damage_and_defence_bonus)
	g.invalidate_stat_cache();g.player.armour=g.stat("armour");g.player.shield=g.stat("shield")
	g.jewel_defence_damage.clear();g.enhancement_deferred.clear();g.sync_jewel_defence_damage()
	g.event.emit("hyperspace_rebuild",{"drone_id":ids[0],"stacks":rebuild_stacks});return true
func advance(g,dt: float) -> void:
	dodge_cooldown=maxf(0.0,dodge_cooldown-dt)
	for pending in delayed.duplicate():
		pending.remaining-=dt
		if pending.remaining>0.000000001:continue
		delayed.erase(pending)
		for target in g.enemies.duplicate():
			if N.compare(target.hp,0)>0:g.hit_enemy(target,pending.damage,int(pending.type),[],false,pending.context)
	var black:=effect(g,"black_hole")
	if black.is_empty():black_hole_remaining=0.0;black_hole_damage=0.0;return
	var remaining:=maxf(0.0,dt)
	while remaining>0.000000001:
		if black_hole_remaining<=0:
			var waiting:=maxf(0.0,float(black.constants.period)-black_hole_elapsed)
			var step:=minf(remaining,waiting)
			black_hole_elapsed+=step;remaining-=step
			if black_hole_elapsed+0.000000001<float(black.constants.period):break
			black_hole_elapsed=0.0;black_hole_remaining=float(black.constants.absorption_duration);black_hole_damage=0.0
			black_hole_source="drone:"+str(black.drone_id)
			g.event.emit("hyperspace_black_hole",{"active":true,"duration":black_hole_remaining})
			continue
		var step:=minf(remaining,black_hole_remaining)
		black_hole_elapsed+=step;black_hole_remaining-=step;remaining-=step
		if black_hole_remaining<=0.000000001:
			black_hole_remaining=0.0
			var damage=N.multiply(black_hole_damage,float(black.parameters.damage_multiplier));black_hole_damage=0.0
			var context:=CC.derive(CC.root(0,black_hole_source,""),"black_hole")
			for target in g.enemies.duplicate():
				if N.compare(damage,0)>0 and N.compare(target.hp,0)>0:g.hit_enemy(target,damage,int(g.db.equip(str(g.profile.hyperspace.inventory.drones[black.drone_id].weapon),1).dmgtype),[],false,context)
			g.event.emit("hyperspace_black_hole",{"active":false})
