extends SceneTree
var checks:=0
var failures:=0
func check(ok:bool,label:String) -> void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var scene=load("res://main.tscn").instantiate();scene.automation_args=["--capture"];root.add_child(scene);scene.set_process(false)
 var g=scene.game;g.save_enabled=false;g.paused=true;g.profile.highestLevel=101;g.profile.cleared=range(1,101);g.rebuild_unlocks();g.pending_unlocks.clear();g.profile.scientists=15
 var total:Dictionary={}
 for offset in 6:
  for id in g.scientist_cost(offset):total[id]=float(total.get(id,0))+float(g.scientist_cost(offset)[id])
 for id in total:g.profile.resources[id]=float(total[id])+0.25
 scene.refresh_structure();scene.refresh_tab_visibility();scene.select_system(1);await process_frame
 var p=scene.hightech_page;p.refresh()
 var before=JSON.stringify(g.profile);var rng=g.rng.state
 check(p.generate_actions[-1].text==UIText.t("research.dock_ai_max_count",{"count":"6"}) and not p.generate_actions[-1].disabled,"Default MAX displays its actual affordable six-AI batch")
 check(p.generation_quote(-1)==g.scientist_purchase(-1) and p.generation_quote(-1).costs==total,"Default and hover share the actual authoritative batch total")
 var tooltip=p.generate_actions[-1]._make_custom_tooltip(p.generate_actions[-1].tooltip_text)
 check(tooltip!=null and p.generation_quote_text(-1).contains("6"),"Actual MAX button still opens its total-cost custom tooltip")
 tooltip.free()
 check(JSON.stringify(g.profile)==before and g.rng.state==rng,"Batch projection does not purchase, debit or change RNG")
 var evaluations=p.maximum_quote_evaluations
 for i in 30:
  for id in total:g.profile.resources[id]+=0.001
  p.refresh()
 check(p.maximum_quote_evaluations==evaluations,"Income within the same affordable batch never repeats the MAX traversal")
 var id=str(total.keys()[0]);g.profile.resources[id]=float(total[id])-0.1;p.refresh()
 check(p.generation_quote(-1).count==5 and p.generate_actions[-1].text==UIText.t("research.dock_ai_max_count",{"count":"5"}),"Spending below a batch boundary immediately reduces the visible count")
 for resource in total:g.profile.resources[resource]=float(total[resource])+float(g.scientist_cost(6)[resource])
 p.refresh()
 check(p.generation_quote(-1).count==7 and p.generate_actions[-1].text==UIText.t("research.dock_ai_max_count",{"count":"7"}),"Reaching the next whole batch recomputes its actual total")
 for resource in total:g.profile.resources[resource]=float(total[resource])+0.25
 p.refresh();var purchase=p.generation_quote(-1);var balances=g.profile.resources.duplicate(true)
 p.generate_actions[-1].pressed.emit();p.refresh()
 check(g.profile.scientists==21,"Native MAX control executes the quoted six-AI purchase")
 for resource in total:check(is_equal_approx(float(g.profile.resources[resource]),float(balances[resource])-float(purchase.costs[resource])),"Each currency debit equals the shown batch quote")
 check(p.generate_actions[-1].disabled and p.generate_actions[-1].text==UIText.t("research.dock_ai_max_count",{"count":"0"}),"Post-purchase empty budget clears quantity and disables MAX")
 print("AI MAX quantity: ",checks," checks, ",failures," failures")
 scene.queue_free();await process_frame;quit(1 if failures else 0)
