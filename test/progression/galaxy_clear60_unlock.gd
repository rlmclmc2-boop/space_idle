extends SceneTree
const Game=preload("res://scripts/game.gd")
var checks:Array=[]
func check(label:String,condition:bool)->void:
	assert(condition,label)
	checks.append(label)
func run()->void:
	var g=Game.new(ShipDatabase.new())
	g.save_enabled=false
	g.profile.cleared=range(1,60)
	g.profile.highestLevel=61
	g.rebuild_unlocks();g.galaxy.refresh_unlocks(g)
	check("reached61 without clear60 stays locked",not g.content_unlocked("feature","galaxy") and g.galaxy.regions.galaxy_1.state.status=="locked")
	for id in g.profile.planets:g.profile.planets[id].conquered=true
	g.rebuild_unlocks();g.galaxy.refresh_unlocks(g)
	check("six conquests do not replace clear60",not g.content_unlocked("feature","galaxy"))
	for id in g.profile.planets:g.profile.planets[id].conquered=false
	g.profile.cleared.append(60)
	g.rebuild_unlocks();g.galaxy.refresh_unlocks(g)
	check("clear60 with zero conquests opens feature",g.content_unlocked("feature","galaxy"))
	check("clear60 with zero conquests makes first galaxy available",g.galaxy.regions.galaxy_1.state.status=="available")
	check("clear60 permits actual exploration start",g.galaxy.start(g,"galaxy_1"))
	var saved:Dictionary=g.portable_save_data()
	saved.chronoSavedAt=Time.get_unix_time_from_system()
	var restored=Game.new(ShipDatabase.new());restored.save_enabled=false
	restored.load_progress_data(saved)
	check("clear60 feature survives actual save restore",restored.content_unlocked("feature","galaxy"))
	check("active first galaxy survives actual save restore",restored.galaxy.regions.galaxy_1.state.status=="exploring")
	check("later conquest condition still requires its count",not g.galaxy.condition_met(g,{"unlock_type":"conquered_planet_count","unlock_value":2}))
	g.profile.planets["1"].conquered=true;g.profile.planets["2"].conquered=true
	check("later conquest condition still accepts its count",g.galaxy.condition_met(g,{"unlock_type":"conquered_planet_count","unlock_value":2}))
	check("later galaxy completion condition remains closed",not g.galaxy.condition_met(g,{"unlock_type":"galaxy_complete","unlock_value":"galaxy_1"}))
	g.galaxy.regions.galaxy_1.state.status="complete"
	check("later galaxy completion condition still opens",g.galaxy.condition_met(g,{"unlock_type":"galaxy_complete","unlock_value":"galaxy_1"}))
	FileAccess.open("res://.runtime/galaxy-clear60-unlock.json",FileAccess.WRITE).store_string(JSON.stringify({"scope":"controlled production Game/ShipDatabase unlock contract; no fresh journey or all-max timing claim","checks":checks,"data_sha256":FileAccess.get_sha256("res://data/game_data.json"),"engine":Engine.get_version_info()},"\t"))
	print("GALAXY_CLEAR60_UNLOCK_PASS ",checks.size());quit()
func _initialize()->void:call_deferred("run")
