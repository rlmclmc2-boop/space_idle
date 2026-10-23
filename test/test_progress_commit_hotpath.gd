extends SceneTree
class CountedProjection extends "res://scripts/attribute_projection.gd":
	var reads:=0
	func configuration_inputs(g)->Array:
		reads+=1
		return super.configuration_inputs(g)
class Crew extends "res://scripts/crew_system.gd":
	var scans:=0
	func invalidate_resources(g,ids:Array)->void:
		scans+=1
		super.invalidate_resources(g,ids)
class Effects extends "res://scripts/commit_effects.gd":
	var full_results:=0
	func finish(g,domains:Array,resources:Array,slots:Array,facts:Dictionary,notices:Array)->Dictionary:
		full_results+=1
		return super.finish(g,domains,resources,slots,facts,notices)
var failures:=0
var checks:=0
func check(ok:bool)->void:
	checks+=1
	if not ok:failures+=1
func _initialize()->void:
	for scenario in ["planet","research_unpaid","research_paid"]:measure(scenario)
	print("PROGRESS HOT PATH: %d checks %d failures"%[checks,failures])
	quit(1 if failures else 0)
func advance(g,scenario:String)->void:
	# Measure the interior of the existing 250ms notice window; due delivery is
	# covered by the boundary fixture, independently of machine throughput.
	g.ai_tech_last_resource_notice_ms=Time.get_ticks_msec()
	if scenario=="planet":g.advance_planets(0.001)
	else:g.advance_hightech(0.001)
func measure(scenario:String)->void:
	var db:=ShipDatabase.new()
	db.data.planet["1"].baseTime=1e9;db.data.planet["1"].minTime=1e9
	db.data.ai_tech_tree.singularity.base_seconds=1e9
	var g:=BattleGame.new(db,false)
	g.profile.cleared=range(1,101);g.rebuild_unlocks()
	g.economy.credit("1",1e8);g.economy.credit("2",1e8)
	var projection:=CountedProjection.new();g.attributes=projection
	var crew:=Crew.new();crew.install_snapshot(g.crew.save_data(),db)
	g.event.disconnect(g.crew.on_event);g.crew=crew;crew.attach(g)
	var effects:=Effects.new();g.commit_effects=effects
	if scenario=="planet":check(g.start_planet_exploration("1","navigator"))
	else:
		check(g.select_tech("singularity"))
		if scenario=="research_paid":check(g.set_tech_input("1",1) and g.set_tech_input("2",1))
	for i in 200:advance(g,scenario)
	projection.reads=0;crew.scans=0;effects.full_results=0
	var samples:Array=[]
	for batch in 7:
		var start:=Time.get_ticks_usec()
		for i in 1000:advance(g,scenario)
		samples.append(Time.get_ticks_usec()-start)
	var work:float=g.planet_progress("1").elapsed if scenario=="planet" else g.research.progress("singularity")
	check(absf(work-7.2)<0.000001)
	check(g.save_dirty and not g.commit_effects.active)
	check(g.planet_progress("1").degree==0 and g.hightech_level("singularity")==0)
	var sorted:=samples.duplicate();sorted.sort()
	print("HOTPATH ",JSON.stringify({"scenario":scenario,"warmup":200,"steps":7000,"dt":0.001,"batch_us":samples,"median_batch_us":sorted[3],"configuration_reads":projection.reads,"resource_scans":crew.scans,"full_results":effects.full_results,"work":work,"wallet":g.economy.resources()}))
