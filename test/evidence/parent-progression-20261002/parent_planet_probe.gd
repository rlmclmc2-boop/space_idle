extends SceneTree

func _initialize() -> void:call_deferred("run")

func simulate(interval: float) -> Dictionary:
	var g := BattleGame.new(ShipDatabase.new(),false)
	g.stat_cache_enabled=true
	g.profile.cleared=range(1,31)
	g.profile.highestLevel=31
	g.stage=31
	g.rebuild_unlocks()
	var t:=0.0
	var next_action:=0.0
	var action_count:=0
	var states: Dictionary={}
	var milestones: Array=[]
	var last: Dictionary={}
	while t<24000.0 and not g.can_reforge_planet("1"):
		if t+0.00001>=next_action:
			for row in g.planet_buildings.rows(g,"1"):
				var s: Dictionary=g.planet_buildings.state(g,"1",str(row.id))
				if s.get("status","")=="ready" and g.planet_buildings.activate(g,"1",str(row.id)):action_count+=1
				if s.get("status","")=="building" and int(row.extra_crew)>s.get("crew",[]).size():
					for member in g.profile.crew:
						var id: String=str(member.crewId)
						if id!="navigator" and g.idle_planet_crew(id):
							if g.planet_buildings.assign(g,"1",str(row.id),id):action_count+=1
							break
			if str(g.planet_progress("1").crewId).is_empty() and g.start_planet_exploration("1","navigator"):action_count+=1
			next_action=t+interval
		g.advance_planets(1.0/60.0)
		t+=1.0/60.0
		if int(round(t*60.0))%60==0:
			for row in g.planet_buildings.rows(g,"1"):
				var status: String=str(g.planet_buildings.state(g,"1",str(row.id)).get("status",""))
				if last.get(str(row.id),"")!=status:
					last[str(row.id)]=status
					milestones.append({"time":t,"building":row.id,"status":status,"degree":g.planet_progress("1").degree})
	return {"decision_interval":interval,"game_seconds":t,"can_reforge":g.can_reforge_planet("1"),"actions":action_count,"degree":g.planet_progress("1").degree,"milestones":milestones,"buildings":g.planet_progress("1").buildings}

func run() -> void:
	var result: Array=[]
	for interval in [10.0,60.0,300.0]:
		var r:=simulate(interval)
		result.append(r)
		print("PARENT_PLANET ",JSON.stringify(r))
	FileAccess.open("res://.runtime/parent-planet-stage.json",FileAccess.WRITE).store_string(JSON.stringify({"source_commit":"04a5a307bcef9325efa9026e1ca94affa577e10d","scope":"controlled fresh first planet at granted clears1–30, existing config, two available crew reserved, direct exact planet advance only; not whole-game elapsed proof","runs":result},"\t"))
	quit(0)
