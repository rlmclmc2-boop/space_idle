extends RefCounted
## Owns crew growth, assignments and the event-driven job schedule. Game commits cross-domain commands.
var revision := 0
var contribution_revision:=0
var _contribution_inputs:Array=[]
var _members: Array = []
var _entries: Dictionary = {}
var handlers: Dictionary = {}
var targets: Dictionary = {}
var timers: Dictionary = {}
var intervals: Dictionary = {}
var allocation_timers: Dictionary = {}
var allocation_intervals: Dictionary = {}
var allocation_dependencies: Array = []
var game_ref: WeakRef
const PURCHASE_JOBS := ["equipment_upgrade","jewel_auto","reactor_upgrade"]

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
	register_handler("hightech", "AUTO_RESEARCH", passive)
	register_handler("jewel", "AUTO_COMBINE", auto_jewels)
	register_handler("reactor", "AUTO_REACTOR", auto_reactor)
	for target in ["production", "smelting"]:
		for effect in ["OUTPUT", "SPEED", "EFFICIENCY"]:
			register_handler(target, effect, passive)

func attach(g) -> void:
	game_ref = weakref(g)
	g.event.connect(on_event)

func clear_schedule() -> void:
	timers.clear()
	intervals.clear()
	allocation_timers.clear()
	allocation_intervals.clear()
	allocation_dependencies.clear()

func reset_schedule(g) -> void:
	clear_schedule()
	invalidate_jobs(g,PURCHASE_JOBS)
	invalidate_reactor_allocation(g)

func invalidate_jobs(g, jobs: Array) -> void:
	for item in _members:
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
	if ids.has(g.db.evolution_material_id()):jobs.append("equipment_upgrade")
	for category in ["weapons","defence"]:
		var cost_key: String = g.module_cost_key(category)
		for row in g.db.equipment.get(cost_key,[]):
			for field in row:
				if str(field).begins_with("res_") and row[field]!=null and ids.has(str(int(row[field]))):
					if not jobs.has("equipment_upgrade"):jobs.append("equipment_upgrade")
	if ids.has(str(int(g.db.config.reactorUraniumId))):jobs.append("reactor_upgrade")
	invalidate_jobs(g,jobs)

func reactor_allocation_state(g, id: String) -> Array:
	# Free charge affects multipliers/UI, never the ordinary energy pool or split.
	return [id,active(g,entry(g,id)),g.reactor_capacity(),g.reactor_available_modules(),g.reactor.allocations().duplicate()]

func invalidate_reactor_allocation(g) -> void:
	var id := ""
	for item in _members:
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

func on_committed(g,result: Dictionary) -> void:
	if result.status!="committed":return
	if not result.resources.is_empty():invalidate_resources(g,result.resources)
	if result.facts.get("equipment_changed",false):invalidate_jobs(g,["equipment_upgrade"])
	var allocation_changed: bool=result.facts.get("reactor_allocation_changed",false)
	for change in result.facts.get("crew_changes",[]):
		var item: Dictionary=change.current
		var previous: Dictionary=change.previous
		# XP alone does not alter costs, eligibility or cadence.
		if [item.assignmentType,item.targetId,item.upgradeMode,item.level] != [previous.assignmentType,previous.targetId,previous.upgradeMode,previous.level]:invalidate_member(g,item)
		for member in [previous,item]:
			if str(member.assignmentType)=="reactor_upgrade":allocation_changed=true
			if [item.level,item.assignmentType,item.targetId] != [previous.level,previous.assignmentType,previous.targetId] and assignments(g).get(str(member.assignmentType),{}).get("targetType","")=="reactor":allocation_changed=true
	if allocation_changed:invalidate_reactor_allocation(g)

func on_event(kind: String, payload: Dictionary) -> void:
	# S1 commands already delivered their authoritative facts before UI notices.
	# Only unmigrated resource/reactor/unlock producers use this S2 bridge.
	if payload.get("_committed_fact",false):return
	var g = game_ref.get_ref()
	if g==null:return
	match kind:
		"collect","galaxy_income":invalidate_resources(g,[str(payload.id)])
		"resources_changed":invalidate_resources(g,payload.ids)
		"jewels_changed":invalidate_jobs(g,["jewel_auto"])
		"reactor_changed":
			if payload.has("level"):invalidate_jobs(g,["reactor_upgrade"])
			if payload.get("equalized",false):
				if not allocation_dependencies.is_empty():allocation_dependencies=reactor_allocation_state(g,str(allocation_dependencies[0]))
			else:invalidate_reactor_allocation(g)
		"unlocks_changed","planet_reforged":
			invalidate_jobs(g,PURCHASE_JOBS)
			invalidate_reactor_allocation(g)

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

