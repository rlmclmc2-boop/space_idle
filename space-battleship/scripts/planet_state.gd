extends RefCounted
## Owns exploration, building work/occupation, activation and permanent conquest.
const N=preload("res://scripts/growth_number.gd")
const Buildings=preload("res://scripts/planet_buildings.gd")
var revision:=0
var contribution_revision:=0
var _progress: Dictionary={}

static func freeze(value) -> void:
	if value is Dictionary:
		for child in value.values():freeze(child)
		value.make_read_only()
	elif value is Array:
		for child in value:freeze(child)
		value.make_read_only()

func all() -> Dictionary:
	return _progress
func progress(id: String) -> Dictionary:
	return _progress.get(id,{})
func save_data() -> Dictionary:
	return {"planets":_progress.duplicate(true)}
func _install(next: Dictionary, contributions:=true) -> void:
	_progress=next.duplicate(true);freeze(_progress);revision+=1
	if contributions:contribution_revision+=1
func reset(g) -> void:
	var next: Dictionary={}
	for id in g.db.data.get("planet",{}):
		next[id]={"degree":0.0,"unlocked":g.unlock_available(str(g.db.data.planet[id].get("unlockId",""))),"conquered":false,"auto_explore":false,"crewId":"","elapsed":0.0,"buildings":{}}
		Buildings.sync_progress(g.db,str(id),next[id])
	_install(next)

static func duration(row: Dictionary, degree) -> float:
	var base:=float(row.get("baseTime",0));var minimum:=float(row.get("minTime",5.0))
	if not is_finite(minimum) or minimum<=0:minimum=5.0
	return maxf(minimum,N.ratio(base*base,N.add(base,degree))) if base>0 else 0.0
static func experience_multiplier(db, lifetime_stage: int, highest_stage: int) -> float:
	var level:=clampi(maxi(lifetime_stage,highest_stage),1,db.levels.size())
	return float(db.levels[level-1].get("planetExpRatio",0)) if level>0 else 0.0
static func experience_reward(db,id: String, enabled: bool, lifetime_stage: int, highest_stage: int, galaxy_multiplier: float) -> float:
	return roundf(float(db.data.planet.get(id,{}).get("baseExp",0))*experience_multiplier(db,lifetime_stage,highest_stage)*galaxy_multiplier) if enabled else 0.0
static func reforge_start(db,id: String) -> int:
	return clampi(int(db.data.planet.get(id,{}).get("reforgeStartLevel",1)),1,maxi(1,db.levels.size()))

static func valid_snapshot(raw: Dictionary, db) -> bool:
	if not raw.get("planets") is Dictionary or not raw.get("crew") is Array:return false
	var planets: Dictionary=raw.planets;var definitions: Dictionary=db.data.get("planet",{})
	if planets.size()!=definitions.size():return false
	var crew: Dictionary={};var occupied: Dictionary={}
	for member in raw.crew:
		if not member is Dictionary or not member.get("crewId") is String or not member.get("assignmentType") is String:return false
		crew[member.crewId]=true
		if not str(member.assignmentType).is_empty():occupied[member.crewId]=true
	# Hyperspace reservation is checked by the complete save binding validator.
	for id in definitions:
		if not planets.get(id) is Dictionary:return false
		var value: Dictionary=planets[id]
		if not N.valid(value.get("degree")) or not value.get("unlocked") is bool or not value.get("conquered") is bool or not value.get("auto_explore") is bool or not value.get("crewId") is String:return false
		if not (value.get("elapsed") is int or value.get("elapsed") is float) or not is_finite(float(value.elapsed)) or value.elapsed<0:return false
		if value.crewId.is_empty():
			if value.elapsed!=0:return false
		else:
			if not crew.has(value.crewId) or occupied.has(value.crewId):return false
			occupied[value.crewId]=true
		var rows:=Buildings.rows_for(db,str(id))
		if not value.get("buildings") is Dictionary or value.buildings.size()!=rows.size():return false
		for row in rows:
			var building_id:=str(row.id)
			if not value.buildings.get(building_id) is Dictionary:return false
			var item: Dictionary=value.buildings[building_id]
			if not item.get("status") in ["locked","building","ready","built"] or not N.valid(item.get("build_progress")) or not item.get("crew") is Array or item.crew.size()>int(row.extra_crew):return false
			if item.status!="building" and not item.crew.is_empty():return false
			for member_id in item.crew:
				if not crew.has(member_id) or occupied.has(member_id):return false
				occupied[member_id]=true
	return true

