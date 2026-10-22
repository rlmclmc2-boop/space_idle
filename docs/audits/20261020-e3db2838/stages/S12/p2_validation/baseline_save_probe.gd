extends SceneTree
func _initialize()->void:
	call_deferred("_run")
func _run()->void:
	GDExtensionManager.load_extension("res://space_native.gdextension")
	var db:=ShipDatabase.new()
	var started:int=Time.get_ticks_usec()
	var g:=BattleGame.new(db,false)
	var construction:int=Time.get_ticks_usec()-started
	g.state=g.State.RETREAT
	g.profile.highestLevel=int(g.hyperspace.config.unlock_stage)
	g.profile.resources["1"]={"m":1.0,"e":3800.0}
	g.profile.hyperspace.materials[db.evolution_material_id()]=1000
	g.progress_writer.path=ProjectSettings.globalize_path("user://p2-baseline-save.json")
	var owned:bool=g.progress_writer.acquire_owner()
	g.save_enabled=true
	var durations:Array=[]
	var ok:bool=owned and g.startup_error.is_empty()
	for index in 3:
		started=Time.get_ticks_usec()
		g.save_progress()
		durations.append(Time.get_ticks_usec()-started)
		ok=ok and g.last_save_error==OK
	print("P2_BASELINE_SAVE_RESULT ",JSON.stringify({"status":"PASS" if ok else "FAIL","construction_us":construction,"save_us":durations,"bytes":FileAccess.get_file_as_bytes(g.progress_writer.path).size(),"latency_verdict":"report only; diagnostic baseline"}))
	print("P2_BASELINE_SAVE_COMPLETE")
	quit(0 if ok else 1)
