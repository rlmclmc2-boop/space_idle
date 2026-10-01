extends SceneTree

class ObservedGame extends BattleGame:
	var attempts := {"equipment":0,"ai":0,"enhance":0,"reactor":0}
	var splits := {"reactor":0,"ai":0}
	func equalize_reactor_allocation() -> bool:
		splits.reactor+=1
		return super.equalize_reactor_allocation()
	func distribute_scientists() -> bool:
		splits.ai+=1
		return super.distribute_scientists()
	func upgrade_equipment_batch(mode: String) -> bool:
		attempts.equipment+=1
		return super.upgrade_equipment_batch(mode)
	func generate_scientist(amount := 1) -> bool:
		attempts.ai+=1
		return super.generate_scientist(amount)
	func upgrade_enhancement(count := 1) -> int:
		attempts.enhance+=1
		return super.upgrade_enhancement(count)
	func upgrade_reactor(amount: int) -> bool:
		attempts.reactor+=1
		return super.upgrade_reactor(amount)

var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr(label)

func fixture(budget := 0.0) -> ObservedGame:
	var g := ObservedGame.new(ShipDatabase.new(),false)
	g.profile.cleared=range(1,101)
	g.rebuild_unlocks()
	g.profile.resources={"1":budget,"2":budget}
	g.profile.jewelFragments=budget
	var jobs := [["equipment_upgrade","equipment"],["hightech_scientists","hightech"],["jewel_auto","jewels"],["reactor_upgrade","reactor"]]
	for i in jobs.size():
		var id: String = g.profile.crew[i].crewId
		check(g.assign_crew(id,jobs[i][0],jobs[i][1]),"assign "+jobs[i][0])
		if i<2:check(g.crew.set_upgrade_mode(g,id,"1"),"+1 mode")
	return g

func compare_state(g, reference, label: String) -> void:
	for key in ["resources","loadout","scientists","scientistAssignments","enhancementLevel","jewelFragments","reactorLevel","reactorAllocation"]:
		check(g.profile[key]==reference.profile[key],label+" "+key)
	check(g.player.armour==reference.player.armour and g.player.shield==reference.player.shield,label+" health")

func reference_second(g) -> void:
	# Original periodic business calls, in configuration crew order.
	for item in g.profile.crew:
		match item.assignmentType:
			"equipment_upgrade":g.crew.auto_upgrade(g,item)
			"hightech_scientists":g.crew.auto_scientists(g,item)
			"jewel_auto":g.crew.auto_jewels(g,item)
			"reactor_upgrade":
				g.upgrade_reactor(1)
				g.equalize_reactor_allocation()

