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
	g.profile.cleared=range(1,int(db.data.unlock["feature/galaxy"].level))
	for id in ["1","2","3","4","5"]:g.profile.planets[id].conquered=true
	g.galaxy.refresh_unlocks(g)
	check(not g.galaxy.available(),"Before clear60 first galaxy remains locked")
	for progress in g.profile.planets.values():progress.conquered=false
	g.profile.cleared.append(int(db.data.unlock["feature/galaxy"].level))
	g.rebuild_unlocks()
	g.galaxy.refresh_unlocks(g)
	check(r.state.status=="available","Clear60 opens first galaxy with zero conquered planets")
	var gated := BattleGame.new(db,false)
	for p in gated.profile.planets.values():p.conquered=true
	gated.galaxy.refresh_unlocks(gated)
	check(not gated.galaxy.available(),"Configured level gate retained")
	check(g.assign_crew("navigator","galaxy_explore","galaxy_1") and r.state.status=="exploring","Existing crew starts Galaxy")
	for i in r.slots.size():
		var p := Vector2(r.slots[i].world_pos[0],r.slots[i].world_pos[1])
		check(p.length()>17,"Core has free space")
		for j in range(i):
			var q := Vector2(r.slots[j].world_pos[0],r.slots[j].world_pos[1])
			check(p.distance_to(q)>=13,"No overlapping macro slots")
	var layout: Dictionary=r.layout_snapshot()
	check(layout.nodes.size()==30 and layout.edges.size()==30 and layout.core_id=="core","Complete connected blueprint with separate core")
	var reached := {"core":true}
	for node in layout.nodes:
		check(reached.has(node.requires[0]),"Prerequisite graph rooted at core, no cycles")
		reached[node.node_id]=true
		check(node.type!="" and node.footprint==[14.0,14.0],"All types and footprints planned before work")
	for edge in layout.edges:
		var a := Vector2(edge.path[0][0],edge.path[0][1])
		var b := Vector2(edge.path[1][0],edge.path[1][1])
		for node in layout.nodes:
			if node.node_id in [edge.from,edge.to]:continue
			var p := Vector2(node.world_pos[0],node.world_pos[1])
			check(p.distance_to(Geometry2D.get_closest_point_to_segment(p,a,b))>=8.0,"Corridor clears other footprints")
	var normal_counts := {}
	for node in layout.nodes.slice(0,25):normal_counts[node.type]=int(normal_counts.get(node.type,0))+1
	check(normal_counts.size()==5 and normal_counts.values().all(func(value):return value==5),"Five normal shuffle bags preplanned")
	check(r.builds[layout.nodes[25].type].group=="special","Configured special cycle retained in blueprint")
	var frontier=fixture(db,20,12)
	for _i in 200:
		frontier.advance(0.5,1)
		var building: Array=frontier.slots.filter(func(slot):return slot.status=="constructing")
		check(building.size()<=1,"At most one new construction")
		for slot in building:
			check(frontier.slot_unlocked(slot),"Selected construction has built prerequisites")
			for other in frontier.slots:
				if other.status=="empty" and frontier.slot_unlocked(other):check(int(frontier.blueprint.nodes[int(slot.id)].depth)<=int(frontier.blueprint.nodes[int(other.id)].depth),"Nearest eligible layer builds first")
	var a=fixture(db)
	var untouched: Dictionary=a.save_data()
	a.advance(100,0)
	check(a.save_data()==untouched,"Zero crew preserves work, RNG and all states")
	a.advance(3,1)
	var current: Dictionary=a.slots.filter(func(slot):return slot.status=="constructing")[0]
	check(current.work==2.0 and a.blueprint.nodes[int(current.id)].requires==["core"],"Starts adjacent to main base; configured per-crew rate")
	var paused: Dictionary=a.save_data()
	a.advance(100,0)
	check(a.save_data()==paused,"Recall immediately pauses partial construction")
	a.advance(1,2)
	check(current.work==5.0,"Redispatch continues same node and multi-crew work rate")
	var stalled=fixture(db)
	for node in stalled.blueprint.nodes:node.requires=["node_999"]
	var rng_before: int=stalled.random.state
	stalled.advance(100,1)
	check(stalled.occupied_count==0 and stalled.random.state==rng_before,"No candidates exits without consuming RNG or type bag")
	var development=fixture(db)
	development.advance(10,1)
	var persisted: Dictionary=development.save_data()
	var restored=Region.new()
	restored.setup(development.row,development.builds,8,JSON.parse_string(JSON.stringify(persisted)))
	check(restored.cells==development.cells and restored.slots==development.slots,"Partial node work and construction round trip")
	check(JSON.stringify(restored.blueprint)==JSON.stringify(development.blueprint) and restored.random.state==development.random.state,"Full blueprint and RNG saved losslessly")
	restored.advance(100,1);development.advance(100,1)
	check(restored.slots==development.slots,"Reload has identical subsequent random choices")
	check(development.state.status=="complete" and development.max_level_count==4 and development.map_full(),"Continuous work completes construction and all upgrades")
	var upgrading=fixture(db)
	var initial_seconds: float= float(upgrading.row.explore_work_total)/(float(upgrading.row.explore_power_base)+float(upgrading.row.explore_power_per_crew))+upgrading.slots.size()*(float(upgrading.row.build_interval)+float(upgrading.row.construction_time))
	upgrading.advance(initial_seconds+1.0,1)
	check(upgrading.slots.any(func(slot):return slot.status=="upgrading"),"Fixture reaches partial upgrade")
	var upgrade_frozen: Dictionary=upgrading.save_data()
	upgrading.advance(100,0)
	check(upgrading.save_data()==upgrade_frozen,"Zero crew freezes upgrades too")
	var upgrade_copy=Region.new()
	upgrade_copy.setup(upgrading.row,upgrading.builds,8,JSON.parse_string(JSON.stringify(upgrading.save_data())))
	check(upgrade_copy.slots==upgrading.slots,"Partial upgrades persist without granting effects early")
	var no_build_seconds=fixture(db)
	no_build_seconds.row.construction_time=0.0
	no_build_seconds.advance(100,1)
	check(no_build_seconds.is_complete(),"Zero finishing seconds does not spin or stall")
	var finished: Dictionary=development.save_data()
	development.advance(100,1)
	check(development.save_data()==finished,"Complete region remains stable")
	var batch=fixture(db);var stepped=fixture(db)
	batch.advance(60,1,false)
	for _i in 60:stepped.advance(1,1,true)
	check(is_equal_approx(batch.state.explore_work,stepped.state.explore_work) and batch.slots==stepped.slots,"Visible and hidden event timing agree")
	var legacy := {"status":"complete","explore_work":50.0,"slots":[{"status":"core","level":0},{"type":"colony_ring","level":5,"construction":0.0}]}
	var migrated=Region.new();migrated.setup(development.row,development.builds,8,legacy)
	check(migrated.occupied_count==1 and migrated.slots[0].level==5 and migrated.state.explore_work==50.0,"Legacy known buildings and earned work retained")
	# A save contains pending ONLINE game time, never a wall-clock catch-up.
	g.galaxy.elapsed.galaxy_1=0.0
	g.galaxy.advance(g,1.0)
	check(g.galaxy.elapsed.galaxy_1==1.0,"Hidden batching retains earned game time")
	var pending_save: Dictionary=g.galaxy.save_data()
	g.galaxy.load_state(g,pending_save)
	check(g.galaxy.elapsed.galaxy_1==1.0,"Saving preserves pending online time without advancing it")
	check(g.assign_crew("navigator","",""),"Recall assigned crew")
	check(g.galaxy.elapsed.galaxy_1==0.0 and g.galaxy.regions.galaxy_1.state.build_elapsed==1.0,"Recall flushes old batch with old crew")
	var zero_save: Dictionary=g.galaxy.save_data()
	g.galaxy.advance(g,20.0)
	check(g.galaxy.save_data()==zero_save,"No-crew scheduler accrues no construction time")
	g.assign_crew("navigator","galaxy_explore","galaxy_1")
	g.paused=true
	g.galaxy.advance(g,100.0)
	check(g.galaxy.elapsed.galaxy_1==0.0,"Pause does not advance game clock")
	g.paused=false
	# Art fixture uses the live configuration, same saved blueprint, no player data.
	var full=Region.new()
	full.setup(r.row,r.builds,8)
	full.state.status="exploring"
	full.advance(1000000,1)
	check(full.state.status=="complete" and full.slots.size()==30,"Live first galaxy fully built fixture")
	var file := FileAccess.open("res://.runtime/galaxy_1_complete.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"snapshot":full.layout_snapshot(),"save":full.save_data()},"  "))
	file.close()
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
