extends SceneTree
var failures:=0
func check(ok:bool,message:String)->void:
 if not ok:failures+=1;printerr("FAIL: ",message)
func _initialize()->void:call_deferred("run")
func run()->void:
 var scene=load("res://main.tscn").instantiate();scene.automation_args=["--capture"]
 root.add_child(scene);scene.set_process(false);root.gui_embed_subwindows=true
 var g=scene.game;g.save_enabled=false;g.paused=true;g.pending_unlocks.clear()
 var gate=int(g.db.data.unlock[str(g.db.data.planet["1"].unlockId)].level)
 g.profile.highestLevel=gate+1;g.profile.cleared=range(1,gate+1);g.rebuild_unlocks();g.pending_unlocks.clear()
 var state=g.planet_buildings.state(g,"1","shipyard");state.status="built"
 var d=preload("res://scripts/drone_rewards.gd").create_drone(g.rng,g.hyperspace.config,"receipt-retain","white","laser",1,"1")
 g.profile.hyperspace.unlocked_drones=true;g.profile.hyperspace.inventory.drones[d.id]=d;g.profile.hyperspace.inventory.warehouse.append(d.id)
 var draft=preload("res://scripts/hyperspace_reforge_dialog.gd").new();draft.setup(g,"1","");scene.add_child(draft)
 draft.choices[d.id].button_pressed=true;draft.commit()
 await process_frame;await process_frame
 var receipts=root.get_children().filter(func(child):return child is AcceptDialog and child.title==UIText.t("planet.reforge_completed"))
 check(not is_instance_valid(draft) and receipts.size()==1,"Successful reforge receipt survives destruction of the old draft/page")
 var expected=UIText.t("planet.reforge_sealed_receipt",{"count":"1","level":str(gate)})+"\n"+UIText.t("planet.reforge_reclaim_path")
 check(receipts.size()==1 and receipts[0].dialog_text==expected,"Receipt states actual retained count, table-derived gate and real reclaim path")
 for receipt in receipts:receipt.hide()
 scene.refresh_tab_visibility();scene.select_system(6);await process_frame
 scene.planet_panel._show_facility("1","shipyard")
 check(scene.planet_panel.facility_description.text==expected,"Completed shipyard keeps the same destination available for active lookup")
 for receipt in receipts:receipt.queue_free()
 scene.queue_free();await process_frame
 print("Reforge receipt: 3 checks, ",failures," failures");quit(1 if failures else 0)
