extends RefCounted
## Permanent activation lives in planet progress, never in copied reward values.
const FIELDS := {
	"level_bonus:equipment":"equipment_level_bonus",
	"level_bonus:hightech":"hightech_level_bonus",
	"free_charge:all":"charge_free_ratio",
	"level_bonus:enhancement":"gem_drop_level_bonus",
	"luck:all":"hyperspace_luck",
}

func description(row: Dictionary) -> String:
	return str(row.des).replace("{value}",NumberFormat.precise(float(row.value)))

func active(g, row: Dictionary) -> bool:
	var planet_id := str(int(row.planet_id))
	var progress: Dictionary = g.planet_progress(planet_id)
	if progress.is_empty():return false
	# A conquest source cannot activate early even if its condition is edited.
	if str(row.source)=="conquer" and not progress.get("conquered",false):return false
	match str(row.condition):
		"always":return true
		"conquered":return progress.get("conquered",false)==true
		"building_complete":
			return g.planet_buildings.rows(g,planet_id).any(func(building):return str(building.id)==str(row.source_id)) and g.planet_buildings.state(g,planet_id,str(row.source_id)).get("status","")=="built"
	return false

func rows(g, planet_id := "", source := "") -> Array:
	var result: Array=[]
	for row in g.db.data.get("planet_buff",{}).values():
		if not planet_id.is_empty() and str(int(row.planet_id))!=planet_id:continue
		if not source.is_empty() and str(row.source)!=source:continue
		if active(g,row):result.append(row)
	result.sort_custom(func(a,b):return float(a.order)<float(b.order) if a.order!=b.order else int(a.id)<int(b.id))
	return result

func allows_planet(g, planet_id: String) -> bool:
	var planets: Dictionary = g.db.data.get("planet", {})
	if not planets.has(planet_id):return false
	var first_id := int(planet_id)
	for id in planets:first_id = mini(first_id, int(id))
	if int(planet_id) == first_id:return true
	for row in g.db.data.get("planet_buff", {}).values():
		if str(row.source) == "conquer" and str(row.buff_type) == "planet_unlock" and str(row.target) == "planet" and str(row.stack) == "max" and int(row.value) == int(planet_id) and active(g, row):return true
	return false

func shares_experience(g, planet_id: String) -> bool:
	return rows(g,planet_id).any(func(row):return str(row.buff_type)=="crew_exp_share" and str(row.target)=="all" and float(row.value)>0)

func totals(g) -> Dictionary:
	var buckets := {}
	for field in FIELDS.values():buckets[field]={"add":0.0,"mul":1.0,"max":0.0,"has_add":false,"has_mul":false}
	for row in rows(g):
		var field: String=FIELDS.get(str(row.buff_type)+":"+str(row.target),"")
		if field.is_empty():continue
		var bucket: Dictionary=buckets[field]
		match str(row.stack):
			"add":
				bucket.add+=float(row.value)
				bucket.has_add=true
			"mul":
				bucket.mul*=float(row.value)
				bucket.has_mul=true
			"max":bucket.max=maxf(bucket.max,float(row.value))
	var result := {}
	for field in buckets:
		var bucket: Dictionary=buckets[field]
		# Stable operation order, independent of presentation order: add, mul, max.
		var base: float=bucket.add if bucket.has_add else (1.0 if bucket.has_mul else 0.0)
		result[field]=maxf(base*bucket.mul,bucket.max)
	return result
