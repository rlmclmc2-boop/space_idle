extends SceneTree
const Rewards=preload("res://scripts/drone_rewards.gd")
const Bag=preload("res://scripts/drone_inventory.gd")
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
 var before=JSON.stringify(g.profile);var state=g.rng.state
 var legendary=g.hyperspace.preview_forge(g,a.request("legendary"));var hanging=g.hyperspace.preview_forge(g,a.request("add_hanging_slot"));var affix=g.hyperspace.preview_forge(g,a.request("add_affix"))
 check(g.hyperspace.is_unlocked(g) and legendary.error=="insufficient_materials" and legendary.cost.size()==1 and int(legendary.cost.zero_point_energy)==1000 and legendary.draws==1,"Mainline20 white conversion has no later-stage gate and formally quotes one1000-zero-point conversion")
 check(hanging.error=="insufficient_materials" and hanging.cost.size()==1 and int(hanging.cost.glueball)==100 and Bag.hanging_limit(d,g.hyperspace.config)==4 and affix.error=="affix_limit","White's real early path is100-glueball hanging slots, with four-slot cap and no ordinary affixes")
 check(a.cells.legendary.get_parent()==a.unavailable_grid and not a.cells.legendary.is_visible_in_tree() and not a.advanced_expanded,"Currently the material-poor white conversion goal is hidden by the unavailable-actions fold")
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
 var req=a.request("legendary");var q=g.hyperspace.preview_forge(g,req);var result=g.hyperspace.forge(g,req);var grown=g.profile.hyperspace.inventory.drones[d.id]
 check(q.error=="" and q.cost.zero_point_energy==1000 and result.error=="" and g.profile.hyperspace.materials.zero_point_energy==0 and grown.legendary and grown.origin_quality=="white" and not grown.legendary_effect.is_empty(),"Actual paid conversion always makes the white source legendary with one randomly selected effect")
 check(grown.hanging_slots==4 and grown.preserved_hanging_slots==4 and Bag.hanging_limit(grown,g.hyperspace.config)==4 and Bag.affix_limit(grown,g.hyperspace.config)==3 and grown.affixes.is_empty(),"White-origin legendary preserves all four bought slots and opens three empty ordinary-affix positions")
 var one_slot=g.profile.hyperspace.duplicate(true);one_slot.inventory.drones[d.id].hanging_slots=1;one_slot.inventory.drones[d.id].preserved_hanging_slots=1
 var frozen_slot=preload("res://scripts/drone_forge.gd").plan(one_slot,g.hyperspace.config,a.request("add_hanging_slot"),g)
 check(Bag.hanging_limit(one_slot.inventory.drones[d.id],g.hyperspace.config)==1 and frozen_slot.error=="hanging_limit","One-slot white-origin legendary is capped at its preserved one slot; conversion does not grant the unused original four-slot capacity")
 q=g.hyperspace.preview_forge(g,a.request("add_affix"))
 check(q.error=="insufficient_materials" and q.cost.size()==1 and int(q.cost.degenerate_matter)==10 and Effects.weapon_bonus(grown,g.hyperspace.config)==1,"Next random ordinary affix formally costs10; conversion weapon-level bonus is only+1")
 # Supply the parent's observed matching module outcomes to the real credit function.
 # Module type is random on dismantle; this fixture does not claim guaranteed drops.
 var progress=g.profile.hyperspace.hanging_modules.resource_collector
 var credited=Rewards.credit_modules(g.profile.hyperspace,g.hyperspace.config,{"resource_collector":1})
 check(credited and progress.unlocked and progress.level==0,"First matching module unlocks at level0 without an immediate efficiency bonus")
 credited=Rewards.credit_modules(g.profile.hyperspace,g.hyperspace.config,{"resource_collector":1})
 check(credited and progress.level==1,"Second matching module reaches level1 through actual shared experience credit")
 check(g.hyperspace.attach_hangings(g,d.id,["resource_collector"]) and g.hyperspace.equip_drone(g,d.id).ok and is_equal_approx(float(g.hyperspace_totals().hangings.resource_collector),0.1),"Installing the known level1 module and equipping its carrier produces stable ten-percent system bonus")
 var replacement=Rewards.create_drone(rng,g.hyperspace.config,"cultivation-replacement","blue","laser",1,"1");Bag.insert(g.profile.hyperspace.inventory,replacement,g.hyperspace.config)
 var invested=g.profile.hyperspace.inventory.drones[d.id].duplicate(true);var materials=g.profile.hyperspace.materials.duplicate(true)
 var replaced=g.hyperspace.equip_drone(g,replacement.id,d.id)
 check(replaced.ok and g.profile.hyperspace.inventory.warehouse.has(d.id) and g.profile.hyperspace.inventory.drones[d.id]==invested and g.profile.hyperspace.materials==materials and g.profile.hyperspace.hanging_modules.resource_collector.level==1,"Actual replacement retains the invested old drone, its slots/effect/level, shared module progress and materials")
 var dismantled=preload("res://scripts/drone_forge.gd").plan(g.profile.hyperspace.duplicate(true),g.hyperspace.config,a.request("dismantle"),g)
 check(dismantled.error=="" and int(dismantled.rewards.materials.degenerate_matter)==100 and not dismantled.rewards.materials.has("zero_point_energy") and not dismantled.rewards.materials.has("glueball"),"Dismantling invested legendary returns fixed quality salvage rather than refunding1000zero-point and400glueball")
 var weights=Rewards.quality_weights(g.hyperspace.config)
 print("Current ordinary natural legendary reward probability: ",float(weights.legendary)*100,"%; expected wins ",1.0/float(weights.legendary))
 scene.queue_free();await process_frame
 print("White cultivation quotes: ",checks," checks, ",failures," failures");quit(1 if failures else 0)
