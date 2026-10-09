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
 var g=scene.game;g.save_enabled=false;g.paused=true;g.profile.cleared=range(1,34);g.profile.highestLevel=34;g.rebuild_unlocks();g.pending_unlocks.clear();g.profile.onboarding.completed=true
 var p=scene.equipment_panel
 var entry:Dictionary=g.module_entry("weapons",1);entry.key="cannon";entry.level=57;g.invalidate_stat_cache()
 scene.refresh_tab_visibility();scene.select_system(scene.equipment_tabs.get_tab_idx_from_control(p));p.refresh();await process_frame
 var card=p.cards.weapons_1;var old_icon=card.picture.texture
 for key in ["longLaser","cannon"]:
  var index:int=card.equipment_options.find(key)
  check(index>=0,"Unlocked quick-menu option exists")
  var menu:PopupMenu=card.name_button.get_popup();menu.index_pressed.emit(index);await process_frame;await process_frame
  check(g.module_entry("weapons",1).key==key and g.module_entry("weapons",1).level==57,"Native menu keeps slot level and applies requested equipment")
  check(p.items.weapons_1.key==key and card.name_button.text=="W02 "+scene.NAMES[key],"Card full title follows authoritative key")
  check(card.picture.texture==p.icon_for(key),"Card icon follows authoritative key")
  check(card==p.cards.weapons_1,"Quick refit retains the same card")
  p.invalidate_stats({"slot":"weapons_1"});p.refresh_pending();await process_frame
  check(card.name_button.text=="W02 "+scene.NAMES[key],"Later stat refresh preserves current title")
 # Synthetic missed identity event: exactly the projection-only refresh route.
 g.module_entry("weapons",1).key="longLaser";g.invalidate_stat_cache()
 check(p.items.weapons_1.key=="cannon","Fixture begins with a previous cached card identity")
 p.invalidate_stats({"slot":"weapons_1"});p.refresh_pending();await process_frame
 check(p.items.weapons_1.key=="longLaser" and card.name_button.text=="W02 "+scene.NAMES.longLaser,"Stat invalidation repairs full identity from authoritative entry")
 check(card.picture.texture==p.icon_for("longLaser") and card==p.cards.weapons_1,"Identity repair updates icon without recreating the card")
 scene.queue_free();await process_frame
 print("REFIT IDENTITY: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
