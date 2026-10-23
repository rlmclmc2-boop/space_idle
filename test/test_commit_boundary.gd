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
	var refuse_income:=false
	func reactor_capacity(galaxy_charge := -1.0) -> Variant:
		return super.reactor_capacity(galaxy_charge) if forced_capacity==null else forced_capacity
	func configuration_committed(native_updated:=false) -> void:
		if forced_capacity!=null:committed_allocations.append(reactor_allocated())
		super.configuration_committed(native_updated)
	func native_before_configuration_change() -> bool:
		if before_change.is_valid():
			var callback:=before_change;before_change=Callable();callback.call()
		return not refuse_income

class SecondPlanetFailure extends "res://scripts/progress_runtime.gd":
	var refuse:=true
	func commit_planet_step_result(g,plan:Dictionary)->Dictionary:
		if refuse and plan.get("id","")=="2":return Result.make("blocked","second_planet")
		return super.commit_planet_step_result(g,plan)

class TwoRegionCrew extends "res://scripts/galaxy_system.gd":
	func crew_count(_g,_key:String)->int:return 1
class SecondRegionFailure extends "res://scripts/galaxy_runtime.gd":
	var refused_key:=""
	func flush_pending(g,key:String)->bool:
		if key==refused_key:return false
		return super.flush_pending(g,key)

class GalaxyPreparationFailure extends "res://scripts/galaxy_runtime.gd":
	var refuse:=true
	var durations:Array=[]
	func prepare_advance(g,dt:float)->bool:
		durations.append(dt)
		return false if refuse else super.prepare_advance(g,dt)

class SecondCombatFailure extends "res://scripts/presented_battle_game.gd":
	var executed:=0
	var refuse:=true
	func _tick_combat_step(dt:float)->void:
		if executed==1 and refuse:block_step("second_combat");return
		executed+=1;super._tick_combat_step(dt)

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
	g.departure_remaining=0.25;g.step_progress.accept(0.125,1.0,0.0);g.resource_prune_elapsed=0.5
	g.save_dirty=false
	var observer:=func(kind,payload):
		if kind=="upgrade":
			seen.append([int(g.slot_entry("weapons",0).level),g.economy.resources(),g.save_dirty,tracker.commits,tracker.timers.has("navigator"),payload.is_read_only(),payload.cost.is_read_only()])
			reentered.append(g.upgrade_slot("weapons",0,1))
			reentered.append(g.progress_runtime.set_crew_upgrade_mode_result(g,"navigator","10").status)
			g.tick(1.0)
			var time_before:Array=[g.economy.balance("chrono"),g.economy.revision,g.departure_remaining,g.step_progress.available(),g.resource_prune_elapsed,g.speed,g.save_checks,g.external_time_active]
			g.consume_external_time(1.0,presentation)
			external_observations.append(time_before==[g.economy.balance("chrono"),g.economy.revision,g.departure_remaining,g.step_progress.available(),g.resource_prune_elapsed,g.speed,g.save_checks,g.external_time_active])
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
	check(tracker.timers.is_empty(),"UI resource event no longer drives business scheduling")
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
	income_receipts()
	derived_income_peak()
	timed_resource_pickup()
	shared_income_failure()
	combat_income_failure()
	partial_domain_failure()
	partial_region_failure()
	galaxy_preparation_retry()
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

