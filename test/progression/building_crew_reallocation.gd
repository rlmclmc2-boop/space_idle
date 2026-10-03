extends SceneTree
const Game=preload("res://scripts/balance_game.gd")
const Policy=preload("res://qa/sparse_policy.gd")
func _initialize()->void:call_deferred("run")
func run()->void:
	var g=Game.new(ShipDatabase.new());g.save_enabled=false
	g.metrics=preload("res://scripts/balance_metrics.gd").new();g.metrics.initialize(g)
	g.profile.cleared=range(1,36);g.profile.highestLevel=36;g.stage=35
	g.profile.planets["1"].conquered=true
	g.rebuild_unlocks()
	var shipyard:=""
	for id in ["1","2"]:
		g.profile.planets[id].degree=180 if id=="1" else 150
		g.planet_buildings.sync(g,id)
		for row in g.planet_buildings.rows(g,id):
			var state:Dictionary=g.planet_buildings.state(g,id,str(row.id))
			state.status="built";state.crew=[]
			if id=="2" and row.type=="shipyard":shipyard=str(row.id);state.status="building";state.build_progress=0
		assert(g.set_planet_auto(id,true))
	assert(not shipyard.is_empty())
	assert(g.start_planet_exploration("1","navigator"))
	g.profile.planets["1"].elapsed=17.0
	var needs_explorer:bool=OS.get_environment("PROGRESSION_NEEDS_EXPLORER")=="1"
	if needs_explorer:assert(g.assign_crew("engineer","jewel_auto","jewels"))
	else:assert(g.start_planet_exploration("2","engineer"))
	for pair in [["researcher","hightech_scientists","hightech"],["crew_04","equipment_upgrade","equipment"],["crew_05","reactor_upgrade","reactor"]]:assert(g.assign_crew(pair[0],pair[1],pair[2]))
	for member in g.profile.crew:assert(not g.idle_planet_crew(str(member.crewId)))
	var count_before:int=g.profile.crew.size()
	var unlocked_before:int=g.profile.crew.filter(func(member):return g.crew.unlocked(g,str(member.crewId))).size()
	var events:Array=[]
	var policy=Policy.new();policy.allow_reforge=false;policy.configure("BALANCED",20261004)
	policy.journal=func(kind,extra):events.append({"kind":kind,"extra":extra.duplicate(true)})
	policy.act(g,0)
	var assigned:bool=g.planet_buildings.state(g,"2",shipyard).crew.has("engineer" if needs_explorer else "navigator")
	var expect:bool=OS.get_environment("PROGRESSION_EXPECT_REALLOCATION")!="0"
	assert(assigned==expect)
	assert(g.profile.crew.size()==count_before)
	assert(g.profile.planets["2"].crewId==("navigator" if needs_explorer and expect else "" if needs_explorer else "engineer"))
	if expect:
		assert(g.profile.planets["1"].crewId.is_empty() and g.profile.planets["1"].elapsed==0)
		assert(events.any(func(row):return row.kind.begins_with("recall_conquered_for_") and row.extra.forfeited_trip_seconds==17.0))
		if needs_explorer:assert(events.any(func(row):return row.kind=="reassign_growth_for_preparation" and row.extra.previous.assignmentType=="jewel_auto"))
	else:assert(g.profile.planets["1"].crewId=="navigator")
	var old_degree=g.profile.planets["1"].degree
	g.advance_planets(60.0)
	assert(g.N.compare(g.profile.planets["1"].degree,old_degree)==(0 if expect else 1))
	assert((g.N.compare(g.planet_buildings.state(g,"2",shipyard).build_progress,0)>0)==expect)
	var output={"pass":true,"scope":"Controlled five-unlocked-crew35 fixture, public actions at one actual visit; no legal fresh timing claim. Partial17s old trip is lost and continuing old planet exploration stops; optional growth worker transfer stops jewel automation. No extra crew/resources created.","policy":policy.VERSION,"expected_reallocation":expect,"needs_explorer":needs_explorer,"profile_crew_count":count_before,"unlocked_crew_count":unlocked_before,"assigned":assigned,"old_planet":g.profile.planets["1"],"new_building":g.planet_buildings.state(g,"2",shipyard),"events":events}
	var result_dir:=OS.get_environment("QA_DIAGNOSTIC_RESULT_DIR")
	var path:="res://.runtime/building-crew-reallocation.json" if result_dir.is_empty() else result_dir.path_join("building-crew-reallocation.json")
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(output,"\t"))
	print("BUILDING_CREW_REALLOCATION_PASS assigned=",assigned," unlocked_crew=",unlocked_before);quit()
