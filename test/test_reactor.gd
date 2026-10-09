extends SceneTree

var failures := 0

func check(value: bool, label: String) -> void:
	if not value:
		failures += 1
		printerr("FAIL: ",label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var db := ShipDatabase.new()
	# Pin this arithmetic fixture; production upgrade pricing may change independently.
	db.config.reactorUpgradeBase = 100.0
	db.config.reactorUpgradeGrowth = 1.4
	db.config.reactorPercentScale = 100.0 # Fixed arithmetic fixture, separate from live config.
	db.config.reactorEnergyGrowth = 1.2 # Existing level-4 expectation is 100 * 1.2^3 = 172.8.
	check(not db.data.has("charge"),"Old charge table removed")
	var game := BattleGame.new(db,false)
	check(game.profile.reactorLevel == 1 and game.reactor_energy() == 100.0,"Initial level and energy")
	check(not game.upgrade_reactor(1),"Locked reactor cannot upgrade")
	game.profile.cleared = [1]
	check(game.reactor_unlocked(),"Reactor gate")
	game.profile.resources["2"] = 436.0
	check(game.reactor_max_upgrades() == 3,"MAX sums changing costs")
	check(not game.upgrade_reactor(4) and game.profile.resources["2"] == 436.0,"Unaffordable batch is atomic")
	check(game.upgrade_reactor(game.reactor_max_upgrades()),"MAX purchases all affordable levels")
	check(game.profile.reactorLevel == 4 and absf(float(game.profile.resources["2"])) < 0.00001,"Exact batch debit")
	check(absf(game.reactor_energy()-172.8)<0.00001,"Energy follows level")
	check(game.reactor_capacity() == 172,"Available energy is an integer without changing growth formula")
	check(game.set_reactor_allocation("weapons",100.9),"Weapon allocation")
	check(int(game.profile.reactorAllocation.weapons) == 100,"Fractional input is rounded down")
	check(game.set_reactor_allocation("defence",100),"Defence allocation clamps")
	check(game.reactor_allocated() == 172,"Total never exceeds integer capacity")
	check(int(game.profile.reactorAllocation.defence) == 72,"Second slider limited by integer remainder")
	check(absf(game.reactor_multiplier("weapons")-(1.0+pow(100.0,0.8)/100.0))<0.00001,"Configured module exponent")
	check(game.set_reactor_allocation("weapons",0),"Allocation changes immediately")
	check(game.reactor_multiplier("weapons") == 1.0,"Zero allocation clears boost")
	var uranium_before := float(game.profile.resources["2"])
	check(game.equalize_reactor_allocation(),"Automatic equal allocation")
	check(game.reactor_allocated() == 172,"Equalization keeps the integer remainder")
	for key in game.reactor_available_modules():
		check(int(game.profile.reactorAllocation[key]) in [57,58],"Integer equal share: "+key)
	check(float(game.profile.resources["2"]) == uranium_before,"Equal allocation does not spend uranium")
	var defence_before := float(game.profile.reactorAllocation.defence)
	check(game.set_reactor_allocation("weapons",10),"One module can change after equalization")
	check(float(game.profile.reactorAllocation.defence) == defence_before,"Single slider leaves other modules unchanged")
	var raw := {"reactorLevel":2,"reactorAllocation":{"weapons":90.7,"defence":90,"smelting":90},"charge":{"攻击充能":{"level":999}}}
	game.load_reactor(raw)
	check(game.profile.reactorLevel == 2 and game.reactor_allocated() <= game.reactor_capacity() and int(game.profile.reactorAllocation.weapons) == 90,"Loaded allocation is integer and clamped")
	check(not game.profile.has("charge"),"Legacy charge state ignored")
	var batch := BattleGame.new(db,false)
	batch.profile.cleared = [1]
	batch.profile.resources["2"] = 1000000.0
	var expected_cost := 0.0
	for level in range(1,11):expected_cost += ceilf(100.0*pow(1.4,level-1))
	check(batch.upgrade_reactor(10),"x10 batch succeeds")
	check(batch.profile.reactorLevel == 11 and absf(float(batch.profile.resources["2"])-(1000000.0-expected_cost))<0.00001,"x10 pays every level cost")
	var smelt := BattleGame.new(db,false)
	smelt.profile.cleared = [1]
	smelt.set_reactor_allocation("smelting",100)
	smelt.start(1,false)
	smelt.spawn_group()
	var enemy: Dictionary = smelt.enemies[0]
	enemy.hp = 1.0
	enemy.res_ratio = 1.0
	enemy.drops = [{"resourceId":1,"amount":100.0,"chance":1.0},{"resourceId":2,"amount":100.0,"chance":1.0}]
	smelt.hit_enemy(enemy,10000,0)
	var iron := smelt.drops.filter(func(drop):return str(drop.get("id","")) == "1")
	var uranium := smelt.drops.filter(func(drop):return str(drop.get("id","")) == "2")
	check(iron.size()==1 and uranium.size()==1,"Both enemy drops generated")
	if iron.size()==1 and uranium.size()==1:
		check(float(iron[0].amount)>100.0 and float(uranium[0].amount)==100.0,"Smelting boosts only enemy iron")
	print("reactor failures: ",failures)
	quit(1 if failures else 0)