func hyperspace_level(g, crew_id: String) -> int:
	var item := entry(g,crew_id)
	return maxi(0,int(item.get("level",0))) if levels_unlocked(g) and unlocked(g,crew_id) else 0

func hyperspace_efficiency(g, crew_id: String) -> float:
	var level := hyperspace_level(g,crew_id)
	var k := config_value(g,"hyperspace_duration_k")
	return (k+float(level))/k

func hyperspace_luck(g, crew_id: String) -> float:
	return config_value(g,"hyperspace_luck_per_level")*float(hyperspace_level(g,crew_id))

func unlocked(g, id: String) -> bool:
	var definition: Dictionary = definitions(g).get(id, {})
	var gate := str(definition.get("unlockId", ""))
	return not definition.is_empty() and (gate.is_empty() or g.unlock_available(gate))

func members() -> Array:
	return _members

func entry(_g, id: String) -> Dictionary:
	return _entries.get(id,{})

func save_data() -> Dictionary:
	return {"crew":_members.duplicate(true),"crewEquipment":{}}

func _install_members(items: Array) -> void:
	var inputs:Array=[]
	for item in items:inputs.append([item.crewId,item.level,item.assignmentType,item.targetId])
	if inputs!=_contribution_inputs:contribution_revision+=1;_contribution_inputs=inputs
	_members=items.duplicate(true);_entries={}
	for item in _members:
		item.equipmentSlots.make_read_only();item.make_read_only();_entries[item.crewId]=item
	_members.make_read_only();_entries.make_read_only();revision+=1

func reset(g) -> void:
	var items: Array=[]
	var modes:=upgrade_modes(g)
	for id in definitions(g):
		var slots: Array=[];slots.resize(int(definitions(g)[id].equipmentSlotCount))
		items.append({"crewId":id,"level":0,"exp":0.0,"assignmentType":"","targetId":"","equipmentSlots":slots,"upgradeMode":modes[0] if not modes.is_empty() else ""})
	_install_members(items)
	# Defaults use the same configured targets and capacity as player assignments.
	for item in items:
		var row: Dictionary=definitions(g)[item.crewId]
		var assignment:=str(row.get("defaultAssignment",""));var target:=str(row.get("defaultTargetId",""))
		if can_assign(g,str(item.crewId),assignment,target,true):
			item.assignmentType=assignment;item.targetId=target;_install_members(items)
	clear_schedule()

