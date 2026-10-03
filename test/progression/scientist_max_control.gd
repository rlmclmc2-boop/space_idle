extends SceneTree
const Game=preload("res://qa/presented_balance_game.gd")
const Policy=preload("res://qa/sparse_policy.gd")
const Metrics=preload("res://scripts/balance_metrics.gd")
func _initialize():call_deferred("run")
func run():
	var path=OS.get_environment("PROGRESSION_SCIENCE_CHECKPOINT")
	assert(not path.is_empty())
	var cp:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path));var rows:Array=[]
	for mode in ["one","ten","max"]:
		var g=Game.new(ShipDatabase.new());g.simulated_time=float(cp.x1_seconds)
		var raw:Dictionary=cp.save.duplicate(true);raw.chronoSavedAt=Time.get_unix_time_from_system()
		g.load_progress_data(raw);g.profile.chronoParticles=float(raw.get("chronoParticles",0));g.login_chrono_particles=0;g.resume_progress()
		var metrics=Metrics.new();g.metrics=metrics;metrics.initialize(g)
		var policy=Policy.new();policy.scientist_batch_mode=mode=="ten";policy.scientist_max_mode=mode=="max"
		var calls:Array=[];policy.journal=func(kind,extra):calls.append({"kind":kind,"payload":extra})
		var before:int=int(g.profile.scientists);var resources:Dictionary=g.profile.resources.duplicate(true)
		policy.buy_scientist(g,0.1)
		var delta:int=int(g.profile.scientists)-before
		assert(delta==int(metrics.uses.get("scientists",0)))
		assert(delta>0)
		rows.append({"mode":mode,"before":before,"after":g.profile.scientists,"purchased":delta,"metrics_purchased":metrics.uses.scientists,"before_resources":resources,"after_resources":g.profile.resources.duplicate(true),"journal":calls})
		policy.journal=Callable()
	assert(rows[0].purchased==1 and rows[1].purchased==10 and rows[2].purchased>10)
	var output={"pass":true,"checkpoint":path,"rows":rows,"scope":"Same legal saved post-reforge profile, one real public science-button action per case;1/+10 reserve-limited versus MAX without reserve. Purchases/resources/counting only; no progression timing or human-strategy acceptance."}
	var file=FileAccess.open("res://.runtime/scientist-max-control.json",FileAccess.WRITE);file.store_string(JSON.stringify(output,"\t"));file.close()
	print("SCIENTIST_MAX_CONTROL ",JSON.stringify(output));quit()
