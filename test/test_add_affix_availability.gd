extends SceneTree
const Rewards=preload("res://scripts/drone_rewards.gd")
const Bag=preload("res://scripts/drone_inventory.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String) -> void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var scene=load("res://main.tscn").instantiate();scene.automation_args=["--capture"];root.add_child(scene);scene.set_process(false)
 var g=scene.game;g.save_enabled=false;g.paused=true;g.profile.highestLevel=34;g.profile.cleared=range(1,34);g.rebuild_unlocks();g.pending_unlocks.clear();g.profile.hyperspace.unlocked_drones=true
 var rng=RandomNumberGenerator.new();rng.seed=912
 var plain=Rewards.create_drone(rng,g.hyperspace.config,"affix-white","white","laser",6,"1")
 var blue=Rewards.create_drone(rng,g.hyperspace.config,"affix-blue","blue","laser",6,"1")
 blue.affixes=[]
 Bag.insert(g.profile.hyperspace.inventory,plain,g.hyperspace.config);Bag.insert(g.profile.hyperspace.inventory,blue,g.hyperspace.config)
 for key in g.profile.hyperspace.materials:g.profile.hyperspace.materials[key]=1000000
 scene.refresh_tab_visibility();scene.select_system(9);await process_frame
 var p=scene.hyperspace_panel;var c=p.commands;var a=c.forge_actions;p.refresh_manual_status();p.selected_id=plain.id;p.select_section(2);a.advanced_expanded=true;a.refresh()
 var quote=g.hyperspace.preview_forge(g,a.request("add_affix"))
 check(quote.error=="affix_limit" and Bag.affix_limit(plain,g.hyperspace.config)==0 and a.cells.add_affix.get_parent()==a.unavailable_grid and a.buttons.add_affix.disabled,"Material-rich white drone is blocked by its actual zero affix capacity")
 check(a.buttons.add_affix.text.contains(c.t("action_no_affix_slots")),"Zero-capacity blocked button states the real limitation")
 p.choose_drone(blue.id);a.refresh();quote=g.hyperspace.preview_forge(g,a.request("add_affix"))
 check(quote.error=="" and a.cells.add_affix.get_parent()==a.available_grid and not a.buttons.add_affix.disabled,"Material-rich drone with a free affix slot is placed in available actions")
 var before=int(g.profile.hyperspace.materials.degenerate_matter);a.buttons.add_affix.pressed.emit();a.refresh()
 check(g.profile.hyperspace.inventory.drones[blue.id].affixes.size()==1 and int(g.profile.hyperspace.materials.degenerate_matter)==before-int(quote.cost.degenerate_matter) and a.cells.add_affix.get_parent()==a.available_grid,"Real add-affix transaction debits the quoted price and leaves the second slot available")
 a.buttons.add_affix.pressed.emit();a.refresh();quote=g.hyperspace.preview_forge(g,a.request("add_affix"))
 check(quote.error=="affix_limit" and g.profile.hyperspace.inventory.drones[blue.id].affixes.size()==Bag.affix_limit(blue,g.hyperspace.config) and a.cells.add_affix.get_parent()==a.unavailable_grid and a.buttons.add_affix.disabled,"After filling the real second slot, sufficient materials do not bypass capacity")
 var full=g.profile.hyperspace.inventory.drones[blue.id]
 check(a.buttons.add_affix.text.contains(c.t("action_affix_full_count",{"count":str(full.affixes.size()),"capacity":str(Bag.affix_limit(full,g.hyperspace.config))})),"Full-capacity button shows actual used and maximum affix count")
 var profile=JSON.stringify(g.profile);var state=g.rng.state;a.refresh()
 check(JSON.stringify(g.profile)==profile and g.rng.state==state,"Classification and explanation retain resources, affixes and RNG")
 scene.queue_free();await process_frame
 print("Add-affix availability: ",checks," checks, ",failures," failures");quit(1 if failures else 0)
