extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:failures += 1;printerr(label)
func make_game(db):
	var g := BattleGame.new(db,false)
	g.profile.cleared = range(1,61)
	g.rebuild_unlocks()
	return g
func total_exp(g, member: Dictionary) -> float:
	var result := float(member.exp)
	for level in int(member.level):result += g.crew.required_exp(g,level)
	return result
func trip(g, id: String, member := "navigator") -> void:
	check(g.start_planet_exploration(id,member), "Dispatch " + id)
	g.advance_planets(g.planet_duration(id))
func _initialize() -> void:
	var db := ShipDatabase.new()
	var original := db.data.duplicate(true)
	# Shared XP must respect each crew's existing unlock gate, including future unlocks.
	var locked_id := "engineer"
	var locked_gate: String = db.data.crew[locked_id].unlockId
	var gate_before: Dictionary = db.data.unlock[locked_gate].duplicate(true)
	db.data.unlock[locked_gate].level=61
	db.data.unlock[locked_gate].mode="cleared"
	var shared = make_game(db)
	shared.profile.planets["1"].conquered=true
	var shared_reward: float = shared.planet_exp_reward("1")
	check(not shared.crew.unlocked(shared,locked_id),"Fixture includes a locked crew")
	check(not shared.add_crew_exp(locked_id,shared_reward),"Direct XP also rejects locked crew")
	trip(shared,"1")
	for member in shared.profile.crew:
		var expected: float = shared_reward if shared.crew.unlocked(shared,member.crewId) else 0.0
		check(is_equal_approx(total_exp(shared,member),expected),"Sharing pays unlocked crew only, once: "+str(member.crewId))
	shared.profile.cleared.append(61)
	check(shared.crew.unlocked(shared,locked_id),"Existing unlock system unlocks crew")
	trip(shared,"1")
	check(is_equal_approx(total_exp(shared,shared.crew.entry(shared,locked_id)),shared_reward),"Newly unlocked crew receives next trip only, with no backfill")
	db.data.unlock[locked_gate]=gate_before
	for index in 6:
		var id := str(index+1)
		var g = make_game(db)
		check(g.planet_reforge_start(id)==(index+1)*5, "Configured initial start " + id)
		var amount: float = g.planet_exp_reward(id)
		trip(g,id)
		for member in g.profile.crew:
			check(is_equal_approx(total_exp(g,member),amount if member.crewId=="navigator" else 0.0), "Before conquest explorer only " + str(member.crewId))
		g.profile.planets[id].buildings.shipyard.status = "built"
		g.profile.planets[id].auto_explore = true
		var historical: int = g.profile.highestLevel
		var multiplier: float = g.planet_exp_multiplier()
		var resources: Dictionary = g.profile.resources.duplicate()
		var old_unlocks: Array = g.available_unlocks()
		check(g.reforge_planet(id), "Conquest " + id)
		check(g.stage==(index+1)*5 and g.profile.highestLevel==g.stage and g.profile.cleared==range(1,g.stage), "Starts at table stage, earlier stages skipped")
		check(g.profile.resources==resources, "Skipped stages grant no resources")
		check(g.profile.lifetime_max_stage==historical and g.planet_exp_multiplier()==multiplier, "Historical XP retained")
		check(g.planet_progress(id).auto_explore and g.planet_progress(id).crewId=="", "Reforge retains auto preference without dispatch")
		check(g.pending_unlocks.is_empty(), "Reforge has no repeated notices")
		for gate in old_unlocks:
			check(g.profile.seenUnlocks.has(gate), "Old notice history retained " + gate)
			if int(db.data.unlock[gate].level)<=g.stage:check(g.unlock_available(gate), "Old starting-stage unlock restored " + gate)
		var before := {}
		for member in g.profile.crew:before[member.crewId]=total_exp(g,member)
		trip(g,id)
		for member in g.profile.crew:
			var expected: float = amount if g.crew.unlocked(g,member.crewId) else 0.0
			check(is_equal_approx(total_exp(g,member)-before[member.crewId],expected), "Conquest pays unlocked crew exactly once " + str(member.crewId))
		g.save_enabled = true
		g.save_progress()
		var restored := BattleGame.new(db,false)
		restored.load_progress()
		restored.resume_progress()
		check(restored.stage==g.stage and restored.planet_exp_multiplier()==multiplier, "Starting stage and historical XP survive reload")
		check(restored.profile.seenUnlocks==g.profile.seenUnlocks, "Notification history survives reload")
		for member in restored.profile.crew:check(is_equal_approx(total_exp(restored,member),total_exp(g,g.crew.entry(g,member.crewId))), "No offline XP catch-up")
		# Previously granted later unlocks activate again, silently.
		for stage in range(g.stage,61):
			g.stage=stage
			g.clear_level()
		check(g.pending_unlocks.is_empty(), "All previously experienced unlocks remain silent after reforge")
	# First-time unlocks still notify and acknowledge one page at a time.
	var g = make_game(db)
	db.data.unlock["test_future"]={"name":"test_future","type":"equipment","target":"laser","level":61,"mode":"cleared","title":"future","desc":"future"}
	g.stage=61
	g.clear_level()
	check(g.pending_unlocks.has("test_future"), "New unlock still notifies")
	while not g.pending_unlocks.is_empty():g.acknowledge_unlocks()
	check(g.profile.seenUnlocks.has("test_future"), "Acknowledgement stores permanent history")
	g.profile.planets["1"].buildings.shipyard.status="built"
	db.data.planet["1"].reforgeStartLevel=17
	check(g.reforge_planet("1") and g.stage==17, "Edited start table value controls runtime")
	var first_peak: int=g.profile.lifetime_max_stage
	g.profile.planets["2"].buildings.shipyard.status="built"
	check(g.reforge_planet("2") and g.profile.lifetime_max_stage==first_peak, "Repeated reforge never lowers historical peak")
	g.profile.cleared=range(1,64)
	g.rebuild_unlocks()
	check(g.profile.lifetime_max_stage==64 and g.planet_exp_multiplier()==float(db.levels[63].planetExpRatio), "New best stage raises historical XP")
	# Legacy migration uses saved highest stage while preserving pending first notices.
	var raw = g.profile.duplicate(true)
	raw.erase("seenUnlocks")
	raw.erase("lifetime_max_stage")
	raw.journey={"stage":63,"groupIndex":db.levels[62].groups.size(),"distance":0,"state":int(BattleGame.State.LEVEL_CLEAR),"pendingUnlocks":["test_future"]}
	var f=FileAccess.open(BattleGame.SAVE_PATH,FileAccess.WRITE)
	f.store_string(JSON.stringify(raw));f.close()
	var legacy := BattleGame.new(db,false)
	legacy.load_progress()
	check(legacy.profile.lifetime_max_stage==64, "Legacy peak migrates from saved highest stage")
	check(not legacy.profile.seenUnlocks.has("test_future"), "Legacy pending notice excluded from experienced history")
	legacy.resume_progress()
	check(legacy.pending_unlocks.has("test_future"), "Legacy pending first notice is not dropped")
	legacy.acknowledge_unlocks()
	check(legacy.profile.seenUnlocks.has("test_future"), "Legacy notice acknowledgement recorded")
	db.data=original
	print("CONQUEST PROGRESS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