func income_receipts()->void:
	var g:=OrderedGame.new(ShipDatabase.new(),false)
	g.profile.cleared=range(1,101);g.rebuild_unlocks()
	var raw:=g.research.save_data();raw.aiTechLevels.unification=1
	g.research.install_snapshot(raw,g.db.data.ai_tech_tree)
	var drop:Dictionary={"id":"1","amount":120.0,"age":0.0,"x":0.0,"y":0.0}
	g.drops.append(drop)
	var wallet:=g.economy.save_data();var history:=g.income_history.records()
	g.before_change=func():g.configuration_revision+=1
	var rejected:=g.collect_result(drop,true)
	check(rejected.status=="rejected" and g.drops.has(drop) and g.economy.save_data()==wallet and g.income_history.records()==history,"invalidated income preparation leaves wallet, receipt and drop untouched")
	var observed:Array=[]
	g.event.connect(func(kind,payload):
		if kind=="collect":
			observed.append([not g.drops.has(drop),g.income_history.size(),payload.is_read_only(),g.collect_result(drop,true).status,g.pickup_jewel_fragment()])
	)
	var committed:=g.collect_result(drop,true)
	check(committed.status=="committed" and observed==[[true,1,true,"no_change",false]],"income installs all owners before immutable notice and rejects nested income")
	var balance:Variant=g.economy.balance("1")
	check(g.collect_result(drop,true).status=="no_change" and g.economy.balance("1")==balance and g.income_history.size()==1,"collected receipt cannot replay")
	var economy=preload("res://scripts/economy_state.gd").new()
	economy.credit_fragments(0.0101)
	check(economy.balance("jewel")==N.add(0.0,0.0101),"fragment wallet uses existing big-number addition without extra precision policy")
	economy.credit("jewel",{"m":1.0,"e":400.0});var large:Variant=economy.balance("jewel")
	economy.credit_fragments(0.0001)
	check(economy.balance("jewel")==N.add(large,0.0001),"large-balance small credit follows shared big-number discard without compensation")

func derived_income_peak()->void:
	var g:=OrderedGame.new(ShipDatabase.new(),false)
	g.profile.cleared=range(1,101);g.rebuild_unlocks()
	var raw:=g.research.save_data();raw.aiTechLevels.unification=1
	g.research.install_snapshot(raw,g.db.data.ai_tech_tree)
	g.refuse_income=true
	var revision:=g.research.revision
	var result:=g.commit_income_receipt("1",6000.0,"furnace",[])
	check(result.status=="committed" and g.research.revision==revision,"furnace receipt credits without preparing a combat peak or requiring native handoff")
	check(g.income_history.display_total("1",g.economy_time())==6000.0 and g.income_history.peak_total("1",g.economy_time())==0.0,"derived income remains displayed but is excluded from peak history")
	g.refuse_income=false
	result=g.commit_income_receipt("1",120.0,"drop",[])
	check(result.status=="committed" and g.research.save_data().aiIncomePeak["1"]==N.divide(120.0,60.0),"next ordinary receipt peak excludes earlier furnace income and includes its pending amount once")

func shared_income_failure()->void:
	for invalidate in [false,true]:
		var g:=OrderedGame.new(ShipDatabase.new(),false)
		g.profile.cleared=range(1,101);g.rebuild_unlocks()
		var raw:=g.research.save_data();raw.aiTechLevels.unification=1
		g.research.install_snapshot(raw,g.db.data.ai_tech_tree)
		var drop:Dictionary={"id":"1","amount":120.0,"age":100.0,"x":0.0,"y":0.0}
		g.drops.append(drop);g.refuse_income=true
		var before:=g.portable_save_data();var earned_before:Variant=g.economy.balance("1")
		g.consume_external_time(2.0*g.LOGICAL_STEP)
		var clock:float=g.production_time();var age:float=drop.age
		check(g.paused and g.step_progress.active and g.step_progress.stage==9 and g.step_progress.item==0,"failed income retains the exact shared item")
		check(g.economy.balance("1")==earned_before and g.income_history.size()==0 and g.drops.has(drop),"failed income leaves no partial receipt")
		check(is_equal_approx(g.step_progress.available()+g.step_progress.duration,2.0*g.LOGICAL_STEP),"blocked receipt conserves reserved and undispatched budget")
		check(g.portable_save_data().is_empty() and g._build_save_data().is_empty(),"incomplete shared step gates every full snapshot")
		g.load_progress_data(before)
		g.load_hightech(before);g.load_journey(before.get("journey",{}))
		check(g.production_time()==clock and g.step_progress.active,"replacement cannot erase an incomplete step")
		if invalidate:g.economy.credit("1",1)
		g.refuse_income=false;g.paused=false;g.tick(g.LOGICAL_STEP)
		if invalidate:
			check(g.step_progress.frozen and g.drops.has(drop) and g.income_history.size()==0,"changed blocked context freezes without replay or stale credit")
		else:
			check(not g.step_progress.active and g.production_time()==clock and drop.age==age and g.income_history.size()==1 and not g.drops.has(drop),"retry completes only the retained receipt without aging or shared-time replay")

