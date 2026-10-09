extends SceneTree
const Rewards=preload("res://scripts/drone_rewards.gd")
const Bag=preload("res://scripts/drone_inventory.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String) -> void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func positions(a) -> Dictionary:
 var result:Dictionary={}
 for op in a.BASIC:
  if a.cells[op].get_parent()==a.available_grid and a.cells[op].visible:result[op]=a.cells[op].get_index()
 return result
func unchanged(a,previous:Dictionary) -> bool:
 for op in previous:
  if a.cells[op].get_parent()!=a.available_grid or not a.cells[op].visible or a.cells[op].get_index()!=previous[op]:return false
 return true
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var scene=load("res://main.tscn").instantiate();scene.automation_args=["--capture"];root.add_child(scene);scene.set_process(false)
 var g=scene.game;g.save_enabled=false;g.paused=true;g.profile.highestLevel=20;g.profile.cleared=range(1,20);g.rebuild_unlocks();g.pending_unlocks.clear();g.profile.hyperspace.unlocked_drones=true
 var rng=RandomNumberGenerator.new();rng.seed=912
 var d=Rewards.create_drone(rng,g.hyperspace.config,"fixed-blue","blue","laser",1,"1");d.affixes=[Rewards.affix(rng,g.hyperspace.config,"laser")];d.hanging_slots=0
 var white=Rewards.create_drone(rng,g.hyperspace.config,"fixed-white","white","laser",1,"1");white.hanging_slots=0
 Bag.insert(g.profile.hyperspace.inventory,d,g.hyperspace.config);Bag.insert(g.profile.hyperspace.inventory,white,g.hyperspace.config)
 for key in g.profile.hyperspace.materials:g.profile.hyperspace.materials[key]=0
 g.profile.hyperspace.materials.degenerate_matter=10
 scene.refresh_tab_visibility();scene.select_system(9);await process_frame
 var p=scene.hyperspace_panel;p.refresh_manual_status();p.selected_id=d.id;p.select_section(2);var a=p.commands.forge_actions;a.advanced_expanded=false;a.refresh()
 var initial=positions(a);var button=a.buttons.add_affix;var selector=a.selectors.replace_affix;selector.grab_focus()
 var chosen=selector.selected
 check(initial.has("add_affix") and initial.has("replace_affix") and initial.has("add_hanging_slot") and initial.has("reroll_values") and not initial.has("modernize"),"Only currently useful basic actions enter the initial visible layout")
 a.buttons.add_affix.pressed.emit();a.refresh();await process_frame
 check(g.profile.hyperspace.materials.degenerate_matter==0 and g.profile.hyperspace.inventory.drones[d.id].affixes.size()==2 and unchanged(a,initial),"Native second-affix purchase consumes10 without moving the existing basic actions")
 check(a.buttons.add_affix.disabled and a.buttons.add_affix.text.split("\n").size()==2 and a.buttons.add_affix.text.contains("2/2") and a.buttons.add_affix==button and a.selectors.replace_affix==selector and selector.selected==chosen,"Full affix becomes a compact completed state while controls and selection are retained")
 check(not a.unavailable_grid.visible and not a.cells.lock_affix.is_visible_in_tree() and not a.cells.promote_affix.is_visible_in_tree() and not a.cells.ultimate.is_visible_in_tree(),"Unavailable advanced operations remain folded after purchase")
 var before=JSON.stringify(g.profile);var state=g.rng.state
 p.select_section(0);p.select_section(2);a.refresh()
 check(unchanged(a,initial) and JSON.stringify(g.profile)==before and g.rng.state==state,"Hiding/revealing forge retains carrier positions without profile or RNG writes")
 # Explicit historical-record fixture exposes the existing free modernization quote, not a played win.
 g.profile.hyperspace.history.alpha={"2":90.0};a.refresh()
 check(a.cells.modernize.get_parent()==a.available_grid and a.cells.modernize.visible and unchanged(a,initial),"A newly useful basic action appends without shifting existing slots")
 var expanded=positions(a);a.advanced_expanded=true;a.refresh();a.advanced_expanded=false;a.refresh()
 check(unchanged(a,expanded) and not a.unavailable_grid.visible,"Advanced folding changes no basic positions")
 p.choose_drone(white.id);a.refresh()
 check(not a.cells.add_affix.is_visible_in_tree() and not a.cells.replace_affix.is_visible_in_tree() and not a.cells.reroll_values.is_visible_in_tree() and a.cells.add_hanging_slot.is_visible_in_tree() and not a.unavailable_grid.visible,"Selecting a white carrier resets retained layout and does not display its impossible basic actions as grey buttons")
 scene.queue_free();await process_frame
 print("Forge basic positions: ",checks," checks, ",failures," failures");quit(1 if failures else 0)
