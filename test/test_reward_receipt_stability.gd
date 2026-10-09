extends SceneTree
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize()->void:call_deferred("run")
func run()->void:
 var scene=load("res://main.tscn").instantiate();scene.automation_args=["--capture"]
 root.add_child(scene);scene.set_process(false)
 var g=scene.game;g.save_enabled=false;g.paused=true;g.profile.highestLevel=34;g.profile.cleared=range(1,34);g.rebuild_unlocks();g.pending_unlocks.clear();g.profile.onboarding.completed=true
 g.profile.hyperspace.unlocked_drones=true;g.profile.hyperspace.history.alpha={"1":1.0}
 g.hyperspace.config.quality_weights={"white":1.0,"blue":0.0,"gold":0.0,"legendary":0.0};g.hyperspace.config.ultimate_core_probability=0.0
 g.hyperspace.set_filter(g,{"version":2,"enabled":true,"action":"clear_matches","mode":"all","conditions":[{"field":"weapon","value":"laser"}]})
 scene.refresh_tab_visibility();scene.select_system(9);await process_frame
 var p=scene.hyperspace_panel;p.set_process(false);p.reward_feedback.first_drone=false;p.select_section(0);p.refresh()
 var receipt:Dictionary=g.hyperspace.start(g,"alpha",1,"idle")
 check(not receipt.is_empty(),"Real domain idle receipt starts with authorized fixture history")
 if receipt.is_empty():scene.queue_free();quit(1);return
 g.profile.hyperspace.idle.work=receipt.duration
 check(g.hyperspace.complete(g,int(receipt.round_id),int(receipt.run_id),true),"Core freezes the actual generated and automatically dismantled reward")
 var frozen:Dictionary=g.profile.hyperspace.idle.reward.duplicate(true)
 check(frozen.drone.is_empty() and not frozen.hanging_rewards.is_empty(),"Core-filtered reward contains actual module drops")
 check(g.hyperspace.claim(g,int(receipt.round_id),int(receipt.run_id)),"Real claim settles the frozen reward")
 var feedback=p.reward_feedback
 check(feedback.summary.text.contains(p.t("reward_auto_dismantled")),"Receipt explicitly attributes automatic dismantling")
 for key in frozen.hanging_rewards:
  check(feedback.summary.text.contains(p.t("reward_module_receipt",{"name":p.hanging_name(key),"copies":str(int(frozen.hanging_rewards[key])),"level":str(int(g.profile.hyperspace.hanging_modules[key].level))})),"Receipt displays exact frozen module copies and actual post-claim level")
 var profile_before:=JSON.stringify(g.profile);var rng_before:int=g.rng.state
 p.route_ui.refresh();await process_frame;await process_frame
 var old_position:Vector2=p.route_ui.challenge_button.global_position
 var frame=p.exploration_receipt_scroll
 var old_height:float=frame.size.y
 feedback.latest={};feedback.show_receipt();await process_frame;await process_frame
 check(p.route_ui.challenge_button.global_position==old_position and frame.size.y==old_height,"No-receipt placeholder does not move route actions or resize reserved receipt area")
 feedback.latest={"drone":{},"materials":frozen.materials,"ultimate_cores":0,"module_receipt":[]}
 for key in g.hyperspace.config.hanging_modules:feedback.latest.module_receipt.append({"key":key,"copies":2,"level":1})
 feedback.show_receipt();await process_frame;await process_frame
 check(p.route_ui.challenge_button.global_position==old_position and frame.size.y==old_height,"Tall module receipt scrolls within fixed area without moving route actions")
 check(JSON.stringify(g.profile)==profile_before and g.rng.state==rng_before,"Receipt projection changes neither rewards, profile nor combat RNG")
 scene.queue_free();await process_frame
 print("REWARD RECEIPT: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
