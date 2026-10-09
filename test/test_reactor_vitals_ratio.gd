extends SceneTree
const A = preload("res://scripts/reactor_automation.gd")
const I = preload("res://scripts/reactor_integer.gd")
const N = preload("res://scripts/growth_number.gd")
const Vitals = preload("res://scripts/reactor_vitals.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",label)

func fixture(large: bool, cached: bool):
	var g = BattleGame.new(ShipDatabase.new(),false)
	g.stat_cache_enabled = cached
	g.profile.highestLevel = 41
	g.profile.cleared = range(1,41)
	g.rebuild_unlocks()
	g.pending_unlocks.clear()
	g.profile.selectedShip = "Destroyer"
	var level = 4000 if large else 10
	g.profile.loadout = {"weapons":[{"key":"laser","level":level}],"defence":[{"key":"armour","level":level},{"key":"shield","level":level}]}
	g.profile.reactorLevel = 1000 if large else 10
	g.invalidate_stat_cache()
	var half = I.divmod(g.reactor_capacity(),2)[0]
	check(g.set_reactor_allocation("defence",half),"Fixture defence allocation")
	check(g.set_reactor_allocation("weapons",half),"Fixture weapon allocation")
	check(g.start(6,false,{},true),"Fixture starts paused")
	g.player.armour = N.multiply(g.stat("armour"),0.37)
	g.player.shield = N.multiply(g.max_shield(),0.61)
	g.since_hit = 7.25
	g.jewel_defence_times = {0:3.5,1:4.75}
	g.enhancement_memory_elapsed = 0.125
	g.enhancement_deferred_elapsed = 0.25
	g.enhancement_defense_time = 4.0
	g.rng.seed = 1701
	return g

func clocks(g) -> Array:
	return [g.since_hit,g.jewel_defence_times.duplicate(true),g.enhancement_memory_elapsed,g.enhancement_deferred_elapsed,g.enhancement_defense_time,g.rng.state,g.production_time(),g.distance,g.group_index,g.cooldowns.duplicate(true)]

func fractions(g) -> Array:
	return [N.ratio(g.player.armour,g.stat("armour")),N.ratio(g.player.shield,g.max_shield())]

func same_fractions(g, expected: Array, label: String) -> void:
	var actual = fractions(g)
	check(absf(actual[0]-expected[0])<1e-10 and absf(actual[1]-expected[1])<1e-10,label)

