extends SceneTree
const Adapter=preload("res://qa/presented_balance_game.gd")
const Driver=preload("res://qa/scene_driver.gd")
const Policy=preload("res://scripts/balance_autoplayer.gd")
class Native extends "res://scripts/presented_battle_game.gd":
	var simulated_time:=0.0
	func _init(db):
		super(db,false);profile.hightechSavedAt=0.0
	func economy_time()->float:return simulated_time
	func tick(dt:float)->void:
		simulated_time+=dt;super.tick(dt)
var scenes:Array=[]
func signature(g)->Dictionary:
	return {"stage":g.stage,"node":g.group_index,"state":g.state,"distance":g.distance,"player":g.player,"enemies":g.enemies,"resources":g.profile.resources,"loadout":g.profile.loadout,"tech":g.profile.hightechLevels,"points":g.profile.techPoints,"scientists":g.profile.scientists,"assignments":g.profile.scientistAssignments,"reactor":g.profile.reactorLevel,"allocation":g.profile.reactorAllocation,"rng":str(g.rng.state),"cleared":g.profile.cleared,"production":g.production_time(),"furnace_peak":g.profile.furnaceIncomePeak,"projectiles":g.projectiles,"queue":g.missile_queue,"drops":g.drops,"motion_clock":g.motion_clock,"crew":g.profile.crew,"planets":g.profile.planets,"galaxies":g.profile.get("galaxies",{}),"enhancement":g.profile.get("enhancementBranches",{}),"enhancement_level":g.profile.get("enhancementLevel",0),"jewels":g.profile.get("jewels",{})}
func _initialize():call_deferred("run")
func run():
	var a=Adapter.new(ShipDatabase.new());var b=Native.new(ShipDatabase.new())
	a.stat_cache_enabled=true;b.stat_cache_enabled=true
	a.rng.seed=20261002;b.rng.seed=20261002
	var checkpoint_path:=OS.get_environment("PROGRESSION_COMPARE_CHECKPOINT")
	if not checkpoint_path.is_empty():
		var checkpoint:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(checkpoint_path))
		for game in [a,b]:
			game.simulated_time=float(checkpoint.x1_seconds)
			var raw:Dictionary=checkpoint.save.duplicate(true)
			raw.chronoSavedAt=Time.get_unix_time_from_system()
			game.load_progress_data(raw);game.profile.chronoParticles=float(raw.get("chronoParticles",0));game.login_chrono_particles=0
			game.resume_progress();game.rng.state=int(str(checkpoint.rng_state))
		print("FORMAL_COMPARE_CHECKPOINT diagnostic=",checkpoint_path," input_seconds=",a.simulated_time," config_sha256=",FileAccess.get_sha256("res://data/game_data.json"))
	var scene_mode:=OS.get_environment("PROGRESSION_COMPARE_SCENE")=="1"
	var drivers:Array=[]
	if scene_mode:
		for game in [a,b]:
			var driver=Driver.new();driver.setup(self,game);driver.scene.automation_args=[];drivers.append(driver);scenes.append(driver.scene)
	var policies=[Policy.new(),Policy.new()]
	for policy in policies:policy.configure("BALANCED",20261002)
	var duration:=int(OS.get_environment("PROGRESSION_COMPARE_DURATION"))
	if duration<=0:duration=900
	var next_visit:=0.0
	for step in duration*60:
		if step/60.0+.000001>=next_visit:
			for index in 2:
				var game=a if index==0 else b
				for drop in game.drops.duplicate():game.collect(drop,true)
				policies[index].act(game,step/60.0)
			next_visit=step/60.0+(10.0 if a.profile.highestLevel<=5 else 120.0)
		if scene_mode:
			drivers[0].before_tick(1.0/60.0);a.tick(1.0/60.0);drivers[0].after_tick(1.0/60.0)
			# Independent native path: call the production battlefield/main frame.
			scenes[1]._process(1.0/60.0)
		else:
			a.tick(1.0/60.0);b.tick(1.0/60.0)
		if (step+1)%60==0:
			var left=JSON.parse_string(JSON.stringify(signature(a)));var right=JSON.parse_string(JSON.stringify(signature(b)))
			if left!=right:
				var f=FileAccess.open("res://.runtime/formal-adapter-mismatch.json",FileAccess.WRITE);f.store_string(JSON.stringify({"second":(step+1)/60,"adapter":left,"native":right},"\t"));f.close()
				printerr("FORMAL_ADAPTER_MISMATCH second=",(step+1)/60);quit(1);return
		if (step+1)%36000==0:print("FORMAL_COMPARE_HEARTBEAT seconds=",(step+1)/60," stage=",a.stage)
	print("FORMAL_ADAPTER_PASS seconds=",duration," scene_providers=",scene_mode," stage=",a.stage," node=",a.group_index," scope=full scene event hook; driver versus native production frame; same sparse decisions; every-second state/resources/RNG/research/queue check")
	for scene in scenes:scene.queue_free()
	quit()
