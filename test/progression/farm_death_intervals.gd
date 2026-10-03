extends SceneTree
const Game=preload("res://qa/presented_balance_game.gd")
const Sparse=preload("res://qa/sparse_policy.gd")
const Metrics=preload("res://scripts/balance_metrics.gd")
func _initialize():
	var g=Game.new(ShipDatabase.new());g.stat_cache_enabled=true
	g.profile.highestLevel=8;g.profile.cleared=range(1,8);g.rebuild_unlocks();g.start(8,false)
	g.metrics=Metrics.new();g.metrics.initialize(g)
	var policy=Sparse.new();policy.configure("BALANCED",20261002);policy.allow_reforge=false
	policy.furthest=8;policy.best_won={"8":1};policy.deaths_seen=0
	# One observed retreat between each visit. Older policy reset its baseline
	# after every visit, so it never reached the declared two-loss threshold.
	g.metrics.deaths=1;policy.act(g,120.0);assert(policy.farm.is_empty())
	g.metrics.deaths=2;policy.act(g,240.0)
	var expected_farm:=OS.get_environment("PROGRESSION_FARM_EXPECT_FARM")!="0"
	assert((not policy.farm.is_empty())==expected_farm)
	if expected_farm:assert(g.profile.loop)
	print("SPARSE_LOSS_INTERVAL_PASS visits120_and240 one_loss_each second_visit_farms=",not policy.farm.is_empty()," version=",Sparse.VERSION," scope=controlled retreat-counter fixture, legal start/toggle actions")
	quit()
