extends SceneTree
var checks:=0
var failures:=0
func check(ok:bool,label:String) -> void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var scene=load("res://main.tscn").instantiate();scene.automation_args=["--capture"];root.add_child(scene);scene.set_process(false)
 var g=scene.game;g.save_enabled=false;g.paused=true;g.profile.highestLevel=101;g.profile.cleared=range(1,101);g.rebuild_unlocks();g.pending_unlocks.clear()
 g.profile.reactorAllocation={"weapons":0,"defence":0,"smelting":0,"condensation":0};g.invalidate_stat_cache()
 var before=float(g.profile.jewelFragments);var rng=g.rng.state
 var drop={"jewel":true,"amount":3.2,"jewelRatio":1.0};g.drops.append(drop);g.collect(drop,true)
 var item:Dictionary=scene.floats.filter(func(f):return f.get("resource","")=="jewel").back()
 check(item.text==UIText.t("main.on_event.text_01",{"amount":"3","id":UIText.t("main._ready.text_02")}) and not item.text.contains("3.2"),"Actual credited fragment pickup displays whole units")
 check(is_equal_approx(float(g.profile.jewelFragments),before+3.2) and item.amount==3.2,"Pickup display retains every internally credited fraction")
 scene.floats.clear();drop={"jewel":true,"amount":0.2,"jewelRatio":1.0};g.drops.append(drop);g.collect(drop,true)
 item=scene.floats.filter(func(f):return f.get("resource","")=="jewel").back()
 check(item.text.contains("少于1") and not item.text.contains("+0"),"Small positive fragment pickup never claims a zero gain")
 drop={"jewel":true,"amount":0.9,"jewelRatio":1.0};g.drops.append(drop);g.collect(drop,true)
 check(is_equal_approx(float(item.amount),1.1) and item.text.begins_with("+1 ") and is_equal_approx(float(g.profile.jewelFragments),before+4.3),"Fractional pickup aggregation crosses the whole-unit boundary without loss")
 scene.floats.clear()
 for amount in [0.3,0.6,0.1]:
  drop={"jewel":true,"amount":amount,"jewelRatio":1.0};g.drops.append(drop);g.collect(drop,true)
 check(scene.floats.back().text.begins_with("+1 ") and is_equal_approx(float(g.profile.jewelFragments),before+5.3),"Whole-unit cent-credit sum is not misclassified by floating arithmetic")
 scene.floats.clear();scene.resource_pickup_feedback({"id":"1","amount":39100})
 check(scene.floats.back().text.contains("39.1K"),"Large ordinary-resource pickups retain the shared suffix ladder")
 scene.floats.clear();scene.resource_pickup_feedback({"jewel":true,"amount":0})
 check(not scene.floats.back().text.contains("+0") and not scene.floats.back().text.contains("少于1"),"Zero credit invents neither a positive nor fractional gain")
 check(g.rng.state==rng,"Formatting and these deterministic collections do not consume reward RNG")
 print("Resource pickup numbers: ",checks," checks, ",failures," failures")
 scene.queue_free();await process_frame;quit(1 if failures else 0)
