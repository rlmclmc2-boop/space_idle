extends RefCounted
## Never accept caller-supplied crew levels, hull capacity, or sealed thresholds.
static func hull_capacity(g,c: Dictionary) -> int:
	return int(c.hull_capacities.get(str(g.profile.selectedShip),0))

static func planet_for_level(data: Dictionary,level: int) -> String:
	var selected:="";var selected_stage:=-1;var first:="";var first_stage:=2147483647
	for id in data.get("planet",{}):
		var gate: Dictionary=data.unlock.get(str(data.planet[id].unlockId),{})
		if gate.is_empty():continue
		var stage:=int(gate.level)
		if stage<first_stage:first=str(id);first_stage=stage
		if stage<=level and stage>selected_stage:selected=str(id);selected_stage=stage
	return first if selected.is_empty() else selected

static func planet_stage(data: Dictionary,id: String) -> int:
	var planet: Dictionary=data.get("planet",{}).get(id,{})
	var gate: Dictionary=data.get("unlock",{}).get(str(planet.get("unlockId","")),{})
	return int(gate.get("level",0))

static func claim_stages(s: Dictionary,ids: Array,data: Dictionary) -> Dictionary:
	var stages: Dictionary={}
	for id in ids:
		if not s.inventory.drones.has(id):return {}
		var stage:=planet_stage(data,str(s.inventory.drones[id].planet_id))
		if stage<1:return {}
		stages[id]=stage
	return stages

static func reserved_crew(s: Dictionary) -> String:
	var idle:Dictionary=s.get("idle",{})
	if not idle.is_empty() and idle.mode=="auto":return str(idle.crew_id)
	if s.get("version")==4 and not s.active.is_empty() and s.active.mode=="auto":return str(s.active.crew_id)
	return str(s.auto.crew_id) if s.auto.enabled else ""

static func crew_available(g,id: String) -> bool:
	var entry: Dictionary=g.crew.entry(g,id)
	if entry.is_empty() or not g.crew.unlocked(g,id) or not str(entry.assignmentType).is_empty() or not g.crew_exploration(id).is_empty() or not g.planet_buildings.occupied(g,id).is_empty():return false
	var current:=reserved_crew(g.profile.hyperspace)
	return current.is_empty() or current==id

static func crew_level(g,id: String) -> int:
	var entry: Dictionary=g.crew.entry(g,id)
	return int(entry.get("level",0)) if g.crew.levels_unlocked(g) else 0

static func bindings_valid(profile: Dictionary,data: Dictionary,c: Dictionary) -> bool:
	if not profile.has("hyperspace"):return true
	var s: Dictionary=profile.hyperspace
	if not s.active.is_empty() and not s.active.get("return_state",{}).is_empty() and not preload("res://scripts/hyperspace_main_return.gd").binding_valid(s.active.return_journey,profile,data):return false
	var bag: Dictionary=s.inventory
	if bag.equipped.size()>int(c.hull_capacities.get(str(profile.get("selectedShip","")),0)):return false
	for id in bag.drones:
		var d: Dictionary=bag.drones[id]
		if not data.get("planet",{}).has(d.planet_id) or d.planet_id!=planet_for_level(data,int(d.level)):return false
	for receipt in [s.active,s.get("idle",{})]:
		if not receipt.is_empty() and receipt.status=="completed_pending" and not receipt.reward.drone.is_empty():
			var reward_drone:Dictionary=receipt.reward.drone
			if reward_drone.planet_id!=planet_for_level(data,int(reward_drone.level)):return false
	for id in bag.sealed:
		if int(bag.sealed[id])!=planet_stage(data,str(bag.drones[id].planet_id)):return false
	var crew_id:=reserved_crew(s)
	if crew_id.is_empty():return not s.auto.enabled and s.get("idle",{}).get("mode","")!="auto" and (s.active.is_empty() or s.active.mode!="auto")
	var found:=false
	for item in profile.get("crew",[]):
		if item.get("crewId")==crew_id:
			if not str(item.get("assignmentType","")).is_empty():return false
			found=true
	if not found or not data.get("crew",{}).has(crew_id):return false
	var gate_id:=str(data.crew[crew_id].get("unlockId",""))
	if not gate_id.is_empty():
		var gate: Dictionary=data.get("unlock",{}).get(gate_id,{})
		if gate.is_empty():return false
		var unlocked: bool=profile.get("grantedUnlocks",[]).has(gate_id) or int(gate.level)==0 or (int(profile.get("highestLevel",1))>int(gate.level) if gate.get("mode","cleared")=="reached" else profile.get("cleared",[]).has(int(gate.level)))
		if not unlocked:return false
	for planet in profile.get("planets",{}).values():
		if planet.get("crewId","")==crew_id:return false
		for building in planet.get("buildings",{}).values():
			if crew_id in building.get("crew",[]):return false
	return true
