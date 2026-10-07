extends SceneTree
var checks=0
var failures=0
func check(ok:bool,label:String) -> void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize() -> void:call_deferred("run")
func capture(name:String) -> void:
 var folder=OS.get_environment("PLAYER_FEEDBACK_EVIDENCE")
 if folder.is_empty() or DisplayServer.get_name()=="headless":return
 await process_frame;await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(folder.path_join(name+"-fixture.png"))
func run() -> void:
 var scene=load("res://main.tscn").instantiate();scene.automation_args=["--capture"]
 root.add_child(scene);scene.set_process(false);root.gui_embed_subwindows=true
 var g=scene.game;g.save_enabled=false;g.paused=true;g.pending_unlocks.clear()
 g.profile.highestLevel=34;g.profile.cleared=range(1,34);g.rebuild_unlocks();g.pending_unlocks.clear();g.profile.onboarding.completed=true
 scene.refresh_tab_visibility();scene.select_system(9)
 await process_frame
 var p=scene.hyperspace_panel;var c=p.commands;var f=p.reward_feedback
 var rng=RandomNumberGenerator.new();rng.seed=419
 var d=preload("res://scripts/drone_rewards.gd").create_drone(rng,g.hyperspace.config,"feedback:white","white","laser",5,"1")
 g.profile.hyperspace.unlocked_drones=false
 g.profile.hyperspace.active={"status":"completed_pending","reward":{"drone":d,"materials":{"degenerate_matter":3},"ultimate_cores":0}}
 var before=JSON.stringify(g.profile)
 p.on_event("hyperspace_changed",{"reason":"completed_pending"})
 check(JSON.stringify(g.profile)==before and not f.card.visible,"Pending feedback does not settle or reveal unclaimed reward")
 g.profile.hyperspace.active={};g.profile.hyperspace.unlocked_drones=true
 var bag:Dictionary=g.profile.hyperspace.inventory
 bag.drones[d.id]=d;bag.warehouse.append(d.id);bag.generation+=1
 p.on_event("hyperspace_changed",{"reason":"claimed"})
 await process_frame
 check(f.card.visible and f.view_button.visible and f.summary.text.contains("等级 5"),"Settled drone receives visible receipt and action")
 check(f.notice!=null and f.notice.visible,"First acquired drone opens actionable notice")
 before=JSON.stringify(g.profile);f.view_drone()
 check(p.section_index==1 and p.selected_id==d.id,"Receipt opens the exact acquired drone")
 check(JSON.stringify(g.profile)==before,"Viewing reward does not auto-equip or change progress")
 f.notice.hide();p.toggle_equipped()
 check(g.profile.hyperspace.inventory.equipped.has(d.id),"Player explicitly equips the acquired drone")
 check(p.equipment_ui.heading.text.contains("1 / "),"Slot heading shows authoritative occupancy")
 p.select_section(2);c.operation.select(0);c.configure_operation()
 await process_frame
 check(c.material_basis.text.contains("词条位") and c.commit_button.disabled,"White drone sees capacity condition instead of a fake payable quote")
 check(c.material_stock.text.contains("简并态物质"),"Materials are visible without pressing preview")
 var blue=preload("res://scripts/drone_rewards.gd").create_drone(rng,g.hyperspace.config,"feedback:blue","blue","missile",40,"1")
 bag=g.profile.hyperspace.inventory;bag.drones[blue.id]=blue;bag.warehouse.append(blue.id);bag.generation+=1
 g.profile.hyperspace.materials.degenerate_matter=2
 p.selected_id=blue.id;p.dirty=true;p.refresh();c.operation.select(1);c.configure_operation()
 await process_frame
 var line:Label=c.material_rows.degenerate_matter
 check(line.visible and line.text.contains("需要 5") and line.text.contains("持有 2") and line.text.contains("缺少 3"),"Actual replacement price and material deficit appear before explicit preview")
 check(line.get_theme_color("font_color")==Color("b32929") and c.material_route_button.visible,"Deficit is highlighted and has an exploration action")
 await capture("missing-material")
 before=JSON.stringify(g.profile)
 c.refresh_materials();c.refresh_materials()
 check(JSON.stringify(g.profile)==before,"Material projection preserves resources, command sequence and RNG")
 var count=c.material_reads
 for repeat in 5:p.refresh_progress()
 check(c.material_reads==count,"Frame progress never recomputes forge forecasts")
 c.explore_missing_material()
 check(p.section_index==0 and p.route=="alpha","Missing operation material opens its producing route, not the drone weapon route")
 p.select_section(2);c.preview()
 check(c.commit_button.disabled and c.feedback.text.contains("材料不足"),"Insufficient-material quote cannot execute")
 var rows=c.material_rows.duplicate();g.profile.hyperspace.materials.degenerate_matter=5
 c.refresh_materials()
 check(c.material_rows.degenerate_matter==rows.degenerate_matter and line.text.contains("缺少 0"),"Stock changes reuse controls and clear deficit")
 c.preview();c.execute_quote()
 check(g.profile.hyperspace.materials.degenerate_matter==0 and c.result_scroll.visible,"Paid action keeps exact domain debit and directly displays result")
 check(line.text.contains("持有 0"),"Post-command material holding updates")
 await capture("paid-result")
 p.select_section(1);p.toggle_equipped()
 check(g.profile.hyperspace.inventory.equipped==[blue.id],"One occupied slot replaces directly without an intermediate unload")
 check(p.equipment_ui.feedback.text.contains("已更新"),"Successful replacement has local feedback")
 p.selected_id=d.id;g.profile.hyperspace.inventory.sealed[d.id]=100
 before=JSON.stringify(g.profile);p.toggle_equipped()
 check(JSON.stringify(g.profile)==before and not p.equipment_ui.feedback.text.is_empty(),"Rejected sealed replacement preserves existing equipment and explains failure")
 g.profile.hyperspace.inventory.sealed.erase(d.id)
 g.profile.selectedShip="Destroyer"
 g.hyperspace.set_equipped(g,[blue.id,d.id])
 var other=preload("res://scripts/drone_rewards.gd").create_drone(rng,g.hyperspace.config,"feedback:other","white","laser",5,"1")
 bag=g.profile.hyperspace.inventory;bag.drones[other.id]=other;bag.warehouse.append(other.id);bag.generation+=1
 p.selected_id=other.id;p.dirty=true;p.refresh();before=JSON.stringify(g.profile);p.toggle_equipped()
 check(p.equipment_ui.replacement_dialog!=null and p.equipment_ui.replacement_dialog.visible and p.equipment_ui.replacement_choice.item_count==2,"Multiple occupied slots ask which drone to replace")
 check(JSON.stringify(g.profile)==before,"Opening replacement chooser never unloads anything")
 await capture("replacement-choice")
 p.equipment_ui.replacement_dialog.hide()
 print("Player feedback: ",checks," checks, ",failures," failures")
 scene.queue_free();await process_frame;quit(1 if failures else 0)
