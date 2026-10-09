extends SceneTree
var checks:=0
var failures:=0
func check(ok:bool,label:String) -> void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var scene=load("res://main.tscn").instantiate();scene.automation_args=["--capture"];root.add_child(scene);scene.set_process(false)
 var g=scene.game;g.save_enabled=false;g.paused=true;g.profile.highestLevel=101;g.profile.cleared=range(1,101);g.rebuild_unlocks();g.pending_unlocks.clear();g.profile.scientists=2
 var key=BattleGame.FURNACE
 check(g.assign_scientist(key,2),"Assign first two actual AI to construction through existing domain")
 scene.refresh_structure();scene.refresh_tab_visibility();scene.select_system(1);await process_frame
 var p=scene.hightech_page;p.sync_projects();p.select_project(key)
 var rate=g.research_rate(key);g.advance_hightech(1.4/rate);p.refresh()
 check(is_equal_approx(float(g.profile.techPoints[key]),1.4) and p.stage_points.text==p.t("points",{"points":"1.5","required":NumberFormat.scalar(g.hightech_required(key))}),"Actual fractional accumulation remains1.4 while visible construction progress follows half units")
 var seconds=ceili((g.hightech_required(key)-float(g.profile.techPoints[key]))/rate)
 check(p.stage_eta.text==p.t("remaining",{"time":"%02d:%02d" % [seconds/60,seconds%60]}),"ETA still uses unrounded actual points and unchanged rate")
 for pair in [[1.24,"1"],[1.25,"1.5"],[0,"0"],[39100,"39.1K"]]:
  g.profile.techPoints[key]=pair[0];var before=JSON.stringify(g.profile);var rng=g.rng.state;p.refresh()
  check(p.stage_points.text==p.t("points",{"points":pair[1],"required":NumberFormat.scalar(g.hightech_required(key))}) and JSON.stringify(g.profile)==before and g.rng.state==rng,"Progress display boundary and suffix changes neither research nor profile/RNG")
 p.completion_key=key;p.machines[key].completed=1.0;p.refresh()
 check(p.stage_points.text==p.t("next_points",{"points":"39.1K","required":NumberFormat.scalar(g.hightech_required(key))}),"Same completion readout uses the shared formatting for next-round points")
 scene.queue_free();await process_frame
 print("Research progress numbers: ",checks," checks, ",failures," failures");quit(1 if failures else 0)
