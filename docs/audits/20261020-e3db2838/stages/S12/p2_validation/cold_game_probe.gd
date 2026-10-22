extends SceneTree
const L=preload("res://scripts/currency_ledger.gd")
var failure:=""
func _initialize()->void:
	Engine.max_fps=60
	call_deferred("_run")
func _run()->void:
	var scenario:String=OS.get_cmdline_user_args()[0]
	var g:=BattleGame.new(ShipDatabase.new(),false)
	g.state=g.State.RETREAT
	g.profile.highestLevel=int(g.hyperspace.config.unlock_stage)
	g.profile.hyperspace.materials[g.db.evolution_material_id()]=9007199254740991
	g.profile.loadout.weapons[0].key="laser"
	g.profile.loadout.weapons[0].level=1
	g.profile.resources["1"]={"v":1,"i":"55916713612491779479035"} if scenario=="exact256" else {"m":1.0,"e":3800.0 if scenario=="middle" else 1000000000.0}
	var start:int=Time.get_ticks_usec()
	var outcome=g.request_max_upgrade_slot("weapons",0)
	var frame_work:int=Time.get_ticks_usec()-start
	var work_max:int=frame_work
	var heartbeat_max:=0
	var previous:int=start
	var frames:=0
	var cancel_at:=0
	var income_max:=0
	while outcome.status=="pending":
		await process_frame
		var now:int=Time.get_ticks_usec()
		heartbeat_max=maxi(heartbeat_max,now-previous)
		previous=now
		frames+=1
		var work:int=Time.get_ticks_usec()
		g.process_equipment_queries()
		outcome=g.poll_max_upgrade(outcome.request_id)
		if scenario=="cancel" and cancel_at==0 and outcome.metrics.phase=="bound" and int(outcome.metrics.candidate)>=32768:
			cancel_at=Time.get_ticks_usec()
			g.equipment_queries.cancel(outcome.request_id)
		frame_work=Time.get_ticks_usec()-work
		work_max=maxi(work_max,frame_work)
		var income_start:int=Time.get_ticks_usec()
		if g.currency_income("1",1).status!="committed":failure="income"
		income_max=maxi(income_max,Time.get_ticks_usec()-income_start)
	var elapsed:int=Time.get_ticks_usec()-start
	var expected:bool=outcome.status=="cancelled" and cancel_at>0 if scenario=="cancel" else outcome.status=="complete"
	if scenario=="exact256":expected=expected and int(outcome.quote.get("count",-1))==256 and outcome.quote.get("mode")=="exact"
	if scenario=="middle":expected=expected and int(outcome.quote.get("count",-1))==47959
	if scenario=="far":expected=expected and int(outcome.quote.get("count",-1))>1000000
	var cancel_us:int=int(outcome.metrics.get("stopped_us",0))-cancel_at if cancel_at>0 else 0
	var passed:bool=expected and failure.is_empty() and work_max<=4000 and heartbeat_max<=50000 and (cancel_at==0 or (cancel_us>=0 and cancel_us<=100000))
	print("P2_COLD_RESULT ",JSON.stringify({"scenario":scenario,"status":"PASS" if passed else "FAIL","outcome":outcome.status,"reason":outcome.reason,"count":outcome.quote.get("count",0),"elapsed_us":elapsed,"frames":frames,"query_frame_work_max_us":work_max,"heartbeat_max_us":heartbeat_max,"cancel_actual_stop_us":cancel_us,"income_max_us":income_max,"failure":failure}))
	g.cancel_max_upgrade(outcome.request_id)
	g.shutdown_equipment_queries()
	print("P2_COLD_COMPLETE")
	quit(0 if passed else 1)
