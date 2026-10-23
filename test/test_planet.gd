extends SceneTree

class BlockedGame extends BattleGame:
	var reject_change:=false
	var captures:=0
	var configurations:=0
	func capture_refit_health()->void:
		captures+=1;super.capture_refit_health()
	func configuration_committed(native_updated:=false)->void:
		configurations+=1;super.configuration_committed(native_updated)
	func native_before_configuration_change() -> bool:
		return false if reject_change else super.native_before_configuration_change()
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(label)

func set_degree(g: BattleGame,id: String,value) -> void:
	var snapshot:=g.portable_save_data();snapshot.planets[id].degree=value
	check(g.planets.install_snapshot(snapshot,g.db),"Current planet fixture installs")
func _initialize() -> void:
	var db := ShipDatabase.new()
	# This scenario exercises the duration curve independently of live balance edits.
	db.data.planet["1"].baseTime = 100
	db.data.planet["1"].minTime = 5
	for index in range(29,34):db.levels[index].planetExpRatio=[1.0,1.2,1.44,1.73,2.08][index-29]
	db.config.offlineMax = 0
	var g := BattleGame.new(db, false)
	var id := "1"
	check(not g.planet_unlocked(id), "Planet locked before level 30 clear")
	check(not g.start_planet_exploration(id, "navigator"), "Locked planet rejects exploration")
	check(is_equal_approx(g.planet_duration(id), 100.0), "Initial exploration lasts 100 seconds")
	check(is_equal_approx(g.planet_equipment_multiplier(), 1.0), "Initial equipment multiplier")
	g.profile.cleared = range(1, 31)
	g.profile.highestLevel = 30
	check(g.planet_unlocked(id), "Level 30 clear unlocks planet")
	check(is_equal_approx(g.planet_exp_multiplier(), 1.0), "Level 30 experience coefficient")
	check(is_equal_approx(float(db.levels[31].planetExpRatio), 1.44), "Level 32 coefficient rounds to two decimals")
	check(is_equal_approx(float(db.levels[33].planetExpRatio), 2.08), "Each level grows from previous rounded coefficient")
	var weapon: Dictionary = g.weapon_entries()[0]
	var before = g.jewel_equipment_stat(weapon)
	var baseline := {}
	for key in ["laser", "cannon", "missile", "longLaser", "armour", "shield"]:
		baseline[key] = g.jewel_equipment_stat({"key":key, "level":1, "sockets":[]})
	check(g.start_planet_exploration(id, "navigator"), "Idle crew starts exploration")
	check(not g.assign_crew("navigator", "equipment_upgrade", "equipment"), "Exploring crew cannot take assignment")
	check(not g.start_planet_exploration(id, "engineer"), "Planet accepts only one crew")
	g.paused = true
	g.tick(99.0)
	check(is_equal_approx(float(g.planet_progress(id).elapsed), 0.0), "Pause freezes exploration")
	g.paused = false
	g.advance_planets(99.0)
	check(int(g.planet_progress(id).degree) == 0, "No early completion")
	g.advance_planets(1.0)
	check(int(g.planet_progress(id).degree) == 1 and str(g.planet_progress(id).crewId).is_empty(), "Completion releases crew and adds exploration")
	check(int(g.crew.entry(g, "navigator").level) == 1, "100 experience upgrades crew from level zero")
	check(is_equal_approx(g.planet_duration(id), 10000.0 / 101.0), "Duration uses squared base time")
	check(is_equal_approx(g.jewel_equipment_stat(weapon), before), "Exploration alone does not improve weapon")
	for key in baseline:
		check(is_equal_approx(g.jewel_equipment_stat({"key":key, "level":1, "sockets":[]}), float(baseline[key])), "No inherent exploration bonus on " + key)
	set_degree(g,id,4)
	check(is_equal_approx(g.planet_equipment_multiplier(), 1.0), "Degree alone grants no multiplier")
	set_degree(g,id,100000000)
	check(is_equal_approx(g.planet_duration(id), 5.0), "Duration floors at configured five seconds")
	check(is_equal_approx(preload("res://scripts/planet_state.gd").duration({"baseTime":100,"minTime":8},1e100),8.0),"Duration floor follows per-planet configuration")
	check(is_equal_approx(preload("res://scripts/planet_state.gd").duration({"baseTime":100},1e100),5.0),"Missing duration floor uses safe default")
	set_degree(g,id,1)
	g.profile.highestLevel = 31
	check(is_equal_approx(g.planet_exp_multiplier(), 1.2), "Next level experience coefficient")
	check(g.start_planet_exploration(id, "navigator"), "Crew can explore again")
	g.advance_planets(10.0)
	g.advance_planets(g.planet_duration(id) - 10.0)
	check(int(g.crew.entry(g, "navigator").level) == 2, "Second reward uses current highest level and growth cost")
	check(g.assign_crew("navigator", "equipment_upgrade", "equipment"), "Completed crew can take assignment")
	db.levels[30].planetExpRatio=1.235
	check(is_equal_approx(g.planet_exp_reward(id),124),"Exploration preview rounds fractional reward")
	var payout_views:Array=[]
	var emitted_reward := [-1.0]
	g.event.connect(func(kind, payload):
		if kind=="crew_changed" and payload.get("source","")=="planet":payout_views.append(g.portable_save_data())
		if kind=="planet_changed" and payload.has("reward"):emitted_reward[0]=float(payload.reward))
	check(g.start_planet_exploration(id,"engineer"),"Idle crew starts integer reward check")
	g.advance_planets(g.planet_duration(id))
	check(g.crew.entry(g,"engineer").level==1 and is_equal_approx(g.crew.entry(g,"engineer").exp,24) and is_equal_approx(emitted_reward[0],124),"Credited and emitted experience match integer preview")
	check(payout_views.size()==1 and payout_views[0].planets[id].crewId=="" and payout_views[0].crew==g.crew.save_data().crew,"Planet-sourced crew notification observes committed trip and entire experience payout")
	joint_payout_boundary()
	construction_boundaries()
	conquest_boundaries()
	print("PLANET: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func construction_boundaries() -> void:
	var db:=ShipDatabase.new()
	for gate in db.data.unlock.values():gate.level=0
	db.data.planet_build.station.unlock_explore=1;db.data.planet_build.station.build_explore=2
	db.data.planet_build.shipyard.unlock_explore=1;db.data.planet_build.shipyard.build_explore=2;db.data.planet_build.shipyard.extra_crew=1
	var g:=BlockedGame.new(db,false)
	g.profile.cleared=range(1,31);g.rebuild_unlocks()
	var row: Dictionary=g.planet_buildings.rows(g,"1").filter(func(value):return value.type=="shipyard")[0]
	check(not g.profile.has("planets") and g.planets.all().is_read_only() and g.planet_progress("1").buildings.is_read_only(),"Planet owner exposes immutable state")
	check(g.start_planet_exploration("1","navigator"),"Dispatch first construction trip")
	var unpaid_planet:=g.planets.save_data();var unpaid_crew:=g.crew.save_data()
	g.reject_change=true;g.advance_planets(g.planet_duration("1"))
	check(g.planets.save_data()==unpaid_planet and g.crew.save_data()==unpaid_crew,"Refused experience handoff commits neither completed trip nor crew growth")
	g.reject_change=false;g.advance_planets(g.planet_duration("1"))
	check(g.planet_buildings.state(g,"1","station").status=="building" and g.planet_buildings.state(g,"1","station").build_progress==0,"Threshold trip unlocks without backfilling construction")
	check(g.assign_planet_builder("1",str(row.id),"engineer"),"Assign builder through current game command")
	check(not g.start_planet_exploration("1","engineer") and not g.assign_crew("engineer","reactor_upgrade","reactor"),"Building occupation excludes other jobs")
	for i in 2:
		check(g.start_planet_exploration("1","navigator"),"Dispatch staffed construction trip");g.advance_planets(g.planet_duration("1"))
	check(g.planet_buildings.state(g,"1","station").status=="ready" and g.planet_buildings.state(g,"1",str(row.id)).status=="ready" and g.crew_exploration("engineer")=="","Ready buildings release builders without automatic activation")
	g.reject_change=true
	var before:=g.planets.save_data()
	check(not g.activate_planet_building("1","station") and g.planets.save_data()==before,"Failed native preparation preserves activation and auto preference")
	g.reject_change=false
	check(g.activate_planet_building("1","station") and g.planet_progress("1").auto_explore and g.planet_progress("1").crewId=="","Activation enables preference without silently dispatching")
	check(g.start_planet_exploration("1","navigator"),"Dispatch automatic trip");g.advance_planets(g.planet_duration("1"))
	check(g.planet_progress("1").crewId=="navigator","Automatic trip retains assigned explorer")
	check(g.set_planet_auto("1",false),"Turn auto off while trip is in flight");g.advance_planets(g.planet_duration("1"))
	check(g.planet_progress("1").crewId=="" and not g.planet_progress("1").auto_explore,"Current trip finishes and stops with the chosen preference")
	var stale:=g.planets.prepare_start(g,"1","navigator");g.start_planet_exploration("1","engineer")
	check(not g.planets.proposal_current(stale),"Intervening occupation invalidates prepared planet command")
	g.cancel_planet_exploration("1")
	check(g.activate_planet_building("1",str(row.id)),"Activate completed shipyard")
	g.start_planet_exploration("1","navigator");g.advance_planets(0.25)
	before=g.planets.save_data();var crew_before:=g.crew.save_data();var wallet_before:=g.economy.save_data()
	g.reject_change=true
	check(not g.reforge_planet("1") and g.planets.save_data()==before and g.crew.save_data()==crew_before and g.economy.save_data()==wallet_before,"Rejected reforge preparation leaves all growth and wallet state intact")
	g.reject_change=false
	var observed: Array=[]
	var observer:=func(kind,_payload):
		if kind=="planet_reforged":observed.append(g.portable_save_data())
	g.galaxy_runtime.native_prepared=true;g.hyperspace_runtime.advancing=true
	g.event.connect(observer);check(g.reforge_planet("1"),"Reforge commits permanent conquest and new run");g.event.disconnect(observer)
	check(observed.size()==1 and observed[0].planets["1"].conquered and observed[0].planets["1"].crewId=="navigator" and observed[0].planets["1"].elapsed==0.25 and observed[0].crew==crew_before.crew,"Reforge notification sees conquest, retained trip and all crew together")
	check(not g.galaxy_runtime.native_prepared and not g.hyperspace_runtime.advancing,"Reforge clears previous runtime predictions before deriving new schedules")
	check(not g.reforge_planet("1"),"Conquest remains once per planet")

func update_planet(g,id: String,fields: Dictionary) -> void:
	var snapshot: Dictionary=g.portable_save_data();snapshot.planets[id].merge(fields,true)
	check(g.planets.install_snapshot(snapshot,g.db),"Valid planet fixture installs")
func update_building(g,id: String,key: String,fields: Dictionary) -> void:
	var snapshot: Dictionary=g.portable_save_data();snapshot.planets[id].buildings[key].merge(fields,true)
	check(g.planets.install_snapshot(snapshot,g.db),"Valid building fixture installs")
func make_game(db):
	var g := BattleGame.new(db,false)
	g.profile.cleared = range(1,61)
	g.rebuild_unlocks()
	return g
func complete_shipyard(g, id: String) -> void:
	# Building identity is table-driven: later planets may migrate a legacy ID.
	for row in g.planet_buildings.rows(g,id):
		if str(row.type)=="shipyard":
			update_building(g,id,str(row.id),{"status":"built"})
			return
	check(false,"Configured shipyard exists for " + id)
func total_exp(g, member: Dictionary) -> float:
	var result := float(member.exp)
	for level in int(member.level):result += g.crew.required_exp(g,level)
	return result
func trip(g, id: String, member := "navigator") -> void:
	check(g.start_planet_exploration(id,member), "Dispatch " + id)
	g.advance_planets(g.planet_duration(id))
func conquest_boundaries() -> void:
	var db := ShipDatabase.new()
	var original := db.data.duplicate(true)
	# Shared XP must respect each crew's existing unlock gate, including future unlocks.
	var locked_id := "engineer"
	var locked_gate: String = db.data.crew[locked_id].unlockId
	var gate_before: Dictionary = db.data.unlock[locked_gate].duplicate(true)
	db.data.unlock[locked_gate].level=61
	db.data.unlock[locked_gate].mode="cleared"
	var shared = make_game(db)
	update_planet(shared,"1",{"conquered":true})
	var shared_reward: float = shared.planet_exp_reward("1")
	check(not shared.crew.unlocked(shared,locked_id),"Fixture includes a locked crew")
	check(not shared.add_crew_exp(locked_id,shared_reward),"Direct XP also rejects locked crew")
	trip(shared,"1")
	for member in shared.crew.members():
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
		# Later planets are unlocked by prior conquest, not just combat stage.
		for previous in range(1,index+1):update_planet(g,str(previous),{"conquered":true})
		g.rebuild_unlocks()
		var start := int(db.data.planet[id].reforgeStartLevel)
		check(g.planet_reforge_start(id)==start, "Configured initial start " + id)
		var amount: float = g.planet_exp_reward(id)
		trip(g,id)
		for member in g.crew.members():
			check(is_equal_approx(total_exp(g,member),amount if member.crewId=="navigator" else 0.0), "Before conquest explorer only " + str(member.crewId))
		complete_shipyard(g,id)
		update_planet(g,id,{"auto_explore":true})
		var historical: int = g.profile.highestLevel
		var multiplier: float = g.planet_exp_multiplier()
		var resources: Dictionary = g.economy.resources().duplicate()
		var old_unlocks: Array = g.available_unlocks()
		check(g.reforge_planet(id), "Conquest " + id)
		check(g.stage==start and g.profile.highestLevel==g.stage and g.profile.cleared==range(1,g.stage), "Starts at table stage, earlier stages skipped")
		check(g.economy.resources()==resources, "Skipped stages grant no resources")
		check(g.profile.lifetime_max_stage==historical and g.planet_exp_multiplier()==multiplier, "Historical XP retained")
		check(g.planet_progress(id).auto_explore and g.planet_progress(id).crewId=="", "Reforge retains auto preference without dispatch")
		check(g.pending_unlocks.is_empty(), "Reforge has no repeated notices")
		for gate in old_unlocks:
			check(g.profile.seenUnlocks.has(gate), "Old notice history retained " + gate)
			if int(db.data.unlock[gate].level)<=g.stage:check(g.unlock_available(gate), "Old starting-stage unlock restored " + gate)
		var before := {}
		for member in g.crew.members():before[member.crewId]=total_exp(g,member)
		trip(g,id)
		for member in g.crew.members():
			var expected: float = amount if g.crew.unlocked(g,member.crewId) else 0.0
			check(is_equal_approx(total_exp(g,member)-before[member.crewId],expected), "Conquest pays unlocked crew exactly once " + str(member.crewId))
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
	complete_shipyard(g,"1")
	db.data.planet["1"].reforgeStartLevel=17
	check(g.reforge_planet("1") and g.stage==17, "Edited start table value controls runtime")
	var first_peak: int=g.profile.lifetime_max_stage
	complete_shipyard(g,"2")
	check(g.reforge_planet("2") and g.profile.lifetime_max_stage==first_peak, "Repeated reforge never lowers historical peak")
	g.profile.cleared=range(1,64)
	g.rebuild_unlocks()
	check(g.profile.lifetime_max_stage==64 and g.planet_exp_multiplier()==float(db.levels[63].planetExpRatio), "New best stage raises historical XP")
	# Current format must reject an incomplete progression snapshot intact.
	var raw: Dictionary=g.portable_save_data();raw.erase("lifetime_max_stage")
	var before_crew: Dictionary=g.crew.save_data();var before_planets: Dictionary=g.planets.save_data()
	g.load_progress_data(raw)
	check(g.crew.save_data()==before_crew and g.planets.save_data()==before_planets and not g.hyperspace.last_error.is_empty(),"Incomplete save cannot reset permanent conquest or crew")
	db.data=original

func joint_payout_boundary()->void:
	var g:=BlockedGame.new(ShipDatabase.new(),false)
	g.profile.cleared=range(1,61);g.rebuild_unlocks()
	update_planet(g,"1",{"conquered":true})
	for row in g.planet_buildings.rows(g,"1"):
		if str(row.type)=="equipment":update_building(g,"1",str(row.id),{"status":"built"})
	check(g.assign_crew("engineer","reactor_upgrade","reactor"),"Joint payout includes staffed reactor contribution")
	check(g.start_planet_exploration("1","navigator"),"Joint payout starts real exploration")
	g.player.armour=GrowthNumber.multiply(g.stat("armour"),0.4)
	g.captures=0;g.configurations=0
	var views:Array=[]
	g.event.connect(func(kind,info):
		if kind=="crew_changed" and info.get("source","")=="planet":views.append([g.planet_progress("1").degree,g.crew.entry(g,"engineer").level,GrowthNumber.ratio(g.player.armour,g.stat("armour")),g.reactor_capacity(),g.reactor_allocated()]))
	g.advance_planets(g.planet_duration("1"))
	check(g.captures==1 and g.configurations==1,"Joint planet and crew commit captures health and updates configuration exactly once")
	check(not views.is_empty() and views.all(func(view):return view[0]==1 and view[1]>0 and absf(view[2]-0.4)<0.000001 and GrowthNumber.compare(view[4],view[3])<=0),"Every payout notice sees final crew, planet, capacity and preserved health ratio")
