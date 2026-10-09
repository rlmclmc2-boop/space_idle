extends SceneTree
var checks:=0
var failures:=0
func check(ok:bool,label:String) -> void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var scene=load("res://main.tscn").instantiate();scene.automation_args=["--capture"];root.add_child(scene);scene.set_process(false)
 var g=scene.game;g.save_enabled=false;g.paused=true;g.profile.highestLevel=101;g.profile.cleared=range(1,101);g.rebuild_unlocks();g.pending_unlocks.clear();g.profile.unlocked=BattleGame.EQUIPMENT.duplicate();g.switch_ship("Heavy_Battleship");g.equip_slot("weapons",1,"cannon")
 scene.refresh_tab_visibility();scene.select_system(0);await process_frame
 var p=scene.equipment_panel;p.refresh();p.select_item("weapons_1");p.show_inspector()
 var before=JSON.stringify(g.profile);var rng=g.rng.state
 p.detail.slots.select(p.slot_options.find("missile"));p.detail.slots.item_selected.emit(p.detail.slots.selected);p.refresh_detail()
 var entry=g.module_entry("weapons",1);var candidate=entry.duplicate(true);candidate.key="missile"
 var projection=scene.EQUIPMENT_DISPLAY.refit_snapshot(g,entry,"missile")
 var heading=UIText.t("equipment.candidate_attributes",{"name":scene.NAMES.missile})
 var sections=p.detail.basics.text.split("\n\n"+heading+"\n")
 check(sections.size()==2 and sections[0].begins_with(UIText.t("equipment.current_attributes",{"name":p.items.weapons_1.name})),"Expanded basics explicitly separate mounted cannon and pending missile")
 check(sections.size()==2 and sections[0].contains(UIText.t("equipment.attack_interval",{"seconds":NumberFormat.scalar(float(g.player_weapon_row(entry).cd))})) and sections[1].contains(UIText.t("equipment.attack_interval",{"seconds":NumberFormat.scalar(float(g.player_weapon_row(candidate).cd))})),"Each interval comes from the corresponding current or candidate weapon row")
 check(p.detail.stats.text.contains(heading) and p.detail.stats.text.contains(p.rate_detail(projection,{})) and p.detail.basics.text.contains(p.equipment_attributes(candidate,false)),"Expanded candidate uses real missile rate and attributes")
 check(not p.detail.description.text.contains(heading),"Default compact comparison does not dump expanded details")
 check(JSON.stringify(g.profile)==before and g.rng.state==rng and g.module_entry("weapons",1).key=="cannon","Candidate details leave equipped weapon, resources, progression and RNG untouched")
 p.detail.slots.select(p.slot_options.find("cannon"));p.detail.slots.item_selected.emit(p.detail.slots.selected);p.refresh_detail()
 check(not p.detail.basics.text.contains(heading) and not p.detail.stats.text.contains(heading),"Returning to mounted selection clears candidate-only details")
 var local_rng=RandomNumberGenerator.new();local_rng.seed=927
 var rewards=preload("res://scripts/drone_rewards.gd");var bag=preload("res://scripts/drone_inventory.gd")
 var d=rewards.create_drone(local_rng,g.hyperspace.config,"interval-speed","blue","laser",5,"1");d.affixes=[rewards.affix(local_rng,g.hyperspace.config,"laser","attack_speed")]
 check(bag.insert(g.profile.hyperspace.inventory,d,g.hyperspace.config),"Actual configured attack-speed drone enters inventory")
 g.profile.hyperspace.inventory.equipped=[d.id];g.invalidate_stat_cache()
 var dynamic_row=g.player_weapon_row(candidate);projection=scene.EQUIPMENT_DISPLAY.refit_snapshot(g,entry,"missile")
 before=JSON.stringify(g.profile);rng=g.rng.state
 check(not NumberFormat.scalar_is_exact(float(dynamic_row.cd)) and p.basic_attributes(candidate,projection).contains(UIText.t("equipment.attack_interval_approx",{"seconds":NumberFormat.scalar(float(dynamic_row.cd))})) and p.rate_detail(projection,{}).contains("间隔约"),"Real drone acceleration displays the half-second estimate explicitly as approximate")
 check(is_equal_approx(float(dynamic_row.cd),2.5/float(g.hyperspace_totals().attack_speed)) and JSON.stringify(g.profile)==before and g.rng.state==rng,"Approximate interval presentation preserves real acceleration and precise internal rate")
 scene.queue_free();await process_frame
 print("Candidate attribute ownership: ",checks," checks, ",failures," failures");quit(1 if failures else 0)
