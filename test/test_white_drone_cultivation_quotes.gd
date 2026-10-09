extends SceneTree
const Rewards=preload("res://scripts/drone_rewards.gd")
const Bag=preload("res://scripts/drone_inventory.gd")
const State=preload("res://scripts/hyperspace_state.gd")
const Effects=preload("res://scripts/drone_effect_aggregator.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String) -> void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var scene=load("res://main.tscn").instantiate();scene.automation_args=["--capture"];root.add_child(scene);scene.set_process(false)
 var g=scene.game;g.save_enabled=false;g.paused=true;g.profile.highestLevel=20;g.profile.cleared=range(1,20);g.rebuild_unlocks();g.pending_unlocks.clear();g.profile.hyperspace.unlocked_drones=true
 var rng=RandomNumberGenerator.new();rng.seed=912
 var d=Rewards.create_drone(rng,g.hyperspace.config,"cultivation-white","white","laser",1,"1");d.hanging_slots=0
 Bag.insert(g.profile.hyperspace.inventory,d,g.hyperspace.config)
 for key in g.profile.hyperspace.materials:g.profile.hyperspace.materials[key]=0
 scene.refresh_tab_visibility();scene.select_system(9);await process_frame
 var p=scene.hyperspace_panel;p.refresh_manual_status();p.selected_id=d.id;p.select_section(2)
 var c=p.commands;var a=c.forge_actions;a.advanced_expanded=false;a.refresh()
 check(p.capability_summary(d)=="挂载 0/4" and p.drone_description(d,false,true).contains("挂载 0/4"),"White potential four slots is visible even before the first slot, without pretending slots are already opened")
 var before=JSON.stringify(g.profile);var state=g.rng.state
 var legendary=g.hyperspace.preview_forge(g,a.request("legendary"));var hanging=g.hyperspace.preview_forge(g,a.request("add_hanging_slot"));var affix=g.hyperspace.preview_forge(g,a.request("add_affix"))
 check(g.hyperspace.is_unlocked(g) and legendary.error=="insufficient_materials" and legendary.cost.size()==1 and int(legendary.cost.zero_point_energy)==1000 and legendary.draws==1,"Mainline20 white conversion has no later-stage gate and formally quotes one1000-zero-point conversion")
 check(hanging.error=="insufficient_materials" and hanging.cost.size()==1 and int(hanging.cost.glueball)==100 and Bag.hanging_limit(d,g.hyperspace.config)==4 and affix.error=="affix_limit","White's real early path is100-glueball hanging slots, with four-slot cap and no ordinary affixes")
 check(a.cells.legendary.get_parent()==a.available_grid and a.cells.legendary.is_visible_in_tree() and not a.advanced_expanded,"Material-poor white conversion goal stays visible outside the unavailable-actions fold")
 var income=Rewards.material_amount(g.hyperspace.online_config(g),1)
 check(income==10 and int(hanging.cost.glueball)/income==10 and int(legendary.cost.zero_point_energy)/income==100,"Unbuffed won route layer1 pays10 matching material: ten wins per first slot or hundred Delta wins per conversion")
 g.profile.hyperspace.materials.degenerate_matter=2000
 var exchange=g.hyperspace.material_exchange_quote(g,"degenerate_matter","zero_point_energy",1000)
 check(exchange.error=="" and exchange.cost=={"degenerate_matter":2000} and exchange.received=={"zero_point_energy":1000},"Existing2-to1 exchange formally costs2000 ordinary route material for1000 conversion material")
 g.profile.hyperspace.materials.degenerate_matter=0
 check(JSON.stringify(g.profile)==before and g.rng.state==state,"All diagnostic quotes and UI checks preserve the original empty-budget fixture and RNG")
 # Hypothetical higher-route record tests only the official quote, not a played win.
 g.profile.hyperspace.history.alpha={"2":90.0}
 var old_weapon=g.drone_weapon_entry(g.profile.hyperspace.inventory.drones[d.id]).level
 var modern_req=a.request("modernize");var modern=g.hyperspace.preview_forge(g,modern_req);var raised=g.hyperspace.forge(g,modern_req)
 check(modern.error=="" and int(modern.cost.degenerate_matter)==0 and raised.error=="" and g.profile.hyperspace.inventory.drones[d.id].level==2 and not g.profile.hyperspace.inventory.drones[d.id].legendary and g.drone_weapon_entry(g.profile.hyperspace.inventory.drones[d.id]).level==old_weapon,"Formal first modernization1-to2 is free but neither promotes white quality nor increases its inherited weapon level")
 # Hypothetical budgets below test only the existing legal path; they are not a natural-play balance.
 g.profile.hyperspace.materials.glueball=400
 var added=true
 for i in 4:
  var req=a.request("add_hanging_slot");var q=g.hyperspace.preview_forge(g,req);var result=g.hyperspace.forge(g,req)
  added=added and q.error=="" and q.cost.glueball==100 and result.error==""
 check(added and g.profile.hyperspace.materials.glueball==0 and g.profile.hyperspace.inventory.drones[d.id].hanging_slots==4,"Four existing slot purchases debit exactly400 and retain white quality")
 g.profile.hyperspace.materials.zero_point_energy=1000
 a.act("legendary")
 check(a.confirmation.visible and a.confirmation.dialog_text.contains("已有 4 个挂载位") and a.confirmation.dialog_text.contains("未开的容量不会继承") and a.confirmation.dialog_text.contains("无法再增开"),"Actual conversion confirmation names retained slots and irreversible unused-capacity loss")
 a.confirmation.hide();c.quoted_request={}
 var req=a.request("legendary");var q=g.hyperspace.preview_forge(g,req);var result=g.hyperspace.forge(g,req);var grown=g.profile.hyperspace.inventory.drones[d.id]
 check(q.error=="" and q.cost.zero_point_energy==1000 and result.error=="" and g.profile.hyperspace.materials.zero_point_energy==0 and grown.legendary and grown.origin_quality=="white" and not grown.legendary_effect.is_empty(),"Actual paid conversion always makes the white source legendary with one randomly selected effect")
 check(grown.hanging_slots==4 and grown.preserved_hanging_slots==4 and Bag.hanging_limit(grown,g.hyperspace.config)==4 and Bag.affix_limit(grown,g.hyperspace.config)==3 and grown.affixes.is_empty(),"White-origin legendary preserves all four bought slots and opens three empty ordinary-affix positions")
 var one_slot=g.profile.hyperspace.duplicate(true);one_slot.inventory.drones[d.id].hanging_slots=1;one_slot.inventory.drones[d.id].preserved_hanging_slots=1
 var frozen_slot=preload("res://scripts/drone_forge.gd").plan(one_slot,g.hyperspace.config,a.request("add_hanging_slot"),g)
 check(Bag.hanging_limit(one_slot.inventory.drones[d.id],g.hyperspace.config)==1 and frozen_slot.error=="hanging_limit","One-slot white-origin legendary is capped at its preserved one slot; conversion does not grant the unused original four-slot capacity")
 q=g.hyperspace.preview_forge(g,a.request("add_affix"))
 check(q.error=="insufficient_materials" and q.cost.size()==1 and int(q.cost.degenerate_matter)==10 and Effects.weapon_bonus(grown,g.hyperspace.config)==1,"Next random ordinary affix formally costs10; conversion weapon-level bonus is only+1")
 # Existing unlocked-zero normalization uses the actual load entry, not a general migration.
 var original_state=g.profile.hyperspace.duplicate(true);var legacy=original_state.duplicate(true)
 legacy.hanging_modules.resource_collector={"unlocked":true,"level":0,"exp":50.0}
 check(State.valid(legacy,g.hyperspace.config,g.db.levels.size()) and g.hyperspace.load_state(g,legacy),"Existing legal unlocked-zero state loads through formal loader")
 check(g.profile.hyperspace.hanging_modules.resource_collector.level==1 and g.profile.hyperspace.hanging_modules.resource_collector.exp==50 and not g.profile.hyperspace.hanging_modules.distributed_algorithm.unlocked and g.profile.hyperspace.hanging_modules.distributed_algorithm.level==0,"Only already obtained zero-level module becomes1, retaining experience and locked types")
 var loaded=g.profile.hyperspace.duplicate(true)
 check(g.hyperspace.load_state(g,loaded) and g.profile.hyperspace==loaded and legacy.hanging_modules.resource_collector.level==0,"Repeated real load is idempotent and leaves raw input untouched")
 check(g.hyperspace.load_state(g,original_state),"Restore isolated current fixture through same formal loader")
 g.invalidate_stat_cache()
 # Matching module type is supplied deliberately; natural dismantle type remains random.
 # Module type is random on dismantle; this fixture does not claim guaranteed drops.
 var progress=g.profile.hyperspace.hanging_modules.resource_collector
 var first_outcome:Dictionary={};var first_before=g.profile.hyperspace.hanging_modules.duplicate(true)
 var credited=Rewards.credit_modules(g.profile.hyperspace,g.hyperspace.config,{"resource_collector":1},first_outcome)
 check(credited and progress.unlocked and progress.level==1 and progress.exp==0,"First matching module unlocks at useful level1, crediting all100 experience instead of deducting its first copy")
 p.select_section(1);p.inventory_feedback.text=c.received_rewards_text({"materials":{},"modules":first_outcome},first_before);p.inventory_feedback.visible=true;p.refresh_details()
 check(p.inventory_feedback.text.contains("首次解锁并升至1级") and p.inventory_module_next.visible and not p.inventory_module_next.disabled,"First useful unlock receipt exposes installation for current carrier without claiming it already applies")
 check(g.hyperspace.equip_drone(g,d.id).ok,"Equip the invested carrier through actual domain before installation")
 p.refresh_manual_status();p.refresh();p.inventory_module_next.pressed.emit()
 check(c.module_id==d.id and p.selected_id==d.id and c.module_dialog.visible,"Receipt entry opens existing module dialog without losing selected carrier")
 for choice in c.module_choices:
  if choice.get_meta("module_key")=="resource_collector":choice.button_pressed=true
 c.refresh_module_apply();c.module_apply.pressed.emit()
 check(is_equal_approx(float(g.hyperspace_totals().hangings.resource_collector),0.1) and p.inventory_feedback.text.contains("0%→10%") and p.inventory_feedback.text.contains("已生效") and p.selected_id==d.id,"Native installation produces actual ten-percent system gain and preserves carrier with before/after receipt")
 var second_outcome:Dictionary={};var second_before=g.profile.hyperspace.hanging_modules.duplicate(true)
 credited=Rewards.credit_modules(g.profile.hyperspace,g.hyperspace.config,{"resource_collector":1},second_outcome)
 progress=g.profile.hyperspace.hanging_modules.resource_collector
 check(credited and progress.level==2 and progress.exp==0 and Rewards.module_required_exp(g.hyperspace.config.hanging_modules.resource_collector,1)==100,"Second matching copy guarantees1-to2 with100 experience and no leftover or free duplicate credit")
 p.inventory_feedback.text=c.received_rewards_text({"materials":{},"modules":second_outcome},second_before);p.refresh_details()
 check(p.inventory_feedback.text.contains("升级 1→2级") and p.inventory_module_next.visible and not p.inventory_module_next.disabled,"Second copy reports the actual guaranteed first upgrade")
 var extra_state=g.profile.hyperspace.duplicate(true);var extra_before=extra_state.hanging_modules.duplicate(true);var extra_outcomes:Dictionary={}
 check(Rewards.credit_modules(extra_state,g.hyperspace.config,{"resource_collector":1},extra_outcomes) and extra_state.hanging_modules.resource_collector.level==2 and extra_state.hanging_modules.resource_collector.exp==100 and is_equal_approx(Rewards.module_required_exp(g.hyperspace.config.hanging_modules.resource_collector,2),144) and c.received_rewards_text({"materials":{},"modules":extra_outcomes},extra_before).contains("获得升级经验，等级未变"),"Third copy stays2 at100-of144 experience; normal growth resumes without fixed per-copy levels")
 var fourth=extra_state.duplicate(true)
 check(Rewards.credit_modules(fourth,g.hyperspace.config,{"resource_collector":1}) and fourth.hanging_modules.resource_collector.level==3 and is_equal_approx(float(fourth.hanging_modules.resource_collector.exp),56) and is_equal_approx(Rewards.module_required_exp(g.hyperspace.config.hanging_modules.resource_collector,3),172.8),"Fourth copy crosses original level2 threshold144, retains56 experience, then needs original172.8")
 g.invalidate_stat_cache()
 check(is_equal_approx(float(g.hyperspace_totals().hangings.resource_collector),0.21) and State.valid(g.profile.hyperspace,g.hyperspace.config,g.db.levels.size()),"First actual upgrade produces21-percent applied efficiency and a valid save")
 var boundary=g.profile.hyperspace.duplicate(true);boundary.hanging_modules.resource_collector.level=1;boundary.hanging_modules.resource_collector.exp=100
 check(not State.valid(boundary,g.hyperspace.config,g.db.levels.size()),"Save validation shares the real level1 threshold and rejects unsettled100 experience")
 var other=State.fresh(g.hyperspace.config)
 check(Rewards.credit_modules(other,g.hyperspace.config,{"distributed_algorithm":1,"resource_collector":0}) and other.hanging_modules.distributed_algorithm.level==1 and not other.hanging_modules.resource_collector.unlocked and other.hanging_modules.resource_collector.level==0,"Different module unlocks independently; zero awarded copies cannot unlock unreceived type")
 var batch=State.fresh(g.hyperspace.config)
 check(Rewards.credit_modules(batch,g.hyperspace.config,{"resource_collector":3}) and batch.hanging_modules.resource_collector.level==extra_state.hanging_modules.resource_collector.level and batch.hanging_modules.resource_collector.exp==extra_state.hanging_modules.resource_collector.exp,"Batch three copies equals sequential three copies without duplicate initial credit")

 var replacement=Rewards.create_drone(rng,g.hyperspace.config,"cultivation-replacement","blue","laser",1,"1");Bag.insert(g.profile.hyperspace.inventory,replacement,g.hyperspace.config)
 var invested=g.profile.hyperspace.inventory.drones[d.id].duplicate(true);var materials=g.profile.hyperspace.materials.duplicate(true)
 var replaced=g.hyperspace.equip_drone(g,replacement.id,d.id)
 check(replaced.ok and g.profile.hyperspace.inventory.warehouse.has(d.id) and g.profile.hyperspace.inventory.drones[d.id]==invested and g.profile.hyperspace.materials==materials and g.profile.hyperspace.hanging_modules.resource_collector.level==2,"Actual replacement retains the invested old drone, its slots/effect/level, shared module progress and materials")
 p.refresh_manual_status();p.refresh();p.selected_id=d.id;c.show_modules();c.module_apply.pressed.emit()
 check(p.inventory_feedback.text.contains("装备此无人机后生效") and is_zero_approx(float(g.hyperspace_totals().hangings.get("resource_collector",0))),"Warehouse installation receipt requests equipping and does not claim an active bonus")
 c.dismantle_request=c.request("dismantle");c.execute_inventory_dismantle()
 check(p.inventory_feedback.visible and not p.inventory_feedback.text.is_empty() and p.inventory_module_next.visible and p.inventory_module_next.disabled,"Actual dismantle keeps result and carrier-selection guidance when the dismantled target is gone")
 p.choose_drone(replacement.id)
 check(p.inventory_feedback.visible and not p.inventory_module_next.disabled and p.selected_id==replacement.id,"Selecting surviving carrier retains dismantle receipt and enables existing installation entry")
 # Restore the invested drone only for the formal salvage quote below.
 Bag.insert(g.profile.hyperspace.inventory,invested,g.hyperspace.config)
 p.refresh_manual_status();p.selected_id=d.id
 var dismantled=preload("res://scripts/drone_forge.gd").plan(g.profile.hyperspace.duplicate(true),g.hyperspace.config,a.request("dismantle"),g)
 check(dismantled.error=="" and int(dismantled.rewards.materials.degenerate_matter)==100 and not dismantled.rewards.materials.has("zero_point_energy") and not dismantled.rewards.materials.has("glueball"),"Dismantling invested legendary returns fixed quality salvage rather than refunding1000zero-point and400glueball")
 # Auto-dismantled challenge rewards settle through the other real acquisition entry.
 var filtered=BattleGame.new(ShipDatabase.new(),false);filtered.save_enabled=false;filtered.profile.highestLevel=7
 filtered.profile.hyperspace.filter={"version":2,"enabled":true,"mode":"all","action":"clear_matches","conditions":[{"field":"weapon","value":"laser"}]}
 var run=filtered.hyperspace.start(filtered,"alpha",1,"manual")
 var complete_ok=not run.is_empty() and filtered.hyperspace.complete(filtered,int(run.round_id),int(run.run_id),true)
 var reward_modules:Dictionary=filtered.profile.hyperspace.active.get("reward",{}).get("hanging_rewards",{}).duplicate(true)
 var claimed=complete_ok and filtered.hyperspace.claim(filtered,int(run.round_id),int(run.run_id))
 var credited_all=not reward_modules.is_empty()
 for key in reward_modules:
  credited_all=credited_all and bool(filtered.profile.hyperspace.hanging_modules[key].unlocked) and int(filtered.profile.hyperspace.hanging_modules[key].level)>=1
 check(claimed and credited_all and not filtered.hyperspace.claim(filtered,int(run.round_id),int(run.run_id)),"Actual filtered-reward claim initializes every received module to at least1 and cannot credit twice")
 var weights=Rewards.quality_weights(g.hyperspace.config)
 print("Current ordinary natural legendary reward probability: ",float(weights.legendary)*100,"%; expected wins ",1.0/float(weights.legendary))
 scene.queue_free();await process_frame
 print("White cultivation quotes: ",checks," checks, ",failures," failures");quit(1 if failures else 0)
