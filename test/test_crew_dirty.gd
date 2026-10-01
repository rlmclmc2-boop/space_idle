extends SceneTree

class ObservedGame extends BattleGame:
	var attempts := {"equipment":0,"ai":0,"enhance":0,"reactor":0}
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

func _initialize() -> void:
	# Limited same-initial-state reference: original per-second callbacks, +1, 1x.
	var g := fixture(1e7)
	var reference := fixture(1e7)
	for second in 3:
		for frame in 60:g.crew.advance(g,1.0/60.0)
		for item in reference.profile.crew:
			match item.assignmentType:
				"equipment_upgrade":reference.crew.auto_upgrade(reference,item)
				"hightech_scientists":reference.crew.auto_scientists(reference,item)
				"jewel_auto":reference.crew.auto_jewels(reference,item)
				"reactor_upgrade":reference.crew.auto_reactor(reference,item)
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
	for item in constrained_reference.profile.crew:
		match item.assignmentType:
			"equipment_upgrade":constrained_reference.crew.auto_upgrade(constrained_reference,item)
			"hightech_scientists":constrained_reference.crew.auto_scientists(constrained_reference,item)
			"jewel_auto":constrained_reference.crew.auto_jewels(constrained_reference,item)
			"reactor_upgrade":constrained_reference.crew.auto_reactor(constrained_reference,item)
	compare_state(constrained,constrained_reference,"constrained balance/order")
	var idle := fixture()
	for frame in 3600:idle.crew.advance(idle,1.0/60.0)
	check(idle.attempts.equipment==1 and idle.attempts.ai==1 and idle.attempts.enhance==1 and idle.attempts.reactor<=2,"failed unchanged jobs stop after initial work")
	print("IDLE ATTEMPTS / 60 seconds: ",idle.attempts,"; previous periodic scheduler: 60 each")
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
