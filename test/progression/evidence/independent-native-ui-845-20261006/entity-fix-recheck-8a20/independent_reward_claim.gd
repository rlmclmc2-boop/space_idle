extends SceneTree
const C=preload("res://scripts/hyperspace_config.gd")
const S=preload("res://scripts/hyperspace_state.gd")
const Rewards=preload("res://scripts/drone_rewards.gd")
var checks=0
var failures=0
func check(ok:bool,msg:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",msg)
func _initialize():
 var g=BattleGame.new(ShipDatabase.new(),false)
 var c=C.load_config();c.dismantle_amounts.legendary=51
 for k in c.quality_weights:c.quality_weights[k]=1.0 if k=="legendary" else 0.0
 check(g.startup_error.is_empty() and g.hyperspace.configure(c),"controlled large legendary dismantle configuration")
 g.profile.highestLevel=7
 g.profile.hyperspace.filter={"version":2,"enabled":true,"mode":"all","action":"clear_matches","conditions":[{"field":"quality","value":"legendary"}]}
 var run=g.hyperspace.start(g,"alpha",7,"manual")
 check(not run.is_empty(),"actual in-memory command starts")
 if run.is_empty():quit(1);return
 check(g.hyperspace.complete(g,run.round_id,run.run_id,true),"actual generated legendary filtered and frozen")
 if g.profile.hyperspace.active.status!="completed_pending":quit(1);return
 var reward=g.profile.hyperspace.active.reward
 var sum=0;var maximum=0
 for v in reward.hanging_rewards.values():sum+=int(v);maximum=maxi(maximum,int(v))
 check(reward.drone.is_empty() and sum==51 and maximum>=11,"51 copies survive generation; some bucket above old10")
 check(reward.materials.degenerate_matter==51+Rewards.material_amount(c,7),"success material plus dismantle material both retained")
 check(g.hyperspace.claim(g,run.round_id,run.run_id),"claim completes")
 var after=g.profile.hyperspace.duplicate(true)
 check(S.valid(after,c,g.db.levels.size()),"state valid for serialization after claim")
 check(not g.hyperspace.claim(g,run.round_id,run.run_id) and after==g.profile.hyperspace,"duplicate claim rejected with no balances changed")
 var over=reward.duplicate(true);over.hanging_rewards={"resource_collector":51,"gem_refiner":1}
 check(not S.valid_reward(over,"alpha",c),"sum52 still rejected even each bucket at most51")
 print("INDEPENDENT_REWARD_CLAIM ",checks," checks ",failures," failures; copies=",sum," maximum_bucket=",maximum)
 quit(1 if failures else 0)
