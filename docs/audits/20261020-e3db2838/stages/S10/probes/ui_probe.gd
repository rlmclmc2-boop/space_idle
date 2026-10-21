extends SceneTree
const R=preload("res://scripts/reactor_integer.gd")
var fails:=0
func check(ok:bool,label:String):
 if not ok:fails+=1;printerr("FAIL ",label)
func _initialize():call_deferred("run")
func run():
 var scene=preload("res://scripts/main.gd").new();scene.automation_args=["--capture"];root.add_child(scene);scene.set_process(false)
 var g=scene.game;g.save_enabled=false;g.profile.cleared=range(1,101);g.rebuild_unlocks();g.profile.reactorLevel=2500
 scene.build_ui();scene.equipment_tabs.current_tab=2
 await process_frame
 var panel=scene.reactor_panel
 var share=R.div_small(g.reactor_capacity(),4)[0]
 g.set_reactor_allocation("weapons",share);g.set_reactor_allocation("defence",5)
 panel.refresh()
 var controls=panel.module_controls.weapons
 check(not controls.slider.editable,"large slider disabled")
 check(controls.exact_input.text==R.digits(share),"exact text")
 check(not panel.remaining_label.text.contains("INF"),"finite remaining")
 panel.step_allocation("weapons",1)
 check(R.compare(g.profile.reactorAllocation.weapons,R.add(share,1))==0,"exact step")
 check(R.compare(g.profile.reactorAllocation.defence,5)==0,"other module preserved")
 panel.submit_exact_allocation("7","weapons")
 check(R.compare(g.profile.reactorAllocation.weapons,7)==0,"exact entry")
 print("UI PROBE FAILS ",fails)
 quit(1 if fails else 0)
