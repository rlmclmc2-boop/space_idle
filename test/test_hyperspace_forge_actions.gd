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
 var p=scene.hyperspace_panel;var c=p.commands;var a=c.forge_actions
 var rng=RandomNumberGenerator.new();rng.seed=912
 var d=preload("res://scripts/drone_rewards.gd").create_drone(rng,g.hyperspace.config,"forge-actions","blue","laser",6,"1")
 d.affixes=[];d.hanging_slots=0
 var bag:Dictionary=g.profile.hyperspace.inventory;bag.drones[d.id]=d;bag.warehouse.append(d.id);bag.generation+=1
 for key in g.profile.hyperspace.materials:g.profile.hyperspace.materials[key]=1000000
 p.refresh_manual_status();p.selected_id=d.id;p.select_section(2);a.refresh()
 check(not c.operation.is_visible_in_tree() and not c.commit_button.is_visible_in_tree(),"Refit no longer requires operation dropdown or generic confirmation")
 var zero_stock=g.profile.hyperspace.materials.zero_point_energy;g.profile.hyperspace.materials.zero_point_energy=0;a.refresh()
 check(not a.cells.legendary.visible and not a.cells.ultimate.visible,"Unseen rare controls remain hidden before their resources are acquired")
 g.profile.hyperspace.materials.zero_point_energy=zero_stock;a.refresh()
 var state=JSON.stringify(g.profile);var rng_state=g.rng.state
 a.refresh();check(JSON.stringify(g.profile)==state and g.rng.state==rng_state,"Rendering action costs changes neither player state nor combat RNG")
 var req=a.request("add_affix");var expected:Dictionary=preload("res://scripts/drone_forge.gd").plan(g.profile.hyperspace.duplicate(true),g.hyperspace.config,req,g)
 var before:int=int(g.profile.hyperspace.materials.degenerate_matter)
 a.buttons.add_affix.pressed.emit()
 check(g.profile.hyperspace.inventory.drones[d.id].affixes.size()==1 and int(g.profile.hyperspace.materials.degenerate_matter)==before-int(expected.cost.degenerate_matter),"One add-affix click executes and charges authoritative cost")
 check(c.result_scroll.get_parent()==c.feedback.get_parent() and c.result_scroll.visible and c.result_details.text.contains(p.affix_summary(g.profile.hyperspace.inventory.drones[d.id].affixes[0],g.profile.hyperspace.inventory.drones[d.id])) and not c.result_details.text.contains(p.t("drone_dynamic_weapon_hint")),"Current affix grades and values stay beside selection without long weapon rules")
 a.refresh();check(a.cells.enable_omen.visible and not a.buttons.enable_omen.disabled,"Omen action becomes visible when affixes exist")
 a.buttons.enable_omen.pressed.emit()
 check(g.profile.hyperspace.inventory.drones[d.id].omen and a.buttons.enable_omen.text.contains(c.t("omen_on_action")),"One click enables omen and shows current on-state immediately")
 a.buttons.enable_omen.pressed.emit()
 check(not g.profile.hyperspace.inventory.drones[d.id].omen and a.buttons.enable_omen.text.contains(c.t("operation_enable_omen")),"Same control disables omen in one click")
 check(a.selectors.replace_affix.is_visible_in_tree() and a.maximum.is_visible_in_tree(),"Guarantee and maximum options belong to their independent action")
 a.selectors.replace_affix.select(1);a.refresh()
 check(a.buttons.replace_affix.text.contains(c.t("action_guaranteed_cost")),"Guaranteed replacement states accumulated cost instead of claiming base cost is total")
 a.buttons.replace_affix.pressed.emit()
 check(a.confirmation!=null and a.confirmation.visible and c.quoted_request.args.has("guaranteed_key"),"Guaranteed action opens its exact cumulative quote directly")
 a.confirmation.canceled.emit();a.confirmation.hide()
 a.selectors.replace_affix.select(0)
 a.buttons.lock_affix.pressed.emit()
 check(a.confirmation.visible and not g.profile.hyperspace.inventory.drones[d.id].affixes[0].locked,"Irreversible lock waits for its own confirmation")
 a.confirmation.confirmed.emit();a.confirmation.hide()
 check(g.profile.hyperspace.inventory.drones[d.id].affixes[0].locked,"Explicit confirmation performs original lock command")
 c.invalidate()
 check(c.result_scroll.visible,"Changing help or operation retains current affix results before any new purchase")
 var selected_operation=c.operation.get_item_metadata(c.operation.selected)
 var help_before=JSON.stringify(g.profile);c.show_guide()
 check(c.guide_dialog.title==c.t("forge_guide") and not c.guide_label.text.contains(c.t("quote")) and not c.guide_label.text.contains(c.t("commit_forge")),"General guide describes current buttons without hidden old workflow")
 a.info_buttons.add_hanging_slot.pressed.emit()
 check(c.guide_dialog.title==c.t("operation_add_hanging_slot") and c.guide_label.text==c.t("forge_guide_add_hanging_slot") and c.operation.get_item_metadata(c.operation.selected)==selected_operation,"Adjacent info opens exact function without choosing an operation")
 check(JSON.stringify(g.profile)==help_before,"Browsing function help does not mutate gameplay")
 c.guide_dialog.hide();g.profile.hyperspace.ultimate_cores=1;a.refresh();a.buttons.ultimate.pressed.emit()
 check(a.confirmation.visible and a.confirmation.dialog_text.contains("不能继续常规改造") and a.confirmation.dialog_text.contains("可以还原") and a.confirmation.dialog_text.contains("不退回") and not a.confirmation.dialog_text.contains("{"),"Ultimate confirmation explains effect, modification lock and paid restoration")
 check(not g.profile.hyperspace.inventory.drones[d.id].ultimate,"Reading ultimate consequence does not perform conversion")
 a.confirmation.canceled.emit();a.confirmation.hide()
 var saved_stock=g.profile.hyperspace.materials.degenerate_matter;g.profile.hyperspace.materials.degenerate_matter=0;a.refresh()
 check(not a.buttons.add_affix.disabled and a.buttons.add_affix.text.contains("先兑换") and a.buttons.add_affix.text.contains(c.t("degenerate_matter")+" "+str(int(g.hyperspace.config.forge_costs.add_affix.degenerate_matter)*int(g.hyperspace.config.material_unit_scale))),"Missing add-affix materials offer the exact-scaled exchange instead of a forge purchase")
 var before_exchange=JSON.stringify(g.profile)
 a.buttons.add_affix.pressed.emit()
 var exchange=c.exchange_ui
 check(exchange.dialog.visible and exchange.material(exchange.source)=="zero_point_energy" and exchange.material(exchange.target)=="degenerate_matter" and int(exchange.amount.value)==int(g.hyperspace.config.forge_costs.add_affix.degenerate_matter)*int(g.hyperspace.config.material_unit_scale),"Button opens existing exchange prefilled with current scaled shortage")
 check(int(exchange.quote.cost.zero_point_energy)==int(exchange.amount.value)*2 and JSON.stringify(g.profile)==before_exchange,"Opening prefill preserves every balance and exact2:1 rate")
 exchange.review()
 check(exchange.confirmation.visible and JSON.stringify(g.profile)==before_exchange,"Review waits for explicit confirmation")
 exchange.confirmation.canceled.emit();exchange.confirmation.hide();exchange.dialog.hide()
 check(JSON.stringify(g.profile)==before_exchange,"Canceled exchange does not spend or forge")
 exchange.show_prefilled("zero_point_energy","degenerate_matter",int(exchange.amount.value));exchange.review()
 var source_before=int(g.profile.hyperspace.materials.zero_point_energy);var received=int(exchange.amount.value)
 exchange.confirmation.confirmed.emit();exchange.confirmation.hide();exchange.dialog.hide()
 check(int(g.profile.hyperspace.materials.zero_point_energy)==source_before-2*received and int(g.profile.hyperspace.materials.degenerate_matter)==received,"Only explicit confirmation exchanges exact2:1 shortage, without performing forge")
 # Reproduce the real100-glue upgrade with90 owned and30 degenerate.
 var saved_glue=int(g.profile.hyperspace.materials.glueball)
 var saved_deg=int(g.profile.hyperspace.materials.degenerate_matter)
 g.profile.hyperspace.materials.glueball=90;g.profile.hyperspace.materials.degenerate_matter=30;a.refresh()
 check(not a.buttons.add_hanging_slot.disabled and a.buttons.add_hanging_slot.text.contains("10"+c.t("glueball")),"Missing10 glue has a clickable exact shortage entry")
 var slots_before=int(g.profile.hyperspace.inventory.drones[d.id].hanging_slots)
 var shortage_state=JSON.stringify(g.profile)
 a.buttons.add_hanging_slot.pressed.emit()
 check(exchange.dialog.visible and exchange.material(exchange.source)=="degenerate_matter" and exchange.material(exchange.target)=="glueball" and int(exchange.amount.value)==10,"Actual hanging-slot action prefills10 glue from20 degenerate, not generic1")
 check(JSON.stringify(g.profile)==shortage_state,"Opening shortage does not exchange or add a slot")
 exchange.amount.value=3;await process_frame
 check(int(exchange.quote.amount)==3,"Native spin-step quote refresh follows its updated visible text")
 exchange.amount.value=1
 var edit:LineEdit=exchange.amount.get_line_edit()
 edit.text="10";edit.text_changed.emit(edit.text)
 check(int(exchange.amount.value)==1 and int(exchange.quote.amount)==10 and int(exchange.quote.cost.degenerate_matter)==20,"Typed10 updates quote while native SpinBox still holds1")
 exchange.review()
 check(int(exchange.pending_request.amount)==10 and int(exchange.amount.value)==10 and exchange.confirmation.dialog_text.contains("20"),"Review commits visible10 and freezes the correct20-for10 request")
 exchange.confirmation.canceled.emit();exchange.confirmation.hide()
 edit.text="2.5";edit.text_changed.emit(edit.text);exchange.review()
 check(exchange.exchange.disabled and exchange.pending_request.is_empty(),"Noninteger visible input cannot confirm an old valid quantity")
 edit.text="10";edit.text_changed.emit(edit.text)
 exchange.review();exchange.confirmation.canceled.emit();exchange.confirmation.hide();exchange.dialog.hide()
 check(JSON.stringify(g.profile)==shortage_state,"Canceled hanging shortage leaves every balance unchanged")
 a.buttons.add_hanging_slot.pressed.emit();exchange.review();exchange.confirmation.confirmed.emit();exchange.confirmation.hide();exchange.dialog.hide()
 check(int(g.profile.hyperspace.materials.degenerate_matter)==10 and int(g.profile.hyperspace.materials.glueball)==100 and int(g.profile.hyperspace.inventory.drones[d.id].hanging_slots)==slots_before,"Explicit exchange supplies shortage without buying the slot")
 a.buttons.add_hanging_slot.pressed.emit()
 check(int(g.profile.hyperspace.inventory.drones[d.id].hanging_slots)==slots_before+1 and int(g.profile.hyperspace.materials.glueball)==0,"A separate operation click performs the original100-glue slot purchase")
 g.profile.hyperspace.materials.glueball=saved_glue;g.profile.hyperspace.materials.degenerate_matter=saved_deg
 a.advanced_expanded=true;a.refresh();g.profile.hyperspace.materials.zero_point_energy=0;a.refresh()
 check(a.advanced_expanded and a.cells.legendary.visible and not a.buttons.legendary.disabled and a.buttons.legendary.text.contains("先兑换"),"Resource refresh preserves expanded controls and shortage exchange entry")
 a.advanced_expanded=false;a.refresh()
 check(not a.cells.legendary.visible,"Explicit collapse hides unavailable advanced operation")
 g.profile.hyperspace.materials.zero_point_energy=zero_stock
 g.profile.hyperspace.materials.degenerate_matter=saved_stock
 a.buttons.add_affix.pressed.emit();a.refresh()
 var before_tiers=g.profile.hyperspace.inventory.drones[d.id].affixes.map(func(affix):return int(affix.tier))
 var promotion_stock=int(g.profile.hyperspace.materials.antiproton)
 a.buttons.promote_affix.pressed.emit();a.confirmation.confirmed.emit();a.confirmation.hide()
 var after_tiers=g.profile.hyperspace.inventory.drones[d.id].affixes.map(func(affix):return int(affix.tier))
 check(int(g.profile.hyperspace.materials.antiproton)<promotion_stock and c.feedback.text.contains(c.t("antiproton")) and (c.feedback.text.contains("→") if before_tiers!=after_tiers else c.feedback.text.contains("未升阶")) and c.result_scroll.visible,"Paid promotion reports actual changed grade or failure and cost beside current affixes")
 print("Forge actions: ",checks," checks, ",failures," failures")
 scene.queue_free();await process_frame;quit(1 if failures else 0)
