extends SceneTree

class ClockGame extends BattleGame:
	var qa_wall := 100000.0
	var qa_game := 0.0
	func economy_time() -> float:return qa_wall
	func tick(dt: float) -> void:
		qa_wall += dt/speed
		qa_game += dt
		super.tick(dt)

func _initialize() -> void:call_deferred("run")

func simulate(raw: Dictionary, multiplier: float, step: float) -> Dictionary:
	var g := ClockGame.new(ShipDatabase.new(),false)
	g.rng.seed=170310
	g.load_progress_data(raw.duplicate(true))
	g.stat_cache_enabled=true
	g.speed=multiplier
	g.profile.chronoParticles=g.chrono_capacity()
	g.profile.hightechSavedAt=g.qa_wall
	g.resume_progress()
	var counts: Dictionary = {}
	g.event.connect(func(kind: String,_payload: Dictionary):counts[kind]=int(counts.get(kind,0))+1)
	var initial_resources: Dictionary = g.profile.resources.duplicate(true)
	var samples: Array = []
	var next_snapshot:=60.0
	for i in int(round(600.0/step)):
		if not g.pending_unlocks.is_empty():g.acknowledge_unlocks()
		g.tick(step)
		if g.qa_game+0.00001>=next_snapshot:
			samples.append({"time":g.qa_game,"stage":g.stage,"wave":g.group_index,"resources":g.profile.resources.duplicate(true),"furnace_peak":g.profile.get("furnaceIncomePeak",null)})
			next_snapshot+=60.0
	return {"multiplier":multiplier,"step":step,"game_seconds":g.qa_game,"equivalent_real_seconds":g.qa_wall-100000.0,"initial_resources":initial_resources,"final_resources":g.profile.resources,"events":counts,"stage":g.stage,"wave":g.group_index,"cleared":g.profile.cleared,"hightech":g.profile.hightechLevels,"furnace_peak":g.profile.get("furnaceIncomePeak",null),"rng_state":str(g.rng.state),"snapshots":samples}

func run() -> void:
	var input_path:="res://.runtime/parent-direct-first-hour/evidence.json"
	var raw: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(input_path)).profile
	var records: Array=[]
	for setting in [[1.0,1.0/60.0],[10.0,1.0/60.0],[10.0,1.0/15.0]]:
		var record:=simulate(raw,float(setting[0]),float(setting[1]))
		records.append(record)
		print("PARENT_CHRONO ",JSON.stringify(record))
	var output:="res://.runtime/parent-chrono-probe.json"
	var file:=FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"commit":"04a5a307bcef9325efa9026e1ca94affa577e10d","scope":"controlled parent first-hour profile restart; no user decisions, no particle accounting; compares game-speed economic clock and coarse battle steps, not end-to-end idle acceptance","engine":Engine.get_version_info().string,"runs":records},"\t"))
	quit(0)
