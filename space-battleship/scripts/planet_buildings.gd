extends RefCounted
## Table-driven per-planet construction. Reads never create or advance state.
const N = preload("res://scripts/growth_number.gd")

func rows(g, planet_id: String) -> Array:
	return rows_for(g.db,planet_id)

static func rows_for(db, planet_id: String) -> Array:
	var planet: Dictionary = db.data.get("planet",{}).get(planet_id,{})
	var result: Array = []
	if planet.is_empty():return result
	for row in db.data.get("planet_build", {}).values():
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
	for id in g.planets.all():
		if not g.planet_unlocked(str(id)):continue
		for row in rows(g, str(id)):
			if state(g, str(id), str(row.id)).get("status", "") == "ready":return true
	return false

func preview(g, planet_id: String) -> Dictionary:
	for row in rows(g,planet_id):
		if state(g,planet_id,str(row.id)).get("status", "locked")=="locked":return row
	return {}

static func sync_progress(db, planet_id: String, progress: Dictionary) -> void:
	if not progress.has("buildings"):progress.buildings = {}
	for row in rows_for(db,planet_id):
		var id := str(row.id)
		if not progress.buildings.has(id):
			progress.buildings[id] = {"status":"locked","build_progress":0,"crew":[]}
		var item: Dictionary = progress.buildings[id]
		if item.status=="locked" and N.compare(progress.degree,row.unlock_explore)>=0:
			item.status = "building"
		if item.status=="building" and N.compare(item.build_progress,row.build_explore)>=0:
			item.status = "ready"
			item.crew = []

static func complete_progress(db, planet_id: String, progress: Dictionary) -> void:
	# Threshold-crossing trips unlock construction without building it early.
	sync_progress(db,planet_id,progress)
	for row in rows_for(db,planet_id):
		var item: Dictionary=progress.buildings[str(row.id)]
		if item.status!="building" or item.crew.size()<int(row.extra_crew):continue
		item.build_progress=N.add(item.build_progress,1)
	progress.degree=N.add(progress.degree,1)
	sync_progress(db,planet_id,progress)

func building_multiplier(g, planet_id: String, row: Dictionary):
	return N.power(N.add(1,N.multiply(row.config1,g.planet_progress(planet_id).degree)),float(row.config2))

func multiplier(g, kind: String):
	var result = 1.0
	for id in g.planets.all():
		for row in rows(g,str(id)):
			if str(row.type)!=kind or state(g,str(id),str(row.id)).get("status", "")!="built":continue
			result = N.multiply(result,building_multiplier(g,str(id),row))
	return result

func occupied(g, crew_id: String) -> String:
	if crew_id.is_empty():return ""
	for id in g.planets.all():
		var progress: Dictionary = g.planets.progress(str(id))
		if str(progress.get("crewId", ""))==crew_id:return str(id)
		for item in progress.get("buildings",{}).values():
			if item.get("crew",[]).has(crew_id):return str(id)
	return ""
