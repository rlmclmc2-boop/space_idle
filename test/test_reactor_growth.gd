extends SceneTree
const Growth = preload("res://scripts/reactor_allocation_growth.gd")
const Main = preload("res://scripts/main.gd")
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
	assert(game.reactor_capacity() == 106)
	assert(game.profile.reactorAllocation.weapons == 43 and game.profile.reactorAllocation.defence == 21 and game.profile.reactorAllocation.smelting == 0)
	assert(game.reactor_capacity()-game.reactor_allocated() == 42)
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
	print("PASS reactor growth: idle/zero shares, integer remainders, float/int64 boundaries, live config/research, purchase/no-heal and save round-trip")
	quit()