func exercise(large: bool, cached: bool) -> void:
	var g = fixture(large,cached)
	var original = [g.player.armour,g.player.shield]
	var ratio = A.capture(g)
	var expected = fractions(g)
	var before = clocks(g)
	var defence = g.profile.reactorAllocation.defence
	var stable = true
	for cycle in 200:
		g.set_reactor_allocation("defence",0)
		var low = fractions(g)
		stable = stable and low[0]<=expected[0] and low[1]<=expected[1]
		g.set_reactor_allocation("defence",defence)
		stable = stable and N.compare(g.player.armour,original[0])==0 and N.compare(g.player.shield,original[1])==0
	check(stable,"200 clear/drag round trips do not accumulate health or shield")
	check(clocks(g)==before,"Allocation keeps hit/repair timers, cooldowns, RNG and progress")
	g.tick(1.0)
	check(g.paused and clocks(g)==before,"Paused allocation remains paused and tick cannot heal/advance")
	g.equalize_reactor_allocation()
	same_fractions(g,expected,"Equalize preserves both damaged fractions")
	A.apply(g,ratio)
	check(N.compare(g.player.armour,original[0])==0 and N.compare(g.player.shield,original[1])==0,"Preset ratio returns to exact original pools")
	check(A.save_slot(g,0,ratio),"Save ratio preset")
	g.set_reactor_allocation("defence",0)
	check(A.apply_slot(g,0),"Apply ratio preset")
	same_fractions(g,expected,"Saved preset preserves fractions")
	var target = {"total":3,"weights":{"weapons":1,"defence":2}}
	check(A.apply(g,target),"Apply distinct ratio")
	same_fractions(g,expected,"Direct ratio changes preserve fractions")
	# Automatic apply uses the existing saved target; no resource injection/upgrade.
	g.profile.reactorAutomation.ratio = ratio.duplicate(true)
	g.profile.reactorAutomation.allocate = true
	A.maintain(g)
	check(N.compare(g.player.armour,original[0])==0 and N.compare(g.player.shield,original[1])==0,"Automatic allocation returns to exact original pools")
	check(clocks(g)==before,"All allocation entrypoints leave recovery/hit clocks unchanged")
	var health_before = [g.player.armour,g.player.shield]
	check(not g.set_reactor_allocation("defence",-1) and not A.apply(g,{"total":0,"weights":{}}),"Invalid scalar/ratio edits rejected")
	check(health_before==[g.player.armour,g.player.shield],"Rejected edits never modify pools")
	# Insert a real hit between two reallocations. Observe post-mitigation health,
	# then independently compare its fraction against the new maximum.
	g.set_reactor_allocation("defence",0)
	g.paused = false
	g.hit_player(N.multiply(g.max_shield(),0.05),1)
	g.paused = true
	var injured = fractions(g)
	var injured_clocks = clocks(g)
	A.apply(g,ratio)
	same_fractions(g,injured,"Real intervening shield damage invalidates its old anchor")
	check(fractions(g)[1]<=injured[1],"Restoring allocation cannot undo intervening shield damage")
	check(clocks(g)==injured_clocks,"Reallocation after hit does not reset hit/repair clocks")
	g.set_reactor_allocation("defence",0)
	g.player.shield = 0.0
	g.paused = false
	g.hit_player(N.multiply(g.stat("armour"),0.05),1)
	g.paused = true
	injured = fractions(g)
	A.apply(g,ratio)
	same_fractions(g,injured,"Intervening armour damage invalidates its anchor")
	check(fractions(g)[0]<=injured[0] and N.compare(g.player.shield,0)==0,"Damage cannot be undone and empty shield is not refilled")
	var damaged = [g.player.armour,g.player.shield]
	for cycle in 100:
		g.set_reactor_allocation("defence",0);A.apply(g,ratio)
	check(N.compare(g.player.armour,damaged[0])==0 and N.compare(g.player.shield,0)==0,"100 post-hit loops cannot heal")
	# Actual equipment/energy purchases retain their old absolute-health policy.
	if not large:
		var armour_before = g.player.armour
		var stat_before = g.stat("armour")
		g.profile.resources["1"] = g.slot_upgrade_cost("defence",0,1)["1"]
		check(g.upgrade_slot("defence",0,1),"Equipment upgrade outside redistribution")
		check(N.compare(g.player.armour,N.add(armour_before,N.subtract(g.stat("armour"),stat_before)))==0,"Equipment upgrade keeps existing additive health rule")
		armour_before = g.player.armour
		g.profile.resources["2"] = g.reactor_upgrade_cost()
		check(g.upgrade_reactor(1),"Reactor upgrade outside redistribution")
		check(N.compare(g.player.armour,armour_before)==0,"Reactor purchase still does not heal")
		expected = fractions(g)
		g.set_reactor_allocation("defence",0);g.equalize_reactor_allocation()
		same_fractions(g,expected,"Capacity/health changes outside redistribution reset anchor")
	g.player.armour = 0.0;g.player.shield = 0.0
	g.set_reactor_allocation("defence",0);g.equalize_reactor_allocation();A.apply(g,ratio);A.maintain(g)
	check(N.compare(g.player.armour,0)==0 and N.compare(g.player.shield,0)==0,"All entrypoints preserve dead HP and zero shield")
	if large:check(original[0] is Dictionary and original[1] is Dictionary,"Large fixture actually exceeds float range")

func _initialize() -> void:
	exercise(false,true)
	exercise(false,false)
	exercise(true,true)
	var pools = Vitals.new()
	var full = pools.remap("armour",100.0,100.0,333.0)
	check(full==333.0,"Full fraction remains full without rounding heal")
	check(pools.remap("armour",full,333.0,0.0)==0.0,"Zero new maximum empties pool")
	check(pools.remap("armour",0.0,0.0,100.0)==0.0,"No hidden positive fraction resurrects after zero maximum")
	check(pools.remap("shield",10.0,0.0,100.0)==0.0,"Invalid old zero maximum cannot invent a fraction")
	var tiny = pools.remap("tiny",1e-200,{"m":2.0,"e":400.0},{"m":3.0,"e":450.0})
	check(N.compare(tiny,0)>0 and absf(N.ratio(tiny,1.5e-150)-1.0)<1e-10,"Extreme exponent mapping avoids an underflowing fraction")
	print("Reactor vitals ratio: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
