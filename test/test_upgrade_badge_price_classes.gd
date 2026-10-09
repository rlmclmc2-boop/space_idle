extends SceneTree
## Compare the retained price set with exhaustive authoritative forge plans.
const Badges=preload("res://scripts/system_upgrade_badges.gd")
const Forge=preload("res://scripts/drone_forge.gd")
const Rewards=preload("res://scripts/drone_rewards.gd")
const Bag=preload("res://scripts/drone_inventory.gd")
const Permission=preload("res://scripts/hyperspace_permissions.gd")
var checks:=0
func canonical(costs:Array)->Array:
	var result:Array=[]
	for cost in costs:result.append(JSON.stringify(cost,"",true,true))
	result.sort()
	return result
func exhaustive(g)->Array:
	var result:Array=[]
	var state:Dictionary=g.profile.hyperspace
	for id in state.inventory.drones:
		if state.inventory.sealed.has(id):continue
		for operation in Badges.PAID_MODIFICATIONS:
			# A complete independent working copy avoids depending on the
			# production query's selective-copy or price-class implementation.
			var preview:Dictionary=state.duplicate(true)
			var plan:=Forge.plan(preview,g.hyperspace.config,{"operation":operation,"drone_id":id,"args":{}},g)
			if plan.error not in ["","insufficient_materials"]:continue
			var cost:Dictionary=plan.get("cost",{})
			if cost.is_empty() or not cost.values().any(func(value):return float(value)>0):continue
			if not Bag.valid_drone(preview.inventory.drones[id],g.hyperspace.config):continue
			if not Bag.equipment_valid(preview.inventory,preview.inventory.equipped,int(g.hyperspace.config.maximum_equipped),g.hyperspace.config):continue
			if not g.hyperspace.equipment_constraints(g,preview.inventory.equipped,preview.inventory):continue
			if not result.has(cost):result.append(cost)
	return result
func compare(g,label:String)->void:
	var before:=JSON.stringify(g.profile)
	var combat_rng:int=g.rng.state
	var badge:=Badges.new()
	badge.game=g
	var expected:=exhaustive(g)
	var actual:=badge.drone_quotes()
	assert(canonical(actual)==canonical(expected),label+" retains every attainable price")
	assert(JSON.stringify(g.profile)==before and g.rng.state==combat_rng,label+" leaves state and RNG unchanged")
	# The same price set must answer exact thresholds after a currency event,
	# without refreshing the price classes or retaining an affordability result.
	badge.quotes[9]=actual
	for cost in expected:
		for id in g.profile.hyperspace.materials:g.profile.hyperspace.materials[id]=0
		g.profile.hyperspace.ultimate_cores=0
		for id in cost:
			if id=="ultimate_cores":g.profile.hyperspace.ultimate_cores=int(cost[id])
			else:g.profile.hyperspace.materials[id]=int(cost[id])
		assert(badge.affordable(9),label+" exact attainable price remains affordable")
		checks+=1
	checks+=2
	badge.free()
func _initialize()->void:call_deferred("run")
func run()->void:
	var g:=BattleGame.new(ShipDatabase.new(),false)
	g.save_enabled=false
	g.profile.highestLevel=40;g.profile.cleared=range(1,41);g.rebuild_unlocks()
	g.profile.selectedShip="Heavy_Battleship"
	var state:Dictionary=g.profile.hyperspace
	state.unlocked_drones=true
	var rng:=RandomNumberGenerator.new();rng.seed=234
	for i in 24:
		var weapon:String=["laser","missile","cannon","longLaser"][i%4]
		var level:int=[1,2,10,39][i%4]
		var quality:String="legendary" if i%5==0 else "blue" if i%3==0 else "white"
		var drone:=Rewards.create_drone(rng,g.hyperspace.config,"price-class:%d"%i,quality,weapon,level,Permission.planet_for_level(g.db.data,level))
		if i%4==0:
			for affix in drone.affixes:affix.locked=true
		if i==0:
			drone.ultimate=true
			drone.ultimate_affix=Rewards.affix(rng,g.hyperspace.config,weapon)
		assert(Bag.insert(state.inventory,drone,g.hyperspace.config))
	compare(g,"no record / empty currency / first drone ineligible")
	for route in g.hyperspace.config.routes:state.history[route]={"40":{},"41":{}}
	for weapon in ["laser","missile","cannon","longLaser"]:
		assert(Forge.modernization_target(state,g.hyperspace.config,weapon,40)==40,"modernization excludes records above the highest level")
		assert(Forge.modernization_target(state,g.hyperspace.config,weapon,39)==0,"no available modernization record")
		checks+=2
	for id in state.materials:state.materials[id]=1000000000
	state.ultimate_cores=100
	compare(g,"modernization records and mixed levels/tiers/locks")
	state.inventory.equipped=["price-class:1","price-class:2"]
	state.inventory.warehouse.erase("price-class:1");state.inventory.warehouse.erase("price-class:2")
	state.inventory.sealed["price-class:5"]=5
	compare(g,"equipped and sealed members")
	var config:Dictionary=g.hyperspace.config.duplicate(true)
	config.material_unit_scale=20
	config.lock_cost_multiplier=3
	config.modernization_base_coefficient=2
	config.modernization_legendary_multiplier=4
	for operation in config.forge_costs:
		for id in config.forge_costs[operation]:config.forge_costs[operation][id]*=2
	g.hyperspace.config=config
	compare(g,"distinct pricing configuration")
	state.inventory.sealed.clear()
	for id in state.inventory.drones:
		if id!="price-class:23":state.inventory.sealed[id]=1
	compare(g,"last remaining eligible member")
	print("PASS upgrade badge price classes: ",checks," checks")
	quit()
