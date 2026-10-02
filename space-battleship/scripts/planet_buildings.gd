extends RefCounted
## Table-driven per-planet construction. Reads never create or advance state.
const N = preload("res://scripts/growth_number.gd")

func rows(g, planet_id: String) -> Array:
	var planet: Dictionary = g.planet_row(planet_id)
	var result: Array = []
	if planet.is_empty():return result
	for row in g.db.data.get("planet_build", {}).values():
		if int(planet.id) < int(row.min_planet):continue
		var values := str(row.planet_value).split(",",false)
		var matches := false
		match str(row.planet_rule):
			"all":matches = true
			"only":matches = values.has(planet_id)
			"exclude":matches = not values.has(planet_id)
			"tag":matches = str(planet.get("tags", "")).split(",",false).has(str(row.planet_value))
		if matches:result.append(row)
	result.sort_custom(func(a,b):return float(a.order)<float(b.order) if a.order!=b.order else str(a.id).naturalnocasecmp_to(str(b.id))<0)
	return result

func state(g, planet_id: String, building_id: String) -> Dictionary:
	return g.planet_progress(planet_id).get("buildings",{}).get(building_id,{})

func built(g, planet_id: String, kind: String) -> bool:
	for row in rows(g,planet_id):
		if str(row.type)==kind and state(g,planet_id,str(row.id)).get("status", "") == "built":return true
	return false

func has_ready(g) -> bool:
	for id in g.profile.get("planets", {}):
		if not g.planet_unlocked(str(id)):continue
		for row in rows(g, str(id)):
			if state(g, str(id), str(row.id)).get("status", "") == "ready":return true
	return false

func activate(g, planet_id: String, building_id: String) -> bool:
	if not g.planet_unlocked(planet_id):return false
	var item := state(g, planet_id, building_id)
	if item.get("status", "") != "ready":return false
	for row in rows(g, planet_id):
		if str(row.id) != building_id:continue
		item.status = "built"
		if str(row.type) == "auto_explore":g.planet_progress(planet_id).auto_explore = true
		g.invalidate_stat_cache()
		g.save_dirty = true
		g.event.emit("planet_changed", {"id":planet_id, "activated":building_id})
		return true
	return false

func preview(g, planet_id: String) -> Dictionary:
	for row in rows(g,planet_id):
		if state(g,planet_id,str(row.id)).get("status", "locked")=="locked":return row
	return {}

func sync(g, planet_id: String) -> void:
	var progress: Dictionary = g.planet_progress(planet_id)
	if not progress.has("buildings"):progress.buildings = {}
	for row in rows(g,planet_id):
		var id := str(row.id)
		if not progress.buildings.has(id):
			var previous := str(row.get("previous_id",""))
			if not previous.is_empty() and progress.buildings.has(previous):
				progress.buildings[id]=progress.buildings[previous].duplicate(true)
				progress.buildings.erase(previous)
			else:progress.buildings[id] = {"status":"locked","build_progress":0,"crew":[]}
		var item: Dictionary = progress.buildings[id]
		if item.status=="locked" and N.compare(progress.degree,row.unlock_explore)>=0:
			item.status = "building"
		if item.status=="building" and N.compare(item.build_progress,row.build_explore)>=0:
			item.status = "ready"
			item.crew = []

func complete(g, planet_id: String) -> void:
	# Called BEFORE this exploration increments degree; threshold-crossing trips
	# unlock construction, but never count as a trip after unlocking.
	sync(g,planet_id)
	for row in rows(g,planet_id):
		var item := state(g,planet_id,str(row.id))
		if item.status!="building" or item.crew.size()<int(row.extra_crew):continue
		item.build_progress = N.add(item.build_progress,1)
	g.profile.planets[planet_id].degree = N.add(g.planet_progress(planet_id).degree,1)
	sync(g,planet_id)

func building_multiplier(g, planet_id: String, row: Dictionary):
	return N.power(N.add(1,N.multiply(row.config1,g.planet_progress(planet_id).degree)),float(row.config2))

func multiplier(g, kind: String):
	var result = 1.0
	for id in g.profile.get("planets",{}):
		for row in rows(g,str(id)):
			if str(row.type)!=kind or state(g,str(id),str(row.id)).get("status", "")!="built":continue
			result = N.multiply(result,building_multiplier(g,str(id),row))
	return result

func occupied(g, crew_id: String) -> String:
	if crew_id.is_empty():return ""
	for id in g.profile.get("planets",{}):
		var progress: Dictionary = g.profile.planets[id]
		if str(progress.get("crewId", ""))==crew_id:return str(id)
		for item in progress.get("buildings",{}).values():
			if item.get("crew",[]).has(crew_id):return str(id)
	return ""

func assign(g, planet_id: String, building_id: String, crew_id: String) -> bool:
	var row: Dictionary = {}
	for candidate in rows(g,planet_id):
		if str(candidate.id)==building_id:row=candidate
	var item := state(g,planet_id,building_id)
	if row.is_empty() or item.get("status", "")!="building":return false
	if item.crew.has(crew_id):
		item.crew.erase(crew_id)
	else:
		var member: Dictionary = g.crew.entry(g,crew_id)
		if item.crew.size()>=int(row.extra_crew) or member.is_empty() or not g.crew.unlocked(g,crew_id) or not str(member.assignmentType).is_empty() or not occupied(g,crew_id).is_empty():return false
		item.crew.append(crew_id)
	g.save_dirty = true
	g.event.emit("planet_changed",{"id":planet_id})
	return true
