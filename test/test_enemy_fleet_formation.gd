extends SceneTree
const Simulator:=preload("res://scripts/enemy_fleet_simulator.gd")
var failures:=0
func check(ok: bool,label: String) -> void:
	if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	check(UIText.reload_catalog().is_empty(),"formation labels satisfy UI text contract")
	var db:=ShipDatabase.new()
	var original:=JSON.stringify(db.data)
	var sim:=Simulator.new(db)
	var ids: Array=db.enemies.keys()
	var all_tags:=[]
	for template in sim.policy.formation.templates:
		var local_policy: Dictionary=sim.policy.duplicate(true)
		local_policy.formation.templates=[template]
		var local:=Simulator.new(db,local_policy)
		for count in [7,8]:
			var group: Dictionary=local.sample(7821,ids,[count])
			var row: Dictionary=local.analyze(group)
			check(row.formation_type==template.id and row.count==count and row.slots.size()==local.slot_count,"template size and source slots "+template.id)
			check(row.formation_score>=float(local.policy.formation.min_score),"formation threshold "+template.id)
			check(row.formation_metrics.size()==4 and row.formation_tags.has(template.tag),"formation metrics and tag "+template.id)
			var units:=0
			var centers:=0
			for unit in row.formation_positions:
				units+=1
				if int(unit.pair)<0:centers+=1;check(absf(float(unit.x))<0.001,"odd core at center")
				check(int(row.slots[int(unit.slot)])==int(unit.id),"layout refers to source group slot")
			check(units==count and centers==count%2,"pair count and odd core "+template.id)
			for tag in row.formation_tags:
				if not all_tags.has(tag):all_tags.append(tag)
	for tag in ["symmetric","core_wings","front_back","paired","formation_rows","loose_symmetric"]:check(all_tags.has(tag),"required structure tag "+tag)
	var options:={"count":100,"min_count":1,"max_count":10,"min_strength":0,"max_strength":100000,"seed":12345,"available_enemies":ids}
	var started:=Time.get_ticks_usec()
	var batch: Dictionary=sim.generate(options)
	var elapsed_ms:=float(Time.get_ticks_usec()-started)/1000.0
	check(batch.results.size()==100 and batch.status=="complete" and batch.attempts<30000 and elapsed_ms<5000,"bounded data-only coherent generation")
	check(batch==sim.generate(options),"same seed reproduces formation and composition")
	var all_valid:=true
	var seen:={}
	var kinds:={}
	var min_score:=1.0
	for row in batch.results:
		kinds[str(row.formation_type)]=true
		min_score=minf(min_score,float(row.formation_score))
		all_valid=all_valid and not seen.has(row.signature) and row.formation_score>=float(sim.policy.formation.min_score)
		seen[row.signature]=true
		all_valid=all_valid and row.count==row.formation_positions.size() and row.strength>=options.min_strength and row.strength<=options.max_strength
		all_valid=all_valid and is_equal_approx(float(row.strength),float(row.fleet_power)+float(row.max_ship_power))
		all_valid=all_valid and row.ship_count==row.count and row.type_count==row.composition.size() and ["small","medium","large","superlarge"].has(row.scale)
		all_valid=all_valid and ["symmetric","loose_symmetric","core_wings","front_back","paired","rows"].has(row.formation)
		all_valid=all_valid and row.ship_count<=int(sim.policy.generation.count_caps[row.scale]) and row.type_count<=int(sim.policy.generation.type_caps[row.scale])
		var type_cap:=2 if row.ship_count<=6 else 3 if row.ship_count<=10 else 4
		if row.formation=="core_wings" and row.scale=="medium":type_cap+=1
		all_valid=all_valid and row.type_count<=type_cap
		var family_counts: Dictionary={}
		var role_counts: Dictionary={}
		var scale_counts: Dictionary={}
		for value in row.slots:
			if value==null:continue
			var id:=str(int(value))
			var family:=str(sim.projections[id].family)
			family_counts[family]=int(family_counts.get(family,0))+1
			var role:=sim.role_for(id)
			role_counts[role]=int(role_counts.get(role,0))+1
			var scale:=sim.scale_for(id)
			scale_counts[scale]=int(scale_counts.get(scale,0))+1
		var dominant:=0
		for counts_by_theme in [family_counts,role_counts,scale_counts]:
			for amount in counts_by_theme.values():dominant=maxi(dominant,int(amount))
		all_valid=all_valid and float(dominant)/float(row.ship_count)>=float(sim.policy.generation.dominant_share)
		all_valid=all_valid and family_counts.size()<=int(sim.policy.generation.unrelated_family_cap) and role_counts.size()<=int(sim.policy.generation.unrelated_role_cap)
		if seen.size()<=20:all_valid=all_valid and sim.replay(row)==row
	check(all_valid,"deduplicated, bounded and replayable formations")
	check(not sim.valid_composition(["1","2","3","4"],{"anchor":"1","scale":"small","archetype":"paired"}),"four types rejected before formation")
	check(not sim.valid_composition(["1","3"],{"anchor":"1","scale":"small","archetype":"paired"}),"same-family tiers excluded from ordinary groups")
	check(sim.valid_composition(["5","4","4"],{"anchor":"5","scale":"medium","archetype":"core_escort"}),"tier variants allowed for explicit strong core and weak escorts")
	check(not sim.valid_composition(["7","1","2","3","4"],{"anchor":"7","scale":"large","archetype":"core_escort"}),"large core cannot bring many escort types")
	check(kinds.size()>=3,"coherent batch still varies structure")
	var only: String=str(ids[0])
	var fixed: Dictionary=options.duplicate(true)
	fixed.count=10
	fixed.min_count=2
	fixed.max_count=2
	fixed.available_enemies=[only]
	fixed.min_strength=3*float(sim.projections[only].strength)
	fixed.max_strength=fixed.min_strength
	var narrow: Dictionary=sim.generate(fixed)
	check(narrow.results.size()==1 and narrow.results[0].count==2 and is_equal_approx(narrow.results[0].strength,fixed.min_strength),"exact count and strength not altered for symmetry")
	var strict: Dictionary=sim.policy.duplicate(true)
	strict.formation.min_score=1.01
	var rejected: Dictionary=Simulator.new(db,strict).generate({"count":1,"min_count":4,"max_count":4,"min_strength":0,"max_strength":100000,"seed":9,"available_enemies":ids})
	check(rejected.results.is_empty() and rejected.status=="attempt_limit","below-threshold candidates discarded within attempt budget")
	check(Simulator.matches_filter(batch.results[0],str(batch.results[0].formation_tags[0]),0,100000,1,10),"structure tags filter generated results")
	check(JSON.stringify(db.data)==original,"no formal data mutation")
	print("FLEET FORMATION 100 elapsed_ms=",elapsed_ms," min_score=",min_score," failures=",failures)
	quit(1 if failures else 0)
