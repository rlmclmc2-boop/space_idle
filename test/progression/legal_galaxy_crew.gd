extends SceneTree
const Game=preload("res://scripts/balance_game.gd")
const Policy=preload("res://qa/sparse_policy.gd")
func _initialize() -> void:
	var g=Game.new(ShipDatabase.new())
	g.metrics=preload("res://scripts/balance_metrics.gd").new();g.metrics.initialize(g)
	g.profile.cleared=range(1,61);g.profile.highestLevel=61;g.stage=60;g.rebuild_unlocks()
	for id in g.profile.planets:g.profile.planets[id].conquered=true
	g.galaxy.refresh_unlocks(g)
	var policy=Policy.new();policy.allow_reforge=false;policy.configure("BALANCED",20261002)
	policy.act(g,0)
	var count:int=g.galaxy.crew_count(g,"galaxy_1")
	assert(count==6)
	assert(g.galaxy.regions.galaxy_1.state.status=="exploring")
	for member in g.profile.crew:
		if member.assignmentType=="galaxy_explore":assert(g.crew.unlocked(g,member.crewId))
	print("LEGAL_GALAXY_CREW_PASS actual=",count," authored_max=",g.crew.assignments(g).galaxy_explore.maxCrew," scope=controlled unlock fixture, not fresh progression")
	quit()
