extends SceneTree
const Rewards=preload("res://scripts/drone_rewards.gd")
const Bag=preload("res://scripts/drone_inventory.gd")
var checks:=0
var failures:=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize() -> void:
	var db:=ShipDatabase.new();var g:=BattleGame.new(db,false)
	g.profile.cleared=range(1,41);g.rebuild_unlocks();g.stat_cache_enabled=true
	var rng:=RandomNumberGenerator.new();rng.seed=234
	var drone:=Rewards.create_drone(rng,g.hyperspace.config,"consumer","white","laser",5,"1")
	drone.affixes=[];drone.hanging_slots=4;drone.hangings=[]
	Bag.insert(g.profile.hyperspace.inventory,drone,g.hyperspace.config);g.hyperspace.set_equipped(g,[drone.id])
	for key in g.hyperspace.config.hanging_modules:g.profile.hyperspace.hanging_modules[key]={"unlocked":true,"level":2,"exp":0.0}
	for growth in [0.1,0.2]:
		g.hyperspace.attach_hangings(g,drone.id,[])
		var energy:=g.reactor_energy();var chrono:=g.chrono_capacity()
		check(chrono>0,"nonzero live chrono capacity fixture")
		g.hyperspace.config.hanging_modules.extra_storage.effect_growth=growth
		check(g.hyperspace.attach_hangings(g,drone.id,["extra_storage"]),"storage attaches")
		var factor:=pow(1.0+growth,2)
		check(is_equal_approx(g.reactor_energy(),energy*factor) and g.reactor_capacity()==floori(energy*factor),"storage boosts reactor total energy and integer capacity")
		check(g.chrono_capacity()==chrono,"storage leaves offline chrono upper limit unchanged")
		var modules:=g.reactor_available_modules()
		check(not modules.is_empty(),"reactor allocation fixture unlocked")
		check(g.set_reactor_allocation(modules[0],g.reactor_capacity()),"boosted reactor energy can be allocated")
		g.hyperspace.attach_hangings(g,drone.id,[])
		check(g.reactor_allocated()<=g.reactor_capacity() and g.reactor_capacity()==floori(energy),"removing storage reconciles allocations to reduced capacity")
		check(g.chrono_capacity()==chrono,"detach leaves chrono limit unchanged")
	for key in g.reactor_modules():g.profile.reactorAllocation[key]=0
	g.invalidate_stat_cache()
	var rate_keys: Array=g.db.data.hightech.keys().filter(func(key):return g.hightech_unlocked(key))
	var key: String=rate_keys[0];g.profile.scientistAssignments[key]=1
	var base_rate:=g.research_rate(key,{"tech_ai_per_level":0,"tech_speed":1.0})
	g.hyperspace.attach_hangings(g,drone.id,["distributed_algorithm"])
	check(is_equal_approx(g.research_rate(key,{"tech_ai_per_level":0,"tech_speed":1.0}),base_rate*1.21),"algorithm targets AI research production")
	g.hyperspace.attach_hangings(g,drone.id,["resource_collector"])
	check(is_equal_approx(float(g.planet_resource_multiplier()),1.21),"collector targets iron uranium output")
	g.hyperspace.attach_hangings(g,drone.id,["gem_refiner"])
	check(is_equal_approx(g.settle_jewel_fragments(10,"furnace",1),12.1),"refiner targets gem fragment production")
	check(g.settle_jewel_fragments(10,"refund",1)==10,"refiner never multiplies refund")
	g.hyperspace.attach_hangings(g,drone.id,["hyperspace_charge"])
	var online: Dictionary=g.hyperspace.online_config(g)
	check(is_equal_approx(online.energy_cap,float(g.hyperspace.config.energy_cap)*1.21) and is_equal_approx(online.energy_rate,float(g.hyperspace.config.energy_rate)*1.21),"hyperspace charge targets its own rate and cap")
	print("HYPERSPACE_CONSUMERS ",checks," checks ",failures," failures")
	quit(1 if failures else 0)
