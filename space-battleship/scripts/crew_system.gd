extends RefCounted
## Excel owns definitions. This object owns only disposable scheduler state/handlers.
var handlers: Dictionary = {}
var targets: Dictionary = {}
var timers: Dictionary = {}
var intervals: Dictionary = {}
var allocation_timers: Dictionary = {}
var allocation_intervals: Dictionary = {}
var allocation_dependencies: Array = []
var game_ref: WeakRef
const PURCHASE_JOBS := ["equipment_upgrade","hightech_scientists","jewel_auto","reactor_upgrade"]

func _init() -> void:
	register_target("equipment", equipment_targets)
	register_target("hightech", research_targets)
	register_target("production", production_targets)
	register_target("smelting", smelting_targets)
	register_target("jewel", jewel_targets)
	register_target("reactor", reactor_targets)
	register_target("galaxy", galaxy_targets)
	register_handler("galaxy", "EXPLORE", passive)
	register_handler("equipment", "AUTO_UPGRADE", auto_upgrade)
	register_handler("hightech", "AUTO_SCIENTIST", auto_scientists)
	register_handler("jewel", "AUTO_COMBINE", auto_jewels)
	register_handler("reactor", "AUTO_REACTOR", auto_reactor)
	for target in ["production", "smelting"]:
		for effect in ["OUTPUT", "SPEED", "EFFICIENCY"]:
			register_handler(target, effect, passive)

func attach(g) -> void:
	game_ref = weakref(g)
	g.event.connect(on_event)

func reset_schedule(g) -> void:
	timers.clear()
	intervals.clear()
	allocation_timers.clear()
	allocation_intervals.clear()
	allocation_dependencies.clear()
	invalidate_jobs(g,PURCHASE_JOBS)
	invalidate_reactor_allocation(g)

func invalidate_jobs(g, jobs: Array) -> void:
	for item in g.profile.get("crew",[]):
		if jobs.has(str(item.assignmentType)):invalidate_member(g,item)

func invalidate_member(g, item: Dictionary) -> void:
	if not PURCHASE_JOBS.has(str(item.assignmentType)):return
	# First change fixes the deadline. Later changes merge without postponing it.
	if timers.has(item.crewId):return
	var row: Dictionary = assignments(g).get(item.assignmentType,{})
	var value := effect_value(g,item)
	var interval := float(row.get("interval",0))/value if value>0 else 0.0
	if not supported(row) or interval<=0 or not is_finite(interval):return
	intervals[item.crewId]=interval
	timers[item.crewId]=0.0

func invalidate_resources(g, ids: Array) -> void:
	var jobs: Array = []
	for category in ["weapons","defence"]:
		var cost_key: String = g.module_cost_key(category)
		for row in g.db.equipment.get(cost_key,[]):
			for field in row:
				if str(field).begins_with("res_") and row[field]!=null and ids.has(str(int(row[field]))):
					if not jobs.has("equipment_upgrade"):jobs.append("equipment_upgrade")
	for part in Array(str(g.db.config.scientistCost).split(",")).slice(1):
		if ids.has(str(part).get_slice("|",0)):
			jobs.append("hightech_scientists")
			break
	if ids.has(str(int(g.db.config.reactorUraniumId))):jobs.append("reactor_upgrade")
	invalidate_jobs(g,jobs)

func reactor_allocation_state(g, id: String) -> Array:
	# Free charge affects multipliers/UI, never the ordinary energy pool or split.
	return [id,active(g,entry(g,id)),g.reactor_capacity(),g.reactor_available_modules(),g.profile.reactorAllocation.duplicate()]

