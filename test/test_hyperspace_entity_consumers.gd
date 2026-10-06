extends SceneTree
const C=preload("res://scripts/hyperspace_config.gd")
const Agg=preload("res://scripts/drone_effect_aggregator.gd")
const Rewards=preload("res://scripts/drone_rewards.gd")
const Forge=preload("res://scripts/drone_forge.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",label)
func _initialize()->void:
	var c:=C.load_config()
	check(not c.is_empty() and C.valid(c),"ordinary load validates entity config")
	if c.is_empty():quit(1);return
	var g:=BattleGame.new(ShipDatabase.new(),false)
	check(g.startup_error.is_empty(),"normal constructor validates full pack before profile")
	if not g.startup_error.is_empty():quit(1);return
	for level in [0,1,10,100,500]:
		var q:=g.hyperspace.auto_quote(900.0,level)
		check(is_equal_approx(q.ticket,float(c.ticket)*20.0/(20.0+level)) and is_equal_approx(q.duration,maxf(float(c.minimum_duration),900.0*100.0/(100.0+level))),"default shared auto quote "+str(level))
	var changed:=c.duplicate(true);changed.auto_duration_crew_base=200.0;changed.auto_ticket_crew_base=40.0;changed.amplification_start_level=6;changed.modernization_base_coefficient=2.0
	check(g.hyperspace.configure(changed),"distinct valid numeric config")
	var quote:=g.hyperspace.auto_quote(900.0,100)
	check(is_equal_approx(quote.ticket,float(c.ticket)*40.0/140.0) and is_equal_approx(quote.duration,600.0),"both crew bases consumed")
	var a:Dictionary={"key":"global_damage","tier":5,"value":0.1,"locked":false}
	check(is_equal_approx(Agg.affix_value(a,{"level":6},changed),0.1) and is_equal_approx(Agg.affix_value(a,{"level":5},changed),0.1/1.05),"amplification exponent start and below-start")
	var rng:=RandomNumberGenerator.new();rng.seed=123
	var d:=Rewards.create_drone(rng,c,"entity:1","gold","laser",5,"1");d.affixes=[a]
	var state:Dictionary=g.profile.hyperspace.duplicate(true);state.inventory.drones[d.id]=d;state.history={"alpha":{"10":30.0}};state.materials.degenerate_matter=100000
	g.profile.highestLevel=10
	var request:Dictionary={"operation":"modernize","drone_id":d.id,"args":{}}
	var old:=Forge.plan(state.duplicate(true),c,request,g)
	var revised:=Forge.plan(state.duplicate(true),changed,request,g)
	var common:float=1.0+float(10-int(c.material_reward_start_level))/float(c.modernization_level_step)
	var weight:float=float(c.modernization_tier_weights["5"])
	check(old.error.is_empty() and revised.error.is_empty(),"modernization actual planner accepts both configs")
	check(old.cost.degenerate_matter==roundf(common*(1.0+weight))*float(c.modernization_cost_base) and revised.cost.degenerate_matter==roundf(common*(2.0+weight))*float(c.modernization_cost_base),"base coefficient consumed; price origin and quantization preserved")
	for pair in [["auto_duration_crew_base",0],["maximum_equipped",6],["overflow_capacity",11]]:
		var bad:=c.duplicate(true);bad[pair[0]]=pair[1];check(not C.valid(bad),"invalid runtime config rejected "+str(pair[0]))
	var bad:=c.duplicate(true);bad.legendary_effects.dodge_counter.parameters.maximum_dodge[1]=1.1
	check(not C.valid(bad),"dodge upper probability rejected at runtime")
	print("HYPERSPACE_ENTITY_CONSUMERS ",checks," checks ",failures," failures")
	quit(1 if failures else 0)
