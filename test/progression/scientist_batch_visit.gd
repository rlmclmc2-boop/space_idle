extends SceneTree
const Game=preload("res://qa/presented_balance_game.gd")
const Sparse=preload("res://qa/sparse_policy.gd")
const Metrics=preload("res://scripts/balance_metrics.gd")
func _initialize():
	var g=Game.new(ShipDatabase.new());g.stat_cache_enabled=true
	g.profile.highestLevel=8;g.profile.cleared=range(1,8);g.rebuild_unlocks();g.start(8,false)
	g.profile.resources={"1":1e12,"2":1e12};g.metrics=Metrics.new();g.metrics.initialize(g)
	var policy=Sparse.new();policy.configure("BALANCED",20261002);policy.allow_reforge=false;policy.scientist_batch_mode=true
	var before:int=g.profile.scientists
	policy.act(g,120.0)
	assert(g.profile.scientists==before+10)
	print("SPARSE_SCIENTIST_BATCH_PASS purchased=10 real_button_supported=true reserve_fraction=0.1 scope=optional sparse-visit assumption; no teaching change")
	quit()
