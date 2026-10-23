extends SceneTree
const N=preload("res://scripts/growth_number.gd")
class TimeGame extends BattleGame:
	var save_checks:=0
	func check_timed_save()->void:
		save_checks+=1
class Presentation extends RefCounted:
	var calls:=0
	func prepare_time_frame()->bool:calls+=1;return true
	func before_time_step(_dt:float)->void:calls+=1
	func after_time_step(_completed:bool)->bool:calls+=1;return true
	func publish_time_frame()->void:calls+=1
class TrackedCrew extends "res://scripts/crew_system.gd":
	var commits:=0
	var last: Dictionary={}
	func on_committed(g,result: Dictionary) -> void:
		commits+=1;last=result
		super.on_committed(g,result)

class OrderedGame extends BattleGame:
	var forced_capacity: Variant=null
	var committed_allocations: Array=[]
	var before_change: Callable
	func reactor_capacity(galaxy_charge := -1.0) -> Variant:
		return super.reactor_capacity(galaxy_charge) if forced_capacity==null else forced_capacity
	func configuration_committed(native_updated:=false) -> void:
		if forced_capacity!=null:committed_allocations.append(reactor_allocated())
		super.configuration_committed(native_updated)
	func native_before_configuration_change() -> bool:
		if before_change.is_valid():
			var callback:=before_change;before_change=Callable();callback.call()
		return true

class NumericSession extends RefCounted:
	var accepted:=false
	var calls:=0
	var nested: Array=[]
	func prepare_numeric_batch(_g,_plan:Dictionary,_next:Dictionary) -> Dictionary:
		return {"descriptor":{}}
	func commit_numeric_batch(g,_batch:Dictionary) -> bool:
		calls+=1
		nested.append(g.upgrade_slot("weapons",0,1))
		return accepted
	func configuration_changed() -> void:pass

var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",label)

func fixture() -> BattleGame:
	var g:=TimeGame.new(ShipDatabase.new(),false)
	g.profile.cleared=range(1,101);g.rebuild_unlocks()
	g.economy.credit("1",1e8);g.economy.credit("2",1e8)
	return g

func plan_for(g) -> Dictionary:
	return g.equipment.prepare_upgrades(g.db,g.economy.equipment_balances(g.db.evolution_material_id()),g.hyperspace.is_unlocked(g),"1",{"category":"weapons","index":0})

