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
 var g=scene.game;g.save_enabled=false;g.paused=true;g.profile.cleared=range(1,20);g.profile.highestLevel=20;g.rebuild_unlocks();g.pending_unlocks.clear();g.profile.onboarding.completed=true;g.profile.enhancementLevel=4
 g.profile.enhancementOrder=g.default_enhancement_order();g.invalidate_stat_cache()
 scene.refresh_tab_visibility();scene.select_system(4);await process_frame
 var p=scene.enhancement_panel;p.refresh()
 var before:=JSON.stringify(g.profile);var rng_before:int=g.rng.state
 var card=p.effect_cards.defence[1]
 check(card.state.text==UIText.t("enhance.effect.reorder") and card.description.get_parsed_text().contains("悬浮"),"Inactive memory remains marked inactive and advertises the compact preview")
 var popup=card.description._make_custom_tooltip(card.description.tooltip_text)
 var memory:String=popup.get_node("TooltipLabel").text;popup.free()
 check(memory.contains("当前 Lv4") and memory.contains("移到首位后") and memory.contains("20%/秒") and not memory.contains("[color"),"Actual hover previews current Lv4 recovery20% per second as a conditional choice")
 var repeat_preview:String=p.effect_hover_text("weapons",1)
 check(repeat_preview.contains("概率") and repeat_preview.contains("%") and not repeat_preview.contains("[color"),"Inactive repeat preview includes configured probability and damage")
 var critical_preview:String=p.effect_hover_text("weapons",2)
 check(critical_preview.contains("%") and critical_preview.contains("原伤害"),"Inactive critical preview includes current trigger and damage numbers")
 p.open_effect_details("defence","memory_material")
 check(p.effect_detail_body.text.contains(memory) and p.effect_detail_body.text.length()<200,"Inactive detail entry also shows the prospective value instead of an active-zero claim")
 p.effect_detail_dialog.hide()
 check(JSON.stringify(g.profile)==before and g.rng.state==rng_before,"Hover and detail projection preserve persistent profile, resources and combat RNG")
 p.move_effect("defence",1,-1);await process_frame;p.refresh()
 check(p.effect_cards.defence[0].description.get_parsed_text().contains("20%/秒") and memory.contains(p.effect_cards.defence[0].description.get_parsed_text()),"Current-level preview agrees with actual move-to-first result")
 p.move_effect("defence",0,1);await process_frame
 g.profile.enhancementLevel=0;g.invalidate_stat_cache();p.refresh()
 check(p.effect_hover_text("defence",1)==UIText.t("enhance.preview_not_active"),"Zero level does not promise an active effect merely by reordering")
 g.profile.enhancementLevel=mini(g.enhancement_effect_threshold(2)-1,40);g.profile.enhancementBranches.weapons.critical={"2":"B"};g.invalidate_stat_cache();p.refresh()
 var static_preview:String=p.effect_hover_text("weapons",2)
 var live:Dictionary=g.enhancement_branches.weapon(g,0);live.stacks=100;live.next=100;live.dwell=1000
 check(p.effect_hover_text("weapons",2)==static_preview,"Temporary combat stacks and pending attacks cannot enter candidate numbers")
 check(p.preview_button.visible and p.effect_cards.weapons[2].branches.visible,"Next-level preview and branch entry remain available")
 scene.queue_free();await process_frame
 print("ENHANCEMENT CANDIDATE PREVIEW: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
