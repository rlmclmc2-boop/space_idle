extends SceneTree
## Legal in-memory zero-slot fixtures and one isolated dismantle command;
## no natural-play timing, altered drop rule, configuration or player save.
const Rewards=preload("res://scripts/drone_rewards.gd")
const Bag=preload("res://scripts/drone_inventory.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String) -> void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func texts(window) -> Array:
 return window.find_children("*","Label",true,false).map(func(n):return n.text)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var scene=load("res://main.tscn").instantiate();scene.automation_args=["--capture"];root.add_child(scene);scene.set_process(false);root.gui_embed_subwindows=true
 var g=scene.game;g.save_enabled=false;g.paused=true;g.profile.highestLevel=6;g.profile.cleared=range(1,6);g.rebuild_unlocks();g.pending_unlocks.clear();g.profile.onboarding.completed=true;g.profile.hyperspace.unlocked_drones=true
 var rng=RandomNumberGenerator.new();rng.seed=8021
 var gold=Rewards.create_drone(rng,g.hyperspace.config,"display-gold","gold","laser",1,"1")
 var white=Rewards.create_drone(rng,g.hyperspace.config,"display-white","white","laser",1,"1")
 gold.hanging_slots=0;white.hanging_slots=0
 check(Bag.insert(g.profile.hyperspace.inventory,gold,g.hyperspace.config) and Bag.insert(g.profile.hyperspace.inventory,white,g.hyperspace.config),"Both zero-opened-slot fixtures are legal")
 scene.refresh_tab_visibility();scene.select_system(9);await process_frame
 var p=scene.hyperspace_panel;var c=p.commands;p.refresh_manual_status();p.select_section(1);p.choose_drone(gold.id)
 var before=JSON.stringify(g.profile);var combat_rng=g.rng.state
 for d in [gold,white]:
  p.choose_drone(d.id);c.show_modules();await process_frame
  var capacity=p.t("drone_hanging_capacity",{"opened":"0","capacity":str(Bag.hanging_limit(d,g.hyperspace.config))})
  check(p.capability_summary(d).contains(capacity) and texts(c.module_dialog).has(capacity),"Card and manager distinguish opened slots from capacity limit")
  check(c.module_id==d.id and p.selected_id==d.id and c.module_dialog.title.contains(p.quality_caption(d)),"Manager title and body use the selected drone")
  check(texts(c.module_dialog).has(p.t("module_slots",{"used":"0","cap":"0"})) and is_instance_valid(c.module_open_slot),"Zero installed/opened slots still allow existing paid opening")
  c.module_dialog.hide()
 p.selected_id="";p.refresh_details();c.show_module_carriers();await process_frame
 check(c.carrier_buttons.size()==2,"Receipt picker includes both valid carriers")
 var gold_button=c.carrier_buttons.filter(func(b):return str(b.get_meta("drone_id"))==gold.id)[0]
 gold_button.pressed.emit();await process_frame
 check(p.selected_id==gold.id and c.module_id==gold.id,"Picking gold among two carriers opens gold rather than last loop item")
 c.module_dialog.hide()
 check(JSON.stringify(g.profile)==before and g.rng.state==combat_rng,"Slot explanations and carrier selection are read-only")
 # Exact named-module receipt fixture checks short/secondary text, independent
 # of which module the later real dismantle command randomly awards.
 var rewards={"materials":{"glueball":10},"modules":{"extra_storage":{"level":1,"copies":1,"newly_unlocked":true,"experience_added":0}}}
 var brief=c.received_rewards_summary(rewards);var full=c.received_rewards_details(rewards)
 var name=p.hanging_name("extra_storage")
 check(brief.contains(name+" Lv1") and not brief.contains(c.module_effect_text("extra_storage",1)),"Short receipt retains exact module name/Lv and excludes long effects")
 p.show_inventory_receipt(brief,full);p.refresh_details();await process_frame
 check(p.inventory_feedback.text==brief and p.inventory_feedback.max_lines_visible==-1 and p.inventory_feedback.text_overrun_behavior==TextServer.OVERRUN_NO_TRIMMING,"Short module receipt cannot be line-clipped or ellipsized")
 p.inventory_receipt_details.pressed.emit();await process_frame
 check(p.inventory_receipt_dialog.visible and p.inventory_receipt_dialog.dialog_text==full and full.contains(c.module_effect_text("extra_storage",1)),"Secondary receipt exposes full progress and module effect explanation")
 p.choose_drone(white.id);await process_frame
 check(not p.inventory_receipt_dialog.visible and not p.inventory_receipt_details.visible and p.inventory_receipt_detail_text.is_empty(),"Changing selection dismisses stale receipt and secondary contents")
 check(JSON.stringify(g.profile)==before and g.rng.state==combat_rng,"Receipt formatting and detail interaction preserve profile/RNG")
 # Fresh-receipt fixture has no previously remembered module carrier.
 c.module_id=""
 c.dismantle_request=c.request("dismantle");c.execute_inventory_dismantle();await process_frame
 check(not g.profile.hyperspace.inventory.drones.has(white.id) and p.inventory_feedback.visible and p.inventory_feedback.text.contains(" Lv") and p.inventory_receipt_details.visible,"Existing real dismantle command supplies short Lv receipt and secondary details")
 before=JSON.stringify(g.profile);combat_rng=g.rng.state
 p.inventory_module_next.pressed.emit();await process_frame
 check(c.carrier_buttons.size()==1,"Post-dismantle receipt offers surviving carrier")
 c.carrier_buttons[0].pressed.emit();await process_frame
 check(p.selected_id==gold.id and c.module_id==gold.id and int(g.profile.hyperspace.inventory.drones[gold.id].hanging_slots)==0,"Receipt continuation selects gold without granting a slot")
 check(JSON.stringify(g.profile)==before and g.rng.state==combat_rng,"Receipt continuation changes no paid state or RNG")
 print("SLOT_FIELDS gold opened=",gold.hanging_slots," limit=",Bag.hanging_limit(gold,g.hyperspace.config)," white opened=",white.hanging_slots," limit=",Bag.hanging_limit(white,g.hyperspace.config))
 scene.queue_free();await process_frame
 print("Drone slot/receipt display: ",checks," checks, ",failures," failures");quit(1 if failures else 0)
