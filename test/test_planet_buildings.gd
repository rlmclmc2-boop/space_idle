extends SceneTree
const N = preload("res://scripts/growth_number.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr(label)

func trip(g, id := "1", member := "navigator") -> void:
	if str(g.planet_progress(id).crewId).is_empty():check(g.start_planet_exploration(id,member),"Dispatch succeeds")
	g.advance_planets(g.planet_duration(id))

func _initialize() -> void:
	var db := ShipDatabase.new()
	# Fixed construction boundary for this scenario; live table balance is editable.
	db.data.planet_build.station.unlock_explore=10
	db.data.planet_build.station.build_explore=5
	var g := BattleGame.new(db,false)
	var b=g.planet_buildings
	g.profile.cleared=range(1,41)
	g.rebuild_unlocks()
	check(db.data.planet["1"].id==1 and not db.data.planet.has("first"),"Numeric planet identity")
	check(b.preview(g,"1").id=="station","First preview uses order")
	g.profile.planets["1"].degree=9
	trip(g)
	check(b.state(g,"1","station").status=="building" and b.state(g,"1","station").build_progress==0,"Threshold trip never backfills construction")
	check(b.preview(g,"1").id=="refinery","Next preview advances immediately at unlock")
	for i in 5:trip(g)
	check(b.state(g,"1","station").status=="ready" and not b.built(g,"1","auto_explore"),"Five later trips finish station without enabling it")
	check(b.activate(g,"1","station"),"Player activates completed station")
	check(g.planet_progress("1").auto_explore and g.planet_progress("1").crewId=="","Station activation enables auto without silently dispatching crew")
	check(g.set_planet_auto("1",true),"Station enables automatic exploration")
	trip(g)
	check(g.planet_progress("1").crewId=="navigator","Automatic trip retains normal explorer")
	check(not g.start_planet_exploration("1","engineer"),"Duplicate start rejected")
	g.set_planet_auto("1",false)
	b.sync(g,"1")
	check(not g.planet_progress("1").auto_explore,"Repeated sync preserves manual auto-off")
	trip(g)
	check(g.planet_progress("1").crewId=="","Turning auto off finishes current trip then stops")
	check(g.start_planet_exploration("1","engineer"),"Replacement can start while auto is off")
	g.cancel_planet_exploration("1")
	check(not g.planet_progress("1").auto_explore,"Crew replacement and recall also retain manual off")
	g.set_planet_auto("1",true)
	g.start_planet_exploration("1","navigator")
	g.cancel_planet_exploration("1")
	check(g.planet_progress("1").auto_explore and g.planet_progress("1").elapsed==0 and g.planet_progress("1").crewId=="","Recall clears assignment and timer but retains auto preference")
	var recalled_degree=g.planet_progress("1").degree
	g.advance_planets(1000)
	check(g.planet_progress("1").degree==recalled_degree,"Enabled auto without a crew never runs a trip")
	check(g.start_planet_exploration("1","engineer"),"Replacement crew can start exploration")
	trip(g,"1","engineer")
	check(g.planet_progress("1").crewId=="engineer" and g.planet_progress("1").auto_explore,"Replacement crew inherits enabled auto")
	g.cancel_planet_exploration("1")
	var recalled=g.profile.planets.duplicate(true)
	g.load_planets(recalled)
	check(g.planet_progress("1").auto_explore and g.planet_progress("1").crewId=="","Unassigned enabled preference survives load")
	var suspended=recalled.duplicate(true)
	suspended["1"].buildings.station.status="locked"
	suspended["1"].buildings.station.build_progress=0
	g.load_planets(suspended)
	check(g.planet_progress("1").auto_explore,"Temporarily unavailable facility does not erase preference")
	g.load_planets(recalled)
	g.profile.planets["1"].degree=300
	b.sync(g,"1")
	check(b.preview(g,"1").is_empty(),"No preview after all applicable buildings unlock")
	var before: float=g.jewel_equipment_stat(g.weapon_entries()[0])
	check(g.planet_equipment_multiplier()==1,"Exploration has no inherent equipment bonus")
	trip(g)
	check(b.state(g,"1","shipyard").build_progress==0,"Shipyard needs additional crew")
	check(b.assign(g,"1","shipyard","engineer"),"Construction crew independent assignment")
	check(b.assign(g,"1","shipyard","engineer") and g.crew_exploration("engineer")=="","Construction crew can withdraw")
	check(b.assign(g,"1","shipyard","engineer"),"Construction crew can rejoin")
	check(not g.start_planet_exploration("1","engineer"),"Builder cannot explore")
	check(not g.assign_crew("engineer","equipment_upgrade","equipment"),"Builder cannot take another job")
	for i in 9:trip(g)
	check(b.activate(g,"1","workshop") and b.activate(g,"1","refinery"),"Workshop and refinery count only post-unlock trips")
	check(b.state(g,"1","shipyard").build_progress==9,"Only staffed trips advance shipyard")
	check(is_equal_approx(g.jewel_equipment_stat(g.weapon_entries()[0]),before*pow(1+.1*310,.8)),"Equipment uses current degree through shared multiplier")
	for key in ["laser","missile","cannon","longLaser","armour","shield"]:
		check(is_equal_approx(g.jewel_equipment_stat({"key":key,"level":1}),g.equipment_stat(key,1)*pow(1+.1*310,.8)),"Shared workshop layer: "+key)
	trip(g)
	check(not g.can_reforge_planet("1") and g.crew_exploration("engineer")=="","Completed shipyard releases crew but requires activation")
	check(b.activate(g,"1","shipyard") and g.can_reforge_planet("1"),"Activated shipyard allows reforge")
	# Rules independently filter each planet before ordering.
	db.data.planet["10"]=db.data.planet["1"].duplicate(true)
	db.data.planet["10"].id=10
	db.data.planet["10"].tags="ice,ancient"
	var gate_buff: Dictionary = db.data.planet_buff["1"].duplicate(true)
	gate_buff.id=999;gate_buff.buff_type="planet_unlock";gate_buff.target="planet";gate_buff.value=10;gate_buff.stack="max"
	db.data.planet_buff["999"]=gate_buff
	g.load_planets(g.profile.planets.duplicate(true))
	db.data.planet_build.shipyard.min_planet=10
	db.data.planet_build.shipyard.planet_rule="tag"
	db.data.planet_build.shipyard.planet_value="ancient"
	check(not b.rows(g,"1").any(func(row):return row.id=="shipyard") and b.rows(g,"10").any(func(row):return row.id=="shipyard"),"Minimum and tag rules intersect")
	db.data.planet_build.shipyard.planet_rule="only"
	db.data.planet_build.shipyard.planet_value="1,10"
	check(not b.rows(g,"1").any(func(row):return row.id=="shipyard"),"Only never bypasses minimum")
	db.data.planet_build.shipyard.planet_rule="exclude"
	db.data.planet_build.shipyard.planet_value="10"
	check(not b.rows(g,"10").any(func(row):return row.id=="shipyard"),"Exclude rule")
	db.data.planet_build.shipyard.min_planet=1
	db.data.planet_build.shipyard.planet_rule="all"
	db.data.planet_build.shipyard.planet_value=""
	db.data.planet_build.workshop.order=0
	check(b.preview(g,"10").id=="workshop","Preview follows order instead of thresholds")
	db.data.planet_build.workshop.order=3
	# Save v2 migration with an active exploration and arbitrary permanent data.
	var legacy=g.profile.duplicate(true)
	legacy.version=2
	legacy.planets={"first":g.planet_progress("1").duplicate(true)}
	legacy.planets.first.crewId="navigator"
	legacy.planets.first.elapsed=.5
	legacy.planets.first.permanentMarker=73
	legacy.grantedUnlocks.append("planet/first")
	var file=FileAccess.open(BattleGame.SAVE_PATH,FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy));file.close()
	var restored=BattleGame.new(db,false)
	restored.load_progress()
	check(restored.planet_progress("1").degree==311 and restored.planet_progress("1").crewId=="navigator" and restored.planet_progress("1").permanentMarker==73,"Legacy ID migration preserves active trip and permanent fields")
	check(not restored.profile.planets.has("first") and restored.planet_unlocked("1"),"Legacy keys removed; unlock retained")
	restored.set_planet_auto("1",true)
	restored.save_enabled=true;restored.save_progress()
	var resumed=BattleGame.new(db,false);resumed.load_progress()
	var old_degree=resumed.planet_progress("1").degree
	check(resumed.planet_progress("1").auto_explore and resumed.planet_progress("1").elapsed==.5,"Read restores one timer with no offline completion")
	trip(resumed)
	check(resumed.planet_progress("1").degree==old_degree+1 and resumed.planet_progress("1").crewId=="navigator","Read resumes exactly one automatic trip")
	# Reforge validates once, clears all reset systems, preserves every planet.
	g.profile.hightechLevels[BattleGame.FURNACE]=5
	g.profile.reactorLevel=8
	g.profile.jewels=[{"id":"1","level":3}]
	g.profile.chronoParticles=50
	g.profile.planets["1"].crewId="navigator"
	g.profile.planets["1"].elapsed=12.0
	var permanent=g.profile.planets.duplicate(true)
	var crew_before=g.profile.crew.duplicate(true)
	check(g.reforge_planet("1"),"Shipyard reforges once")
	for planet_id in permanent:
		check(g.planet_progress(planet_id).auto_explore==permanent[planet_id].auto_explore,"Reforge retains each planet auto preference")
	check(g.stage==g.planet_reforge_start("1") and g.profile.highestLevel==g.stage and g.profile.cleared==range(1,g.stage),"Reforge resets run to configured start stage")
	check(g.profile.jewels.is_empty() and g.profile.hightechLevels.is_empty() and g.profile.chronoParticles==50 and g.profile.reactorLevel==int(db.config.reactorInitialLevel),"Reset run systems while preserving chrono reserve")
	for feature in ["jewels","reactor"]:
		var gate=db.data.unlock[db.unlock_id("feature",feature)]
		check(g.content_unlocked("feature",feature)==(int(gate.level)<=g.stage),"Reset systems follow configured start stage")
	check(g.planet_progress("1").conquered and not g.reforge_planet("1") and g.profile.crew==crew_before,"Conquest is one-use and crew remains permanent")
	check(g.planet_progress("1").degree==permanent["1"].degree and g.planet_progress("1").buildings==permanent["1"].buildings and g.planet_progress("1").crewId=="navigator" and is_equal_approx(float(g.planet_progress("1").elapsed),12.0) and g.planet_unlocked("1"),"Planet construction, active exploration and unlock survive reset")
	g.profile.planets["10"].degree=400
	b.sync(g,"10")
	g.profile.planets["10"].buildings.shipyard.status="built"
	check(g.can_reforge_planet("10") and g.reforge_planet("10") and g.planet_progress("1").conquered,"Different planets each permit one independent reforge")
	# Several factories beyond IEEE exponent range, including combat and save/load.
	for id in ["1","10"]:
		g.profile.planets[id].degree=1e250
		b.sync(g,id)
		for kind in ["workshop","refinery"]:g.profile.planets[id].buildings[kind].status="built"
	var mult=g.planet_equipment_multiplier()
	check(N.valid(mult) and N.logarithm(mult)>390,"Multiple planets multiply beyond float range without a cap")
	g.invalidate_stat_cache();g.reset_player()
	var maximum=g.stat("armour")
	check(N.valid(maximum) and maximum is Dictionary,"Huge defense remains representable")
	g.profile.loadout.defence[0].sockets=[{"id":"2","level":1}]
	g.invalidate_stat_cache();g.reset_player()
	g.hit_player(100,1)
	g.advance_jewel_repair(1.0)
	check(N.valid(g.player.armour),"Huge defense accepts ordinary damage")
	g.capture_refit_health();g.apply_refit_health()
	check(N.valid(g.player.armour),"Refit preserves huge health without float casts")
	var enemy={"uid":987,"x":100.0,"y":100.0,"hp":10.0,"max_hp":10.0,"armourType":1,"slot":0,"res_ratio":1.0,"drops":[{"resourceId":1,"amount":10,"chance":1.0},{"resourceId":2,"amount":5,"chance":1.0}]}
	g.enemies=[enemy]
	g.hit_enemy(enemy,g.jewel_attack(0).damage,1)
	check(enemy.hp==0 and g.drops.size()==2,"Huge weapon kills and produces both direct drops")
	var expected_production=0.0
	for drop in g.drops.duplicate():
		if str(drop.id)=="1":expected_production+=float(drop.production_base)
		g.collect(drop,true)
	check(N.logarithm(g.profile.resources["1"])>390 and N.logarithm(g.profile.resources["2"])>390,"Both resources retain huge direct drops")
	check(is_equal_approx(g.furnace_income_peak(),expected_production),"Refinery cannot feed enhanced amount into building production")
	g.profile.resources["1"]=0.0
	var produced={"id":"1","amount":7.0,"age":10.0,"hightech":true}
	g.drops.append(produced);g.collect(produced,true)
	check(g.profile.resources["1"]==7.0,"Building production receives no refinery multiplier")
	g.profile.resources["1"]=N.multiply(mult,10)
	var start_us:=Time.get_ticks_usec()
	for i in 100:
		check(N.valid(g.planet_equipment_multiplier()),"Large multiplier stays finite")
	check(Time.get_ticks_usec()-start_us<1000000,"Large multipliers require no growth-sized loop")
	var prior=g.planet_equipment_multiplier()
	g.profile.planets["1"].degree={"m":1.0,"e":600.0}
	check(N.compare(g.planet_equipment_multiplier(),prior)>0 and g.planet_duration("1")==float(g.planet_row("1").minTime),"Exploration beyond float range respects configured duration floor and grows effect")
	check(not NumberFormat.compact(mult).contains("inf") and not NumberFormat.damage(mult).contains("nan"),"Huge numbers render scientific text")
	g.save_enabled=true;g.save_progress()
	var saved=BattleGame.new(db,false);saved.load_progress()
	check(is_equal_approx(N.ratio(saved.profile.resources["1"],g.profile.resources["1"]),1.0) and saved.planet_progress("1").conquered,"Extended quantities and conquest survive save")
	print("PLANET BUILDINGS: %d checks, %d failures" % [checks,failures])
	quit(failures)
