extends SceneTree
const Simulator := preload("res://scripts/enemy_fleet_simulator.gd")
var failures := 0
var checks := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ", label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var db := ShipDatabase.new()
	var before := JSON.stringify(db.data)
	var sim := Simulator.new(db)
	var options := {"count":100,"min_count":1,"max_count":10,"min_strength":0,"max_strength":1000,"seed":12345,"available_enemies":db.enemies.keys()}
	var started := Time.get_ticks_usec()
	var batch := sim.generate(options)
	var elapsed := float(Time.get_ticks_usec()-started)/1000.0
	print("GENERATE 100 elapsed_ms=", elapsed, " attempts=", batch.attempts)
	check(batch.results.size()==100 and batch.status=="complete", "coherent groups from existing ships")
	check(elapsed < 5000, "data-only generation completes within 5 seconds")
	check(batch==sim.generate(options), "exact batch replay")
	check(sim.replay(batch.results[50])==batch.results[50], "individual saved seed replays independently")
	options.available_enemies.reverse()
	check(batch==sim.generate(options) or batch.results.map(func(r):return r.signature)==sim.generate(options).results.map(func(r):return r.signature), "pool order does not change random composition")
	options.available_enemies.reverse()
	var seen := {}
	var all_valid := true
	for row in batch.results:
		all_valid = all_valid and not seen.has(row.signature) and row.slots.size()==sim.slot_count
		seen[row.signature] = true
		all_valid = all_valid and row.count >= 1 and row.count <= 10 and row.strength <= 1000
		all_valid = all_valid and row.primary_tags.size()<=2 and row.secondary_tags.size()<=3
		all_valid = all_valid and row.feature_scores.size()==10 and row.has("seed")
		for value in row.feature_scores.values():all_valid = all_valid and is_finite(value) and value>=0 and value<=1
	check(all_valid, "unique signatures, structure, seed, bounded features and tag limits")
	var oversized:=options.duplicate(true)
	oversized.count=2000
	var limited:=sim.generate(oversized)
	check(limited.status=="attempt_limit" and limited.results.size()>0 and limited.results.size()<2000 and limited.attempts<60000, "strict themes stop large requests within bounded sampling")
	var light := sim.analyze({"description":"fixture", "slots":[3,3]})
	var heavy := sim.analyze({"description":"fixture", "slots":[7,7]})
	check(is_equal_approx(light.fleet_power,2.0*float(sim.projections["3"].strength)) and is_equal_approx(heavy.strength,heavy.fleet_power+heavy.max_ship_power), "fleet power and peak-ship difficulty use actual hostile stats")
	check(is_equal_approx(float(light.feature_scores.durability),float(db.enemies["3"].health)/float(sim.reference.durability)) and heavy.feature_scores.durability>light.feature_scores.durability, "catalog-relative mean health")
	check(heavy.feature_scores.burst>light.feature_scores.burst and heavy.feature_scores.sustained>light.feature_scores.sustained, "all equipped weapons included")
	check(heavy.feature_scores.armor==0.5 and heavy.feature_scores.shield==0 and heavy.feature_scores.range==0 and heavy.feature_scores.aoe==0, "no invented shield, range or AOE")
	check(light.primary_tags.has("fragile") and sim.analyze({"slots":[11]}).primary_tags.has("elite"), "meaningful light and elite tags")
	check(sim.signature_for({"slots":[null,3,7,3]})==sim.signature_for({"slots":[7,3,3,null]}), "slot permutation ignored")
	check(sim.analyze({"slots":[7,3]}).feature_scores==sim.analyze({"slots":[3,7]}).feature_scores, "analysis order invariant")
	var narrow := options.duplicate(true)
	narrow.available_enemies=["3"]
	narrow.min_count=2
	narrow.max_count=2
	narrow.count=20
	var exhausted := sim.generate(narrow)
	check(exhausted.results.size()==1 and exhausted.status=="attempt_limit" and exhausted.attempts<=600, "small pool terminates without duplicates or exhaustive search")
	narrow.min_strength=3.0*float(sim.projections["3"].strength)
	narrow.max_strength=narrow.min_strength
	check(sim.generate(narrow).results.size()==1, "inclusive exact strength boundary")
	narrow.min_strength=7
	narrow.max_strength=8
	check(sim.generate(narrow).status=="infeasible", "impossible interval exits before sampling")
	narrow.available_enemies=[]
	check(sim.generate(narrow).status=="empty_pool", "empty whitelist rejected")
	narrow=options.duplicate(true)
	narrow.min_count=11
	check(sim.generate(narrow).status=="invalid_input", "group capacity enforced")
	narrow=options.duplicate(true)
	narrow.max_strength=0.0/0.0
	check(sim.generate(narrow).status=="invalid_input", "nonfinite input rejected")
	var elite: Dictionary=sim.analyze({"slots":[11]})
	check(Simulator.matches_filter(elite,"elite",elite.strength,elite.strength,1,1) and not Simulator.matches_filter(light,"elite",0,100,1,10), "tag and numeric filters use inclusive values")
	var changed_policy: Dictionary = sim.policy.duplicate(true)
	changed_policy.tags = [{"id":"custom", "priority":1, "min":{"durability":0.01}}]
	check(Simulator.new(db,changed_policy).analyze({"slots":[3]}).primary_tags==["custom"], "tag thresholds come from configuration")
	check(JSON.stringify(db.data)==before, "original database remains unchanged")
	var fixture := ShipDatabase.new()
	fixture.enemies=fixture.enemies.duplicate(true)
	fixture.enemies["99"]=fixture.enemies["7"].duplicate(true)
	fixture.enemies["99"].id=99
	var renamed := Simulator.new(fixture).analyze({"slots":[99,99]})
	check(renamed.primary_tags==heavy.primary_tags and renamed.feature_scores==heavy.feature_scores, "tags follow stats, not IDs")
	fixture.enemies["99"].equipment=[{"name":"missile-mon"}]
	fixture.enemies["99"].dmgMultiple=1
	check(Simulator.new(fixture).analyze({"slots":[99]}).raw_totals.sustained==5, "hostile missile does not use player salvo count")
	fixture.enemies["99"].equipment=[{"name":"longLaser-mon"}]
	check(Simulator.new(fixture).analyze({"slots":[99]}).raw_totals.sustained==200, "continuous beam resolved through database")
	print("ENEMY FLEET checks=",checks," failures=",failures)
	quit(1 if failures else 0)