func combat_income_failure()->void:
	var g:=OrderedGame.new(ShipDatabase.new(),false)
	g.profile.cleared=range(1,101);g.rebuild_unlocks()
	var raw:=g.research.save_data();raw.aiTechLevels.unification=1
	g.research.install_snapshot(raw,g.db.data.ai_tech_tree)
	g.native_execution_auto=false;g.start(1,false)
	g.group_index=g.db.levels[0].groups.size();g.change_state(g.State.COMBAT)
	var drop:Dictionary={"id":"1","amount":120.0,"age":0.0,"x":0.0,"y":0.0}
	g.drops.append(drop);g.refuse_income=true
	g.tick(g.LOGICAL_STEP)
	check(g.state==g.State.LEVEL_CLEAR and g.step_progress.phase=="combat_running" and g.step_progress.reason=="native_handoff","real final encounter reaches refused forced income inside combat")
	check(g.drops.has(drop) and g.income_history.size()==0,"failed combat settlement retains its receipt")
	var clock:=g.production_time();var rng_state:=g.rng.state;var clear_time:=g.clear_timer
	print("COMBAT_INCOME_RETRY context_equal=",g.step_progress.blocked_context==g.continuation_context())
	g.refuse_income=false;g.paused=false;g.tick(g.LOGICAL_STEP)
	check(g.step_progress.frozen and g.step_progress.active,"interrupted combat without a resumable cursor freezes instead of spinning")
	check(g.production_time()==clock and g.rng.state==rng_state and g.clear_timer==clear_time and g.drops.has(drop),"frozen combat neither replays execution nor retires the failed receipt")
	check(g.portable_save_data().is_empty(),"interrupted combat cannot publish a complete snapshot")
	var budget:float=g.step_progress.available()+g.step_progress.duration
	for retry in range(3):
		g.paused=false;g.consume_external_time(1.0)
	check(g.step_progress.available()+g.step_progress.duration==budget and g.production_time()==clock and g.drops.has(drop),"repeated external resumes of frozen combat return without accepting new budget or losing receipts")

func partial_domain_failure()->void:
	var g:=fixture();var runtime:=SecondPlanetFailure.new();g.progress_runtime=runtime
	for row in g.db.data.unlock.values():
		if row.type=="crew" and not g.profile.grantedUnlocks.has(row.name):g.profile.grantedUnlocks.append(row.name)
	var station:Dictionary=g.planet_progress("1").duplicate(true);station.conquered=true
	g.planets.commit(g.planets.proposal("1",station,true));g.configuration_committed()
	check(g.start_planet_exploration("1","navigator") and g.start_planet_exploration("2","engineer"),"two real planet jobs start")
	g.advance_planets(0.25)
	var first:Dictionary=g.planet_progress("1").duplicate(true)
	check(g.paused and g.step_progress.scope=="planets" and g.step_progress.item==1,"second planet failure retains stable list position after first commit")
	runtime.refuse=false;g.paused=false;g.advance_planets(100.0)
	check(not g.step_progress.active and g.planet_progress("1")==first,"direct retry uses reserved duration and never replays first planet")
	var combat:=SecondCombatFailure.new(ShipDatabase.new(),false);combat.native_execution_auto=false
	combat.start(1,false);combat.spawn_group();combat.tick(2.0*combat.LOGICAL_STEP)
	var clock:float=combat.production_time();var rng_state:int=combat.rng.state
	check(combat.paused and combat.executed==1 and is_equal_approx(combat.step_progress.completed,combat.LOGICAL_STEP) and combat.step_progress.phase=="combat","second combat subdivision blocks after first retirement")
	check(combat.portable_save_data().is_empty(),"second combat failure cannot export half a logical step")
	combat.tick(2.0*combat.LOGICAL_STEP)
	check(combat.rng.state==rng_state and combat.executed==1,"paused retry preserves RNG and damage execution position")
	combat.speed=10.0;combat.refuse=false;combat.paused=false;combat.tick(20.0)
	check(combat.executed==2 and not combat.step_progress.active and combat.production_time()==clock,"changed speed and retry duration cannot reprice or replay reserved combat")

