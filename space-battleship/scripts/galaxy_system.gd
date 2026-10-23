extends RefCounted
## Owns galaxy progress, pending online work and income time. No backend or event orchestration.
const Region := preload("res://scripts/galaxy_region.gd")
var effects := preload("res://scripts/galaxy_effect_aggregator.gd").new()
var _regions:Dictionary={}
var _elapsed:Dictionary={}
var _elapsed_crew:Dictionary={}
var _income_elapsed:=0.0
var effect_generation:=0
var combat_generation:=0
var revision:=0
var regions:Dictionary:
	get:return _regions
func pending(key:String)->float:return float(_elapsed.get(key,0.0))
func pending_crew(key:String)->int:return int(_elapsed_crew.get(key,0))
func income_time()->float:return _income_elapsed
func setting(g,key:String)->float:return float(g.db.data.galaxy_config[key].value)

static func building_definitions(db,key:String)->Dictionary:
	var result:Dictionary={}
	for row in db.data.get("galaxy_build",{}).values():
		if row.galaxy_key==key:result[row.key]=row
	return result

func _install(db,raw:Dictionary,income:float)->void:
	_regions={};_elapsed={};_elapsed_crew={};_income_elapsed=income
	for key in db.data.get("galaxy",{}):
		var saved:Dictionary=raw.get(key,{})
		var region:=Region.new()
		region.setup(db.data.galaxy[key],building_definitions(db,key),int(db.data.galaxy_config.chunk_size.value),saved)
		_regions[key]=region
		_elapsed[key]=float(saved.get("pending_online_time",0.0))
		_elapsed_crew[key]=int(saved.get("pending_crew_count",0))
	_regions.make_read_only();revision+=1;effect_generation+=1;combat_generation+=1;effects.invalidate()
func reset(db)->void:_install(db,{},0.0)
func install_snapshot(raw:Dictionary,db)->bool:
	if not valid_snapshot(raw,db):return false
	_install(db,raw.galaxies,float(raw.galaxyIncomeElapsed));return true
static func valid_snapshot(raw:Dictionary,db)->bool:
	var income=raw.get("galaxyIncomeElapsed")
	if not (income is float or income is int) or not is_finite(float(income)) or income<0:return false
	if not raw.get("galaxies") is Dictionary or raw.galaxies.size()!=db.data.galaxy.size():return false
	for key in db.data.galaxy:
		if not raw.galaxies.get(key) is Dictionary or not Region.valid_snapshot(raw.galaxies[key],db.data.galaxy[key],building_definitions(db,key),db.data.crew.size()):return false
	return true

func conquered(g) -> int:
	var count := 0
	for progress in g.planets.all().values():
		if progress.get("conquered",false):count+=1
	return count

func condition_met(g, definition: Dictionary) -> bool:
	match str(definition.unlock_type):
		"stage_cleared":return g.profile.cleared.has(int(definition.unlock_value))
		"conquered_planet_count":return conquered(g)>=int(definition.unlock_value)
		"galaxy_complete":return regions.has(str(definition.unlock_value)) and regions[str(definition.unlock_value)].state.status=="complete"
	return false

func refresh_unlocks(g) -> Array:
	var unlocked:Array=[]
	for key in regions:
		var region=regions[key]
		if region.state.status!="locked":continue
		if not g.content_unlocked("feature","galaxy") or not condition_met(g,region.row):continue
		var predecessors := regions.values().filter(func(other):return str(other.row.next_galaxy)==key)
		if not predecessors.all(func(other):return other.state.status=="complete"):continue
		if region.unlock():unlocked.append(key);revision+=1
	return unlocked

func available() -> bool:
	return regions.values().any(func(region):return region.state.status!="locked")

func start(key: String) -> bool:
	if not regions.has(key) or regions[key].state.status!="available":return false
	var started:bool=regions[key].start()
	if started:revision+=1
	return started

func crew_count(g, key: String) -> int:
	var count := 0
	for member in g.crew.members():
		if member.assignmentType=="galaxy_explore" and member.targetId==key and g.crew.unlocked(g,member.crewId):count+=1
	return count

