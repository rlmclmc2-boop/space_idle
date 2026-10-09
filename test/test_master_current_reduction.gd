extends SceneTree
const Rewards=preload("res://scripts/drone_rewards.gd")
const Bag=preload("res://scripts/drone_inventory.gd")
const CC=preload("res://scripts/combat_context.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize()->void:call_deferred("run")
func run()->void:
 var scene=load("res://main.tscn").instantiate();scene.automation_args=["--capture"]
 root.add_child(scene);scene.set_process(false);root.gui_embed_subwindows=true
 var g=scene.game;g.save_enabled=false;g.paused=true;g.profile.highestLevel=40;g.profile.cleared=range(1,40);g.rebuild_unlocks();g.pending_unlocks.clear();g.profile.onboarding.completed=true
 g.profile.hyperspace.unlocked_drones=true
 var rng:=RandomNumberGenerator.new();rng.seed=811
 var d:Dictionary=Rewards.create_drone(rng,g.hyperspace.config,"master-current","legendary","laser",6,"1")
 d.legendary_effect={"effect_id":"drone_master","parameters":{"maximum_reduction":0.578}};d.affixes=[]
 check(Bag.insert(g.profile.hyperspace.inventory,d,g.hyperspace.config),"Legal legendary master fixture")
 g.profile.hyperspace.inventory.equipped=[d.id];g.invalidate_stat_cache()
 scene.refresh_tab_visibility();scene.select_system(9);await process_frame
 var p=scene.hyperspace_panel;p.refresh_manual_status();p.selected_id=d.id;p.select_section(1);p.refresh()
 var help=p.legendary_help
 p.show_selected_legendary()
 var expected:float=0.578*float(g.hyperspace.config.legendary_effects.drone_master.constants.quality_ratios.legendary)/float(g.hyperspace.config.legendary_effects.drone_master.constants.quality_ratios.ultimate)
 check(help.dialog.visible and help.body.text.contains(p.t("master_owned_cap")+": 57.8%") and help.body.text.contains(p.t("master_current_reduction",{"value":"%.1f"%(expected*100.0)})),"Actual detail distinguishes owned57.8percent cap from current quality-scaled reduction")
 check(p.legendary_summary.text.contains("当前全舰减伤"),"Compact owned-effect area shows actual current reduction")
 var before:=JSON.stringify(g.profile);var rng_before:int=g.rng.state
 var incoming:Dictionary=g.drone_combat.incoming(g,100.0,CC.root(0,"enemy","laser"))
 check(is_equal_approx(float(incoming.damage),100.0*(1.0-expected)) and is_equal_approx(g.drone_combat.master_reduction(g),expected),"Read-only display and actual incoming path agree")
 check(help.explanation(d.legendary_effect,"another-master").contains(p.t("master_other_source")),"Viewing another same-kind effect cannot attribute the active reduction to its own cap")
 check(JSON.stringify(g.profile)==before and g.rng.state==rng_before,"Display and ordinary master-only incoming step preserve save and RNG")
 g.drone_combat.disabled=[d.id];g.invalidate_stat_cache();g.event.emit("hyperspace_rebuild",{});p.refresh()
 check(help.body.text.contains(p.t("master_current_reduction",{"value":"0.0"})) and help.body.text.contains(p.t("master_not_active")),"Already-open detail updates to zero when the only master is disabled")
 g.drone_combat.restore_disabled(g,"stage");p.refresh()
 check(help.body.text.contains(p.t("master_current_reduction",{"value":"%.1f"%(expected*100.0)})),"Existing restore event updates the same open detail")
 d=g.profile.hyperspace.inventory.drones[d.id];d.ultimate=true;d.ultimate_affix=Rewards.affix(rng,g.hyperspace.config,"laser");g.invalidate_stat_cache();g.event.emit("hyperspace_changed",{"reason":"forge_ultimate"})
 incoming=g.drone_combat.incoming(g,100.0,CC.root(0,"enemy","laser"))
 check(is_equal_approx(float(incoming.damage),42.2) and help.body.text.contains(p.t("master_current_reduction",{"value":"57.8"})),"Active ultimate quality reaches the owned cap in both damage and live detail")
 d.legendary_effect.parameters.maximum_reduction=0.889;g.invalidate_stat_cache()
 check(is_equal_approx(g.drone_combat.master_reduction(g),0.889),"Existing historical parameter remains exact without clamping")
 g.profile.hyperspace.inventory.equipped=[];g.invalidate_stat_cache();g.event.emit("hyperspace_changed",{"reason":"equipped"})
 check(help.body.text.contains(p.t("master_not_active")) and is_equal_approx(g.drone_combat.master_reduction(g),0.0),"Unequipped owned effect still shows its cap but no active reduction")
 check(not p.commands.error_text("legendary_repeat_policy_required").contains("尚未确定"),"Repeat legendary action contains no author placeholder")
 scene.queue_free();await process_frame
 print("MASTER CURRENT: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