func invalidate_reactor_allocation(g) -> void:
	var id := ""
	for item in g.profile.get("crew",[]):
		if item.assignmentType=="reactor_upgrade":id=str(item.crewId);break
	if id.is_empty():
		allocation_timers.clear()
		allocation_intervals.clear()
		allocation_dependencies.clear()
		return
	var next := reactor_allocation_state(g,id)
	if next==allocation_dependencies:return
	if allocation_dependencies.is_empty() or allocation_dependencies[0]!=id:
		allocation_timers.clear()
		allocation_intervals.clear()
	allocation_dependencies=next
	if allocation_timers.has(id):return
	var item := entry(g,id)
	var row: Dictionary = assignments(g)[item.assignmentType]
	var value := effect_value(g,item)
	var interval := float(row.interval)/value if value>0 else 0.0
	if interval<=0 or not is_finite(interval):return
	allocation_timers[id]=0.0
	allocation_intervals[id]=interval

func run_reactor_allocation(g, item: Dictionary) -> void:
	allocation_timers.erase(item.crewId)
	allocation_intervals.erase(item.crewId)
	if active(g,item):g.equalize_reactor_allocation()
	allocation_dependencies=reactor_allocation_state(g,str(item.crewId))

func on_event(kind: String, payload: Dictionary) -> void:
	var g = game_ref.get_ref()
	if g==null:return
	match kind:
		"collect","galaxy_income":invalidate_resources(g,[str(payload.id)])
		"resources_changed":invalidate_resources(g,payload.ids)
		"upgrade","upgrades_completed","module_changed","ship_changed":invalidate_jobs(g,["equipment_upgrade"])
		"scientists_changed":
			if payload.has("purchased"):invalidate_jobs(g,["hightech_scientists"])
		"jewels_changed":invalidate_jobs(g,["jewel_auto"])
		"reactor_changed":
			if payload.has("level"):invalidate_jobs(g,["reactor_upgrade"])
			if payload.get("equalized",false):
				if not allocation_dependencies.is_empty():allocation_dependencies=reactor_allocation_state(g,str(allocation_dependencies[0]))
			else:invalidate_reactor_allocation(g)
		"unlocks_changed","planet_reforged":
			invalidate_jobs(g,PURCHASE_JOBS)
			invalidate_reactor_allocation(g)
		"planet_changed":
			if payload.has("reward") or payload.has("activated"):invalidate_reactor_allocation(g)
		"crew_changed":
			var item := entry(g,str(payload.crewId))
			var previous: Dictionary=payload.previous
			# XP-only payouts leave purchase eligibility, costs and cadence unchanged.
			if [item.get("assignmentType"),item.get("targetId"),item.get("upgradeMode"),item.get("level")] != [previous.get("assignmentType"),previous.get("targetId"),previous.get("upgradeMode"),previous.get("level")]:
				invalidate_member(g,item)
			if item.get("assignmentType")=="reactor_upgrade" or payload.previous.get("assignmentType")=="reactor_upgrade":invalidate_reactor_allocation(g)

func register_target(target_type: String, provider: Callable) -> void:
	targets[target_type] = provider

func register_handler(target_type: String, effect_type: String, handler: Callable) -> void:
	handlers[target_type + ":" + effect_type] = handler

func supported(row: Dictionary) -> bool:
	return targets.has(str(row.get("targetType", ""))) and handlers.has(str(row.get("targetType", ""))+":"+str(row.get("effectType", "")))

func definitions(g) -> Dictionary:
	return g.db.data.get("crew", {})

func assignments(g) -> Dictionary:
	return g.db.data.get("crew_assignment", {})

func required_exp(g, level: int) -> float:
	return maxf(1.0,roundf(config_value(g,"base_exp")*pow(config_value(g,"exp_multiplier"),maxi(0,level))))

func unlocked(g, id: String) -> bool:
	var definition: Dictionary = definitions(g).get(id, {})
	var gate := str(definition.get("unlockId", ""))
	return not definition.is_empty() and (gate.is_empty() or g.unlock_available(gate))

func number(value, fallback: float) -> float:
	return float(value) if (value is float or value is int) and is_finite(float(value)) else fallback

