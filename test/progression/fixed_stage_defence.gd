extends SceneTree
const Game=preload("res://qa/presented_balance_game.gd")
const Policy=preload("res://qa/sparse_policy.gd")
const Driver=preload("res://qa/scene_driver.gd")
func _initialize()->void:call_deferred("run")
func run()->void:
	var g=Game.new(ShipDatabase.new());g.save_enabled=false;g.rng.seed=20261004
	g.metrics=preload("res://scripts/balance_metrics.gd").new();g.metrics.initialize(g)
	g.profile.cleared=range(1,34);g.profile.highestLevel=34;g.rebuild_unlocks()
	for id in g.profile.resources:g.profile.resources[id]=0
	g.profile.jewelFragments=0
	var p=Policy.new();p.configure("BALANCED",20261004);p.allow_reforge=false
	p.fixed_defence_from_stage=34;p.fixed_defence_layout=["armour","shield","shield"]
	var commits:Array=[];var changes:Array=[]
	p.journal=func(kind,payload):
		if kind=="fixed_defence_commit":commits.append(payload.duplicate(true))
	g.event.connect(func(kind,payload):
		if kind=="encounter":p.observe_progress_stage(g.stage)
		if kind=="module_changed":changes.append(payload.duplicate(true)))
	g.start(33,false);p.act(g,0)
	var driver=Driver.new();driver.ui_refresh_seconds=1.0;driver.setup(self,g)
	assert(not p.fixed_defence_active)
	var levels:Array=g.defense_entries().map(func(entry):return entry.level)
	g.start(34,false)
	# Encounter callback may occur immediately, or upon actual arrival.
	if not p.fixed_defence_stage_seen:
		p.act(g,300);assert(not p.fixed_defence_active)
		for step in 6000:
			driver.before_tick(1.0/60.0);g.tick(1.0/60.0);driver.after_tick(1.0/60.0)
			if p.fixed_defence_stage_seen:break
	assert(p.fixed_defence_stage_seen)
	p.act(g,600);assert(p.fixed_defence_active and commits.size()==1)
	assert(g.defense_entries().map(func(entry):return entry.key)==p.fixed_defence_layout)
	assert(g.stat("armour")>0)
	var changes_after_commit:int=changes.size()
	g.start(33,false);p.act(g,900)
	assert(commits.size()==1 and changes.size()==changes_after_commit)
	assert(g.defense_entries().map(func(entry):return entry.level)==levels)
	var result={"pass":true,"scope":"Synthetic progress, actual Presented/main scene encounter and public sparse refits; activation/churn control only, no growth timing claim","commits":commits,"module_changes":changes,"retained_layout":p.fixed_defence_layout,"levels":levels,"x1_seconds":g.simulated_time,"rng_state":str(g.rng.state)}
	var dir:=OS.get_environment("QA_DIAGNOSTIC_RESULT_DIR");assert(not dir.is_empty())
	FileAccess.open(dir.path_join("fixed-stage-defence.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	driver.close();print("FIXED_STAGE_DEFENCE_PASS ",JSON.stringify(result));quit()
