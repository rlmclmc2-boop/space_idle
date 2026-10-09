extends SceneTree
const Rewards=preload("res://scripts/drone_rewards.gd")
const Bag=preload("res://scripts/drone_inventory.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String) -> void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func operation(c,key:String) -> void:
 for i in c.operation.item_count:
  if str(c.operation.get_item_metadata(i))==key:c.operation.select(i);break
 c.refresh_materials()
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var scene=load("res://main.tscn").instantiate();scene.automation_args=["--capture"];root.add_child(scene);scene.set_process(false)
 var g=scene.game;g.save_enabled=false;g.paused=true;g.profile.highestLevel=20;g.profile.cleared=range(1,20);g.rebuild_unlocks();g.pending_unlocks.clear();g.profile.hyperspace.unlocked_drones=true
 var rng=RandomNumberGenerator.new();rng.seed=912
 var d=Rewards.create_drone(rng,g.hyperspace.config,"route-receipt-blue","blue","laser",1,"1");d.hanging_slots=0;d.affixes=[Rewards.affix(rng,g.hyperspace.config,"laser")]
 var carrier=Rewards.create_drone(rng,g.hyperspace.config,"route-receipt-white","white","laser",1,"1");carrier.hanging_slots=0
 Bag.insert(g.profile.hyperspace.inventory,d,g.hyperspace.config);Bag.insert(g.profile.hyperspace.inventory,carrier,g.hyperspace.config)
 for key in g.profile.hyperspace.materials:g.profile.hyperspace.materials[key]=0
 scene.refresh_tab_visibility();scene.select_system(9);await process_frame
 var p=scene.hyperspace_panel;p.refresh_manual_status();p.selected_id=d.id;p.select_section(2);var c=p.commands
 g.profile.hyperspace.materials.degenerate_matter=10
 var result=g.hyperspace.forge(g,c.forge_actions.request("add_affix"))
 check(result.error=="" and g.profile.hyperspace.materials.degenerate_matter==0 and g.profile.hyperspace.inventory.drones[d.id].affixes.size()==2,"Actual second blue affix consumes10 and reaches capacity")
 operation(c,"add_affix")
 check(c.missing_material.is_empty() and c.material_route_button.visible,"Material exploration survives zero stock and full-affix quote without inventing a shortage")
 var before=JSON.stringify(g.profile);var state=g.rng.state
 c.material_route_button.pressed.emit()
 check(p.section_index==0 and p.selected_id==d.id and JSON.stringify(g.profile)==before and g.rng.state==state,"No-specific-shortage exploration opens existing routes without changing drone or state")
 p.select_section(2);g.profile.hyperspace.materials.glueball=40;operation(c,"add_hanging_slot")
 before=JSON.stringify(g.profile);state=g.rng.state;c.material_route_button.pressed.emit()
 check(p.section_index==0 and p.route=="beta" and p.selected_id==d.id and JSON.stringify(g.profile)==before and g.rng.state==state,"Known60-glue shortage opens Beta without purchasing or running it")
 p.select_section(2);g.profile.hyperspace.materials.degenerate_matter=2000
 c.forge_actions.refresh()
 check(c.forge_actions.buttons.legendary.text.contains("2K") and c.forge_actions.buttons.legendary.text.contains("1K"),"Legendary conversion shortage hint shortens2000-to1000 without changing its goal")
 var q=g.hyperspace.material_exchange_quote(g,"degenerate_matter","zero_point_energy",1000)
 c.exchange_ui.show_prefilled("degenerate_matter","zero_point_energy",1000)
 check(q.cost=={"degenerate_matter":2000} and q.received=={"zero_point_energy":1000} and c.exchange_ui.preview.text.contains("2K") and c.exchange_ui.preview.text.contains("1K") and c.exchange_ui.preview.tooltip_text.contains("2000") and c.exchange_ui.preview.tooltip_text.contains("1000") and c.exchange_ui.amount.get_line_edit().text=="1000","Exchange shortens display while exact hover, editable integer and2-to1 domain quote stay intact")
 c.exchange_ui.dialog.hide();p.select_section(1)
 p.show_inventory_receipt("第一段\n第二段\n第三段");p.refresh_details()
 before=JSON.stringify(g.profile);state=g.rng.state
 check(p.inventory_feedback.visible and p.inventory_feedback.max_lines_visible==2 and p.inventory_feedback.tooltip_text=="第一段\n第二段\n第三段" and p.inventory_receipt_close.visible,"Receipt is bounded to two lines with full hover and explicit dismissal")
 p.inventory_receipt_close.pressed.emit()
 check(not p.inventory_feedback.visible and not p.inventory_module_next.visible and not p.inventory_receipt_close.visible and p.selected_id==d.id and JSON.stringify(g.profile)==before and g.rng.state==state,"Dismissal leaves profile, selection and RNG unchanged")
 p.show_inventory_receipt("旧拆解回执");p.refresh_details();p.choose_drone(carrier.id)
 check(not p.inventory_feedback.visible and not p.inventory_receipt_close.visible and p.details_drone_id==carrier.id and p.scroll.scroll_vertical==0 and not p.details.text.is_empty(),"Selecting another drone clears old receipt and displays its own attributes")
 p.choose_drone(d.id);c.dismantle_request=c.request("dismantle");c.execute_inventory_dismantle()
 check(p.inventory_feedback.visible and p.inventory_receipt_close.visible and p.inventory_module_next.visible and not p.inventory_module_next.disabled and p.inventory_module_next.text=="选择无人机安装","Actual dismantle retains immediate actionable installation receipt")
 before=JSON.stringify(g.profile);state=g.rng.state;p.inventory_module_next.pressed.emit()
 check(c.carrier_dialog.visible and c.carrier_buttons.size()==1,"Immediate entry opens existing surviving-carrier picker")
 c.carrier_buttons[0].pressed.emit()
 check(p.selected_id==carrier.id and not p.inventory_feedback.visible and c.module_dialog.visible and is_instance_valid(c.module_open_slot) and JSON.stringify(g.profile)==before and g.rng.state==state,"Carrier choice clears obsolete receipt while continuing existing installation and no-slot guidance")
 # Deliberately supplied slot and matching module copies check formatting, not natural drop odds.
 g.profile.hyperspace.inventory.drones[carrier.id].hanging_slots=1
 g.profile.hyperspace.hanging_modules.resource_collector={"unlocked":true,"level":2,"exp":0}
 c.module_dialog.hide()
 var attached=g.hyperspace.attach_hangings(g,carrier.id,["resource_collector"])
 var equipped=g.hyperspace.equip_drone(g,carrier.id);c.show_totals()
 check(attached and equipped.ok and is_equal_approx(float(g.hyperspace_totals().hangings.resource_collector),0.21) and c.totals_label.text.contains("+21%") and not c.totals_label.text.contains("21.0%"),"Actual level2 module applied21-percent totals use integer presentation with no growth change")
 check(c.signed_percentage(0.012)=="+1" and c.signed_percentage(-0.012)=="-1" and c.signed_percentage(11.782)=="+1.2K","All totals percentage categories preserve sign and shared integer/suffix rules")
 scene.queue_free();await process_frame
 print("Receipt/material routes: ",checks," checks, ",failures," failures");quit(1 if failures else 0)