func _initialize()->void:
	var g:=fixture()
	var tracker:=TrackedCrew.new()
	tracker.install_snapshot(g.crew.save_data(),g.db)
	g.event.disconnect(g.crew.on_event);g.crew=tracker;tracker.attach(g)
	g.assign_crew("navigator","equipment_upgrade","equipment")
	tracker.commits=0;tracker.timers.clear();tracker.intervals.clear()
	var plan:=plan_for(g)
	var before:=g.economy.resources();var initial:=int(g.slot_entry("weapons",0).level)
	var seen:Array=[];var reentered:Array=[];var clock:=g.production_time()
	var external_observations:Array=[];var presentation:=Presentation.new()
	g.economy.accrue_chrono(100,100)
	for option in g.chrono_options():
		if option.cost>0:g.speed=option.multiplier;break
	g.departure_remaining=0.25;g.game_time_remainder=0.125;g.resource_prune_elapsed=0.5
	g.save_dirty=false
	var observer:=func(kind,payload):
		if kind=="upgrade":
			seen.append([int(g.slot_entry("weapons",0).level),g.economy.resources(),g.save_dirty,tracker.commits,tracker.timers.has("navigator"),payload.is_read_only(),payload.cost.is_read_only()])
			reentered.append(g.upgrade_slot("weapons",0,1))
			reentered.append(g.progress_runtime.set_crew_upgrade_mode_result(g,"navigator","10").status)
			g.tick(1.0)
			var time_before:Array=[g.economy.balance("chrono"),g.economy.revision,g.departure_remaining,g.game_time_remainder,g.resource_prune_elapsed,g.speed,g.save_checks,g.external_time_active]
			g.consume_external_time(1.0,presentation)
			external_observations.append(time_before==[g.economy.balance("chrono"),g.economy.revision,g.departure_remaining,g.game_time_remainder,g.resource_prune_elapsed,g.speed,g.save_checks,g.external_time_active])
	g.event.connect(observer)
	var result:=g.commit_equipment_upgrades_result(plan,false)
	g.event.disconnect(observer)
	check(result.status=="committed" and result.domains==["equipment","economy"] and result.slots==["weapons_0"],"result identifies the actual joint commit")
	check(result.is_read_only() and result.facts.is_read_only() and result.slots.is_read_only() and result.contributions.after.is_read_only(),"cross-callback result is deeply immutable")
	check(seen.size()==1 and seen[0][0]==initial+1,"one upgrade notice sees the installed level")
	check(seen[0][1]==g.economy.resources() and plan.purchases[0].costs.keys().all(func(id):return N.compare(g.economy.balance(id),N.subtract(before[id],plan.purchases[0].costs[id]))==0),"observer sees exactly one wallet debit and completed growth")
	check(seen[0][2] and seen[0][3]==1 and seen[0][4] and seen[0][5] and seen[0][6],"dirty flag and one scheduler wake precede immutable UI notice")
	check(reentered==[false,"blocked"] and g.production_time()==clock and g.slot_entry("weapons",0).level==initial+1,"notification cannot insert a command or nested time step")
	check(not g.commit_effects.active,"completion releases boundary")
	check(external_observations==[true] and presentation.calls==0,"external-time reentry rejects before save checks, departure, particle debit, budget, history or presentation effects")
	var stale:=plan_for(g);g.economy.credit("1",100)
	var wallet:=g.economy.resources();initial=int(g.slot_entry("weapons",0).level)
	check(g.commit_equipment_upgrades_result(stale,false).reason=="stale_proposal" and g.economy.resources()==wallet and g.slot_entry("weapons",0).level==initial,"intervening receipt cannot be lost through an old wallet plan")
	tracker.timers.clear();tracker.intervals.clear()
	g.event.emit("upgrade",{})
	check(tracker.timers.is_empty(),"UI equipment event no longer drives business scheduling")
	g.event.emit("resources_changed",{"ids":["1"]})
	check(tracker.timers.has("navigator"),"unmigrated income bridge remains available until S2")
	var noop:=g.progress_runtime.assign_crew_result(g,"navigator","equipment_upgrade","equipment")
	check(noop.status=="no_change" and tracker.commits==1,"unchanged assignment does not publish another commit")
	var native:=NumericSession.new();g.native_execution=native
	plan=plan_for(g);wallet=g.economy.resources();initial=int(g.slot_entry("weapons",0).level)
	check(g.commit_equipment_upgrades_result(plan,false).status=="blocked" and g.economy.resources()==wallet and g.slot_entry("weapons",0).level==initial and not g.commit_effects.active,"native rejection leaves both host owners unchanged and releases boundary")
	native.accepted=true
	check(g.commit_equipment_upgrades_result(plan,false).status=="committed" and g.slot_entry("weapons",0).level==initial+1 and native.nested==[false,false],"native commit cannot reenter host installation")
	g.native_execution=null
	var ordered:=OrderedGame.new(ShipDatabase.new(),false)
	ordered.profile.cleared=range(1,101);ordered.rebuild_unlocks()
	ordered.reactor.commit_allocation({"weapons":10.0,"defence":0.0,"smelting":0.0})
	ordered.forced_capacity=1.0
	var refit:=ordered.commit_loadout_change_result(ordered.equipment.selected_ship(),{"weapons":{0:"cannon"}},false)
	check(refit.status=="committed" and ordered.committed_allocations==[1.0] and ordered.reactor_allocated()==1.0,"configuration descriptor is finalized only after capacity reconciliation")
	check(refit.contributions.after==ordered.attributes.configuration_inputs(ordered),"result captures final contribution versions")
	var equipment_before:=ordered.equipment.save_data()
	ordered.equipment.clear_switches()
	ordered.before_change=func():ordered.reactor.commit_allocation({"weapons":0.0,"defence":0.0,"smelting":0.0})
	var rejected:=ordered.commit_loadout_change_result(ordered.equipment.selected_ship(),{"weapons":{0:"laser"}},false)
	check(rejected.status=="rejected" and rejected.reason=="stale_proposal" and ordered.equipment.save_data().loadout==equipment_before.loadout,"preparation callbacks retain their mutation while stale refit is rejected")
	var progress:=OrderedGame.new(ShipDatabase.new(),false)
	progress.profile.cleared=range(1,101);progress.rebuild_unlocks()
	progress.assign_crew("navigator","equipment_upgrade","equipment")
	var crew_before:=progress.crew.save_data()
	progress.before_change=func():progress.reactor.commit_allocation({"weapons":1.0,"defence":0.0,"smelting":0.0})
	var xp_result:=progress.progress_runtime.add_crew_exp_result(progress,"navigator",10000)
	check(xp_result.reason=="stale_configuration" and progress.crew.save_data()==crew_before,"crew XP rejects changed cross-domain inputs after native handoff")
	check(progress.select_tech("singularity"),"research fixture selects a project")
	var research_plan:Dictionary=progress.research.prepare_advance(progress,progress.research.required(progress,"singularity"))
	var research_before:=progress.research.save_data()
	progress.before_change=func():progress.reactor.commit_allocation({"weapons":2.0,"defence":0.0,"smelting":0.0})
	var research_result:=progress.progress_runtime.commit_research_advance_result(progress,research_plan)
	check(research_result.reason=="stale_configuration" and progress.research.save_data()==research_before,"research completion rejects changed contribution inputs without installing progress")
	progress.economy.credit("1",1000)
	progress.set_tech_input("1",1)
	research_plan=progress.research.prepare_advance(progress,1.0)
	research_before=progress.research.save_data()
	progress.economy.credit("1",1)
	wallet=progress.economy.resources()
	research_result=progress.progress_runtime.commit_research_advance_result(progress,research_plan)
	check(research_result.reason=="stale_research_wallet" and progress.economy.resources()==wallet and progress.research.save_data()==research_before and not progress.commit_effects.active,"stale research wallet rejects joint installation and releases the boundary")
	var controls:=fixture()
	var input_observations:Array=[]
	controls.event.connect(func(kind,_payload):
		if kind=="tech_tree_changed":input_observations.append([controls.save_dirty,controls.set_tech_input("2",5),controls.set_tech_input_ratio("2",0.5),controls.set_reactor_allocation("weapons",1.0)])
	)
	controls.save_dirty=false
	var input_result:=controls.progress_runtime.set_tech_input_result(controls,"1",10)
	check(input_result.status=="committed" and input_observations==[[true,false,false,false]],"research controls publish only after dirty state and reject nested research/reactor commands")
	check(not controls.commit_effects.active,"research input completion releases boundary")
	var planet:=fixture()
	check(planet.start_planet_exploration("1","navigator"),"planet fixture starts exploration")
	var half:=planet.planet_duration("1")/2.0
	var notices:Array=[]
	planet.event.connect(func(kind,_payload):notices.append(kind))
	planet.save_dirty=false
	var partial:=planet.progress_runtime.commit_planet_step_result(planet,planet.planets.prepare_step(planet,"1",half))
	check(partial.status=="committed" and partial.domains==["planets"] and planet.save_dirty and notices.is_empty() and planet.planet_progress("1").degree==0,"partial planet work uses completion boundary without completion reward or UI notice")
	var complete:=planet.progress_runtime.commit_planet_step_result(planet,planet.planets.prepare_step(planet,"1",half))
	check(complete.status=="committed" and complete.domains.has("crew") and complete.facts.reactor_allocation_changed and planet.planet_progress("1").degree==1 and notices.count("planet_changed")==1,"planet completion jointly installs reward and publishes exactly one completion notice")
	var hot:=fixture()
	hot.select_tech("singularity");hot.set_tech_input("1",1)
	var hot_tracker:=TrackedCrew.new();hot_tracker.install_snapshot(hot.crew.save_data(),hot.db)
	hot.event.disconnect(hot.crew.on_event);hot.crew=hot_tracker;hot_tracker.attach(hot)
	var paid_notices:Array=[];var nested_time:Array=[]
	hot.event.connect(func(kind,payload):
		if kind=="resources_changed":
			paid_notices.append([payload.ids,payload.is_read_only(),payload.ids.is_read_only(),hot_tracker.commits])
			var old_time:=hot.production_time();var old_checks:int=hot.save_checks
			hot.consume_external_time(1)
			nested_time.append(hot.production_time()==old_time and hot.save_checks==old_checks)
	)
	hot.ai_tech_last_resource_notice_ms=Time.get_ticks_msec()+100000
	var first:=hot.progress_runtime.commit_research_advance_result(hot,hot.research.prepare_advance(hot,0.001))
	var second:=hot.progress_runtime.commit_research_advance_result(hot,hot.research.prepare_advance(hot,0.001))
	check(is_same(first,second) and first.resources==["1"] and first.contributions.is_empty() and first.is_read_only(),"ordinary paid progress reuses an immutable precise result without contribution allocation")
	check(hot_tracker.commits==0 and paid_notices.is_empty(),"ordinary paid substeps do not scan scheduler jobs inside the resource notice window")
	hot.ai_tech_last_resource_notice_ms=Time.get_ticks_msec()-250
	hot.advance_hightech(0.001)
	check(paid_notices==[[["1"],true,true,1]] and nested_time==[true] and not hot.commit_effects.active,"due resource notice delivers one committed fact before immutable UI notification and blocks external time")
	cold_growth_commands()
	print("COMMIT BOUNDARY: ",checks," checks ",failures," failures")
	quit(1 if failures else 0)

