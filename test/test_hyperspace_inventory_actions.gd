extends SceneTree
var checks=0
var failures=0
func check(ok:bool,message:String) -> void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var scene=load("res://main.tscn").instantiate();scene.automation_args=["--capture"]
 root.add_child(scene);scene.set_process(false);root.gui_embed_subwindows=true
 var g=scene.game;g.save_enabled=false;g.paused=true;g.pending_unlocks.clear()
 g.profile.highestLevel=34;g.profile.cleared=range(1,34);g.rebuild_unlocks();g.pending_unlocks.clear();g.profile.onboarding.completed=true
 scene.refresh_tab_visibility();scene.select_system(9);await process_frame
 g.profile.hyperspace.unlocked_drones=true
 var p=scene.hyperspace_panel;var c=p.commands;var rng=RandomNumberGenerator.new();rng.seed=391
 var bag:Dictionary=g.profile.hyperspace.inventory
 for id in ["action-one","action-two"]:
  var d=preload("res://scripts/drone_rewards.gd").create_drone(rng,g.hyperspace.config,id,"white","laser",6,"1")
  bag.drones[id]=d;bag.warehouse.append(id)
 bag.generation+=1;p.refresh_manual_status();p.selected_id="action-one";p.select_section(2);c.select_operation("add_hanging_slot")
 for i in c.operation.item_count:check(c.operation.get_item_metadata(i)!="dismantle","Refit menu excludes dismantling")
 var before=JSON.stringify(g.profile)
 p.begin_forge_pick();check(p.section_index==1 and p.forge_pick_cancel.visible,"Refit selection opens warehouse with cancel")
 p.choose_drone("action-two")
 check(p.section_index==2 and p.selected_id=="action-two" and p.forge_pick_state.is_empty(),"Choosing a drone returns to refit immediately")
 check(c.operation.get_item_metadata(c.operation.selected)=="add_hanging_slot","Chosen refit operation survives changing object")
 p.begin_forge_pick();p.forge_pick_cancel.pressed.emit()
 check(p.section_index==2 and p.selected_id=="action-two" and c.operation.get_item_metadata(c.operation.selected)=="add_hanging_slot","Cancel returns to original object and operation")
 c.select_operation("replace_affix");c.guarantee.select(1)
 var guaranteed_key=c.guarantee.get_item_metadata(c.guarantee.selected)
 p.begin_forge_pick();p.choose_drone("action-one")
 check(c.operation.get_item_metadata(c.operation.selected)=="replace_affix" and c.guarantee.get_item_metadata(c.guarantee.selected)==guaranteed_key,"Selected guaranteed affix survives returning to refit")
 p.choose_drone("action-two");c.select_operation("add_hanging_slot")
 check(JSON.stringify(g.profile)==before,"Choosing and cancelling do not alter player state")
 p.select_section(1);c.show_inventory_dismantle()
 check(c.dismantle_dialog.visible and not c.dismantle_dialog.get_ok_button().disabled and c.dismantle_dialog.dialog_text.contains(c.dismantle_preview_text(c.dismantle_request)),"Warehouse dismantle opens an actionable return preview")
 c.dismantle_dialog.canceled.emit();c.dismantle_dialog.hide()
 check(JSON.stringify(g.profile)==before,"Cancel dismantling leaves inventory and rewards unchanged")
 for kind in ["equipped","favorite","preset"]:
  bag=g.profile.hyperspace.inventory
  if kind=="equipped":bag.equipped=["action-two"]
  elif kind=="favorite":bag.favorites=["action-two"]
  else:bag.presets=[{"name":"fixture","drone_ids":["action-two"]}]
  bag.generation+=1;p.refresh_manual_status();p.refresh();c.show_inventory_dismantle()
  check(c.dismantle_dialog.get_ok_button().disabled and c.dismantle_dialog.dialog_text.contains(p.t(kind)),kind+" protection is visible and blocks confirmation")
  c.dismantle_dialog.hide();c.dismantle_request={}
  bag.equipped=[];bag.favorites=[];bag.presets=[]
 bag.generation+=1;p.refresh_manual_status();p.refresh();c.show_inventory_dismantle()
 g.hyperspace.set_favorites(g,["action-two"])
 c.dismantle_dialog.confirmed.emit();c.dismantle_dialog.hide()
 check(g.profile.hyperspace.inventory.drones.has("action-two") and p.inventory_feedback.text.contains(c.error_text("protected_drone")),"Protection added after preview is rechecked by authoritative command")
 g.hyperspace.set_favorites(g,[]);p.refresh_manual_status();p.refresh();c.show_inventory_dismantle()
 var request=c.dismantle_request.duplicate(true)
 var expected:Dictionary=preload("res://scripts/drone_forge.gd").plan(g.profile.hyperspace.duplicate(true),g.hyperspace.config,request,g)
 check(str(expected.error).is_empty(),"Existing domain accepts this dismantle fixture")
 var stock_before:Dictionary=g.profile.hyperspace.materials.duplicate(true)
 c.dismantle_dialog.confirmed.emit();c.dismantle_dialog.hide()
 check(not g.profile.hyperspace.inventory.drones.has("action-two") and not p.bag.drones.has("action-two") and p.selected_id.is_empty(),"Confirm removes the exact drone and refreshes selected inventory")
 for key in expected.get("rewards",{}).get("materials",{}):check(int(g.profile.hyperspace.materials[key])==int(stock_before[key])+int(expected.rewards.materials[key]),"Returned material matches authoritative plan")
 check(not p.inventory_feedback.text.is_empty() and p.inventory_feedback.visible and p.scroll.is_ancestor_of(p.inventory_feedback) and p.section_index==1,"Dismantle result remains inside scrollable warehouse detail")
 p.choose_drone("action-one")
 check(not p.inventory_feedback.visible and p.details.text.contains("独立开火"),"Selecting another drone clears old receipt obstruction and exposes its details")
 print("Inventory actions: ",checks," checks, ",failures," failures")
 scene.queue_free();await process_frame;quit(1 if failures else 0)
