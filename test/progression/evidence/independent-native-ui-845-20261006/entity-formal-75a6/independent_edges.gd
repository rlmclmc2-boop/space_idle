extends SceneTree
const C=preload("res://scripts/hyperspace_config.gd")
const S=preload("res://scripts/hyperspace_state.gd")
const R=preload("res://scripts/hyperspace_random.gd")
func _initialize():
 var c=C.load_config()
 var g=BattleGame.new(ShipDatabase.new(),false)
 var large=c.duplicate(true);large.dismantle_amounts.legendary=51
 print("EDGE dismantle51 config_valid=",C.valid(large)," reward11_valid=",S.valid_reward({"drone":{},"materials":{},"ultimate_cores":0,"hanging_rewards":{"resource_collector":11}},"alpha",large))
 var q=c.duplicate(true);q.affixes.global_damage.ranges["5"]=[0.043,0.043]
 var rng=RandomNumberGenerator.new();rng.seed=4
 print("EDGE quantized_single043 config_valid=",C.valid(q)," actual_quantized=",R.quantized(rng,[0.043,0.043],0.001))
 var z=c.duplicate(true)
 for k in z.modernization_tier_weights:z.modernization_tier_weights[k]=0.0
 print("EDGE all_zero_extra_weights config_valid=",C.valid(z)," positive_base=",z.modernization_base_coefficient)
 quit(0)
