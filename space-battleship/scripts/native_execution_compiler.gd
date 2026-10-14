extends RefCounted
## Cold compiler for the authorized layer2 fixture. No running battle is evaluated.
const N=preload("res://scripts/growth_number.gd")
const KEYS=["laser","cannon","missile","longLaser"]
const ALLOWED_BRANCHES={"proficiency":{"2":"B"},"repeat":{"1":"B","3":"B"},"critical":{}}
func native_scalar(value:Variant)->bool:
	return (typeof(value)==TYPE_INT or typeof(value)==TYPE_FLOAT) and is_finite(float(value))
func native_fields(row:Dictionary,keys:Array)->bool:
	for key in keys:
		if not native_scalar(row.get(key)):return false
	return true
func native_integer(value:Variant)->bool:
	return native_scalar(value) and float(value)==floorf(float(value)) and float(value)>=-2147483648.0 and float(value)<=2147483647.0
func native_weapon_row(row:Dictionary,kind:int)->bool:
	if not native_integer(row.get("dmgtype")) or not native_fields(row,["cd"]):return false
	if not native_fields(row,["para2" if kind==2 else "para1"]):return false
	if kind==2 and not native_integer(row.get("para1")):return false
	if kind==3 and (not native_fields(row,["para2"]) or (row.get("para3")!=null and not native_scalar(row.para3))):return false
	return true
func external_factor(g,entry:Dictionary,totals:Dictionary,galaxy_values:Dictionary={})->Variant:
	var attack=entry.key in KEYS
	var values:Array=[g.planet_equipment_multiplier(),g.crew.system_effect(g,"equip_bonus"),galaxy_values.get("equipment_value",g.galaxy.multiplier("equipment_value")),totals.get("damage" if attack else "defence"),totals.weapon_damage.get(entry.key,1.0) if attack else totals.get(entry.key,1.0),totals.get("base_damage" if attack else "base_defence",1.0)]
	for value in values:
		if not native_scalar(value):return null
	# Preserve the original grouping while rejecting before scalar conversion.
	var drone=float(values[3])*float(values[4])
	var result=float(values[0])*float(values[1])*float(values[2])*drone*float(values[5])
	return result if is_finite(drone) and is_finite(result) else null
