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
 g.profile.reactorLevel=14;g.profile.reactorAllocation={"weapons":0,"defence":0,"smelting":0,"condensation":5};g.invalidate_stat_cache();scene.refresh_tab_visibility();scene.select_system(2);await process_frame
 var p=scene.reactor_panel;var controls=p.module_controls.condensation;p.refresh()
 for amount in [5,15]:
  p.change_allocation(amount,"condensation");p.refresh()
  var before=JSON.stringify(g.profile);var rng=g.rng.state;var capacity=g.reactor_capacity();var gain=g.reactor_multiplier("condensation")
  check(controls.bay_energy.text==UIText.t("reactor.flow.effective_energy",{"energy":str(amount)}),"Actual supplied energy is distinct from its rounded capacity share")
  check(controls.row.tooltip_text.contains("合计 "+str(amount)+" 有效能源"),"Expanded supply agrees with the default integer energy")
  check(is_equal_approx(float(gain),1.0+pow(float(amount),0.8)/50.0),"Real fragment gain retains the authored formula")
  p.refresh()
  check(JSON.stringify(g.profile)==before and g.rng.state==rng and g.reactor_capacity()==capacity and g.reactor_multiplier("condensation")==gain,"Readout refresh changes no supply, output, capacity or RNG")
 p.change_allocation(5,"condensation");p.refresh()
 check(controls.share.text.contains("<1%") and not controls.bay_energy.text.contains("0%"),"Small supply retains its useful less-than-one-percent context without a misleading zero beside energy")
 print("Reactor supply readout: ",checks," checks, ",failures," failures")
 scene.queue_free();await process_frame;quit(1 if failures else 0)
