extends SceneTree
const Game=preload("res://qa/clock_game.gd")
func planet_case(cadence: float) -> Dictionary:
	var g=Game.new(ShipDatabase.new(),false)
	g.profile.cleared=range(1,31);g.profile.highestLevel=31;g.stage=30;g.rebuild_unlocks()
	var time := 0.0
	var next_visit := 0.0
	var actions := []
	var construction_start := -1.0
	var construction_ready := -1.0
	while time<21600:
		if time+.000001>=next_visit:
			for row in g.planet_buildings.rows(g,"1"):
				if g.planet_buildings.state(g,"1",str(row.id)).get("status","")=="ready" and g.planet_buildings.activate(g,"1",str(row.id)):actions.append({"time":time,"action":"activate","building":row.id})
			if g.planet_progress("1").crewId.is_empty() and g.start_planet_exploration("1","navigator"):actions.append({"time":time,"action":"explore"})
			var shipyard:Dictionary=g.planet_buildings.state(g,"1","shipyard")
			if shipyard.get("status","")=="building" and shipyard.crew.is_empty() and g.planet_buildings.assign(g,"1","shipyard","engineer"):actions.append({"time":time,"action":"assign_builder"})
			next_visit=time+cadence
		g.advance_planets(1.0/60.0);time+=1.0/60.0
		var state:Dictionary=g.planet_buildings.state(g,"1","shipyard")
		if state.get("status","")=="building" and construction_start<0:construction_start=time
		if state.get("status","")=="ready" and construction_ready<0:construction_ready=time
		if g.can_reforge_planet("1"):break
	return {"scope":"controlled stage30 exploration fixture; no combat income or legal30 journey claim","cadence":cadence,"ready_for_reforge":g.can_reforge_planet("1"),"total_seconds":time,"construction_start":construction_start,"construction_ready":construction_ready,"construction_seconds":construction_ready-construction_start,"construction_share":(construction_ready-construction_start)/time,"actions":actions,"planet":g.planet_progress("1")}
func galaxy_case(count: int) -> Dictionary:
	var db:=ShipDatabase.new()
	var region=preload("res://scripts/galaxy_region.gd").new()
	region.setup(db.data.galaxy.galaxy_1,db.data.galaxy_build,32)
	region.state.status="exploring"
	var time := 0.0
	var built_time := -1.0
	while time<172800 and region.state.status!="complete":
		region.advance(10.0,count);time+=10.0
		if region.state.status=="developing" and built_time<0:built_time=time
	return {"scope":"controlled GalaxyRegion phase; bypasses unlock and crew economy","crew":count,"full_build_seconds":built_time,"all_max_seconds":time,"status":region.state.status,"slots":region.slots}
func _initialize() -> void:
	var results := {"data_sha256":FileAccess.get_sha256("res://data/game_data.json"),"engine":Engine.get_version_info(),"planet":[],"galaxy":[]}
	for cadence in [10.0,60.0,300.0]:
		var row=planet_case(cadence);results.planet.append(row);print("PLANET_PHASE ",cadence," total=",row.total_seconds," build=",row.construction_seconds," share=",row.construction_share)
	for count in [1,3,5,10]:
		var row=galaxy_case(count);results.galaxy.append(row);print("GALAXY_PHASE crew=",count," all_max=",row.all_max_seconds)
	var output:=FileAccess.open("res://.runtime/systems-evidence.json",FileAccess.WRITE);output.store_string(JSON.stringify(results,"\t"));output.close();quit()
