extends SceneTree
## Current scheduler results, not a second implementation of the old per-second loop.
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",label)
func fixture()->BattleGame:
	var g:=BattleGame.new(ShipDatabase.new(),false)
	g.profile.cleared=range(1,101);g.rebuild_unlocks()
	var wallet:=g.economy.save_data();wallet.resources={"1":0.0,"2":0.0};wallet.jewelFragments=0
	assert(g.economy.install_snapshot(wallet))
	return g
func _initialize()->void:
	var locked:=BattleGame.new(ShipDatabase.new(),false)
	check(locked.crew.available_targets(locked,"reactor_upgrade").is_empty(),"Locked reactor cannot receive crew")
	var g:=fixture();var c=g.crew
	check(g.assign_crew("navigator","reactor_upgrade","reactor"),"Assign reactor crew")
	check(not g.assign_crew("engineer","reactor_upgrade","reactor"),"Reactor job is exclusive")
	var level:=g.reactor.level();var price=g.reactor_upgrade_cost()
	g.economy.credit("2",price);g.resources_changed(["2"])
	c.advance(g,0.9)
	check(g.reactor.level()==level and g.reactor_allocated()==0,"No purchase or allocation before deadline")
	c.advance(g,0.1)
	check(g.reactor.level()==level+1 and GrowthNumber.compare(g.economy.balance("2"),0)==0,"Deadline pays quote and buys once")
	check(g.reactor_allocated()==g.reactor_capacity(),"New capacity allocated at the same deadline")
	var shares:Array=g.reactor.allocations().values()
	check(int(shares.max())-int(shares.min())<=1,"Small capacity keeps integer remainder")
	g.set_reactor_allocation("weapons",0);c.advance(g,1)
	check(g.reactor.level()==level+1 and g.reactor_allocated()==g.reactor_capacity(),"Unaffordable purchase still permits redistribution")
	var events:Array=[];g.event.connect(func(kind,_payload):events.append(kind))
	g.save_dirty=false;var before:=stable_save(g);c.advance(g,2)
	check(stable_save(g)==before and events.is_empty() and not g.save_dirty,"Unchanged failed job neither mutates domains nor emits saves/events")
	g.db.config.reactorEnergyBase*=2;g.notify_configuration_changed();g.event.emit("reactor_changed",{});c.advance(g,1)
	check(g.reactor.level()==level+1 and g.reactor_allocated()==g.reactor_capacity(),"Capacity-only change redistributes without purchase")
	g.economy.credit("2",GrowthNumber.multiply(g.reactor_upgrade_cost(),100));g.resources_changed(["2"])
	g.paused=true;before=stable_save(g);g.consume_external_time(2)
	check(stable_save(g)==before,"Pause preserves real wallet and all growth domains")
	g.paused=false;c.advance(g,10)
	check(g.reactor.level()==level+2,"Long frame makes one purchase, not a burst")
	g.assign_crew("navigator","","");c.advance(g,1)
	check(g.reactor.level()==level+2,"Recall cancels pending job")
	g.assign_crew("navigator","reactor_upgrade","reactor");c.advance(g,0.9)
	assert(c.install_snapshot(c.save_data(),g.db));c.reset_schedule(g);c.advance(g,0.1)
	check(g.reactor.level()==level+2,"Snapshot install restarts a full job interval")
	c.advance(g,0.9);check(g.reactor.level()==level+3,"Restored current assignment executes once")
	# Income arrivals coalesce at the original deadline; mode changes do not postpone it.
	g=fixture();check(g.assign_crew("navigator","equipment_upgrade","equipment"),"Assign equipment job")
	g.set_crew_upgrade_mode("navigator","1");g.crew.advance(g,1)
	var initial:int=g.slot_entry("weapons",0).level
	g.economy.credit("1",1e7);g.resources_changed(["1"]);g.crew.advance(g,0.6)
	g.economy.credit("2",1e7);g.resources_changed(["2"]);g.crew.advance(g,0.39)
	check(g.slot_entry("weapons",0).level==initial,"Income does not spend before original deadline")
	g.crew.advance(g,0.01);check(g.slot_entry("weapons",0).level==initial+1,"Merged arrivals fund one actual equipment purchase")
	g.crew.advance(g,0.5);g.set_crew_upgrade_mode("navigator","10");g.crew.advance(g,0.5)
	check(g.slot_entry("weapons",0).level==initial+11,"Mode change takes effect at existing deadline")
	g.economy.credit(g.db.evolution_material_id(),10000);g.crew.advance(g,10)
	check(g.slot_entry("weapons",0).level==initial+21,"Large interval executes one configured batch")
	before=stable_save(g);g.crew.advance(g,0.1)
	check(stable_save(g)==before,"Discarded overrun cannot cause a second purchase")
	g.assign_crew("navigator","","");before=stable_save(g);g.crew.advance(g,2)
	check(stable_save(g)==before,"Equipment recall stops spending")
	print("CREW SCHEDULE: ",checks," checks ",failures," failures")
	quit(1 if failures else 0)

func stable_save(g)->Dictionary:
	var data:Dictionary=g.portable_save_data()
	data.erase("chronoSavedAt");data.erase("hightechSavedAt")
	return data
