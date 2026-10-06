extends SceneTree
const C=preload("res://scripts/hyperspace_config.gd")
const S=preload("res://scripts/hyperspace_state.gd")
const R=preload("res://scripts/hyperspace_random.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)
func _initialize()->void:
	var c:=C.load_config();var q:=c.duplicate(true);q.affixes.global_damage.ranges["5"]=[0.043,0.043]
	var rng:=RandomNumberGenerator.new();rng.seed=4
	check(C.valid(q) and is_equal_approx(R.quantized(rng,[0.043,0.043],0.001),0.043),"single point grid uses unchanged sampler tolerance")
	q.affixes.global_damage.ranges["5"]=[0.0434,0.0434];check(not C.valid(q),"off-grid single point remains invalid")
	var zero:=c.duplicate(true)
	for key in zero.modernization_tier_weights:zero.modernization_tier_weights[key]=0.0
	check(C.valid(zero),"all zero additional weights valid with positive base")
	var large:=c.duplicate(true);large.dismantle_amounts.white=51
	for key in large.quality_weights:large.quality_weights[key]=1.0 if key=="white" else 0.0
	var g:=BattleGame.new(ShipDatabase.new(),false);check(g.hyperspace.configure(large),"dismantle51 is valid numeric config")
	g.profile.highestLevel=7;g.profile.hyperspace.filter={"version":2,"enabled":true,"mode":"all","action":"clear_matches","conditions":[{"field":"weapon","value":"laser"}]}
	var run:=g.hyperspace.start(g,"alpha",7,"manual")
	check(not run.is_empty(),"real run started without external reward injection")
	if run.is_empty():quit(1);return
	check(g.hyperspace.complete(g,int(run.round_id),int(run.run_id),true),"filtered actual generated reward accepts configured module budget")
	var reward:Dictionary=g.profile.hyperspace.active.reward;var total:=0;var maximum:=0
	for value in reward.hanging_rewards.values():total+=int(value);maximum=maxi(maximum,int(value))
	check(reward.drone.is_empty() and total==51 and maximum>=11 and S.valid_reward(reward,"alpha",large),"all51 real dismantle copies retained despite one bucket exceeding10")
	var bad:=reward.duplicate(true);bad.hanging_rewards={"resource_collector":51,"gem_refiner":1}
	check(not S.valid_reward(bad,"alpha",large),"sum beyond configured maximum rejected")
	check(g.hyperspace.claim(g,int(run.round_id),int(run.run_id)),"actual pending reward claim credits modules")
	check(S.valid(g.profile.hyperspace,large,g.db.levels.size()),"post-claim state validates for saving")
	print("HYPERSPACE_ENTITY_EDGES ",checks," checks ",failures," failures")
	quit(1 if failures else 0)
