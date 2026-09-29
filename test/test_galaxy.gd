extends SceneTree
const Region=preload("res://scripts/galaxy_region.gd")
var failures := 0
var checks := 0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr(label)
func fixture(db, width := 20, count := 4):
	var row: Dictionary=db.data.galaxy.galaxy_1.duplicate(true)
	row.merge({"map_w":width,"map_h":width,"start_w":2,"start_h":2,"building_slot_count":count,"explore_work_total":100.0,"explore_power_base":1.0,"explore_power_per_crew":1.0,"build_interval":2.0,"construction_time":2.0,"upgrade_power_base":1.0,"upgrade_power_per_crew":1.0,"upgrade_cost_lv2":4.0,"upgrade_cost_lv3":4.0,"upgrade_cost_lv4":4.0,"upgrade_cost_lv5":4.0,"concurrent_upgrade_count":2},true)
	var r=Region.new()
	r.setup(row,db.data.galaxy_build,8)
	r.state.status="exploring"
	return r
func _initialize() -> void:
	var db := ShipDatabase.new()
	var g := BattleGame.new(db,false)
	var r=g.galaxy.regions.galaxy_1
	check(r.cells.size()==40000 and r.owned_count==100 and r.slots.size()==30,"Compact map and independent 30 slots")
	g.profile.cleared=range(1,61)
	for id in ["1","2","3","4","5"]:g.profile.planets[id].conquered=true
	g.galaxy.refresh_unlocks(g)
	check(not g.galaxy.available(),"Five planets remain locked")
	g.profile.planets['6'].conquered=true
	g.rebuild_unlocks()
	g.galaxy.refresh_unlocks(g)
	check(r.state.status=="available","Level60 plus six planets unlock")
	var gated := BattleGame.new(db,false)
	for p in gated.profile.planets.values():p.conquered=true
	gated.galaxy.refresh_unlocks(gated)
	check(not gated.galaxy.available(),"Level60 gate retained")
	check(g.assign_crew("navigator","galaxy_explore","galaxy_1") and r.state.status=="exploring","Existing crew starts Galaxy")
	for i in r.slots.size():
		var p := Vector2(r.slots[i].world_pos[0],r.slots[i].world_pos[1])
		check(p.length()>17,"Core has free space")
		for j in range(i):
			var q := Vector2(r.slots[j].world_pos[0],r.slots[j].world_pos[1])
			check(p.distance_to(q)>=13,"No overlapping macro slots")
	var a=fixture(db)
	var b=fixture(db,40,8)
	a.advance(10,1,true);b.advance(10,1,false)
	check(is_equal_approx(a.progress(),0.2) and is_equal_approx(a.progress(),b.progress()),"Work independent of map and slot counts")
	check(a.owned_count==4+floori(396*a.progress()),"Map follows work proportion")
	check(a.frontier.size()==a.frontier_index.size(),"Indexed frontier stays coherent")
	var sequence=fixture(db)
	for _round in 5:
		var bag := {}
		for _i in 5:bag[sequence.next_build_type()]=true
		check(bag.size()==5 and not bag.has("heavy_element_refinery"),"Normal shuffle bag")
	check(sequence.next_build_type()=="heavy_element_refinery","Special cycle")
	var before := str(sequence.state.bag)
	check(not sequence.build_attempt() and str(sequence.state.bag)!=before,"No candidate consumes attempt, no pending")
	var development=fixture(db)
	development.state.explore_work=100.0
	development.state.status="developing"
	development.build_attempt()
	development.slots.filter(func(s):return s.status=="constructing")[0].construction=0.1
	development.advance(1,1)
	check(development.slots.any(func(s):return s.status=="upgrading") and development.occupied_count<4,"Upgrades begin without filling all slots")
	check(development.slots.filter(func(s):return s.status=="upgrading").size()<=2,"Concurrent upgrade cap")
	var persisted: Dictionary=development.save_data()
	var restored=Region.new()
	restored.setup(development.row,development.builds,8,JSON.parse_string(JSON.stringify(persisted)))
	check(restored.cells==development.cells and restored.slots==development.slots,"Work/construction/upgrades and map round trip")
	check(restored.random.state==development.random.state,"RNG saved losslessly")
	check(not str(persisted).contains("timestamp") and not str(persisted).contains("ships"),"No offline or transient presentation data")
	development.advance(100,1)
	check(development.state.status=="complete" and development.max_level_count==4 and development.map_full(),"Toy rules reach complete only with target slots all Lv5")
	var batch=fixture(db);var stepped=fixture(db)
	batch.advance(60,1,false)
	for _i in 60:stepped.advance(1,1,true)
	check(batch.state.explore_work==stepped.state.explore_work and batch.slots==stepped.slots,"Visible and hidden event timing agree")
	var legacy := {"status":"complete","owned":development.save_data().owned,"slots":[{"status":"core","level":0},{"type":"colony_ring","level":5,"construction":0.0}]}
	var migrated=Region.new();migrated.setup(development.row,development.builds,8,legacy)
	check(migrated.occupied_count==1 and migrated.slots[0].level==5 and migrated.state.status=="developing","Legacy grid migrates into macro slots safely")
	g.galaxy.regions.galaxy_1=development
	g.galaxy.effect_generation+=1
	var sum_levels := 0
	for slot in development.slots:
		if slot.type=="colony_ring":sum_levels+=slot.level
	check(is_equal_approx(g.galaxy.multiplier("crew_exp"),1+0.1*sum_levels),"Sole aggregator projects base times levels")
	development.slots[0].type="interstellar_refinery"
	development.slots[1].type="heavy_element_refinery"
	g.galaxy.effect_generation+=1
	g.resource_samples=[{"time":g.economy_time(),"id":"1","amount":200.0,"production_base":100.0,"origin":"drop"},{"time":g.economy_time(),"id":"1","amount":9000.0,"origin":"galaxy"},{"time":g.economy_time(),"id":"2","amount":80.0,"origin":"drop"},{"time":g.economy_time(),"id":"2","amount":9000.0,"origin":"furnace"}]
	var rates: Dictionary=g.galaxy.effects.rates(g,g.galaxy)
	check(is_equal_approx(float(rates.iron),100*g.galaxy.effects.totals.iron_auto_ratio),"Existing iron valid-income samples exclude automation")
	check(is_equal_approx(float(rates.uranium),80*g.galaxy.effects.totals.uranium_auto_ratio),"Uranium excludes automation")
	var serialized: Dictionary=g.galaxy.save_data()
	g.galaxy.load_state(g,serialized)
	check(g.galaxy.regions.galaxy_1.state.explore_work==100,"Loading never catches up wall time")
	print("GALAXY checks=",checks," failures=",failures)
	quit(1 if failures else 0)
