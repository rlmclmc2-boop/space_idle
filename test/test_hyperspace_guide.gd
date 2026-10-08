extends SceneTree
var checks=0
var failures=0
func check(ok: bool,message: String) -> void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var scene=load("res://main.tscn").instantiate()
 scene.automation_args=["--capture"]
 root.add_child(scene);scene.set_process(false);root.gui_embed_subwindows=true
 var g=scene.game;g.save_enabled=false;g.paused=true;g.pending_unlocks.clear()
 g.profile.highestLevel=34;g.profile.cleared=range(1,34);g.rebuild_unlocks();g.pending_unlocks.clear();g.profile.onboarding.completed=true
 scene.refresh_tab_visibility();scene.select_system(9)
 await process_frame
 var p=scene.hyperspace_panel
 check(p.is_visible_in_tree(),"Fixture enters the legally unlocked hyperspace page")
 var unlocked=bool(g.profile.hyperspace.unlocked_drones)
 g.profile.hyperspace.unlocked_drones=false;p.dirty=true;p.refresh()
 p.select_section(1)
 check(not p.inventory_box.visible and p.drone_locked.visible,"Before first win only the next action appears")
 check(not p.capacity.visible and not p.budgets.visible,"No capacity or advanced equipment budgets before first win")
 check(not p.section_buttons[2].visible and not p.section_buttons[3].visible,"Refit and presets remain hidden before first win")
 p.select_section(2);check(p.section_index==0,"Programmatic refit navigation also honors first win")
 p.commands.show_guide();check(p.commands.guide_dialog==null,"Guide cannot reveal locked content")
 g.profile.hyperspace.unlocked_drones=true;p.dirty=true;p.refresh();p.select_section(1)
 check(p.inventory_box.visible and not p.drone_locked.visible and p.capacity.visible,"Inventory revealed after first win")
 check(p.section_buttons[2].visible and p.section_buttons[3].visible,"Existing refit and presets revealed after first win")
 p.select_section(2)
 var original_state=JSON.stringify(g.profile)
 var unrelated=p.cards[0];var filters=p.weapon_filter
 p.commands.select_operation("add_affix");p.commands.show_guide()
 await process_frame
 var dialog=p.commands.guide_dialog;var label=p.commands.guide_label
 check(label.text.contains("白色没有词条位") and not label.text.contains("究极"),"Adding a first affix explains capacity without unrelated advanced chapters")
 check(dialog.size.y<=550,"Context guide fits a short viewport")
 dialog.hide();p.commands.select_operation("replace_affix");p.commands.show_guide()
 await process_frame
 check(p.commands.guide_dialog==dialog and p.commands.guide_label==label,"Topic changes reuse the guide controls")
 check(label.text.contains("中途可能改掉其他未锁词条") and not label.text.contains("品质决定容量"),"Replacement guide explains guaranteed target instead of retaining previous topic")
 dialog.hide();p.commands.select_operation("promote_affix");p.commands.show_guide()
 check(label.text.contains("未来预兆不会改变升阶目标"),"Promotion guide matches actual target selection")
 check(not p.commands.promotion_hint.text.contains("凶兆"),"Inline promotion hint does not claim nonexistent targeting")
 dialog.hide();p.commands.select_operation("modernize");p.commands.show_guide()
 check(label.text.contains("最高通关记录") and label.text.contains("本轮主线最大关卡"),"Modernization retains both progression conditions")
 check(p.cards[0]==unrelated and p.weapon_filter==filters,"Help preserves unrelated inventory controls")
 check(JSON.stringify(g.profile)==original_state,"Reading guides never changes progress, resources or RNG")
 dialog.hide()
 var rng=RandomNumberGenerator.new();rng.seed=419
 var d=preload("res://scripts/drone_rewards.gd").create_drone(rng,g.hyperspace.config,"guide:white","white","laser",5,"1")
 g.profile.hyperspace.inventory.drones[d.id]=d;g.profile.hyperspace.inventory.warehouse.append(d.id);g.profile.hyperspace.inventory.generation+=1
 p.selected_id=d.id;p.dirty=true;p.refresh();p.commands.select_operation("add_affix")
 var before_preview=JSON.stringify(g.profile);p.commands.preview()
 check(p.commands.feedback.text.contains("词条位") and p.commands.quote_label.text.is_empty() and p.commands.commit_button.disabled,"Rejected capacity preview shows its reason without a misleading free quote")
 var cap=preload("res://scripts/drone_inventory.gd").affix_limit(d,g.hyperspace.config)
 check(p.forge_details.text.contains("0/"+str(cap)) and not p.forge_details.text.contains("版本"),"Selected drone shows actual capacity instead of a revision number")
 check(JSON.stringify(g.profile)==before_preview,"Rejected preview leaves progress and resources unchanged")
 var blue=preload("res://scripts/drone_rewards.gd").create_drone(rng,g.hyperspace.config,"guide:blue","blue","laser",5,"1")
 g.profile.hyperspace.inventory.drones[blue.id]=blue;g.profile.hyperspace.inventory.warehouse.append(blue.id);g.profile.hyperspace.inventory.generation+=1
 g.profile.hyperspace.materials.degenerate_matter=int(g.hyperspace.config.forge_costs.replace_affix.degenerate_matter)
 p.selected_id=blue.id;p.dirty=true;p.refresh();p.commands.select_operation("replace_affix");p.commands.preview();p.commands.execute_quote()
 var current:Dictionary=g.profile.hyperspace.inventory.drones[blue.id]
 check(p.commands.result_scroll.visible and p.commands.result_details.text.ends_with(p.drone_description(current)),"Successful paid replacement displays the actual resulting properties on the refit page")
 if DisplayServer.get_name()!="headless" and not OS.get_environment("GUIDE_EVIDENCE").is_empty():
  scene.automation_args=[];scene.overlay_layer.queue_redraw()
  await process_frame;await process_frame;await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(OS.get_environment("GUIDE_EVIDENCE")+"/49-paid-result-render-fixture.png")
 g.profile.hyperspace.unlocked_drones=false;p.dirty=true;p.refresh()
 check(p.section_index==0 and not p.sections[2].visible,"Losing first-win access while refit is open returns to exploration")
 g.profile.hyperspace.unlocked_drones=unlocked
 print("Hyperspace guide: ",checks," checks, ",failures," failures")
 scene.queue_free();await process_frame;quit(1 if failures else 0)