func load_state(g, raw) -> void:
	timers.clear()
	var incoming := {}
	if raw is Array:
		for item in raw:
			if item is Dictionary and item.get("crewId") is String and not incoming.has(item.crewId):
				incoming[item.crewId] = item
	g.profile.crew = []
	g.profile.crewEquipment = {} # Reserved; no equipment instances exist in v1.
	for id in definitions(g):
		var row: Dictionary = definitions(g)[id]
		var item: Dictionary = incoming.get(id, {})
		var slots: Array = []
		slots.resize(int(row.equipmentSlotCount))
		var entry := {"crewId":id,"level":int(clampf(number(item.get("level"),0.0),0.0,9e18)),"exp":roundf(maxf(0,number(item.get("exp"),0))),"assignmentType":"","targetId":"","equipmentSlots":slots}
		var modes := upgrade_modes(g)
		var mode := str(item.get("upgradeMode",""))
		entry.upgradeMode = mode if modes.has(mode) else (modes[0] if not modes.is_empty() else "")
		g.profile.crew.append(entry)
		gain_exp(g, id, 0, false)
	# Assignment restoration uses the same capacity and target validation as UI actions.
	for entry in g.profile.crew:
		var row: Dictionary = definitions(g)[entry.crewId]
		var item: Dictionary = incoming.get(entry.crewId, {})
		var assignment := str(item.get("assignmentType",row.get("defaultAssignment", "")))
		var target := str(item.get("targetId",row.get("defaultTargetId", "")))
		# Former per-module assignments become the unified equipment-system assignment.
		if assignment in ["weapon_upgrade","defense_upgrade"]:
			assignment = "equipment_upgrade"
			target = "equipment"
		if assignment == "smelting_speed":
			assignment = "jewel_auto"
			target = "jewels"
		if can_assign(g,entry.crewId,assignment,target,true):
			entry.assignmentType = assignment
			entry.targetId = target

	reset_schedule(g)

func entry(g, id: String) -> Dictionary:
	for item in g.profile.get("crew", []):
		if item.crewId == id:return item
	return {}

func gain_exp(g, id: String, amount: float, notify := true) -> bool:
	var item := entry(g,id)
	if item.is_empty() or not is_finite(amount) or amount < 0:return false
	if not levels_unlocked(g) or not unlocked(g,id):return false
	g.capture_refit_health()
	var previous := item.duplicate(true)
	var before := [item.level,item.exp]
	item.exp = minf(roundf(float(item.exp))+roundf(amount),1e308)
	var multiplier: float=config_value(g,"exp_multiplier")
	if multiplier==1.0:
		var needed:=required_exp(g,int(item.level))
		var levels:=int(minf(floor(float(item.exp)/needed),9e18-float(item.level)))
		item.level+=levels
		item.exp=maxf(0.0,float(item.exp)-float(levels)*needed)
	else:
		while true:
			var needed:=required_exp(g,int(item.level))
			if not is_finite(needed) or needed<=0 or float(item.exp)<needed:break
			item.exp-=needed
			item.level+=1
	if notify and before != [item.level,item.exp]:
		changed(g,item,previous)
	return true

func available_targets(g, assignment: String, include_inactive := false) -> Array:
	var row: Dictionary = assignments(g).get(assignment,{})
	if not supported(row):return []
	var result: Array = targets[str(row.targetType)].call(g)
	var category := str(row.get("targetCategory", ""))
	return result.filter(func(target):return (include_inactive or target.get("active",true)) and (category.is_empty() or str(target.get("category", ""))==category))

func valid_target(g, assignment: String, id: String, include_inactive := false) -> bool:
	return available_targets(g,assignment,include_inactive).any(func(target):return target.id==id)

