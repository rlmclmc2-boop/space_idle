extends SceneTree
const Growth = preload("res://scripts/reactor_allocation_growth.gd")
const Main = preload("res://scripts/main.gd")
const Preview = preload("res://scripts/reactor_upgrade_preview.gd")
class LargeCapacityGame extends BattleGame:
	func reactor_capacity() -> int:return 9007199254740999
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var keys: Array = ["weapons","defence","smelting"]
	var result := Growth.expand(keys,{"weapons":2,"defence":1,"smelting":0},7,23)
	assert(result == {"weapons":7,"defence":3,"smelting":0})
	assert(23-int(result.weapons)-int(result.defence) == 13,"idle share survives growth")
	result = Growth.expand(keys,{"weapons":0,"defence":0,"smelting":0},100,106)
	assert(result.values().all(func(value):return value == 0),"zero allocation stays reserved")
	result = Growth.expand(keys,{"weapons":228,"defence":228,"smelting":228},684,725)
	assert(result == {"weapons":242,"defence":242,"smelting":241})
	result = Growth.expand(keys,{"weapons":3002399751580331,"defence":3002399751580331,"smelting":3002399751580331},9007199254740993,9007199254740999)
	assert(result.values().all(func(value):return value == 3002399751580333),"shares above float precision remain exact")
	assert(Growth.product_share(9223372036854775806,9223372036854775805,9223372036854775807) == [9223372036854775804,2],"no int64 multiply overflow")
	var db := ShipDatabase.new()
	assert(float(db.config.techPointGet) == 3 and float(db.config.reactorPercentScale) == 50 and float(db.config.reactorUpgradeBase) == 5)
	var game := BattleGame.new(db,false)
	game.profile.cleared = [1,2,3,4]
	game.rebuild_unlocks()
	game.profile.scientists = 3
	game.profile.scientistAssignments = {"正电子聚焦装置":3}
	assert(game.research_rate("正电子聚焦装置") == 9)
	game.profile.reactorAllocation = {"weapons":40,"defence":20,"smelting":0,"condensation":0}
	game.profile.resources["2"] = game.reactor_upgrade_cost()
	game.player.armour = 1.0
	game.player.shield = 0.0
	assert(game.upgrade_reactor(1))
	var expected_capacity := floori(float(db.config.reactorEnergyBase)*float(db.config.reactorEnergyGrowth))
	assert(game.reactor_capacity() == expected_capacity)
	assert(game.profile.reactorAllocation == Growth.expand(Array(game.reactor_modules()),{"weapons":40,"defence":20,"smelting":0,"condensation":0},100,expected_capacity))
	assert(game.profile.reactorAllocation.smelting == 0 and game.reactor_capacity()-game.reactor_allocated()>0)
	assert(game.player.armour == 1.0 and game.player.shield == 0.0,"power purchase cannot heal")
	var saved := {"reactorLevel":game.profile.reactorLevel,"reactorAllocation":game.profile.reactorAllocation.duplicate()}
	var restored := BattleGame.new(db,false)
	restored.profile.cleared = game.profile.cleared.duplicate()
	restored.rebuild_unlocks()
	restored.load_reactor(saved)
	assert(restored.profile.reactorAllocation == game.profile.reactorAllocation,"existing save fields round-trip without migration")
	var large := LargeCapacityGame.new(db,false)
	large.profile.cleared = [1]
	large.rebuild_unlocks()
	large.load_reactor({"reactorLevel":1,"reactorAllocation":{"weapons":9007199254740997}})
	assert(large.profile.reactorAllocation.weapons == 9007199254740997,"integer save allocations do not round through float")
	# Compare read-only quotes to actual purchases, including batch rounding and
	# planetary free power. A quote must neither spend resources nor change shares.
	for level in [2,37]:
		for count in [1,10]:
			var buyer := BattleGame.new(db,false)
			buyer.profile.cleared = range(1,101)
			buyer.rebuild_unlocks()
			buyer.profile.reactorLevel = level
			buyer.profile.resources["2"] = 1.0e12
			buyer.profile.planets["1"].conquered = true
			buyer.equalize_reactor_allocation()
			var before: Dictionary = buyer.profile.duplicate(true)
			var quote := Preview.quote(buyer,count)
			assert(buyer.profile == before,"purchase preview is read-only")
			assert(buyer.upgrade_reactor(count))
			assert(quote.next_capacity == buyer.reactor_capacity() and quote.allocation == buyer.profile.reactorAllocation,"quote follows actual integer batch allocation")
			assert(absf(float(before.resources["2"])-float(buyer.profile.resources["2"])-float(quote.cost))<0.001,"quote includes every purchased level cost")
			for key in quote.effects:
				assert(is_equal_approx(quote.effects[key].next,buyer.reactor_multiplier(key)),"quoted effect agrees with purchased effect including free power")
	var idle_quote := Preview.quote(restored,0)
	assert(idle_quote.count == 0 and idle_quote.cost == 0 and idle_quote.next_capacity == restored.reactor_capacity(),"unaffordable MAX quotes no purchase")
	db.config.reactorEnergyGrowth = 1.12
	db.config.reactorBoostExponent = 0.9
	db.config.reactorPercentScale = 80
	var alternate := Preview.quote(restored,1)
	restored.profile.resources["2"] = 1.0e6
	assert(restored.upgrade_reactor(1))
	assert(is_equal_approx(alternate.effects.weapons.next,restored.reactor_multiplier("weapons")),"projection reads alternate valid config")
	# This candidate is a new config version, not a legacy-economy migration.
	var candidate_db := ShipDatabase.new()
	var same_level := BattleGame.new(candidate_db,false)
	same_level.profile.cleared=[1];same_level.rebuild_unlocks()
	var raw: Dictionary=JSON.parse_string(JSON.stringify({"reactorLevel":47,"reactorAllocation":{"weapons":100,"defence":100,"smelting":0}}))
	same_level.load_reactor(raw)
	assert(is_equal_approx(same_level.reactor_energy(),float(candidate_db.config.reactorEnergyBase)*pow(float(candidate_db.config.reactorEnergyGrowth),46)),"existing test level uses the same current formula, without persistent capacity or migration")
	var base_energy := same_level.reactor_energy()
	for speed_value in [1.0,2.0,10.0]:
		same_level.speed=speed_value;same_level.tick(0.01)
	assert(same_level.reactor_energy()==base_energy,"time and speed do not compound capacity")
	var boundary := BattleGame.new(candidate_db,false)
	boundary.profile.cleared=[1];boundary.rebuild_unlocks()
	var limit: int=preload("res://scripts/reactor_growth.gd").CAPACITY_LIMIT
	var last_level := 1+floori(log(float(limit)/float(candidate_db.config.reactorEnergyBase))/log(float(candidate_db.config.reactorEnergyGrowth)))
	boundary.profile.reactorLevel=last_level-1
	boundary.profile.resources["2"]=1.0e60
	assert(boundary.reactor_max_upgrades()==1)
	var before_boundary: Dictionary=boundary.profile.duplicate(true)
	assert(not boundary.upgrade_reactor(10) and boundary.profile==before_boundary,"overflowing batch cannot charge or change allocations")
	var boundary_quote := Preview.quote(boundary,boundary.reactor_max_upgrades())
	assert(boundary.upgrade_reactor(1) and boundary.reactor_capacity()==boundary_quote.next_capacity,"last safe MAX quote agrees with purchase")
	before_boundary=boundary.profile.duplicate(true)
	assert(boundary.reactor_max_upgrades()==0 and not boundary.upgrade_reactor(1) and boundary.profile==before_boundary,"integer boundary stops charging unusable levels")
	assert(Preview.quote(boundary,10).next_capacity==limit,"disabled overflow preview clamps safely without integer wraparound")
	print("PASS reactor candidate: same-level config formula / JSON test load, speed independence, MAX quote and integer-boundary atomicity")
	print("PASS reactor growth: idle/zero shares, integer remainders, float/int64 boundaries, live config/research, purchase/no-heal and save round-trip")
	quit()
