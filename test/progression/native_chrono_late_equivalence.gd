extends SceneTree
const Game=preload("res://qa/presented_balance_game.gd")
const Driver=preload("res://qa/scene_driver.gd")
func serializable(value):
	if value is float and not is_finite(value):return str(value)
	if value is Array:
		var result:Array=[]
		for item in value:result.append(serializable(item))
		return result
	if value is Dictionary:
		var result:Dictionary={}
		for key in value:result[key]=serializable(value[key])
		return result
	return value
func signature(g)->Dictionary:
	return {"stage":g.stage,"node":g.group_index,"state":g.state,"distance":g.distance,"player":g.player,"enemies":g.enemies,"resources":g.profile.resources,"loadout":g.profile.loadout,"tech":g.profile.hightechLevels,"points":g.profile.techPoints,"scientists":g.profile.scientists,"assignments":g.profile.scientistAssignments,"reactor":g.profile.reactorLevel,"allocation":g.profile.reactorAllocation,"rng":str(g.rng.state),"cleared":g.profile.cleared,"production":g.production_time(),"furnace_peak":g.profile.furnaceIncomePeak,"projectiles":g.projectiles,"queue":g.missile_queue,"drops":g.drops,"motion_clock":g.motion_clock,"crew":g.profile.crew,"planets":g.profile.planets,"galaxies":g.profile.get("galaxies",{}),"enhancement":g.profile.get("enhancementBranches",{}),"enhancement_level":g.profile.get("enhancementLevel",0),"jewels":g.profile.get("jewels",{})}
func _initialize():call_deferred("run")
func run():
	var path=OS.get_environment("PROGRESSION_CHRONO_CHECKPOINT")
	assert(not path.is_empty())
	var checkpoint:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	var games:Array=[];var drivers:Array=[]
	for index in 2:
		var g=Game.new(ShipDatabase.new());g.stat_cache_enabled=true
		g.simulated_time=float(checkpoint.x1_seconds)
		var raw:Dictionary=checkpoint.save.duplicate(true);raw.chronoSavedAt=Time.get_unix_time_from_system()
		g.load_progress_data(raw);g.profile.chronoParticles=54.0 if index==1 else 0.0;g.login_chrono_particles=0
		g.resume_progress();g.rng.state=int(str(checkpoint.rng_state));g.speed=10.0 if index==1 else 1.0
		var driver=Driver.new();driver.setup(self,g);driver.scene.automation_args=[]
		games.append(g);drivers.append(driver)
	var observations:Array=[]
	for frame in 360:
		var before:float=games[1].simulated_time
		drivers[1].scene._process(1.0/60.0)
		var steps:int=roundi((games[1].simulated_time-before)*60.0)
		for tick in steps:drivers[0].scene._process(1.0/60.0)
		var a=JSON.parse_string(JSON.stringify(serializable(signature(games[0]))));var b=JSON.parse_string(JSON.stringify(serializable(signature(games[1]))))
		if a!=b:
			var f=FileAccess.open("res://.runtime/native-chrono-late-mismatch.json",FileAccess.WRITE);f.store_string(JSON.stringify({"frame":frame,"x1":games[1].simulated_time,"baseline":a,"boosted":b},"\t"));f.close()
			printerr("NATIVE_CHRONO_LATE_MISMATCH frame=",frame," x1=",games[1].simulated_time);quit(1);return
		if frame%60==59:observations.append({"frame":frame,"x1":games[1].simulated_time,"chrono":games[1].profile.chronoParticles,"rng":str(games[1].rng.state),"stage":games[1].stage})
	assert(absf(games[1].profile.chronoParticles)<0.000001)
	var output={"pass":true,"checkpoint":path,"input_x1":checkpoint.x1_seconds,"final_x1":games[1].simulated_time,"compared_boost_frames":360,"observations":observations,"scope":"Two native scene._process paths, same legal saved profile/RNG, no manual actions;54 offline chrono plus6 real seconds equals60 X1. Every shared boosted-frame boundary compares complete combat/economy/research/crew/planet/galaxy signatures; not a full-fresh timing proof."}
	var file=FileAccess.open("res://.runtime/native-chrono-late.json",FileAccess.WRITE);file.store_string(JSON.stringify(output,"\t"));file.close()
	for driver in drivers:driver.close()
	print("NATIVE_CHRONO_LATE_PASS ",JSON.stringify(output));quit()