func compile(g,scope:String,upgrade:Dictionary={},galaxy_values:Dictionary={})->Dictionary:
	if scope not in ["native_low_contract","native_rich15_layer2"]:return {"error":"unsupported_scope"}
	if (("damage_stats" in g) and g.damage_stats.enabled) or g.manual_hyperspace.active:return {"error":"unsupported_optional_combat_mode"}
	for category in ["weapons","defence"]:
		for effect in g.profile.enhancementBranches[category]:
			for node in g.profile.enhancementBranches[category][effect]:
				if category!="weapons" or ALLOWED_BRANCHES.get(effect,{}).get(node,"")!=g.profile.enhancementBranches[category][effect][node]:return {"error":"unsupported_branch"}
	if typeof(upgrade.get("weapon_levels",{}))!=TYPE_DICTIONARY or typeof(upgrade.get("defence_levels",{}))!=TYPE_DICTIONARY:return {"error":"unsupported_native_shape:upgrade"}
	if upgrade.get("category","") in ["weapons","defence"] and (not native_integer(upgrade.get("index")) or not native_integer(upgrade.get("level"))):return {"error":"unsupported_native_scalar:upgrade"}
	for category in ["weapon_levels","defence_levels"]:
		for index in upgrade.get(category,{}):
			if not native_integer(index) or not native_integer(upgrade[category][index]):return {"error":"unsupported_native_scalar:upgrade_levels"}
	var weapon_levels:Dictionary=upgrade.get("weapon_levels",{})
	var defence_levels:Dictionary=upgrade.get("defence_levels",{})
	if upgrade.get("category","")=="weapons":weapon_levels[int(upgrade.index)]=int(upgrade.level)
	var totals:Dictionary=g.hyperspace_totals()
	if not native_fields(totals,["damage","defence"]) or not native_integer(totals.get("chain_count")):return {"error":"unsupported_native_scalar:totals"}
	if typeof(totals.get("weapon_damage"))!=TYPE_DICTIONARY:return {"error":"unsupported_native_shape:weapon_damage"}
	for key in totals.legendary:
		if key not in ["scatter_pulse","prism_tower","laser_charge","strange_matter","precise_guidance","wild_missile","endless_beam"]:return {"error":"unsupported_legendary:"+str(key)}
	if not g.drone_combat.delayed.is_empty() or not g.drone_combat.disabled.is_empty() or g.drone_combat.black_hole_remaining>0:return {"error":"unsupported_pending_drone_state"}
	if totals.legendary.has("endless_beam"):
		var endless=totals.legendary.endless_beam
		if typeof(endless)!=TYPE_DICTIONARY or typeof(endless.get("parameters"))!=TYPE_DICTIONARY or typeof(endless.get("constants"))!=TYPE_DICTIONARY:return {"error":"unsupported_native_shape:endless_beam"}
		if endless.constants.size()!=0 or endless.parameters.keys()!=["maximum_multiplier_bonus"]:return {"error":"unsupported_native_contract:endless_beam"}
		var bonus=endless.parameters.maximum_multiplier_bonus
		if not native_scalar(bonus) or float(bonus)<0:return {"error":"unsupported_native_scalar:endless_beam"}
	# Charge is a configuration-derived multiplier, never a per-hit source scan.
	var charge_multiplier:=1.0
	if totals.legendary.has("laser_charge"):
		var charge=totals.legendary.laser_charge
		if typeof(charge)!=TYPE_DICTIONARY or typeof(charge.get("parameters"))!=TYPE_DICTIONARY or typeof(charge.get("constants"))!=TYPE_DICTIONARY:return {"error":"unsupported_native_shape:laser_charge"}
		var maximum=charge.parameters.get("maximum_bonus")
		var per_source=charge.constants.get("bonus_per_laser")
		if not native_scalar(maximum) or not native_scalar(per_source):return {"error":"unsupported_native_scalar:laser_charge"}
		if float(maximum)<0 or float(per_source)<0:return {"error":"unsupported_native_range:laser_charge"}
		var sources:=0
		for entry in g.combat_weapon_entries():
			if entry.key=="laser":sources+=1
		var uncapped:float=float(per_source)*sources
		if not is_finite(uncapped):return {"error":"unsupported_native_arithmetic:laser_charge"}
		charge_multiplier=1.0+minf(float(maximum),uncapped)
		if not is_finite(charge_multiplier):return {"error":"unsupported_native_arithmetic:laser_charge"}
	var strange_probability:=0.0;var strange_delay:=0.0;var strange_multiplier:=0.0
	var strange_count:=0;var strange_type:=0
	if totals.legendary.has("strange_matter"):
		var strange=totals.legendary.strange_matter
		if typeof(strange)!=TYPE_DICTIONARY or typeof(strange.get("parameters"))!=TYPE_DICTIONARY or typeof(strange.get("constants"))!=TYPE_DICTIONARY:return {"error":"unsupported_native_shape:strange_matter"}
		if not native_fields(strange.constants,["spawn_probability","delay"]) or not native_fields(strange.parameters,["damage_multiplier"]) or not native_integer(strange.constants.get("kill_spawns")):return {"error":"unsupported_native_scalar:strange_matter"}
		strange_probability=float(strange.constants.spawn_probability);strange_delay=float(strange.constants.delay)
		strange_multiplier=float(strange.parameters.damage_multiplier);strange_count=int(strange.constants.kill_spawns)
		var damage_type=g.db.equip("cannon",1).get("dmgtype")
		if not native_integer(damage_type):return {"error":"unsupported_native_scalar:strange_type"}
		strange_type=int(damage_type)
		if strange_probability<0 or strange_probability>1 or strange_delay<0 or strange_multiplier<0 or strange_count<0 or strange_type<0 or strange_type>2:return {"error":"unsupported_native_range:strange_matter"}
	var guidance_multiplier:=1.0;var guidance_limit:=0;var guidance_limited:=false
	var wild_multiplier:=1.0;var wild_period:=0;var wild_blast:=0.0
	var missile_type=g.db.equip("missile",1).get("dmgtype")
	if not native_integer(missile_type) or int(missile_type)<0 or int(missile_type)>2:return {"error":"unsupported_native_range:missile_type"}
	if totals.legendary.has("precise_guidance"):
		var effect=totals.legendary.precise_guidance
		if typeof(effect)!=TYPE_DICTIONARY or typeof(effect.get("constants"))!=TYPE_DICTIONARY:return {"error":"unsupported_native_shape:precise_guidance"}
		var c:Dictionary=effect.constants
		if not native_scalar(c.get("stack_multiplier")) or not native_integer(c.get("stack_limit")) or typeof(c.get("stack_limit_enabled"))!=TYPE_BOOL or c.get("counting_policy")!="first_hit_per_batch_per_target":return {"error":"unsupported_native_scalar:precise_guidance"}
		guidance_multiplier=float(c.stack_multiplier);guidance_limit=int(c.stack_limit);guidance_limited=c.stack_limit_enabled
		if guidance_multiplier<0 or guidance_limit<0:return {"error":"unsupported_native_range:precise_guidance"}
	if totals.legendary.has("wild_missile"):
		var effect=totals.legendary.wild_missile
		if typeof(effect)!=TYPE_DICTIONARY or typeof(effect.get("constants"))!=TYPE_DICTIONARY or typeof(effect.get("parameters"))!=TYPE_DICTIONARY:return {"error":"unsupported_native_shape:wild_missile"}
		if not native_scalar(effect.parameters.get("damage_multiplier")) or not native_scalar(effect.constants.get("blast_fraction")) or not native_integer(effect.constants.get("attack_period")):return {"error":"unsupported_native_scalar:wild_missile"}
		wild_multiplier=float(effect.parameters.damage_multiplier);wild_blast=float(effect.constants.blast_fraction);wild_period=int(effect.constants.attack_period)
		if wild_multiplier<0 or wild_blast<0 or wild_period<0:return {"error":"unsupported_native_range:wild_missile"}
	if not native_integer(g.drone_combat.missile_attacks) or g.drone_combat.missile_attacks<0:return {"error":"unsupported_native_range:missile_attacks"}
	# Galaxy progression preflights its first refit boundary before mutation.
	var enemies:Array=[];var weapons:Array=[];var defence:Array=[]
	var growth=0.0;var defence_growth=0.0;var effect_level=0.0
	for enemy in g.enemies:
		if not native_integer(enemy.get("armourType",0)) or not native_integer(enemy.get("shieldType",0)):return {"error":"unsupported_native_scalar:enemy_type"}
		if not native_integer(enemy.get("guidance_layers",0)) or int(enemy.get("guidance_layers",0))<0:return {"error":"unsupported_native_range:guidance_layers"}
		var view:Dictionary=enemy.duplicate(true)
		view.armourType=int(enemy.get("armourType",0));view.shieldType=int(enemy.get("shieldType",0))
		view.compiled_drops=[]
		view.jewel_rolls=preload("res://scripts/candidate_rewards.gd").rolls(enemy.get("jewelDropRolls",1)) if g.jewels_unlocked() else 0
		if (not enemy.get("drops",[]).is_empty() and not native_scalar(enemy.get("res_ratio"))) or (not enemy.get("equipment",[]).is_empty() and not native_scalar(enemy.get("dmgMultiple"))):return {"error":"unsupported_native_scalar:enemy"}
		for drop in enemy.get("drops",[]):
			if typeof(drop)!=TYPE_DICTIONARY or not native_integer(drop.get("resourceId")) or not native_scalar(drop.get("chance")):return {"error":"unsupported_native_scalar:drop"}
			var multiplier=g.reactor_multiplier("smelting",float(galaxy_values.get("charge_max",-1.0))) if int(drop.resourceId)==1 else 1.0
			var base=N.ceiling(N.multiply(N.multiply(drop.amount,N.multiply(float(enemy.res_ratio),multiplier)),1.0+float(enemy.get("jewelIron",0)) if int(drop.resourceId)==1 else 1.0))
			var amount=N.ceiling(N.multiply(base,g.planet_resource_multiplier())) if int(drop.resourceId) in [1,2] else base
			view.compiled_drops.append({"resource":int(drop.resourceId),"chance":float(drop.chance),"base":base,"amount":amount})
		enemies.append(view)
	var endless_slot:int=g.endless_source_slot(weapon_levels)
	for index in g.combat_weapon_entries().size():
		var entry:Dictionary=g.projected_combat_entry(index,weapon_levels)
		if str(entry.key).is_empty():continue
		if not entry.key in KEYS:return {"error":"unsupported_weapon"}
		if not native_integer(entry.get("level")):return {"error":"unsupported_native_scalar:weapon_level"}
		var row:Dictionary=g.player_weapon_row(entry,totals,index==endless_slot)
		if not native_weapon_row(row,KEYS.find(entry.key)):return {"error":"unsupported_native_scalar:player_weapon"}
		var critical:Vector2=g.jewel_critical(entry,null,false,totals)
		var chain=int(totals.chain_count);var repeat_factor=1.0
		for effect in g.enhancement_recipe(entry):
			if effect.kind=="proficiency" and not native_fields(effect,["p2","level"]):return {"error":"unsupported_native_scalar:proficiency"}
			if effect.kind=="repeat" and (not native_scalar(effect.get("p4")) or not native_integer(effect.get("level"))):return {"error":"unsupported_native_scalar:repeat"}
			if effect.kind=="proficiency":growth=float(effect.p2);effect_level=float(effect.level)
			if effect.kind=="repeat":
				repeat_factor=1.0+float(effect.p4)*int(effect.level)
				if g.enhancement_branch_active(entry,"repeat",1,"B"):chain+=int(g.enhancement_parameter("repeat_b1_targets"))
		var transfer_effects:Array=g.enhancement_recipe(entry).duplicate(true)
		if chain>0:
			var found=false
			for effect in transfer_effects:
				if effect.kind=="repeat":effect.chain=true;effect.chain_targets=chain;found=true
			if not found:transfer_effects.append({"kind":"hyperspace_chain","chain":true,"chain_targets":chain})
		var factor=external_factor(g,entry,totals,galaxy_values)
		if not native_scalar(factor):return {"error":"unsupported_native_scalar:weapon_factor"}
		if KEYS.find(entry.key)!=3 and not native_scalar(g.cooldowns.get(g.slot_id("weapons",index),row.cd)):return {"error":"unsupported_native_scalar:cooldown"}
		var kind=KEYS.find(entry.key)
		var offset:Vector2=g.player_weapon_offset(index)
		weapons.append({"endless":totals.legendary.has("endless_beam") and index==endless_slot,"kind":kind,"type":int(row.dmgtype),"slot":index,"source":-1,"hostile":false,"damage":g.equipment_stat(entry.key,int(entry.level),float(galaxy_values.get("charge_max",-1.0))),"factor":factor,"interval":float(row.cd),"remaining":float(g.cooldowns.get(g.slot_id("weapons",index),row.cd)) if kind!=3 else 0.0,"speed":float(row.para2 if kind==2 else row.para1)*g.db.projectile_pixels_per_unit() if kind!=3 else 1.0,"salvo":int(row.para1) if kind==2 else 1,"charge":float(row.para3) if kind==3 and row.get("para3")!=null else -1.0,"ramp":float(row.para1) if kind==3 else 1.0,"maximum":float(row.para2) if kind==3 else 1.0,"muzzle":Vector2(g.player.x,g.player.y)+offset,"entry":entry.duplicate(true),"row":row.duplicate(true),"transfer_effects":transfer_effects,"critical_rate":critical.x,"critical_multiplier":critical.y,"repeat_probability":g.enhancement_branches.repeat_probability(g,entry),"repeat_multiplier":repeat_factor,"chain_count":chain,"secondary_probability":g.enhancement_parameter("repeat_b3_probability") if g.enhancement_branch_active(entry,"repeat",3,"B") else 0.0})
	for source in enemies.size():
		var enemy:Dictionary=enemies[source]
		for slot in enemy.equipment.size():
			var entry:Dictionary=enemy.equipment[slot];var row:Dictionary=g.db.enemy_weapon(entry.name)
			var key=str(entry.name).replace("_mon","").replace("-mon","");var kind=KEYS.find(key)
			if kind<0:return {"error":"unsupported_hostile_weapon"}
			if not native_weapon_row(row,kind) or not native_scalar(row.get("dmg")) or not native_scalar(g.ratio("atkRatio")):return {"error":"unsupported_native_scalar:hostile_weapon"}
			if kind!=3 and (slot>=enemy.cooldowns.size() or not native_scalar(enemy.cooldowns[slot])):return {"error":"unsupported_native_scalar:hostile_cooldown"}
			weapons.append({"kind":kind,"type":int(row.dmgtype),"slot":slot,"hostile":true,"source":source,"damage":ceilf(float(row.dmg)*float(enemy.dmgMultiple)*g.ratio("atkRatio")),"interval":float(row.cd),"remaining":float(enemy.cooldowns[slot]) if kind!=3 else 0.0,"speed":float(row.para2 if kind==2 else row.para1)*g.db.projectile_pixels_per_unit(true) if kind!=3 else 1.0,"salvo":1,"charge":float(row.para3) if kind==3 and row.get("para3")!=null else -1.0,"ramp":float(row.para1) if kind==3 else 1.0,"maximum":float(row.para2) if kind==3 else 1.0,"muzzle":Vector2(enemy.x,enemy.y)+g.enemy_weapon_offset(enemy,slot),"entry":entry,"row":row})
	for index in g.defense_entries().size():
		var entry:Dictionary=g.slot_entry("defence",index)
		if defence_levels.has(index):
			entry=entry.duplicate();entry.level=int(defence_levels[index])
		elif upgrade.get("category","")=="defence" and int(upgrade.index)==index:
			entry=entry.duplicate();entry.level=int(upgrade.level)
		if entry.key not in ["shield","armour"]:return {"error":"unsupported_defence"}
		var memory_heal=0.0;var memory_cap=0.0;var deferred=0.0
		for effect in g.enhancement_recipe(entry):
			if effect.kind=="adaptation" and not native_fields(effect,["p2","level"]):return {"error":"unsupported_native_scalar:adaptation"}
			if effect.kind=="memory_material" and (not native_fields(effect,["p2","p4"]) or not native_integer(effect.get("level"))):return {"error":"unsupported_native_scalar:memory"}
			if effect.kind=="adaptation":defence_growth=float(effect.p2);effect_level=float(effect.level)
			if effect.kind=="memory_material":memory_heal=float(effect.p2)*int(effect.level);memory_cap=float(effect.p4)*int(effect.level)
			if effect.kind=="delayed_damage":deferred=g.enhancement_deferred_fraction()
		if not native_integer(entry.get("level")):return {"error":"unsupported_native_scalar:defence_level"}
		if not native_scalar(g.jewel_defence_times.get(index,g.since_hit)):return {"error":"unsupported_native_scalar:defence_time"}
		var row:Dictionary=g.combat_equipment_row(entry.key,int(entry.level))
		if not native_integer(row.get("dmgtype",0)) or (entry.key=="shield" and not native_fields(row,["para2","para3"])):return {"error":"unsupported_native_scalar:defence_row"}
		var factor=external_factor(g,entry,totals,galaxy_values)
		if not native_scalar(factor):return {"error":"unsupported_native_scalar:defence_factor"}
		defence.append({"entry":entry.duplicate(true),"layer":0 if entry.key=="shield" else 1,"type":int(row.get("dmgtype",0)),"base":g.equipment_stat(entry.key,int(entry.level),float(galaxy_values.get("charge_max",-1.0))),"factor":factor,"maximum":g.jewel_equipment_stat(entry,-1,null,false,float(galaxy_values.get("equipment_value",-1.0)),float(galaxy_values.get("charge_max",-1.0))),"loss":g.jewel_defence_damage.get(index,0.0),"buffer":g.enhancement_buffers.get(index,0.0),"last_hit":g.enhancement_defense_time-float(g.jewel_defence_times.get(index,g.since_hit)),"delay":float(row.para3) if entry.key=="shield" else 0.0,"rate":float(row.para2) if entry.key=="shield" else 0.0,"memory_heal":memory_heal,"memory_cap":memory_cap,"deferred_fraction":deferred})
	var scatter:Dictionary=totals.legendary.get("scatter_pulse",{});var prism:Dictionary=totals.legendary.get("prism_tower",{})
	if not native_fields(g.db.config,["dmgReduce"]) or not native_scalar(g.db.config.get("jewelDrop",0)):return {"error":"unsupported_native_scalar:config"}
	if not native_scalar(scatter.get("parameters",{}).get("single_target_bonus",0.0)) or not native_integer(prism.get("constants",{}).get("nearby_targets",0)) or not native_scalar(prism.get("parameters",{}).get("maximum_multiplier_bonus",0.0)):return {"error":"unsupported_native_scalar:legendary"}
	var player:Dictionary=g.player.duplicate(true);player.armour_type=0;player.shield_type=0
	return {"requires_endless_beam":totals.legendary.has("endless_beam"),"execution_scope":scope,"final_encounter":g.is_final_encounter(),"since_hit":g.since_hit,"projectile_serial":g.projectile_serial,"attack_serial":g.main_attack_serial,"instance_serial":g.attack_instance_serial,"ejection_gap":g.EJECTION_GAP,"launch_speed":g.MISSILE_LAUNCH_SPEED,"turn_rate":g.MISSILE_TURN_RATE,"ignition":g.MISSILE_IGNITION,"seek":g.MISSILE_SEEK_START,"cruise_at":g.MISSILE_CRUISE_AT,"lifetime":g.MISSILE_LIFETIME,"orphan_lifetime":g.ORPHAN_LIFETIME,"brake_range":g.MISSILE_BRAKE_RANGE,"brake_angle":g.MISSILE_BRAKE_ANGLE,"min_speed":g.MISSILE_MIN_GUIDED_SPEED,"brake_factor":g.MISSILE_BRAKE_FACTOR,"hit_radius":g.MISSILE_HIT_RADIUS,"chain_speed":g.db.weapon_motion_value("chain_carrier_speed",720.0),"player":player,"enemies":enemies,"weapons":weapons,"defences":defence,"clock":g.enemy_shield_time,"rng_state":g.rng.state,"resistance":float(g.db.config.dmgReduce),"attack_counter":g.profile.enhancementAttacks,"incoming_counter":g.profile.enhancementHits,"counter_growth":growth,"defence_counter_growth":defence_growth,"counter_level":effect_level,"counter_log_base":g.enhancement_parameter("counter_log_base"),"counter_round_scale":g.enhancement_parameter("bonus_round_scale"),"repeat_delay":g.enhancement_parameter("repeat_delay"),"requires_missile_legends":totals.legendary.has("precise_guidance") or totals.legendary.has("wild_missile") or weapons.any(func(w):return not w.hostile and int(w.kind)==2),"precise_guidance":totals.legendary.has("precise_guidance"),"guidance_multiplier":guidance_multiplier,"guidance_limited":guidance_limited,"guidance_limit":guidance_limit,"wild_missile":totals.legendary.has("wild_missile"),"wild_multiplier":wild_multiplier,"wild_period":wild_period,"wild_blast":wild_blast,"wild_damage_type":int(missile_type),"missile_attacks":g.drone_combat.missile_attacks,"requires_strange_matter":totals.legendary.has("strange_matter"),"strange_probability":strange_probability,"strange_delay":strange_delay,"strange_damage_multiplier":strange_multiplier,"strange_kill_spawns":strange_count,"strange_damage_type":strange_type,"requires_laser_charge":totals.legendary.has("laser_charge"),"laser_charge_multiplier":charge_multiplier,"scatter":not scatter.is_empty(),"scatter_bonus":float(scatter.get("parameters",{}).get("single_target_bonus",0.0)),"prism_count":int(prism.get("constants",{}).get("nearby_targets",0)),"prism_bonus":float(prism.get("parameters",{}).get("maximum_multiplier_bonus",0.0)),"memory_interval":g.enhancement_parameter("memory_interval"),"deferred_interval":g.enhancement_parameter("deferred_interval"),"deferred_duration":g.enhancement_parameter("deferred_duration"),"clear_probability":g.enhancement_branches.clear_probability(g),"defence_time":g.enhancement_defense_time,"memory_elapsed":g.enhancement_memory_elapsed,"deferred_elapsed":g.enhancement_deferred_elapsed,"deferred_tick":g.enhancement_deferred_tick,"deferred":g.enhancement_deferred.duplicate(true),"drop_rules_compiled":true,"requires_drop_rules":true,"requires_module_defense":true,"drop_uid":g.uid,"jewel_probability":float(g.db.config.get("jewelDrop",0)),"jewel_ratio":g.jewel_ratio()}
