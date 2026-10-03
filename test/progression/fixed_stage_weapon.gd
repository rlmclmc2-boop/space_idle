extends SceneTree
const Game=preload("res://scripts/balance_game.gd")
const Policy=preload("res://qa/sparse_policy.gd")
func _initialize()->void:call_deferred("run")
func run()->void:
	var g=Game.new(ShipDatabase.new());g.save_enabled=false;g.rng.seed=20261004
	g.metrics=preload("res://scripts/balance_metrics.gd").new();g.metrics.initialize(g)
	g.profile.cleared=range(1,33);g.profile.highestLevel=33;g.rebuild_unlocks()
	for id in g.profile.resources:g.profile.resources[id]=0
	g.profile.jewelFragments=0
	var p=Policy.new();p.configure("BALANCED",20261004);p.allow_reforge=false;p.thematic=true
	p.fixed_weapon_from_stage=34;p.fixed_weapon_key="longLaser"
	var commits:Array=[]
	p.journal=func(kind,payload):
		if kind=="fixed_weapon_commit":commits.append(payload.duplicate(true))
	g.start(33,false);p.act(g,0)
	assert(not p.fixed_weapon_active)
	var levels:Array=[]
	for entry in g.weapon_entries():levels.append(entry.level)
	g.profile.cleared.append(33);g.rebuild_unlocks()
	g.start(34,false);p.act(g,300)
	assert(p.fixed_weapon_active and commits.size()==1)
	assert(g.weapon_entries().all(func(entry):return entry.key=="longLaser"))
	g.start(33,false);p.act(g,600)
	assert(p.fixed_weapon_active and commits.size()==1)
	assert(g.weapon_entries().all(func(entry):return entry.key=="longLaser"))
	for index in levels.size():assert(g.weapon_entries()[index].level==levels[index])
	assert(g.profile.resources.values().all(func(value):return value==0))
	assert(g.profile.jewelFragments==0 and g.simulated_time==0)
	var result={"pass":true,"policy":Policy.VERSION,"scope":"Controlled no-tick invocation fixture; declared visits test activation/persistence only, not elapsed player journey. Before34 unlocked beam remains mixed; first real-visit call at34 commits once; next farm33 visit retains beam. Public refits preserve module levels, no resource/time gain.","commit":commits,"slot_levels":levels,"weapon_keys":g.weapon_entries().map(func(entry):return entry.key)}
	var dir:=OS.get_environment("QA_DIAGNOSTIC_RESULT_DIR");assert(not dir.is_empty())
	FileAccess.open(dir.path_join("fixed-stage-weapon.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("FIXED_STAGE_WEAPON_PASS ",JSON.stringify(result));quit()
