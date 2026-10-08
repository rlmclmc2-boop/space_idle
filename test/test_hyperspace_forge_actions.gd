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
 var saved_stock=g.profile.hyperspace.materials.degenerate_matter;g.profile.hyperspace.materials.degenerate_matter=0;a.refresh()
 check(a.buttons.add_affix.disabled and a.buttons.add_affix.text.contains("还缺") and a.buttons.add_affix.text.contains(c.t("degenerate_matter")+" "+str(int(g.hyperspace.config.forge_costs.add_affix.degenerate_matter)*int(g.hyperspace.config.material_unit_scale))),"Unavailable action shows authoritative shortage on its button")
 g.profile.hyperspace.materials.degenerate_matter=saved_stock
 print("Forge actions: ",checks," checks, ",failures," failures")
 scene.queue_free();await process_frame;quit(1 if failures else 0)
