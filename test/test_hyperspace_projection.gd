extends SceneTree
const Rewards=preload("res://scripts/drone_rewards.gd")
const Bag=preload("res://scripts/drone_inventory.gd")
const N=preload("res://scripts/growth_number.gd")
var checks:=0
var failures:=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL: ",label)
func fixture(count: int) -> BattleGame:
	var db:=ShipDatabase.new();db.config.offlineMax=0
	var g:=BattleGame.new(db,false);g.profile.cleared=range(1,41);g.rebuild_unlocks();g.profile.selectedShip="Heavy_Battleship"
	g.profile.loadout={"weapons":[{"key":"laser","level":10},{"key":"missile","level":10},{"key":"cannon","level":10}],"defence":[{"key":"armour","level":10}]}
	var rng:=RandomNumberGenerator.new();rng.seed=5
	var ids: Array=[]
	for i in count:
		var d:=Rewards.create_drone(rng,g.hyperspace.config,"cpu:%d"%i,"blue",["laser","missile","cannon","longLaser","laser"][i],5,"1")
		d.affixes=[{"key":"global_damage","tier":5,"value":0.1,"locked":false}];d.hanging_slots=2;d.hangings=["resource_collector","distributed_algorithm"]
		Bag.insert(g.profile.hyperspace.inventory,d,g.hyperspace.config);ids.append(d.id)
	g.profile.hyperspace.hanging_modules.resource_collector={"unlocked":true,"level":1,"exp":0.0}
	g.profile.hyperspace.hanging_modules.distributed_algorithm={"unlocked":true,"level":1,"exp":0.0}
	g.stat_cache_enabled=true;g.invalidate_stat_cache();g.hyperspace.set_equipped(g,ids);g.reset_player();g.state=g.State.COMBAT
	for i in 20:g.enemies.append({"uid":i+1,"hp":1e30,"max_hp":1e30,"x":70.0+i%5*80,"y":80.0+floori(i/5.0)*55,"slot":i,"armourType":99,"equipment":[],"drops":[],"res_ratio":1.0})
	g.rng.seed=111
	return g
func _initialize() -> void:
	var g:=fixture(5);var projected: Dictionary=g.hyperspace_totals()
	check(is_equal_approx(projected.damage,1.525) and is_equal_approx(projected.hangings.resource_collector,0.5),"five same affix and hanging increments add")
	check(is_equal_approx(g.planet_resource_multiplier(),1.5),"resource output consumer uses one summed multiplier")
	var research_keys: Array=g.db.data.hightech.keys().filter(func(key):return g.hightech_unlocked(key))
	check(not research_keys.is_empty(),"live research consumer fixture unlocked")
	var research_key: String=research_keys[0];g.profile.scientistAssignments[research_key]=1
	check(is_equal_approx(g.research_rate(research_key,{"tech_ai_per_level":0,"tech_speed":1.0}),float(g.db.config.techPointGet)*1.5),"distributed algorithm increases AI research rate")
	var before_source: Dictionary=g.combat_entry(g.weapon_entries().size());g.invalidate_stat_cache()
	check(is_same(before_source,g.combat_entry(g.weapon_entries().size())),"counter-independent sources retained")
	var uncached:=BattleGame.new(g.db,false);uncached.profile=g.profile.duplicate(true);uncached.galaxy.load_state(uncached,g.galaxy.save_data());uncached.reset_player();uncached.state=uncached.State.COMBAT;uncached.enemies.assign(g.enemies.duplicate(true));uncached.rng.seed=111
	check(uncached.hyperspace_totals()==g.hyperspace_totals(),"cached projection equals direct calculation")
	for i in 90:g.tick(1.0/60.0);uncached.tick(1.0/60.0)
	check(g.rng.state==uncached.rng.state and g.enemies==uncached.enemies and g.cooldowns==uncached.cooldowns,"cached and direct ninety short steps gameplay parity")
	check(g.projectiles==uncached.projectiles,"cached and direct source/context/projectile parity")
	var module: String="hyperspace_charge";g.profile.hyperspace.hanging_modules[module]={"unlocked":true,"level":2,"exp":0.0}
	var first: Dictionary=g.profile.hyperspace.inventory.drones["cpu:0"];g.hyperspace.attach_hangings(g,"cpu:0",[module])
	check(is_equal_approx(g.hyperspace.online_config(g).energy_cap,216000*1.21) and is_equal_approx(g.hyperspace.online_config(g).energy_rate,10*1.21),"energy speed and cap use actual growth")
	g.profile.hyperspace.hanging_modules[module].unlocked=false;g.invalidate_stat_cache()
	check(g.hyperspace.online_config(g).energy_cap==216000,"retained layout cannot activate unreunlocked hanging")
	var armour_before=g.stat("armour");g.player.armour=N.divide(armour_before,2.0)
	g.profile.hyperspace.inventory.drones["cpu:0"].affixes.append({"key":"global_defence","tier":5,"value":0.5,"locked":false})
	g.hyperspace.set_equipped(g,g.profile.hyperspace.inventory.equipped)
	check(N.compare(g.stat("armour"),N.multiply(armour_before,1.525))==0,"refit applies amplified defence projection")
	check(is_equal_approx(float(N.divide(g.player.armour,g.stat("armour"))),0.5),"drone refit preserves injured armour fraction")
	# A short source-cost probe, not a graphical FPS estimate or a stage progression run.
	for count in [0,5]:
		var probe:=fixture(count)
		for i in 30:probe.tick(1.0/60.0)
		var samples: Array=[]
		for i in 60:
			var start:=Time.get_ticks_usec();probe.tick(1.0/60.0);samples.append(Time.get_ticks_usec()-start)
		var mean: float=samples.reduce(func(a,b):return a+b,0)/60.0;samples.sort()
		print("SHORT_SOURCE_CPU drones=",count," mean_us=",mean," p95_us=",samples[56]," projectiles=",probe.projectiles.size())
	print("HYPERSPACE_PROJECTION ",checks," checks ",failures," failures")
	quit(1 if failures else 0)
