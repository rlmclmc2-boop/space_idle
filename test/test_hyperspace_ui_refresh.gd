extends SceneTree
## UI refresh regression: in-memory fixtures only; no saves or gameplay.
const PanelScript=preload("res://scripts/hyperspace_panel.gd")
class Domain extends RefCounted:
 func snapshot(g)->Dictionary:return g.profile.hyperspace.duplicate(true)
class GameFixture extends RefCounted:
 var profile={"hyperspace":{"round_id":1,"unlocked_drones":true,"inventory":{"generation":1,"drones":{"one":{"id":"one"}},"warehouse":["one"],"presets":[]}}}
 var hyperspace=Domain.new()
 var manual_hyperspace={"production_accepted":true,"last_error":""}
class Host extends RefCounted:
 var game=GameFixture.new()
 func refresh_hyperspace_badge()->void:pass
class Stub extends RefCounted:
 func on_event(_kind,_payload)->void:pass
class Commands extends RefCounted:
 var exchange_ui=Stub.new()
 var totals_dialog=null
 var materials_box:Control
 var reads:=0
 func refresh_materials()->void:reads+=1
class Component extends "res://scripts/hyperspace_panel.gd":
 var lists:=0
 func refresh_list()->void:lists+=1;inventory_dirty=false
 func refresh_details()->void:pass
func _initialize()->void:call_deferred("run")
func run()->void:
 create_timer(10.0).timeout.connect(func():printerr("UI refresh probe timed out");quit(1))
 var h=Host.new();var p=Component.new();p.host=h;root.add_child(p);p.set_process(false)
 for i in 4:p.section_buttons.append(Button.new())
 for button in p.section_buttons:p.add_child(button)
 p.first_win=Label.new();p.add_child(p.first_win)
 p.capacity=Label.new();p.budgets=Label.new();p.inventory_box=VBoxContainer.new();p.drone_locked=Label.new()
 for node in [p.capacity,p.budgets,p.inventory_box,p.drone_locked]:p.add_child(node)
 p.reward_feedback=Stub.new();var commands=Commands.new();p.commands=commands
 commands.materials_box=Control.new();p.add_child(commands.materials_box)
 p.refresh_manual_status();var initial=p.manual_snapshot_reads
 var button_ids=p.section_buttons.map(func(b):return b.get_instance_id())
 var state_before=JSON.stringify(h.game.profile)
 p.refresh();assert(p.manual_snapshot_reads==initial)
 h.game.profile.hyperspace.inventory.generation+=1
 h.game.profile.hyperspace.inventory.drones.two={"id":"two"}
 h.game.profile.hyperspace.inventory.warehouse.append("two")
 state_before=JSON.stringify(h.game.profile)
 p.refresh();assert(p.manual_snapshot_reads==initial and not p.bag.drones.has("two"))
 p.hide();p.refresh();assert(p.manual_snapshot_reads==initial)
 p.show();p.section_index=1;p.refresh()
 assert(p.manual_snapshot_reads==initial+1 and p.bag.drones.has("two"))
 assert(p.generation==h.game.profile.hyperspace.inventory.generation)
 assert(p.section_buttons.map(func(b):return b.get_instance_id())==button_ids)
 assert(JSON.stringify(h.game.profile)==state_before)
 h.game.profile.hyperspace.inventory.generation+=1
 p.refresh_manual_status();assert(p.manual_snapshot_reads==initial+2)
 commands.materials_box.hide()
 p.on_event("hyperspace_changed",{"reason":"claimed"})
 await process_frame;assert(commands.reads==0)
 commands.materials_box.show()
 p.on_event("hyperspace_changed",{"reason":"claimed"})
 await process_frame;assert(commands.reads==1)
 commands.materials_box.hide()
 p.on_event("hyperspace_changed",{"reason":"forge_done"})
 await process_frame;assert(commands.reads==1)
 print("PASS: repeated/hidden refresh defers bag; reveal catches up once; explicit refresh compatible; instances/state preserved; hidden forge preview skipped, visible preview retained")
 p.free();quit(0)
