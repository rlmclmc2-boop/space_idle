extends SceneTree

class BlockedGame extends BattleGame:
	var reject_change:=false
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
	check(g.planets.install_snapshot(snapshot,g.db),"Current planet fixture installs");g.invalidate_stat_cache()
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
	check(g.progress_writer.acquire_owner(),"Acquire isolated real save writer")
	g.save_enabled = true
	g.save_progress()
	var restored := BattleGame.new(db, false)
	restored.load_progress()
	check(int(restored.planet_progress(id).degree) == 1 and str(restored.planet_progress(id).crewId) == "navigator" and is_equal_approx(float(restored.planet_progress(id).elapsed), 10.0), "Exploration progress survives save and load")
	g.advance_planets(g.planet_duration(id) - 10.0)
	check(int(g.crew.entry(g, "navigator").level) == 2, "Second reward uses current highest level and growth cost")
	check(g.assign_crew("navigator", "equipment_upgrade", "equipment"), "Completed crew can take assignment")
	db.levels[30].planetExpRatio=1.235
	check(is_equal_approx(g.planet_exp_reward(id),124),"Exploration preview rounds fractional reward")
	var emitted_reward := [-1.0]
	g.event.connect(func(kind, payload):
		if kind=="planet_changed" and payload.has("reward"):emitted_reward[0]=float(payload.reward))
	check(g.start_planet_exploration(id,"engineer"),"Idle crew starts integer reward check")
	g.advance_planets(g.planet_duration(id))
	check(g.crew.entry(g,"engineer").level==1 and is_equal_approx(g.crew.entry(g,"engineer").exp,24) and is_equal_approx(emitted_reward[0],124),"Credited and emitted experience match integer preview")
	construction_boundaries()
	print("PLANET: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func construction_boundaries() -> void:
	var db:=ShipDatabase.new()
	for gate in db.data.unlock.values():gate.level=0
	db.data.planet_build.station.unlock_explore=1;db.data.planet_build.station.build_explore=2
	db.data.planet_build.shipyard.unlock_explore=1;db.data.planet_build.shipyard.build_explore=2;db.data.planet_build.shipyard.extra_crew=1
	var g:=BlockedGame.new(db,false)
	var row: Dictionary=g.planet_buildings.rows(g,"1").filter(func(value):return value.type=="shipyard")[0]
	check(not g.profile.has("planets") and g.planets.all().is_read_only() and g.planet_progress("1").buildings.is_read_only(),"Planet owner exposes immutable state")
	check(g.start_planet_exploration("1","navigator"),"Dispatch first construction trip");g.advance_planets(g.planet_duration("1"))
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
	g.event.connect(observer);check(g.reforge_planet("1"),"Reforge commits permanent conquest and new run");g.event.disconnect(observer)
	check(observed.size()==1 and observed[0].planets["1"].conquered and observed[0].planets["1"].crewId=="navigator" and observed[0].planets["1"].elapsed==0.25 and observed[0].crew==crew_before.crew,"Reforge notification sees conquest, retained trip and all crew together")
	check(not g.reforge_planet("1"),"Conquest remains once per planet")