func cold_growth_commands()->void:
	var g:=OrderedGame.new(ShipDatabase.new(),false)
	g.profile.cleared=range(1,101);g.rebuild_unlocks()
	g.profile.grantedUnlocks.append(g.db.unlock_id("feature","jewels"))
	g.economy.credit("2",1e10);g.economy.credit("jewel",1e20)
	var raw:=g.enhancement_growth.save_data();raw.enhancementLevel=40
	check(g.enhancement_growth.install_snapshot(raw),"current growth fixture installs")
	var tracker:=TrackedCrew.new();tracker.install_snapshot(g.crew.save_data(),g.db)
	g.event.disconnect(g.crew.on_event);g.crew=tracker;tracker.attach(g)
	var order:=g.enhancement_order("weapons");order.reverse()
	var commands:Array=[func():return g.upgrade_reactor_result(1),func():return g.set_reactor_allocation_result("weapons",1),func():return g.equalize_reactor_allocation_result(),func():return g.upgrade_enhancement_result(1),func():return g.set_enhancement_order_result("weapons",order),func():return g.set_enhancement_branch_result("weapons","proficiency",1,"B")]
	for index in commands.size():
		var command:Callable=commands[index]
		var before:Array=[g.economy.save_data(),g.reactor.save_data(),g.enhancement_growth.save_data()]
		var calls:int=tracker.commits
		g.before_change=func():g.configuration_revision+=1
		var failed:Dictionary=command.call()
		check(failed.status=="rejected" and failed.reason=="stale_proposal" and before==[g.economy.save_data(),g.reactor.save_data(),g.enhancement_growth.save_data()] and tracker.commits==calls,"growth command rejects handoff-invalidated configuration without partial install "+str(index))
		var seen:Array=[];var nested:Array=[]
		var observer:=func(_kind,payload):
			seen.append([tracker.commits,g.save_dirty,payload.is_read_only(),g.reactor_allocated()<=g.reactor_capacity()])
			if nested.is_empty():
				for another in commands:nested.append(another.call().status)
		g.save_dirty=false;g.event.connect(observer)
		var result:Dictionary=command.call()
		g.event.disconnect(observer)
		check(result.status=="committed" and tracker.commits==calls+1 and not seen.is_empty() and seen.all(func(item):return item==[calls+1,true,true,true]),"growth command installs and schedules once before immutable UI notices "+str(index))
		check(nested.size()==6 and nested.all(func(status):return status=="blocked") and not g.commit_effects.active,"every cold growth entry rejects notification reentry "+str(index))
		check(result.contributions.get("after",[])==g.attributes.configuration_inputs(g),"growth result describes final authoritative configuration "+str(index))