func work_interval(g)->float:
	# The existing visible cadence is the sole online work cadence. The slower
	# hidden-page batching setting no longer controls any business settlement.
	return setting(g,"visible_tick")

func preview_advance(g,dt:float)->Dictionary:
	var candidate:Dictionary={}
	for key in regions:
		var region=regions[key]
		if not region.state.status in ["exploring","developing"]:continue
		var count:=crew_count(g,key)
		var pending:float=_elapsed[key]
		# Pending work keeps the crew count under which it accrued.
		if count!=int(_elapsed_crew[key]) and pending>0:return {"boundary":"crew_change"}
		if count<=0:continue
		pending+=dt
		var settled:=pending if pending>=work_interval(g) else 0.0
		if region.revision_due(settled,count):
			# Keep this command to one exact region settlement. Multiple revisions
			# inside that settlement are already owned by Region.advance().
			if not candidate.is_empty():
				return {"boundary":"compound"}
			candidate={"key":key,"dt":settled,"count":count}
	return candidate

func add_income_time(dt:float)->void:
	_income_elapsed+=dt;revision+=1
func income_due(g)->bool:return _income_elapsed>=setting(g,"income_interval")
func prepare_income(g)->Dictionary:
	var rates:Dictionary=effects.rates(g,self)
	var gains:Dictionary={}
	for pair in [["iron",str(int(setting(g,"iron_resource_id")))],["uranium",str(int(g.db.config.reactorUraniumId))]]:
		var amount=g.N.multiply(rates[pair[0]],_income_elapsed)
		if g.N.compare(amount,0)>0:gains[pair[1]]=g.N.add(gains.get(pair[1],0),amount)
	return {"revision":revision,"gains":gains,"seconds":_income_elapsed}
func income_current(plan:Dictionary)->bool:return plan.revision==revision and plan.seconds==_income_elapsed
func commit_income(_plan:Dictionary)->void:_income_elapsed=0.0;revision+=1
func set_pending_context(key:String,count:int)->void:
	if pending_crew(key)==count:return
	_elapsed_crew[key]=count;revision+=1
func add_pending(key:String,dt:float)->void:_elapsed[key]+=dt;revision+=1
func pending_due(g,key:String)->bool:return pending(key)>=work_interval(g)
func prepare_region(key:String,dt:float,count:int)->Dictionary:
	var region=_regions[key]
	var next=region.predict_advance(dt,count)
	var changed:=false
	var refitted:=false
	if next.building_revision!=region.building_revision:
		var before:Dictionary=effects.region_effects(region)
		var after:Dictionary=effects.region_effects(next)
		changed=before!=after
		refitted=before.equipment_value!=after.equipment_value or before.charge_max!=after.charge_max
	return {"key":key,"dt":dt,"count":count,"source_revision":region.state_revision,"region":next,"effects_changed":changed,"refitted":refitted,"completed":next.state.status=="complete" and region.state.status!="complete"}
func region_current(plan:Dictionary)->bool:
	return _regions.has(plan.key) and _regions[plan.key].state_revision==plan.source_revision and is_equal_approx(pending(plan.key),plan.dt) and pending_crew(plan.key)==plan.count
func commit_region(plan:Dictionary)->void:
	_regions[plan.key].commit_prediction(plan.region)
	_elapsed[plan.key]=0.0;revision+=1
	if plan.effects_changed:effect_generation+=1
	if plan.refitted:combat_generation+=1
func save_data()->Dictionary:
	var result:Dictionary={}
	for key in _regions:
		result[key]=_regions[key].save_data()
		result[key].pending_online_time=pending(key)
		result[key].pending_crew_count=pending_crew(key) if pending(key)>0 else 0
	return {"galaxies":result,"galaxyIncomeElapsed":_income_elapsed}

func targets(_g) -> Array:
	var result: Array=[]
	for key in regions:
		var region=regions[key]
		result.append({"id":key,"name":region.row.name,"active":region.state.status in ["available","exploring","developing"]})
	return result

func multiplier(effect: String) -> float:
	return effects.multiplier(self,effect)