func can_assign(g, id: String, assignment: String, target: String, restoring := false) -> bool:
	if entry(g,id).is_empty() or (not restoring and not unlocked(g,id)):return false
	if not assignment.is_empty() and not restoring:
		if not g.crew_exploration(id).is_empty():return false
	if assignment.is_empty():return target.is_empty()
	if not valid_target(g,assignment,target,restoring):return false
	var count := 0
	for item in g.profile.crew:
		var occupied: Dictionary=assignments(g).get(str(item.assignmentType),{})
		if item.crewId!=id and occupied.get("targetType")==assignments(g)[assignment].targetType and item.targetId==target:count+=1
	return count < int(assignments(g)[assignment].maxCrew)

func assign(g, id: String, assignment: String, target: String) -> bool:
	if not can_assign(g,id,assignment,target):return false
	var item := entry(g,id)
	if item.assignmentType==assignment and item.targetId==target:return true
	g.capture_refit_health()
	var previous := item.duplicate(true)
	if item.assignmentType=="galaxy_explore":g.galaxy.flush_pending(g,str(item.targetId))
	if assignment=="galaxy_explore":g.galaxy.flush_pending(g,target)
	item.assignmentType=assignment
	item.targetId=target
	if assignment=="galaxy_explore":g.galaxy.start(g,target)
	timers.erase(id)
	intervals.erase(id)
	changed(g,item,previous)
	return true

func changed(g, item: Dictionary, previous: Dictionary) -> void:
	g.refresh_crew_level_effects(previous,item)
	g.save_dirty = true
	g.event.emit("crew_changed",{"crewId":item.crewId,"previous":previous,"current":item.duplicate(true)})

func upgrade_modes(g, assignment := "") -> Array[String]:
	var result: Array[String] = []
	for id in assignments(g):
		var row: Dictionary=assignments(g)[id]
		if (assignment.is_empty() or id==assignment) and row.get("effectType") in ["AUTO_UPGRADE","AUTO_SCIENTIST"]:
			for mode in str(row.get("upgradeModes","")).split(",",false):
				var value := mode.strip_edges()
				if not result.has(value):result.append(value)
	return result

func set_upgrade_mode(g, id: String, mode: String, assignment := "") -> bool:
	var item := entry(g,id)
	if item.is_empty() or not upgrade_modes(g,assignment).has(mode):return false
	if item.upgradeMode==mode:return true
	var previous := item.duplicate(true)
	item.upgradeMode=mode
	changed(g,item,previous)
	return true

func upgrade_mode_text(mode: String, effect_type := "AUTO_UPGRADE") -> String:
	if effect_type=="AUTO_SCIENTIST":
		return UIText.t("crew.scientist_max") if mode=="max" else UIText.t("crew.scientist_count",{"count":mode})
	return UIText.t("crew.upgrade_max") if mode=="max" else UIText.t("crew.upgrade_levels",{"count":mode})

func effect_value(g, item: Dictionary) -> float:
	var row: Dictionary = assignments(g).get(str(item.get("assignmentType","")),{})
	var definition: Dictionary = definitions(g).get(str(item.get("crewId","")),{})
	if row.is_empty() or definition.is_empty():return 0.0
	return float(row.baseValue)*pow(float(definition.basePower),float(row.powerScale))

func active(g, item: Dictionary) -> bool:
	return unlocked(g,item.crewId) and not str(item.assignmentType).is_empty() and valid_target(g,item.assignmentType,item.targetId)

func get_modifier(g, target_type: String, target_id: String, effect_type: String) -> float:
	var total := 0.0
	for item in g.profile.get("crew",[]):
		var row: Dictionary = assignments(g).get(item.assignmentType,{})
		if row.get("targetType")==target_type and row.get("effectType")==effect_type and item.targetId==target_id and active(g,item):
			total += effect_value(g,item)
	return total

