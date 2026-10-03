extends SceneTree
const Game=preload("res://scripts/balance_game.gd")
const Policy=preload("res://qa/sparse_policy.gd")
func _initialize()->void:call_deferred("run")
func fixture():
	var g=Game.new(ShipDatabase.new());g.save_enabled=false
	g.metrics=preload("res://scripts/balance_metrics.gd").new();g.metrics.initialize(g)
	g.profile.cleared=range(1,30);g.profile.highestLevel=30;g.stage=30
	g.rebuild_unlocks();g.clear_level()
	# Include the actual simultaneous30 notifications even if one was already
	# available from highest-stage semantics before clear. This is a controlled
	# queued-notification fixture, not a fresh30 arrival timing claim.
	g.pending_unlocks.assign(["ship/Battleship","crew/crew_04","planet/1"])
	for id in g.pending_unlocks:g.profile.seenUnlocks.erase(id)
	for id in g.profile.resources:g.profile.resources[id]=0
	g.profile.jewelFragments=0
	return g
func run()->void:
	var cases:Array=[]
	for limit in [1,32]:
		var g=fixture();var p=Policy.new();p.configure("BALANCED",20261004);p.allow_reforge=false;p.unlock_visit_limit=limit
		var queued:Array=g.pending_unlocks.duplicate();var before:Dictionary=g.profile.resources.duplicate(true)
		p.act(g,0)
		var confirmed:Array=queued.filter(func(id):return not g.pending_unlocks.has(id))
		assert(confirmed.size()==(1 if limit==1 else 3))
		assert(g.pending_unlocks.size()==(2 if limit==1 else 0))
		assert(g.profile.resources==before and g.profile.jewelFragments==0)
		assert(g.stage==(30 if limit==1 else 31))
		cases.append({"limit":limit,"confirmed":confirmed,"acknowledgement_operations":confirmed.size(),"remaining":g.pending_unlocks.duplicate(),"stage":g.stage,"resources_unchanged":true,"x1_seconds":g.simulated_time})
	var g=fixture();g.pending_unlocks.clear();g.profile.seenUnlocks.clear()
	for id in g.db.data.unlock.keys():
		g.pending_unlocks.append(str(id))
		if g.pending_unlocks.size()==40:break
	assert(g.pending_unlocks.size()==40)
	var p=Policy.new();p.configure("BALANCED",20261004);p.allow_reforge=false;p.unlock_visit_limit=32
	p.act(g,0)
	assert(g.pending_unlocks.size()==8 and g.stage==30)
	cases.append({"scope":"synthetic40-valid-ID safety queue; not a legal timing fixture","limit":32,"acknowledgement_operations":32,"remaining_count":8,"stage":g.stage})
	var result={"pass":true,"policy":Policy.VERSION,"scope":"Controlled single actual visit at queued30 notifications, no tick or free resources; each formal API confirms one page. Legacy1 and bounded32 compared; no fresh timing claim.","cases":cases}
	var dir:=OS.get_environment("QA_DIAGNOSTIC_RESULT_DIR");assert(not dir.is_empty())
	FileAccess.open(dir.path_join("unlock-visit-batch.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("UNLOCK_VISIT_BATCH_PASS ",JSON.stringify(result));quit()
