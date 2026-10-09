extends SceneTree
var checks:=0
var failures:=0
func check(ok:bool,label:String) -> void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var scene=load("res://main.tscn").instantiate();scene.automation_args=["--capture"]
 root.add_child(scene);scene.set_process(false)
 var g=scene.game;g.save_enabled=false;g.paused=true
 g.profile.highestLevel=61;g.profile.cleared=range(1,61);g.rebuild_unlocks();g.pending_unlocks.clear();g.profile.onboarding.completed=true
 g.profile.enhancementLevel=0;g.invalidate_stat_cache()
 scene.refresh_tab_visibility();scene.select_system(4)
 await process_frame
 var p=scene.enhancement_panel;p.open();p.refresh()
 var before=JSON.stringify(g.profile);var rng=g.rng.state
 var panels:Array=[]
 for category in ["weapons","defence"]:
  for card in p.effect_cards[category]:
   panels.append(card.panel)
   check(card.title.visible and not card.title.text.is_empty() and card.description.visible and not card.description.get_parsed_text().is_empty(),"Zero level keeps each effect introduction")
   check(not card.state.visible and not card.up.visible and not card.down.visible and not card.details.visible and not card.branches.visible,"Zero level hides repeated activation state and unavailable controls")
 check(p.rule_label.visible and p.rule_label.text==UIText.t("enhance.effect.first_upgrade") and p.preview_button.visible,"First upgrade guidance appears once and real next-upgrade preview remains available")
 p.refresh()
 check(JSON.stringify(g.profile)==before and g.rng.state==rng,"Refresh changes no level, resources, ordering, branch choice or RNG")
 g.profile.jewelFragments=g.enhancement_cost();p.refresh();p.upgrade_button.pressed.emit()
 check(g.enhancement_level()==1 and GrowthNumber.compare(g.profile.jewelFragments,0)==0,"Existing first-upgrade control still purchases and debits the real transaction")
 check(p.effect_cards.weapons[0].details.visible and p.effect_cards.weapons[1].up.visible and p.effect_cards.weapons[0].state.visible,"Comparison and ordering appear when the first effects unlock")
 p.open_effect_details("defence","memory_material")
 var requirement=UIText.t("enhance.effect.position_requirement",{"position":2,"level":p.threshold_level(1)})
 check(p.effect_detail_body.text.begins_with(UIText.t("enhance.effect.inactive")) and p.effect_detail_body.text.contains("移到首位后") and p.effect_detail_body.text.contains("5%/秒") and p.effect_detail_body.text.ends_with(requirement),"Inactive second position leads with the real first-position preview and labels its positional threshold last")
 var before_reorder=g.profile.jewelFragments;p.move_effect("defence",1,-1)
 check(p.effect_detail_body.text.begins_with(UIText.t("enhance.effect.active",{"count":p.eligible_count("defence",0)})) and not p.effect_detail_body.text.contains(requirement) and g.enhancement_order("defence")[0]=="memory_material" and g.profile.jewelFragments==before_reorder,"Moving to first updates the same open detail to active without level-ten gating or cost")
 p.effect_detail_dialog.hide()
 var first=str(g.enhancement_order("weapons")[0]);var threshold=g.enhancement_branch_threshold(1,"weapons",first)
 g.profile.enhancementLevel=threshold-1;g.invalidate_stat_cache();p.refresh()
 check(not p.effect_cards.weapons[0].branches.visible,"Branch entry remains hidden immediately before its actual unlock")
 g.profile.enhancementLevel=threshold;g.invalidate_stat_cache();p.refresh()
 check(p.effect_cards.weapons[0].branches.visible,"Branch entry appears at its actual configured threshold")
 p.effect_cards.weapons[0].branches.pressed.emit()
 check(p.branch_overlay.visible and not p.branch_rows[0].A.disabled,"Revealed branch opens the existing legal choices")
 p.branch_overlay.hide()
 var i:=0
 for category in ["weapons","defence"]:
  for card in p.effect_cards[category]:
   check(card.panel==panels[i],"Level changes reuse original cards");i+=1
 g.profile.enhancementLevel=0;g.invalidate_stat_cache();p.refresh()
 check(not p.effect_cards.weapons[0].details.visible and not p.effect_cards.weapons[0].branches.visible,"Returning to zero strength clears controls instead of retaining unlocked chrome")
 print("Enhancement entry: ",checks," checks, ",failures," failures")
 scene.queue_free();await process_frame;quit(1 if failures else 0)
