extends SceneTree
var checks:=0
var failures:=0
func check(ok:bool,label:String) -> void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize() -> void:call_deferred("run")
func choose(panel,id:String) -> void:
 panel.jobs.select(panel.job_ids.find(id));panel.jobs.item_selected.emit(panel.jobs.selected)
func run() -> void:
 var scene=load("res://main.tscn").instantiate();scene.automation_args=["--capture"];root.add_child(scene);scene.set_process(false)
 var g=scene.game;g.save_enabled=false;g.paused=true;g.profile.highestLevel=101;g.profile.cleared=range(1,101);g.rebuild_unlocks();g.pending_unlocks.clear()
 for key in scene.db.data.hightech:g.profile.hightechLevels[key]=1
 scene.refresh_structure();scene.select_system(5);await process_frame
 var p=scene.crew_panel;p.select("navigator")
 check(not p.job_ids.has("hyperspace") and p.find_children("*","Label",true,false).all(func(label):return label.text!=UIText.t("crew.hyperspace_entry_hint")),"Regular assignment form has no unrelated hyperspace directions or invented job")
 for id in ["equipment_upgrade","hightech_scientists","reactor_upgrade"]:
  choose(p,id)
  var title=p.job_title(g.crew.assignments(g)[id])
  check(p.assign_button.text==UIText.t("crew.confirm_target",{"target":title}) and not p.assignment_preview.text.is_empty(),"Draft button and preview follow "+id)
 choose(p,"equipment_upgrade");p.assign_button.pressed.emit();p.refresh_detail()
 check(g.crew.entry(g,"navigator").assignmentType=="equipment_upgrade" and p.status.text.contains("装备系统"),"Assignment button commits equipment and actual status identifies it")
 choose(p,"hightech_scientists")
 check(p.status.text.contains("装备系统") and p.assign_button.text==UIText.t("crew.confirm_target",{"target":p.job_title(g.crew.assignments(g)["hightech_scientists"])}),"Unconfirmed AI draft does not replace current equipment status")
 scene.select_system(0);scene.select_system(5);p.select("navigator")
 check(p.job_ids[p.jobs.selected]=="equipment_upgrade" and p.status.text.contains("装备系统"),"Reopening selected crew restores actual assigned equipment")
 for id in ["hightech_scientists","reactor_upgrade"]:
  choose(p,id);p.assign_button.pressed.emit();p.refresh_detail()
  check(g.crew.entry(g,"navigator").assignmentType==id and p.status.text.contains(p.job_title(g.crew.assignments(g)[id])),"Assignment commits and names actual "+id)
 p.release_button.pressed.emit();p.refresh_detail()
 check(g.crew.entry(g,"navigator").assignmentType=="" and p.status.text==UIText.t("crew.free"),"Release returns actual status to idle")
 scene.queue_free();await process_frame
 print("Crew assignment copy: ",checks," checks, ",failures," failures");quit(1 if failures else 0)
