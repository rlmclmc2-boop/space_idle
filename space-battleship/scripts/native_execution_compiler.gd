extends RefCounted
## Cold compiler for the authorized layer2 fixture. No running battle is evaluated.
const N=preload("res://scripts/growth_number.gd")
const KEYS=["laser","cannon","missile","longLaser"]
const ALLOWED_BRANCHES={"proficiency":{"2":"B"},"repeat":{"1":"B","3":"B"},"critical":{}}
func external_factor(g,entry:Dictionary,totals:Dictionary)->float:
	var attack=entry.key in KEYS
	var drone=float(totals.damage)*float(totals.weapon_damage.get(entry.key,1.0)) if attack else float(totals.defence)*float(totals.get(entry.key,1.0))
	return g.planet_equipment_multiplier()*g.crew.system_effect(g,"equip_bonus")*g.galaxy.multiplier("equipment_value")*drone*float(totals.get("base_damage" if attack else "base_defence",1.0))
func compile(g,scope:String)->Dictionary:
	if scope not in ["native_low_contract","native_rich15_layer2"]:return {"error":"unsupported_scope"}
	if g.damage_stats.enabled or g.manual_hyperspace.active:return {"error":"unsupported_optional_combat_mode"}
	for category in ["weapons","defence"]:
		for effect in g.profile.enhancementBranches[category]:
			for node in g.profile.enhancementBranches[category][effect]:
				if category!="weapons" or ALLOWED_BRANCHES.get(effect,{}).get(node,"")!=g.profile.enhancementBranches[category][effect][node]:return {"error":"unsupported_branch"}
	var totals:Dictionary=g.hyperspace_totals()
	for key in totals.legendary:
		if key not in ["scatter_pulse","prism_tower"]:return {"error":"unsupported_legendary:"+str(key)}
	if not g.drone_combat.delayed.is_empty() or not g.drone_combat.disabled.is_empty() or g.drone_combat.black_hole_remaining>0:return {"error":"unsupported_pending_drone_state"}
	var enemies:Array=[];var weapons:Array=[];var defence:Array=[]
	var growth=0.0;var defence_growth=0.0;var effect_level=0.0
	for enemy in g.enemies:
		var view:Dictionary=enemy.duplicate(true)
		view.compiled_drops=[]
		view.jewel_rolls=preload("res://scripts/candidate_rewards.gd").rolls(enemy.get("jewelDropRolls",1)) if g.jewels_unlocked() else 0
		for drop in enemy.get("drops",[]):
			var multiplier=g.reactor_multiplier("smelting") if int(drop.resourceId)==1 else 1.0
			var base=N.ceiling(N.multiply(N.multiply(drop.amount,N.multiply(float(enemy.res_ratio),multiplier)),1.0+float(enemy.get("jewelIron",0)) if int(drop.resourceId)==1 else 1.0))
			var amount=N.ceiling(N.multiply(base,g.planet_resource_multiplier())) if int(drop.resourceId) in [1,2] else base
			view.compiled_drops.append({"resource":int(drop.resourceId),"chance":float(drop.chance),"base":base,"amount":amount})
		enemies.append(view)
	for index in g.combat_weapon_entries().size():
		var entry:Dictionary=g.combat_entry(index)
		if str(entry.key).is_empty():continue
		if not entry.key in KEYS:return {"error":"unsupported_weapon"}
		var row:Dictionary=g.player_weapon_row(entry,totals)
		var critical:Vector2=g.jewel_critical(entry,null,false,totals)
		var chain=int(totals.chain_count);var repeat_factor=1.0
		for effect in g.enhancement_recipe(entry):
			if effect.kind=="proficiency":growth=float(effect.p2);effect_level=float(effect.level)
			if effect.kind=="repeat":
				repeat_factor=1.0+float(effect.p4)*int(effect.level)
				if g.enhancement_branch_active(entry,"repeat",1,"B"):chain+=int(g.enhancement_parameter("repeat_b1_targets"))
		var kind=KEYS.find(entry.key)
		var offset:Vector2=g.player_weapon_offset(index)
		weapons.append({"kind":kind,"type":int(row.dmgtype),"slot":index,"source":-1,"hostile":false,"damage":g.equipment_stat(entry.key,int(entry.level),totals),"factor":external_factor(g,entry,totals),"interval":float(row.cd),"remaining":float(g.cooldowns.get(g.slot_id("weapons",index),row.cd)) if kind!=3 else 0.0,"speed":float(row.para2 if kind==2 else row.para1)*g.db.projectile_pixels_per_unit() if kind!=3 else 1.0,"salvo":int(row.para1) if kind==2 else 1,"charge":float(row.para3) if kind==3 and row.get("para3")!=null else -1.0,"ramp":float(row.para1) if kind==3 else 1.0,"maximum":float(row.para2) if kind==3 else 1.0,"muzzle":Vector2(g.player.x,g.player.y)+offset,"entry":entry.duplicate(true),"row":row.duplicate(true),"critical_rate":critical.x,"critical_multiplier":critical.y,"repeat_probability":g.enhancement_branches.repeat_probability(g,entry,totals),"repeat_multiplier":repeat_factor,"chain_count":chain,"secondary_probability":g.enhancement_parameter("repeat_b3_probability") if g.enhancement_branch_active(entry,"repeat",3,"B") else 0.0})
	for source in enemies.size():
		var enemy:Dictionary=enemies[source]
		for slot in enemy.equipment.size():
			var entry:Dictionary=enemy.equipment[slot];var row:Dictionary=g.db.enemy_weapon(entry.name)
			var key=str(entry.name).replace("_mon","").replace("-mon","");var kind=KEYS.find(key)
			if kind<0:return {"error":"unsupported_hostile_weapon"}
			weapons.append({"kind":kind,"type":int(row.dmgtype),"slot":slot,"hostile":true,"source":source,"damage":ceilf(float(row.dmg)*float(enemy.dmgMultiple)*g.ratio("atkRatio")),"interval":float(row.cd),"remaining":float(enemy.cooldowns[slot]) if kind!=3 else 0.0,"speed":float(row.para2 if kind==2 else row.para1)*g.db.projectile_pixels_per_unit(true) if kind!=3 else 1.0,"salvo":1,"charge":float(row.para3) if kind==3 and row.get("para3")!=null else -1.0,"ramp":float(row.para1) if kind==3 else 1.0,"maximum":float(row.para2) if kind==3 else 1.0,"muzzle":Vector2(enemy.x,enemy.y)+g.enemy_weapon_offset(enemy,slot),"entry":entry,"row":row})
	for index in g.defense_entries().size():
		var entry:Dictionary=g.slot_entry("defence",index)
		if entry.key not in ["shield","armour"]:return {"error":"unsupported_defence"}
		var memory_heal=0.0;var memory_cap=0.0;var deferred=0.0
		for effect in g.enhancement_recipe(entry):
			if effect.kind=="adaptation":defence_growth=float(effect.p2);effect_level=float(effect.level)
			if effect.kind=="memory_material":memory_heal=float(effect.p2)*int(effect.level);memory_cap=float(effect.p4)*int(effect.level)
			if effect.kind=="delayed_damage":deferred=g.enhancement_deferred_fraction()
		var row:Dictionary=g.combat_equipment_row(entry.key,int(entry.level))
		defence.append({"layer":0 if entry.key=="shield" else 1,"type":int(row.get("dmgtype",0)),"base":g.equipment_stat(entry.key,int(entry.level),totals),"factor":external_factor(g,entry,totals),"maximum":g.jewel_equipment_stat(entry,-1,null,false,totals),"loss":g.jewel_defence_damage.get(index,0.0),"buffer":g.enhancement_buffers.get(index,0.0),"last_hit":g.enhancement_defense_time-float(g.jewel_defence_times.get(index,g.since_hit)),"delay":float(row.para3) if entry.key=="shield" else 0.0,"rate":float(row.para2) if entry.key=="shield" else 0.0,"memory_heal":memory_heal,"memory_cap":memory_cap,"deferred_fraction":deferred})
	var scatter:Dictionary=totals.legendary.get("scatter_pulse",{});var prism:Dictionary=totals.legendary.get("prism_tower",{})
	var player:Dictionary=g.player.duplicate(true);player.armour_type=0;player.shield_type=0
	return {"execution_scope":scope,"ejection_gap":g.EJECTION_GAP,"launch_speed":g.MISSILE_LAUNCH_SPEED,"turn_rate":g.MISSILE_TURN_RATE,"ignition":g.MISSILE_IGNITION,"seek":g.MISSILE_SEEK_START,"cruise_at":g.MISSILE_CRUISE_AT,"lifetime":g.MISSILE_LIFETIME,"orphan_lifetime":g.ORPHAN_LIFETIME,"brake_range":g.MISSILE_BRAKE_RANGE,"brake_angle":g.MISSILE_BRAKE_ANGLE,"min_speed":g.MISSILE_MIN_GUIDED_SPEED,"brake_factor":g.MISSILE_BRAKE_FACTOR,"hit_radius":g.MISSILE_HIT_RADIUS,"player":player,"enemies":enemies,"weapons":weapons,"defences":defence,"clock":g.enemy_shield_time,"rng_state":g.rng.state,"resistance":float(g.db.config.dmgReduce),"attack_counter":g.profile.enhancementAttacks,"incoming_counter":g.profile.enhancementHits,"counter_growth":growth,"defence_counter_growth":defence_growth,"counter_level":effect_level,"counter_log_base":g.enhancement_parameter("counter_log_base"),"counter_round_scale":g.enhancement_parameter("bonus_round_scale"),"repeat_delay":g.enhancement_parameter("repeat_delay"),"scatter":not scatter.is_empty(),"scatter_bonus":float(scatter.get("parameters",{}).get("single_target_bonus",0.0)),"prism_count":int(prism.get("constants",{}).get("nearby_targets",0)),"prism_bonus":float(prism.get("parameters",{}).get("maximum_multiplier_bonus",0.0)),"memory_interval":g.enhancement_parameter("memory_interval"),"deferred_interval":g.enhancement_parameter("deferred_interval"),"deferred_duration":g.enhancement_parameter("deferred_duration"),"defence_time":g.enhancement_defense_time,"memory_elapsed":g.enhancement_memory_elapsed,"deferred_elapsed":g.enhancement_deferred_elapsed,"deferred_tick":g.enhancement_deferred_tick,"deferred":g.enhancement_deferred.duplicate(true),"drop_rules_compiled":true,"requires_drop_rules":true,"requires_module_defense":true,"drop_uid":g.uid,"jewel_probability":float(g.db.config.get("jewelDrop",0)),"jewel_ratio":g.jewel_ratio()}