static func valid_integer(value,maximum:float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value>=0 and value<=maximum and float(value)==floorf(float(value))

static func valid_snapshot(raw: Dictionary, db) -> bool:
	if not raw.get("crew") is Array or not raw.get("crewEquipment") is Dictionary or not raw.crewEquipment.is_empty():return false
	var definitions: Dictionary=db.data.get("crew",{});var assignments: Dictionary=db.data.get("crew_assignment",{})
	if raw.crew.size()!=definitions.size():return false
	var seen: Dictionary={};var modes: Array=[]
	for row in assignments.values():
		if row.get("effectType")=="AUTO_UPGRADE":
			for mode in str(row.get("upgradeModes","")).split(",",false):
				if not modes.has(mode.strip_edges()):modes.append(mode.strip_edges())
	for item in raw.crew:
		if not item is Dictionary or not item.get("crewId") is String or not definitions.has(item.crewId) or seen.has(item.crewId):return false
		seen[item.crewId]=true
		if not valid_integer(item.get("level"),9e18) or not valid_integer(item.get("exp"),1e308):return false
		if not item.get("equipmentSlots") is Array or item.equipmentSlots.size()!=int(definitions[item.crewId].equipmentSlotCount) or not item.equipmentSlots.all(func(slot):return slot==null):return false
		if not item.get("upgradeMode") is String or (not modes.has(item.upgradeMode) and not (modes.is_empty() and item.upgradeMode.is_empty())):return false
		if not item.get("assignmentType") is String or not item.get("targetId") is String:return false
	var rules = load("res://scripts/crew_system.gd").new()
	for item in raw.crew:
		if not rules.binding_valid(db,raw.crew,item.crewId,item.assignmentType,item.targetId):return false
	return true

func install_snapshot(raw: Dictionary, db) -> bool:
	if not valid_snapshot(raw,db):return false
	# Preserve configured ordering when automatic jobs compete for a balance.
	var incoming: Dictionary={}
	for item in raw.crew:incoming[item.crewId]=item
	var items: Array=[]
	for id in db.data.crew:
		var item: Dictionary=incoming[id].duplicate(true);item.level=int(item.level);item.exp=float(item.exp);items.append(item)
	_install_members(items)
	return true

func prepare_experience(g, rewards: Dictionary) -> Dictionary:
	var items: Array=_members.duplicate(true);var changes: Array=[]
	for id in rewards:
		var amount: float=float(rewards[id])
		if not _entries.has(id) or not is_finite(amount) or amount<0:return {}
	for item in items:
		if not rewards.has(item.crewId) or not levels_unlocked(g) or not unlocked(g,item.crewId):continue
		var previous: Dictionary=item.duplicate(true)
		item.exp=minf(roundf(float(item.exp))+roundf(float(rewards[item.crewId])),1e308)
		var multiplier: float=config_value(g,"exp_multiplier")
		if multiplier==1.0:
			var needed:=required_exp(g,int(item.level))
			var levels:=int(minf(floor(float(item.exp)/needed),9e18-float(item.level)))
			item.level+=levels;item.exp=maxf(0.0,float(item.exp)-float(levels)*needed)
		else:
			while true:
				var needed:=required_exp(g,int(item.level))
				if not is_finite(needed) or needed<=0 or float(item.exp)<needed:break
				item.exp-=needed;item.level+=1
		if previous!=item:changes.append({"previous":previous,"current":item.duplicate(true)})
	return {"revision":revision,"members":items,"changes":changes,"configuration":changes.any(func(change):return change.previous.level!=change.current.level)}

func proposal_current(plan: Dictionary) -> bool:
	return not plan.is_empty() and int(plan.revision)==revision

func commit(plan: Dictionary) -> void:
	assert(proposal_current(plan))
	if plan.changes.is_empty():return
	_install_members(plan.members)
	for change in plan.changes:
		if change.previous.assignmentType!=change.current.assignmentType or change.previous.targetId!=change.current.targetId:
			timers.erase(change.current.crewId);intervals.erase(change.current.crewId)

func binding_targets(db, assignment: String, g = null) -> Array:
	var row: Dictionary = db.data.get("crew_assignment",{}).get(assignment,{})
	if not supported(row):return []
	var result: Array = targets[str(row.targetType)].call(db,g)
	var category := str(row.get("targetCategory", ""))
	return result.filter(func(target):return target.get("active",true) and (category.is_empty() or str(target.get("category", ""))==category))

func available_targets(g, assignment: String, include_inactive := false) -> Array:
	return binding_targets(g.db,assignment,null if include_inactive else g)

func valid_target(g, assignment: String, id: String, include_inactive := false) -> bool:
	return available_targets(g,assignment,include_inactive).any(func(target):return target.id==id)

# Structural bindings are identical for defaults, player commands and strict snapshots.
# A live game adds availability; saved bindings may legitimately be inactive.
func binding_valid(db, items: Array, id: String, assignment: String, target: String, g = null) -> bool:
	if assignment.is_empty():return target.is_empty()
	if not binding_targets(db,assignment,g).any(func(row):return row.id==target):return false
	var jobs: Dictionary=db.data.get("crew_assignment",{})
	var row: Dictionary=jobs[assignment]
	var count := 0
	var capacity := int(row.maxCrew)
	for item in items:
		var occupied: Dictionary=jobs.get(str(item.assignmentType),{})
		if item.crewId!=id and occupied.get("targetType")==row.targetType and item.targetId==target:
			count+=1
			capacity=mini(capacity,int(occupied.maxCrew))
	return count < capacity

func can_assign(g, id: String, assignment: String, target: String, restoring := false) -> bool:
	if entry(g,id).is_empty() or (not restoring and not unlocked(g,id)):return false
	if not assignment.is_empty() and not restoring:
		if preload("res://scripts/hyperspace_permissions.gd").reserved_crew(g.hyperspace.state)==id:return false
		if not g.crew_exploration(id).is_empty():return false
	return binding_valid(g.db,_members,id,assignment,target,null if restoring else g)

func prepare_assignment(g, id: String, assignment: String, target: String, upgrade_mode := "") -> Dictionary:
	if not can_assign(g,id,assignment,target):return {}
	if not upgrade_mode.is_empty() and (assignment.is_empty() or not upgrade_modes(g,assignment).has(upgrade_mode)):return {}
	var previous:=entry(g,id);var current:=previous.duplicate(true)
	current.assignmentType=assignment;current.targetId=target
	if not upgrade_mode.is_empty():current.upgradeMode=upgrade_mode
	return prepare_member(previous,current)

func prepare_mode(g, id: String, mode: String, assignment := "") -> Dictionary:
	var previous:=entry(g,id)
	if previous.is_empty() or not upgrade_modes(g,assignment).has(mode):return {}
	var current:=previous.duplicate(true);current.upgradeMode=mode
	return prepare_member(previous,current)

func prepare_member(previous: Dictionary,current: Dictionary) -> Dictionary:
	var items: Array=_members.duplicate(true)
	for i in items.size():
		if items[i].crewId==current.crewId:items[i]=current
	return {"revision":revision,"members":items,"changes":[] if previous==current else [{"previous":previous.duplicate(true),"current":current.duplicate(true)}],"configuration":previous.assignmentType!=current.assignmentType or previous.targetId!=current.targetId}

func upgrade_modes(g, assignment := "") -> Array[String]:
	var result: Array[String] = []
	for id in assignments(g):
		var row: Dictionary=assignments(g)[id]
		if (assignment.is_empty() or id==assignment) and row.get("effectType")=="AUTO_UPGRADE":
			for mode in str(row.get("upgradeModes","")).split(",",false):
				var value := mode.strip_edges()
				if not result.has(value):result.append(value)
	return result

func upgrade_mode_text(mode: String, _effect_type := "AUTO_UPGRADE") -> String:
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
	for item in _members:
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
	for item in _members:
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

func factory_active(g) -> bool:
	for item in _members:
		var row: Dictionary=assignments(g).get(item.assignmentType,{})
		if row.get("targetType")=="hightech" and row.get("effectType")=="AUTO_RESEARCH" and active(g,item):return true
	return false

func auto_jewels(g, _item: Dictionary) -> bool:
	return g.upgrade_enhancement(1)>0

func auto_reactor(g, _item: Dictionary) -> bool:
	if not g.upgrade_reactor(1):return false
	# A paid upgrade changes capacity: preserve the existing buy-then-split order.
	run_reactor_allocation(g,_item)
	return true

func reactor_targets(_db, g = null) -> Array:
	return [{"id":"reactor","name":UIText.t("crew.job.reactor"),"active":g==null or g.reactor_unlocked()}]

func galaxy_targets(db, g = null) -> Array:
	if g!=null:return g.galaxy.targets(g)
	var result: Array=[]
	for id in db.data.get("galaxy",{}):
		result.append({"id":id,"name":db.data.galaxy[id].name,"active":true})
	return result

func equipment_targets(_db, g = null) -> Array:
	return [{"id":"equipment","name":UIText.t("crew.all_equipment"),"active":g==null or not g.loadout_entries("weapons").is_empty() or not g.loadout_entries("defence").is_empty()}]

func research_targets(_db, g = null) -> Array:
	return [{"id":"hightech","name":UIText.t("crew.hightech_system"),"active":g==null or g.ai_tech_factory_unlocked(),"category":"system"}]

func production_targets(db, g = null) -> Array:
	return furnace_targets(db,["超时空炼铁炉"],g)

func smelting_targets(db, g = null) -> Array:
	return furnace_targets(db,["宝石熔炼炉"],g)

func jewel_targets(_db, g = null) -> Array:
	return [{"id":"jewels","name":UIText.t("crew.jewel_system"),"active":g==null or g.jewels_unlocked()}]

func furnace_targets(db, keys: Array, g = null) -> Array:
	var result: Array = []
	for key in keys:
		if db.data.get("hightech",{}).has(key):result.append({"id":key,"name":UIText.data_text("hightech",key),"active":g==null or (g.hightech_unlocked(key) and g.hightech_level(key)>0)})
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
	for item in _members:
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
	if key=="equip_bonus":return pow(1.0+value,level)
	return 1.0+value*level

func system_level(g, key: String) -> int:
	if not levels_unlocked(g):return 0
	var target_type := str(g.db.data.crew_config[key].targetType)
	for item in _members:
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
		var effect_text := "%+.2f%%" % ((effect - 1.0) * 100.0)
		lines.append(format_text(g,key,{"level":item.level,"value":str(row.value),"effect":effect_text}))
	return "\n".join(lines)

func display_name(g, item: Dictionary) -> String:
	var member_name := str(definitions(g)[item.crewId].name)
	return format_text(g,"name_level",{"name":member_name,"level":item.level}) if levels_unlocked(g) else member_name
