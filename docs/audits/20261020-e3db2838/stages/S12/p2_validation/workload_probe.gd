extends SceneTree
const Transfer=preload("res://scripts/save_transfer.gd")
const Writer=preload("res://scripts/progress_writer.gd")
var failure:=""
func _initialize()->void:
	Engine.max_fps=60
	call_deferred("_run")
func _run()->void:
	print("P2_WORKLOAD_STEP begin")
	if GDExtensionManager.load_extension("res://space_native.gdextension") not in [0,2]:failure="DLL"
	print("P2_WORKLOAD_STEP DLL")
	var actor=load("res://main.tscn").instantiate()
	print("P2_WORKLOAD_STEP scene")
	root.add_child(actor)
	print("P2_WORKLOAD_STEP ready")
	current_scene=actor
	actor.automation_args.erase("--capture")
	actor.set_process(false)
	var g=actor.game
	g.paused=true
	g.state=g.State.RETREAT
	g.profile.highestLevel=int(g.hyperspace.config.unlock_stage)
	g.profile.grantedUnlocks=[g.db.unlock_id("hightech",g.FURNACE)]
	g.profile.resources["1"]={"m":1.0,"e":3800.0}
	g.profile.hyperspace.materials[g.db.evolution_material_id()]=1000
	g.profile.aiTechInput={"1":1,"2":0}
	if not g.select_tech("singularity"):failure="research select"
	g.progress_writer.path=ProjectSettings.globalize_path("user://p2-workload-progress.json")
	if not g.progress_writer.acquire_owner():failure="save owner"
	g.save_enabled=true
	actor.build_ui()
	print("P2_WORKLOAD_STEP UI")
	actor.select_system(0)
	var panel=actor.equipment_panel
	var start:int=Time.get_ticks_usec()
	panel.set_upgrade_amount(0)
	print("P2_WORKLOAD_STEP requested")
	var preparation_us:int=Time.get_ticks_usec()-start
	var requests_after_open:int=g.equipment_queries._next_id-1
	var ui_max:=0
	var economy_max:=0
	var save_max:=0
	var heartbeat:=0
	var previous:int=Time.get_ticks_usec()
	var saves:=0
	for frame in 600:
		await process_frame
		if frame%120==0 or frame<4:print("P2_WORKLOAD_STEP frame ",frame)
		var now:int=Time.get_ticks_usec()
		heartbeat=maxi(heartbeat,now-previous);previous=now
		var work:int=Time.get_ticks_usec()
		if g.currency_income("1",1).status!="committed":failure="credit"
		if frame<4:print("P2_WORKLOAD_STEP credit ",frame)
		g.AITech.advance(g,1.0/60.0)
		if frame<4:print("P2_WORKLOAD_STEP research ",frame)
		if frame%30==0:
			var drop:Dictionary={"id":"1","amount":3.0,"production_base":3.0,"age":1.0}
			g.drops.append(drop);g.collect(drop,true)
			if g.drops.has(drop):failure="source drop"
		if frame%60==0:
			g.galaxy._income_due.append({"id":"1","amount":5.0,"time":float(frame)/60.0,"production_time":1.0})
			if not g.galaxy.deliver_income(g):failure="galaxy receipt"
		economy_max=maxi(economy_max,Time.get_ticks_usec()-work)
		work=Time.get_ticks_usec()
		actor._process(1.0/60.0)
		if frame<4:print("P2_WORKLOAD_STEP main ",frame)
		panel.refresh_pending()
		if frame<4:print("P2_WORKLOAD_STEP panel ",frame)
		ui_max=maxi(ui_max,Time.get_ticks_usec()-work)
		if frame%120==0:
			print("P2_WORKLOAD_STEP save begin ",frame)
			work=Time.get_ticks_usec();g.save_progress()
			print("P2_WORKLOAD_STEP save end ",frame)
			save_max=maxi(save_max,Time.get_ticks_usec()-work);saves+=1
			if g.last_save_error!=OK:failure="save"
	var transfer:=Transfer.new()
	var work:int=Time.get_ticks_usec()
	var export_error:Error=transfer.export_progress(g,"user://p2-workload-portable.json")
	var export_us:int=Time.get_ticks_usec()-work
	work=Time.get_ticks_usec()
	var portable:Dictionary=transfer.prepare("user://p2-workload-portable.json",g.db)
	var portable_load_us:int=Time.get_ticks_usec()-work
	work=Time.get_ticks_usec()
	var disk:Dictionary=Writer.read_progress_result(g.progress_writer.path,g.db)
	var ordinary_load_us:int=Time.get_ticks_usec()-work
	var counts:Dictionary={}
	for job in g.equipment_queries._jobs.values():counts[job.status]=int(counts.get(job.status,0))+1
	var duration:int=Time.get_ticks_usec()-start
	var passed:bool=failure.is_empty() and export_error==OK and portable.error.is_empty() and disk.status=="loaded" and heartbeat<=50000 and g.equipment_queries._next_id-1==requests_after_open
	print("P2_WORKLOAD_RESULT ",JSON.stringify({"status":"PASS" if passed else "FAIL","failure":failure,"frames":600,"duration_us":duration,"ui_open_preparation_us":preparation_us,"ui_step_max_us":ui_max,"economy_step_max_us":economy_max,"heartbeat_max_us":heartbeat,"save_max_us":save_max,"saves":saves,"portable_export_us":export_us,"portable_load_us":portable_load_us,"ordinary_load_us":ordinary_load_us,"save_bytes":FileAccess.get_file_as_bytes(g.progress_writer.path).size(),"portable_bytes":FileAccess.get_file_as_bytes("user://p2-workload-portable.json").size(),"requests":g.equipment_queries._next_id-1,"initial_requests":requests_after_open,"requests_per_second":float(g.equipment_queries._next_id-1)/(float(duration)/1e6),"query_status_counts":counts,"resource_blocks":g.profile.resources["1"].get("blocks",[]).size()}))
	g.shutdown_equipment_queries()
	actor.queue_free()
	await process_frame
	await process_frame
	print("P2_WORKLOAD_COMPLETE")
	quit(0 if passed else 1)
