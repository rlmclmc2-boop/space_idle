extends SceneTree
const Game=preload("res://qa/clock_game.gd")
func _initialize() -> void:
	var cases := 0
	for status in ["built","ready","building"]:
		var g=Game.new(ShipDatabase.new(),false)
		g.profile.cleared=range(1,36);g.profile.highestLevel=36;g.rebuild_unlocks()
		var old := {"status":status,"build_progress":7.5,"crew":["engineer"] if status=="building" else []}
		var planet:Dictionary=g.planet_progress("2")
		planet.buildings={"shipyard":old.duplicate(true)}
		g.planet_buildings.sync(g,"2")
		assert(not planet.buildings.has("shipyard"))
		assert(planet.buildings.shipyard_later==old)
		g.planet_buildings.sync(g,"2")
		assert(planet.buildings.shipyard_later==old)
		cases+=1
	var first=Game.new(ShipDatabase.new(),false)
	first.profile.cleared=range(1,31);first.profile.highestLevel=31;first.rebuild_unlocks()
	var original:Dictionary=first.planet_buildings.state(first,"1","shipyard").duplicate(true)
	first.planet_buildings.sync(first,"1")
	assert(first.planet_buildings.state(first,"1","shipyard")==original)
	assert(not first.planet_progress("1").buildings.has("shipyard_later"))
	print("MIGRATION_PASS cases=",cases," first_identity_preserved=true")
	quit()