func advance(g, dt: float) -> void:
	if g.paused or dt<=0 or not is_finite(dt):return
	# Only pending work advances; passive jobs have no scheduler work.
	var allocation_due: Array = []
	for id in allocation_timers:
		allocation_timers[id]+=dt
		if float(allocation_timers[id])+0.000000001>=float(allocation_intervals[id]):allocation_due.append(id)
	var due: Array = []
	for id in timers:
		var elapsed := float(timers[id])+dt
		if elapsed+0.000000001 < float(intervals[id]):timers[id]=elapsed
		else:due.append(id)
	if due.is_empty() and allocation_due.is_empty():return
	# Preserve configuration crew order when jobs share a resource balance.
	for item in g.profile.get("crew",[]):
		var id: String = item.crewId
		if not due.has(id):continue
		# Clear before acting: synchronous changes can queue the following second.
		# Large steps make one attempt, with no replay or retained overrun.
		timers.erase(id)
		intervals.erase(id)
		var row: Dictionary = assignments(g).get(item.get("assignmentType",""),{})
		if supported(row) and active(g,item) and handlers[str(row.targetType)+":"+str(row.effectType)].call(g,item):
			invalidate_member(g,item)
	for id in allocation_due:
		if allocation_timers.has(id):run_reactor_allocation(g,entry(g,str(id)))

func passive(_g, _item: Dictionary) -> bool:
	return false

func auto_upgrade(g, item: Dictionary) -> bool:
	var mode := str(item.get("upgradeMode",""))
	if not upgrade_modes(g).has(mode):return false
	# Match manual module upgrades. Each later module sees the remaining resources.
	return g.upgrade_equipment_batch(mode)

func auto_scientists(g, item: Dictionary) -> bool:
	var mode := str(item.get("upgradeMode",""))
	if not upgrade_modes(g,item.assignmentType).has(mode):return false
	if not g.generate_scientist(-1 if mode=="max" else int(mode)):return false
	g.distribute_scientists()
	return true

func auto_jewels(g, _item: Dictionary) -> bool:
	return g.upgrade_enhancement(1)>0

func auto_reactor(g, _item: Dictionary) -> bool:
	if not g.upgrade_reactor(1):return false
	# A paid upgrade changes capacity: preserve the existing buy-then-split order.
	run_reactor_allocation(g,_item)
	return true

func reactor_targets(g) -> Array:
	return [{"id":"reactor","name":UIText.t("crew.job.reactor"),"active":g.reactor_unlocked()}]

func galaxy_targets(g) -> Array:
	return g.galaxy.targets(g)

func equipment_targets(g) -> Array:
	return [{"id":"equipment","name":UIText.t("crew.all_equipment"),"active":not g.loadout_entries("weapons").is_empty() or not g.loadout_entries("defence").is_empty()}]

func research_targets(g) -> Array:
	var result: Array = []
	for key in g.db.data.get("hightech",{}):
		result.append({"id":key,"name":UIText.data_text("hightech",key),"active":g.hightech_unlocked(key),"category":"technology"})
	result.append({"id":"hightech","name":UIText.t("crew.hightech_system"),"active":g.db.data.get("hightech",{}).keys().any(func(key):return g.hightech_unlocked(key)),"category":"system"})
	return result

func production_targets(g) -> Array:
	return furnace_targets(g,[g.FURNACE])

func smelting_targets(g) -> Array:
	return furnace_targets(g,[g.JEWEL_FURNACE])

func jewel_targets(g) -> Array:
	return [{"id":"jewels","name":UIText.t("crew.jewel_system"),"active":g.jewels_unlocked()}]

func furnace_targets(g, keys: Array) -> Array:
	var result: Array = []
	for key in keys:
		if g.db.data.get("hightech",{}).has(key):result.append({"id":key,"name":UIText.data_text("hightech",key),"active":g.hightech_unlocked(key) and g.hightech_level(key)>0})
	return result

func target_name(g, item: Dictionary) -> String:
	for target in available_targets(g,item.assignmentType,true):
		if target.id==item.targetId:return str(target.name)
	return str(item.targetId)