func partial_region_failure()->void:
	var db:=ShipDatabase.new()
	var second:Dictionary=db.data.galaxy.galaxy_1.duplicate(true);second.key="galaxy_s2";second.next_galaxy=""
	db.data.galaxy.galaxy_s2=second
	for row in db.data.galaxy_build.values().duplicate():
		if row.galaxy_key!="galaxy_1":continue
		var build:Dictionary=row.duplicate(true);build.key="s2_"+str(row.key);build.galaxy_key="galaxy_s2"
		db.data.galaxy_build[build.key]=build
	var g:=BattleGame.new(db,false);g.profile.cleared=range(1,101);g.rebuild_unlocks()
	var owner:=TwoRegionCrew.new();var runtime:=SecondRegionFailure.new()
	var raw:Dictionary=g.galaxy.save_data();var keys:Array=raw.galaxies.keys()
	check(keys.size()>=2,"multi-region fixture has two independently configured regions")
	if keys.size()<2:return
	for key in keys:
		raw.galaxies[key].status="exploring";raw.galaxies[key].pending_crew_count=1
	check(owner.install_snapshot(raw,g.db),"multi-region fixture installs current owner snapshots")
	g.galaxy=owner;g.galaxy_runtime=runtime;g.configuration_committed()
	runtime.refused_key=str(keys[1]);var dt:float=owner.work_interval(g)
	runtime.advance(g,dt)
	var first:Dictionary=owner.regions[keys[0]].save_data()
	var income:float=owner.income_time()
	check(g.paused and g.step_progress.item==1 and owner.pending(keys[0])==0 and is_equal_approx(owner.pending(keys[1]),dt),"second region failure retains its accepted time after first commit")
	runtime.refused_key="";g.paused=false;runtime.advance(g,999.0)
	check(not g.step_progress.active and owner.regions[keys[0]].save_data()==first and owner.income_time()==income and owner.pending(keys[1])==0,"region retry drains accepted work without replaying income or first region")

func galaxy_preparation_retry()->void:
	var g:=fixture();g.galaxy_runtime.refresh_unlocks(g)
	var runtime:=GalaxyPreparationFailure.new();g.galaxy_runtime=runtime
	var before:float=g.galaxy.income_time()
	runtime.advance(g,0.1)
	check(g.step_progress.active and not g.step_progress.accepted and g.galaxy.income_time()==before,"Galaxy preparation refusal retains an unaccepted interval")
	g.paused=false;runtime.refuse=false;runtime.advance(g,0.2)
	check(runtime.durations==[0.1,0.1] and is_equal_approx(g.galaxy.income_time()-before,0.1) and not g.step_progress.active,"Galaxy direct retry prepares and credits only the original 0.1 seconds")


func timed_resource_pickup()->void:
	var g:=OrderedGame.new(ShipDatabase.new(),false)
	g.profile.cleared=range(1,101);g.rebuild_unlocks();g.start(1,false)
	g.db.config.autoGenRes="1,1,120,100000"
	g.advance_auto_gen(1.0)
	check(g.drops.size()==1 and g.drops[0].get("auto_gen",false),"Configured top timer produces an actual resource block")
	g.db.config.autoGenRes="";g.advance_auto_gen(1.0)
	var rows:Array=g.income_history.records()
	check(g.drops.is_empty() and rows.size()==1 and rows[0].origin=="drop","Top block automatically collects as native battlefield pickup")
	if rows.is_empty():return
	check(g.income_history.peak_total("1",g.economy_time())==rows[0].amount and g.income_history.production_total("1",g.production_time(),g.economy_time(),g.production_time())==rows[0].production_base,"Unification and Galaxy both include the top block with their existing amount bases")
	check(g.research.save_data().aiIncomePeak["1"]==N.divide(rows[0].amount,60.0),"Top block commits the actual unification peak")
