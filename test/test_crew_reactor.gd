extends SceneTree

var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(message)

func _initialize() -> void:
	var db := ShipDatabase.new()
	var g := BattleGame.new(db,false)
	var c = g.crew
	check(c.available_targets(g,"reactor_upgrade").is_empty(),"Locked reactor is not assignable")
	g.profile.cleared = range(1,41)
	check(g.assign_crew("navigator","reactor_upgrade","reactor"),"Reactor job accepts unlocked crew")
	check(not g.assign_crew("engineer","reactor_upgrade","reactor"),"Only one crew per reactor")
	check(c.effect_text(g,c.entry(g,"navigator")).contains("1.0"),"Configured one-second interval is displayed")
	var level := int(g.reactor.level())
	var cost = g.reactor_upgrade_cost()
	g.economy.debit({"2":g.economy.balance("2")});g.economy.credit("2",cost)
	g.resources_changed(["2"])
	c.advance(g,0.9)
	check(g.reactor.level()==level and g.reactor_allocated()==0,"No upgrade or distribution before one second")
	c.advance(g,0.1)
	check(g.reactor.level()==level+1 and is_zero_approx(g.economy.balance("2")),"Deadline buys exactly one level at normal uranium cost")
	check(g.reactor_allocated()==g.reactor_capacity(),"Upgraded capacity is fully allocated")
	var shares: Array = g.reactor.allocations().values()
	check(int(shares.max())-int(shares.min())<=1,"Allocation uses existing integer equalization")
	g.set_reactor_allocation("weapons",0)
	c.advance(g,1.0)
	check(g.reactor.level()==level+1 and g.reactor_allocated()==g.reactor_capacity(),"Insufficient uranium still equalizes available energy")
	var events := {"count":0}
	g.event.connect(func(_kind,_data):events.count+=1)
	c.advance(g,1.0)
	check(events.count==0,"Unaffordable, already balanced cycle emits no events")
	g.economy.credit("2",g.reactor_upgrade_cost()*100)
	g.resources_changed(["2"])
	g.paused = true
	g.tick(2.0)
	check(g.reactor.level()==level+1,"Pause freezes automation")
	g.paused = false
	c.advance(g,10.0)
	check(g.reactor.level()==level+2,"Long frame makes one attempt without spending burst")
	g.assign_crew("navigator","","")
	c.advance(g,1.0)
	check(g.reactor.level()==level+2,"Release stops automation")
	g.assign_crew("navigator","reactor_upgrade","reactor")
	c.advance(g,0.9)
	check(g.reactor.level()==level+2,"Reassignment starts a fresh clock")
	var saved: Dictionary = g.crew.save_data()
	check(c.install_snapshot(saved,db),"Complete crew snapshot installs");c.reset_schedule(g)
	check(c.entry(g,"navigator").assignmentType=="reactor_upgrade","Assignment survives existing state load")
	c.advance(g,0.1)
	check(g.reactor.level()==level+2,"Loading does not restore a partially elapsed clock")
	print("CREW REACTOR: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
