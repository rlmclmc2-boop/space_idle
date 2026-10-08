extends SceneTree
var checks=0
var failures=0
func check(ok:bool,label:String) -> void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize() -> void:call_deferred("run")
func gameplay_snapshot(g) -> String:
 var snapshot:Dictionary=g.profile.duplicate(true)
 snapshot.erase("hyperspaceReceipt") # The sole authorized UI-read marker.
 return JSON.stringify(snapshot)
func same_receipt(raw:Dictionary,expected:Dictionary) -> bool:
 var transfer=preload("res://scripts/save_transfer.gd")
 # JSON numbers are floats; preserve exact integral values without tolerance.
 if raw.size()!=4 or not transfer.shape(raw,transfer.schema().hyperspaceReceipt):return false
 return int(raw.round)==int(expected.round) and int(raw.run)==int(expected.run) and raw.drone_id==expected.drone_id and raw.unread==expected.unread
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
 var before=gameplay_snapshot(g)
 p.on_event("hyperspace_changed",{"reason":"completed_pending"})
 check(gameplay_snapshot(g)==before and not f.card.visible,"Pending feedback does not settle or reveal unclaimed reward")
 g.profile.hyperspace.active={};g.profile.hyperspace.unlocked_drones=true
 var bag:Dictionary=g.profile.hyperspace.inventory
 bag.drones[d.id]=d;bag.warehouse.append(d.id);bag.generation+=1
 p.on_event("hyperspace_changed",{"reason":"claimed"})
 await process_frame
 check(f.card.visible and f.view_button.visible and f.summary.text.contains("等级 5"),"Settled drone receives visible receipt and action")
 check(f.notice!=null and f.notice.visible,"First acquired drone opens actionable notice")
 p.weapon_filter.select(2);p.quality_filter.select(2);p.sort_order.select(1)
 before=gameplay_snapshot(g);f.view_drone()
 check(p.section_index==1 and p.selected_id==d.id,"Receipt opens the exact acquired drone")
 check(p.weapon_filter.selected==0 and p.quality_filter.selected==0 and p.sort_order.selected==0,"Explicit receipt reveals its card despite earlier inventory filters")
 check(gameplay_snapshot(g)==before,"Viewing reward does not auto-equip or change progress")
 f.notice.hide();p.toggle_equipped()
 check(g.profile.hyperspace.inventory.equipped.has(d.id),"Player explicitly equips the acquired drone")
 check(p.details.text.contains("独立开火") and p.details.text.contains(scene.number(g.equipment_stat("laser",int(g.drone_weapon_entry(d).level)))),"White drone exposes its independent weapon and authoritative base damage")
 check(not p.totals_summary.visible and not p.budgets.visible,"A plain white drone does not advertise zero affix benefit or irrelevant rare limits")
 var actual:Array=g.combat_weapon_entries().filter(func(e):return e.get("drone_id","")==d.id)
 check(actual.size()==1 and actual[0]==g.drone_weapon_entry(d),"Details share the exact weapon entry used by combat")
 check(p.equipment_ui.heading.text.contains("1 / "),"Slot heading shows authoritative occupancy")
 p.select_section(2)
 check(str(c.operation.get_item_metadata(c.operation.selected))=="add_hanging_slot" and c.operation.item_count<13,"First white refit defaults to an eligible hanging-slot operation in a compact menu")
 await capture("white-basic")
 c.select_operation("add_affix")
 await process_frame
 check(c.material_basis.text.contains("词条位") and not c.material_basis.text.contains("装备它") and c.commit_button.disabled,"White drone sees capacity condition instead of a fake payable quote")
 check(c.material_stock.text.contains("简并态物质"),"Materials are visible without pressing preview")
 var blue=preload("res://scripts/drone_rewards.gd").create_drone(rng,g.hyperspace.config,"feedback:blue","blue","missile",40,g.hyperspace.Permission.planet_for_level(g.db.data,40))
 bag=g.profile.hyperspace.inventory;bag.drones[blue.id]=blue;bag.warehouse.append(blue.id);bag.generation+=1
 g.profile.hyperspace.materials.degenerate_matter=2
 p.selected_id=blue.id;p.dirty=true;p.refresh();c.select_operation("replace_affix")
 await process_frame
 var line:Label=c.material_rows.degenerate_matter
 check(line.visible and line.text.contains("需要 5") and line.text.contains("持有 2") and line.text.contains("缺少 3"),"Actual replacement price and material deficit appear before explicit preview")
 check(line.get_theme_color("font_color")==Color("b32929") and c.material_route_button.visible,"Deficit is highlighted and has an exploration action")
 await capture("missing-material")
 before=gameplay_snapshot(g)
 c.refresh_materials();c.refresh_materials()
 check(gameplay_snapshot(g)==before,"Material projection preserves resources, command sequence and RNG")
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
 before=gameplay_snapshot(g);p.toggle_equipped()
 check(gameplay_snapshot(g)==before and not p.equipment_ui.feedback.text.is_empty(),"Rejected sealed replacement preserves existing equipment and explains failure")
 g.profile.hyperspace.inventory.sealed.erase(d.id)
 g.profile.selectedShip="Destroyer"
 g.hyperspace.set_equipped(g,[blue.id,d.id])
 var other=preload("res://scripts/drone_rewards.gd").create_drone(rng,g.hyperspace.config,"feedback:other","white","laser",5,"1")
 bag=g.profile.hyperspace.inventory;bag.drones[other.id]=other;bag.warehouse.append(other.id);bag.generation+=1
 p.selected_id=other.id;p.dirty=true;p.refresh();before=gameplay_snapshot(g);p.toggle_equipped()
 check(p.equipment_ui.replacement_dialog!=null and p.equipment_ui.replacement_dialog.visible and p.equipment_ui.replacement_choice.item_count==2,"Multiple occupied slots ask which drone to replace")
 check(gameplay_snapshot(g)==before,"Opening replacement chooser never unloads anything")
 g.hyperspace.set_equipped(g,[blue.id])
 check(g.switch_ship("Frigate"),"Hull-switch fixture uses the legal transaction")
 p.refresh()
 check(p.equipment_ui.heading.text.contains("/ 1") and not p.budgets.text.contains("1/2"),"Changing hull updates the sole occupancy display without a stale repeated budget")
 await capture("replacement-choice")
 p.equipment_ui.replacement_dialog.hide()
 scene.select_system(0)
 f.pending={"drone":blue.duplicate(true),"materials":{"degenerate_matter":1},"ultimate_cores":0}
 before=gameplay_snapshot(g)
 p.on_event("hyperspace_changed",{"reason":"claimed"})
 check(scene.equipment_tabs.current_tab==0 and not f.notice.visible,"Later reward never steals the active page or repeats the first-drone popup")
 var nav:Button=scene.system_nav_buttons[9];var dot:Control=nav.get_node("ActivationBadge")
 check(f.unread and dot.visible and nav.text==p.t("reward_nav_drone"),"A settled later drone remains visible in navigation outside hyperspace")
 await capture("cross-page-reward")
 for repeat in 5:scene.refresh_hyperspace_badge();scene.refresh_system_nav();f.mark_viewed()
 check(f.unread and dot.visible and gameplay_snapshot(g)==before,"Hidden receipts and ordinary refreshes preserve unread feedback without changing progress")
 var unread_save:Dictionary=g.portable_save_data()
 check(preload("res://scripts/hyperspace_state.gd").valid(unread_save.hyperspace,g.hyperspace.config,g.db.levels.size()) and g.hyperspace.Permission.bindings_valid(unread_save,g.db.data,g.hyperspace.config),"Save-boundary fixture satisfies the actual inventory and planet contracts")
 check(bool(unread_save.hyperspaceReceipt.unread),"Unseen rewards enter the existing portable save without an extra settlement")
 var transfer=preload("res://scripts/save_transfer.gd").new()
 var exported="user://feedback-unread-export.json"
 check(transfer.export_progress(g,exported)==OK,"Unread reward uses the actual export writer and schema cleaner")
 var prepared:Dictionary=transfer.prepare(exported,g.db)
 check(prepared.error.is_empty() and same_receipt(prepared.get("data",{}).get("hyperspaceReceipt",{}),unread_save.hyperspaceReceipt),"Actual file import preparation preserves the cleaned unread marker")
 if not prepared.error.is_empty():scene.queue_free();await process_frame;quit(1);return
 var resumed=BattleGame.new(g.db,false);resumed.load_progress_data(prepared.data)
 check(resumed.profile.hyperspaceReceipt==g.profile.hyperspaceReceipt,"Unread identity survives the existing save import boundary")
 var previous_host_game=scene.game
 scene.game=resumed;f.restore_read_state();scene.refresh_hyperspace_badge()
 check(f.unread and nav.text==p.t("reward_nav_drone") and str(f.latest.drone.id)==blue.id,"Restart restores the exact unread drone and visible navigation")
 scene.game=previous_host_game
 scene.select_system(9)
 await process_frame
 check(p.section_index==0 and f.card.is_visible_in_tree(),"Explicit navigation opens the unread receipt instead of an old refit page")
 f.mark_viewed()
 check(not f.unread and not dot.visible and nav.text==UIText.t(scene.SYSTEM_TITLES[9]),"Seeing the actual receipt restores the normal navigation caption and clears its unread dot")
 check(gameplay_snapshot(g)==before,"Reading a later receipt never settles, equips or mutates gameplay progress")
 var read_save:Dictionary=g.portable_save_data()
 check(transfer.export_progress(g,exported)==OK,"Read reward also uses the actual export writer")
 prepared=transfer.prepare(exported,g.db)
 check(prepared.error.is_empty() and not bool(prepared.get("data",{}).get("hyperspaceReceipt",{}).get("unread",true)),"Actual import preparation preserves the already-read flag")
 if not prepared.error.is_empty():scene.queue_free();await process_frame;quit(1);return
 resumed.load_progress_data(prepared.data)
 scene.game=resumed;f.restore_read_state()
 check(not f.unread,"Read rewards remain read after save and restart")
 var legacy:Dictionary=read_save.duplicate(true);legacy.erase("hyperspaceReceipt")
 prepared=transfer.prepare_data(legacy,g.db)
 check(prepared.error.is_empty() and not prepared.get("data",{}).has("hyperspaceReceipt"),"Legacy import remains valid and cleaning never invents UI metadata")
 if not prepared.error.is_empty():scene.queue_free();await process_frame;quit(1);return
 resumed.load_progress_data(unread_save);resumed.load_progress_data(prepared.data);f.restore_read_state()
 check(not f.unread,"Legacy saves do not announce already-owned drones again")
 var invalid:Dictionary=read_save.duplicate(true);invalid.hyperspaceReceipt={"round":"bad","run":-1,"drone_id":5,"unread":true};resumed.load_progress_data(invalid);f.restore_read_state()
 check(not f.unread,"Invalid optional UI receipt metadata stays quiet without accepting a false reward")
 check(transfer.prepare_data(invalid,g.db).error=="format","Malformed known UI fields follow the existing strict import rejection policy")
 invalid=read_save.duplicate(true);invalid.hyperspaceReceipt.round=-1;invalid.hyperspaceReceipt.unread=true
 prepared=transfer.prepare_data(invalid,g.db)
 check(prepared.error.is_empty(),"Integral UI markers follow existing integer shape validation")
 if not prepared.error.is_empty():scene.queue_free();await process_frame;quit(1);return
 resumed.load_progress_data(prepared.data);f.restore_read_state()
 check(not f.unread,"Semantically invalid optional UI counters load quietly through the real cleaner")
 var annotated:Dictionary=read_save.duplicate(true);annotated.hyperspaceReceipt.private_note="not-portable"
 prepared=transfer.prepare_data(annotated,g.db)
 check(prepared.error.is_empty() and not prepared.get("data",{}).get("hyperspaceReceipt",{}).has("private_note"),"Adding receipt fields never enables arbitrary metadata transport")
 var quiet=BattleGame.new(g.db,false);scene.game=quiet;f.restore_read_state();f.show_receipt()
 check(not f.unread and not f.card.visible,"A fresh save never invents a received-materials card")
 scene.game=previous_host_game
 print("Player feedback: ",checks," checks, ",failures," failures")
 scene.queue_free();await process_frame;quit(1 if failures else 0)
