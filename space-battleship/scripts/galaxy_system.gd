extends RefCounted
const Region := preload("res://scripts/galaxy_region.gd")
var effects := preload("res://scripts/galaxy_effect_aggregator.gd").new()
var regions := {}
var elapsed := {}
var elapsed_visible := {}
var elapsed_crew := {}
var visible_key := ""
var effect_generation := 0
var income_elapsed := 0.0

func setting(g, key: String) -> float:
	return float(g.db.data.galaxy_config[key].value)

func load_state(g, raw: Dictionary) -> void:
	regions.clear()
	elapsed.clear()
	elapsed_visible.clear()
	elapsed_crew.clear()
	income_elapsed=0
	g.profile.galaxies={}
	for key in g.db.data.get("galaxy",{}):
		var definition: Dictionary=g.db.data.galaxy[key]
		var definitions := {}
		for build in g.db.data.get("galaxy_build",{}).values():
			if build.galaxy_key==key:definitions[build.key]=build
		var region := Region.new()
		region.setup(definition,definitions,int(setting(g,"chunk_size")),raw.get(key,{}) if raw.get(key,{}) is Dictionary else {})
		regions[key]=region
		g.profile.galaxies[key]=region.state
		var pending: Dictionary=raw.get(key,{}) if raw.get(key,{}) is Dictionary else {}
		elapsed[key]=maxf(0.0,float(pending.get("pending_online_time",0)))
		elapsed_crew[key]=maxi(0,int(pending.get("pending_crew_count",0)))
		elapsed_visible[key]=false
	effect_generation+=1
	effects.invalidate()
	refresh_unlocks(g)

func conquered(g) -> int:
	var count := 0
	for progress in g.profile.get("planets",{}).values():
		if progress.get("conquered",false):count+=1
	return count

func condition_met(g, definition: Dictionary) -> bool:
	match str(definition.unlock_type):
		"conquered_planet_count":return conquered(g)>=int(definition.unlock_value)
		"galaxy_complete":return regions.has(str(definition.unlock_value)) and regions[str(definition.unlock_value)].state.status=="complete"
	return false

func refresh_unlocks(g) -> void:
	for key in regions:
		var region=regions[key]
		if region.state.status!="locked":continue
		if not g.content_unlocked("feature","galaxy") or not condition_met(g,region.row):continue
		var predecessors := regions.values().filter(func(other):return str(other.row.next_galaxy)==key)
		if not predecessors.all(func(other):return other.state.status=="complete"):continue
		region.state.status="available"
		g.event.emit("galaxy_unlocked",{"key":key})

func available() -> bool:
	return regions.values().any(func(region):return region.state.status!="locked")

func start(g, key: String) -> bool:
	if not regions.has(key) or regions[key].state.status!="available":return false
	regions[key].state.status="exploring"
	g.save_dirty = true
	g.event.emit("galaxy_changed",{"key":key})
	return true

func crew_count(g, key: String) -> int:
	var count := 0
	for member in g.profile.get("crew",[]):
		if member.assignmentType=="galaxy_explore" and member.targetId==key and g.crew.unlocked(g,member.crewId):count+=1
	return count

func set_visible(key: String) -> void:
	if key==visible_key:return
	visible_key=key

func advance(g, dt: float) -> void:
	if dt<=0 or g.paused or regions.is_empty():return
	# Unlock checks run at the same bounded online cadence, never from UI reads.
	income_elapsed+=dt
	if income_elapsed>=setting(g,"income_interval"):
		refresh_unlocks(g)
		var rates: Dictionary=effects.rates(g,self)
		for pair in [["iron",str(int(setting(g,"iron_resource_id")))],["uranium",str(int(g.db.config.reactorUraniumId))]]:
			var amount=g.N.multiply(rates[pair[0]],income_elapsed)
			if g.N.compare(amount,0)>0:
				g.profile.resources[pair[1]]=g.N.add(g.profile.resources.get(pair[1],0),amount)
				g.resource_samples.append({"time":g.economy_time(),"production_time":g.production_time(),"id":pair[1],"amount":amount,"origin":"galaxy"})
				g.event.emit("galaxy_income",{"id":pair[1],"amount":amount})
		income_elapsed=0
	for key in regions:
		var region=regions[key]
		if not region.state.status in ["exploring","developing"]:continue
		var count := crew_count(g,key)
		if count!=int(elapsed_crew[key]):flush_pending(g,key)
		elapsed_crew[key]=count
		if count<=0:continue
		var visible: bool=key==visible_key
		# A visibility switch cannot replay hidden time through per-ship logic.
		if visible!=bool(elapsed_visible[key]) and float(elapsed[key])>0:
			advance_region(g,key,float(elapsed[key]),bool(elapsed_visible[key]) and visible)
			elapsed[key]=0.0
		elapsed_visible[key]=visible
		elapsed[key]+=dt
		var interval := setting(g,"visible_tick" if visible else "hidden_tick")
		if elapsed[key]<interval:continue
		advance_region(g,key,float(elapsed[key]),visible)
		elapsed[key]=0.0

func advance_region(g, key: String, dt: float, visible: bool) -> void:
	var region=regions[key]
	var before := int(region.building_revision)
	g.capture_refit_health()
	region.advance(dt,int(elapsed_crew[key]),visible)
	if before!=region.building_revision:
		effect_generation+=1
		g.invalidate_stat_cache()
		g.apply_refit_health()
		for category in ["weapons","defence"]:g.event.emit("equipment_stats",{"category":category})
		g.event.emit("reactor_changed",{})
	g.save_dirty=true
	g.event.emit("galaxy_changed",{"key":key})
	if region.state.status=="complete":refresh_unlocks(g)

func flush_pending(g, key: String) -> void:
	if not regions.has(key) or float(elapsed.get(key,0))<=0:return
	# Settle only time already earned, using the crew present during that time.
	advance_region(g,key,float(elapsed[key]),false)
	elapsed[key]=0.0

func save_data() -> Dictionary:
	var result := {}
	for key in regions:
		result[key]=regions[key].save_data()
		result[key].pending_online_time=float(elapsed[key])
		result[key].pending_crew_count=int(elapsed_crew[key]) if float(elapsed[key])>0 else 0
	return result

func targets(_g) -> Array:
	var result: Array=[]
	for key in regions:
		var region=regions[key]
		result.append({"id":key,"name":region.row.name,"active":region.state.status in ["available","exploring","developing"]})
	return result

func multiplier(effect: String) -> float:
	return effects.multiplier(self,effect)
