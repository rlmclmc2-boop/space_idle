extends SceneTree
const Game=preload("res://qa/presented_balance_game.gd")
const Policy=preload("res://qa/hyperspace_player_policy.gd")
const CP=preload("res://qa/hyperspace_checkpoint.gd")
var tested:=0
var failed:=0
func check(ok:bool,label:String):
 tested+=1
 if not ok:failed+=1;printerr("FAIL: ",label)
func _initialize():call_deferred("run")
func run():
 var source:String=OS.get_environment("QA_NATURAL_SOURCE");var raw:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(source))
 var g=Game.new(ShipDatabase.new());g.save_enabled=false;g.load_hyperspace_routes();g.load_progress_data(raw.save);g.resume_progress();g.rng.state=int(str(raw.rng_state))
 var p=Policy.new();check(p.affix_target_tier==0,"Natural default has no tier prerequisite")
 var before:Dictionary=g.profile.duplicate(true);var rng:String=str(g.rng.state)
 for route in g.hyperspace.config.routes:
  check(p.manual_challenge_level(g,str(route))==30,"Actual cleared33/frontier34/allrecord5 selects prior main milestone30: "+str(route))
 check(before==g.profile and rng==str(g.rng.state),"Challenge planning never inserts history, changes save or advances RNG")
 var supply:Dictionary=p.growth_supply(g)
 check(not supply.is_empty() and not supply.has("desired_tier"),"Default0 finds real forge material or route-record prerequisite")
 check(supply.get("record_prerequisite",false) or int(supply.available)<int(supply.minimum),"Supply is an actual missing record or previewed material, never a tier goal")
 var energy:float=g.profile.hyperspace.energy;g.profile.hyperspace.energy=216000.0
 var planned:Dictionary=p.paid_affix_supply_action(g,float(raw.x1_seconds),supply)
 check(not p.manual_pending.is_empty() and int(p.manual_pending.level)==30,"Declared full energy chooses real prior milestone30 for actual missing record")
 g.profile.hyperspace.energy=energy;p.manual_pending={}
 var now:float=float(raw.x1_seconds)
 p.manual_started(g,"gamma",30,now);p.manual_finished(g,false,now+3.0)
 check(not p.manual_retry_allowed(g,"alpha",30,now+16.6),"Cross-route retry13.6seconds after failure is blocked")
 check(not p.manual_retry_allowed(g,"beta",30,now+1200),"900seconds without earned growth does not unblock another route")
 g.profile.loadout.weapons[0].level+=4
 check(not p.manual_retry_allowed(g,"beta",30,now+1200),"Only four module levels cannot bypass shared frontier failure")
 g.profile.loadout.weapons[0].level+=1
 check(not p.manual_retry_allowed(g,"alpha",30,now+100),"Five real-growth fixture levels do not bypass900second low-frequency gate")
 check(p.manual_retry_allowed(g,"beta",30,now+1200),"Five levels plus elapsed900 permits a new route at the same frontier")
 var memory:Dictionary=CP.fields(p,CP.POLICY);var restored=Policy.new();CP.apply_fields(restored,memory,CP.POLICY)
 check(restored.manual_frontier_failures==p.manual_frontier_failures and restored.last_frontier_attempt==p.last_frontier_attempt,"Checkpoint preserves shared retry state")
 g.profile.loadout.weapons[0].level-=5
 check(not restored.manual_retry_allowed(g,"delta",30,now+1200),"Restored frontier failure cannot be escaped by switching route")
 var legacy=Policy.new();legacy.manual_failures[legacy.manual_key(g,"gamma",34)]={"growth":Policy.manual_growth(g.profile),"failed_at":now,"reason":"Actual prior-version frontier34 death"}
 check(not legacy.manual_retry_allowed(g,"alpha",30,now+1200),"Preserved prior same-round exact-frontier failure seeds conservative shared gate")
 var round:int=g.profile.hyperspace.round_id;g.profile.hyperspace.round_id=round+1
 check(legacy.manual_retry_allowed(g,"alpha",30,now+1200),"A declared new-round fixture does not inherit old-round failure")
 g.profile.hyperspace.round_id=round
 # Separate classification fixtures only; never committed into real history or campaign evidence.
 var history:Dictionary=g.profile.hyperspace.history.duplicate(true);g.profile.hyperspace.history.gamma["999"]=1.0
 check(p.manual_challenge_level(g,"gamma")==30,"Future ineligible record never becomes chosen challenge")
 g.profile.hyperspace.history.gamma={"30":60.0}
 check(p.manual_challenge_level(g,"gamma")==0 and p.manual_challenge_level(g,"gamma",true)==30,"No generic frontier34 jump afterrecord30; requested materials may repeat real30")
 g.profile.hyperspace.history=history
 check(not CP.POLICY.has("imaginary_income"),"No forecast income is checkpointed")
 print("NATURAL_MILESTONE_RETRY ",tested," checks ",failed," failures");quit(2 if failed else 0)