func effect_text(g, item: Dictionary) -> String:
	var row: Dictionary = assignments(g).get(item.assignmentType,{})
	if row.is_empty():return UIText.t("crew.idle")
	if not active(g,item):return UIText.t("crew.inactive")
	var value := effect_value(g,item)
	var key := str(row.get("descTextId", ""))
	if key.is_empty():key="crew.effect.generic"
	if not UIText.loaded:UIText.reload_catalog()
	var possible := {"description":str(row.description),"value":"%.1f" % (value*100),"interval":"%.1f" % (float(row.interval)/value if value>0 else 0.0),"mode":upgrade_mode_text(str(item.get("upgradeMode","")),str(row.effectType))}
	var values := {}
	for parameter in UIText.contracts.get(key,{}).get("params",[]):
		if possible.has(parameter):values[parameter]=possible[parameter]
	return UIText.t(key,values)

func tab_badge(g, target_types: Array) -> Dictionary:
	var lines: Array[String] = []
	for item in g.profile.get("crew",[]):
		var row: Dictionary=assignments(g).get(str(item.assignmentType),{})
		if target_types.has(str(row.get("targetType",""))) and active(g,item):
			var effects := effect_text(g,item)
			var level_bonus := level_description(g,item)
			if not level_bonus.is_empty():effects += "\n" + level_bonus
			lines.append(format_text(g,"badge_tip",{"name":str(definitions(g)[item.crewId].name),"level":item.level,"effect":effects}) if levels_unlocked(g) else str(definitions(g)[item.crewId].name)+"\n"+effects)
	return {"text":UIText.t("crew.badge") if not lines.is_empty() else "","tooltip":"\n".join(lines)}

func equipment_slots(g, id: String) -> Array:
	return entry(g,id).get("equipmentSlots",[]).duplicate(true)

func crew_equipment(_g, _equipment_id: String) -> Dictionary:
	return {} # Reserved lookup API. Drops, inventory and stats are deliberately absent.

func levels_unlocked(g) -> bool:
	return g.content_unlocked("feature", "crew_level")

func config_value(g, key: String) -> float:
	return float(g.db.data.crew_config[key].value)

func format_text(g, key: String, values: Dictionary) -> String:
	var result := str(g.db.data.crew_config[key].des)
	# Unknown placeholders remain literal; descriptions never drive calculations.
	for token in values:result=result.replace("{"+str(token)+"}",str(values[token]))
	return result

func level_effect(g, key: String, level: int) -> float:
	var value := config_value(g,key)
	if key=="tech_ai_per_level":return level*value
	if key=="equip_bonus":return pow(1.0+value,level)
	return 1.0+value*level

func system_level(g, key: String) -> int:
	if not levels_unlocked(g):return 0
	var target_type := str(g.db.data.crew_config[key].targetType)
	for item in g.profile.get("crew",[]):
		var job: Dictionary=assignments(g).get(item.assignmentType,{})
		if job.get("targetType")==target_type and active(g,item):return int(item.level)
	return 0

func system_effect(g, key: String) -> float:
	return level_effect(g,key,system_level(g,key))

func level_description(g, item: Dictionary) -> String:
	if not levels_unlocked(g) or not active(g,item):return ""
	var kind := str(assignments(g).get(item.assignmentType,{}).get("targetType",""))
	var lines: Array[String]=[]
	for key in g.db.data.crew_config:
		var row: Dictionary=g.db.data.crew_config[key]
		if str(row.get("targetType",""))!=kind or kind.is_empty():continue
		var effect := level_effect(g,key,int(item.level))
		# Multipliers show the bonus above baseline; Lv0 (x1) means +0.00%.
		var effect_text := str(int(effect)) if key == "tech_ai_per_level" else "%+.2f%%" % ((effect - 1.0) * 100.0)
		lines.append(format_text(g,key,{"level":item.level,"value":str(row.value),"effect":effect_text,"ai":int(effect)}))
	return "\n".join(lines)

func display_name(g, item: Dictionary) -> String:
	var member_name := str(definitions(g)[item.crewId].name)
	return format_text(g,"name_level",{"name":member_name,"level":item.level}) if levels_unlocked(g) else member_name