func install_snapshot(raw: Dictionary,db) -> bool:
	if not valid_snapshot(raw,db):return false
	_install(raw.planets)
	return true
func proposal(id: String, next: Dictionary, configuration:=false) -> Dictionary:
	return {"revision":revision,"id":id,"next":next,"configuration":configuration,"completed":false}
func proposal_current(plan: Dictionary) -> bool:
	return not plan.is_empty() and int(plan.revision)==revision
func commit(plan: Dictionary) -> void:
	assert(proposal_current(plan))
	if plan.has("conquest"):
		_install(plan.conquest);return
	var next: Dictionary=_progress.duplicate()
	next[plan.id]=plan.next.duplicate(true);freeze(next[plan.id])
	var old: Dictionary=progress(str(plan.id))
	var changed: bool=old.degree!=plan.next.degree or old.conquered!=plan.next.conquered or old.buildings!=plan.next.buildings
	next.make_read_only();_progress=next;revision+=1
	if changed:contribution_revision+=1

func prepare_start(g,id: String,crew_id: String) -> Dictionary:
	var value:=progress(id)
	if value.is_empty() or not g.planet_unlocked(id) or not str(value.crewId).is_empty() or not g.idle_planet_crew(crew_id):return {}
	var next:=value.duplicate(true);Buildings.sync_progress(g.db,id,next)
	next.unlocked=true;next.crewId=crew_id;next.elapsed=0.0
	return proposal(id,next)
func prepare_cancel(id: String) -> Dictionary:
	var value:=progress(id)
	if value.is_empty() or str(value.crewId).is_empty():return {}
	var next:=value.duplicate(true);next.crewId="";next.elapsed=0.0
	return proposal(id,next)
func prepare_auto(g,id: String,enabled: bool) -> Dictionary:
	if not g.planet_buildings.built(g,id,"auto_explore"):return {}
	var next:=progress(id).duplicate(true);next.auto_explore=enabled
	return proposal(id,next)
func prepare_activation(g,id: String,building_id: String) -> Dictionary:
	if not g.planet_unlocked(id):return {}
	var value:=progress(id)
	if value.get("buildings",{}).get(building_id,{}).get("status","")!="ready":return {}
	for row in Buildings.rows_for(g.db,id):
		if str(row.id)!=building_id:continue
		var next:=value.duplicate(true);next.buildings[building_id].status="built"
		if str(row.type)=="auto_explore":next.auto_explore=true
		return proposal(id,next,true)
	return {}
func prepare_builder(g,id: String,building_id: String,crew_id: String) -> Dictionary:
	var row: Dictionary={}
	for candidate in Buildings.rows_for(g.db,id):
		if str(candidate.id)==building_id:row=candidate
	var value:=progress(id)
	if row.is_empty() or value.get("buildings",{}).get(building_id,{}).get("status","")!="building":return {}
	var next:=value.duplicate(true);var item: Dictionary=next.buildings[building_id]
	if item.crew.has(crew_id):item.crew.erase(crew_id)
	else:
		if item.crew.size()>=int(row.extra_crew) or not g.idle_planet_crew(crew_id):return {}
		item.crew.append(crew_id)
	return proposal(id,next)
func prepare_step(g,id: String,dt: float) -> Dictionary:
	var value:=progress(id)
	if dt<=0 or not is_finite(dt) or value.is_empty() or str(value.crewId).is_empty():return {}
	var next:=value.duplicate(true);next.elapsed+=dt
	if next.elapsed<duration(g.planet_row(id),value.degree):return proposal(id,next)
	Buildings.complete_progress(g.db,id,next)
	next.elapsed=0.0
	next.crewId=value.crewId if value.auto_explore and g.planet_buildings.built(g,id,"auto_explore") else ""
	var plan:=proposal(id,next,g.planet_buildings.built(g,id,"equipment"));plan.completed=true;plan.crew_id=value.crewId
	return plan
func prepare_conquest(g,id: String) -> Dictionary:
	var value:=progress(id)
	if value.is_empty() or value.conquered or not g.planet_unlocked(id) or not g.planet_buildings.built(g,id,"shipyard"):return {}
	var next:=_progress.duplicate(true)
	for key in next:next[key].unlocked=g.planet_unlocked(str(key))
	next[id].conquered=true
	var plan:=proposal(id,next[id],true);plan.conquest=next
	return plan