func _initialize() -> void:
	# Limited same-initial-state reference: original per-second callbacks, +1, 1x.
	var g := fixture(1e7)
	var reference := fixture(1e7)
	for second in 3:
		for frame in 60:g.crew.advance(g,1.0/60.0)
		reference_second(reference)
		compare_state(g,reference,"second "+str(second+1))
	check(g.attempts==reference.attempts,"funded attempt cadence")
	# Constrain the shared pool and deliberately enqueue in reverse crew order.
	var constrained := fixture()
	var constrained_reference := fixture()
	var funds: Dictionary=constrained.slot_upgrade_cost("weapons",0)
	constrained.profile.resources=funds.duplicate()
	constrained_reference.profile.resources=funds.duplicate()
	constrained.crew.timers.clear()
	constrained.crew.intervals.clear()
	for i in range(3,-1,-1):constrained.crew.invalidate_member(constrained,constrained.profile.crew[i])
	constrained.crew.advance(constrained,1)
	reference_second(constrained_reference)
	compare_state(constrained,constrained_reference,"constrained balance/order")
	var idle := fixture()
	var idle_reference := fixture()
	for frame in 3600:idle.crew.advance(idle,1.0/60.0)
	for second in 60:reference_second(idle_reference)
	compare_state(idle,idle_reference,"idle same-state comparison")
	check(idle.attempts.equipment==1 and idle.attempts.ai==1 and idle.attempts.enhance==1 and idle.attempts.reactor<=2,"failed unchanged jobs stop after initial work")
	print("IDLE ATTEMPTS / 60 seconds: ",idle.attempts,"; original periodic calls: ",idle_reference.attempts)
	check(idle_reference.attempts=={"equipment":60,"ai":60,"enhance":60,"reactor":60},"reference idle attempt count")
	check(idle.splits.reactor==1,"unchanged energy split is not recomputed on failed purchases")
	var splitting: Dictionary=idle.splits.duplicate()
	idle.profile.planets["1"].conquered=true
	idle.invalidate_stat_cache()
	idle.event.emit("planet_changed",{"id":"1","reward":1.0})
	for frame in 120:idle.crew.advance(idle,1.0/60.0)
	check(idle.splits==splitting and idle.charge_free_ratio()>0,"free charge bonus never triggers ordinary energy distribution")
	idle.set_reactor_allocation("weapons",0)
	idle.crew.advance(idle,0.5)
	idle.set_reactor_allocation("defence",0)
	idle.crew.advance(idle,0.5)
	check(idle.splits.reactor==2 and idle.reactor_allocated()==idle.reactor_capacity(),"manual energy edits merge into first fixed deadline")
	check(idle.attempts.reactor==1,"energy edits do not retry uranium purchase")
	var events := {"count":0}
	idle.event.connect(func(kind,_payload):
		if kind in ["scientists_changed","reactor_changed"]:events.count+=1)
	idle.save_dirty=false
	check(not idle.equalize_reactor_allocation() and events.count==0 and not idle.save_dirty,"identical reactor split has no event/save")
	idle.profile.scientists=12
	idle.distribute_scientists()
	idle.save_dirty=false
	events.count=0
	check(not idle.distribute_scientists() and events.count==0 and not idle.save_dirty,"identical AI split has no event/save")
	var tech: String=idle.hightech_slots()[0]
	idle.assign_scientist(tech,-1)
	var manual: Dictionary=idle.profile.scientistAssignments.duplicate()
	for frame in 120:idle.crew.advance(idle,1.0/60.0)
	check(idle.profile.scientistAssignments==manual and idle.splits.ai==2,"AI manual edit never triggers automatic redistribution")
	var energy := fixture()
	energy.crew.advance(energy,1)
	var reactor_attempts: int=energy.attempts.reactor
	energy.db.config.reactorEnergyBase=float(energy.db.config.reactorEnergyBase)*2
	energy.event.emit("reactor_changed",{})
	energy.crew.advance(energy,1)
	check(energy.reactor_allocated()==energy.reactor_capacity() and energy.splits.reactor==2 and energy.attempts.reactor==reactor_attempts,"capacity-only change redistributes without uranium attempt")
	var locked := fixture()
	locked.crew.advance(locked,1)
	locked.profile.cleared.clear()
	locked.profile.grantedUnlocks=[]
	locked.rebuild_unlocks()
	locked.crew.advance(locked,1)
	check(locked.crew.timers.is_empty() and locked.crew.allocation_timers.is_empty(),"unavailable assignments consume pending work once")
	locked.profile.cleared=range(1,101)
	locked.rebuild_unlocks()
	locked.profile.resources["2"]=1e7
	locked.crew.advance(locked,1)
	check(locked.profile.reactorLevel==int(locked.db.config.reactorInitialLevel)+1,"unlock reactivates retained assignment")
	var first: Dictionary=idle.crew.entry(idle,str(idle.profile.crew[0].crewId))
	idle.profile.resources["1"]=1e7
	idle.event.emit("galaxy_income",{"id":"1","amount":1e7})
	idle.crew.advance(idle,0.6)
	idle.profile.resources["2"]=1e7
	idle.resources_changed(["2"])
	idle.crew.advance(idle,0.39)
	check(idle.attempts.equipment==1,"income merge keeps first fixed deadline")
	idle.crew.advance(idle,0.01)
	check(idle.attempts.equipment==2 and idle.slot_entry("weapons",0).level==2,"first deadline sees all arrivals")
	idle.crew.advance(idle,0.5)
	idle.crew.set_upgrade_mode(idle,str(first.crewId),"10")
	idle.crew.advance(idle,0.5)
	check(idle.slot_entry("weapons",0).level==12,"mode edit does not postpone pending deadline")
	var before: Dictionary=idle.profile.duplicate(true)
	idle.paused=true
	for frame in 120:idle.tick(1.0/60.0)
	check(idle.profile==before,"pause freezes pending work and economy")
	idle.paused=false
	idle.crew.advance(idle,10)
	check(idle.slot_entry("weapons",0).level==22,"large step attempts once")
	idle.crew.advance(idle,0.1)
	check(idle.slot_entry("weapons",0).level==22,"large-step overrun discarded")
	idle.crew.load_state(idle,idle.profile.crew.duplicate(true))
	idle.crew.advance(idle,0.9)
	check(idle.slot_entry("weapons",0).level==22,"load resets elapsed clock")
	idle.crew.advance(idle,0.1)
	check(idle.slot_entry("weapons",0).level==32,"load schedules current assignment")
	var refund := fixture()
	refund.crew.advance(refund,2)
	refund.refund_equipment(refund.module_cost_key("weapons"),2)
	check(refund.crew.timers.has(refund.profile.crew[0].crewId),"refund wakes equipment purchase")
	refund.crew.advance(refund,1)
	check(refund.slot_entry("weapons",0).level==2,"refunded resources are spendable at next deadline")
	refund.assign_crew(str(refund.profile.crew[0].crewId),"","")
	refund.crew.advance(refund,2)
	check(not refund.crew.timers.has(refund.profile.crew[0].crewId),"unassign cancels pending work")
	print("CREW DIRTY: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
