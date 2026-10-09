extends SceneTree
var checks:=0
var failures:=0
func check(ok:bool,label:String) -> void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var scene=load("res://main.tscn").instantiate();scene.automation_args=["--capture"];root.add_child(scene);scene.set_process(false)
 var g=scene.game;g.save_enabled=false;g.paused=true;g.profile.cleared=range(1,34);g.profile.highestLevel=34;g.rebuild_unlocks();g.pending_unlocks.clear();g.profile.onboarding.completed=true
 g.equip_slot("weapons",0,"missile");g.equip_slot("defence",0,"armour")
 var p=scene.equipment_panel
 scene.refresh_tab_visibility();scene.select_system(scene.equipment_tabs.get_tab_idx_from_control(p));p.refresh();await process_frame
 var card=p.cards.weapons_0;var other=p.cards.defence_0;var slot_level=g.module_entry("weapons",0).level
 p.select_item("defence_0");p.footer_buttons.details.pressed.emit()
 check(p.selected=="defence_0" and p.detail_frame.visible and p.detail.title.text.contains(scene.NAMES.armour),"Prior D01 inspector establishes parent's previous selection")
 p.detail_frame.hide();var resources=g.profile.resources.duplicate(true);var rng=g.rng.state;var old_defence=g.module_entry("defence",0).duplicate(true)
 var index:int=card.equipment_options.find("longLaser")
 check(index>=0,"Actual W01 native menu offers unlocked continuous beam")
 card.name_button.get_popup().index_pressed.emit(index);await process_frame
 check(g.module_entry("weapons",0).key=="longLaser" and g.module_entry("weapons",0).level==slot_level,"Native slot dropdown performs requested refit without changing slot level")
 check(p.selected=="weapons_0" and p.selected_slot==0 and p.footer_title.text.contains(scene.NAMES.longLaser),"Footer comparison target follows successfully operated W01 slot immediately")
 p.footer_buttons.details.pressed.emit()
 check(p.detail_frame.visible and p.detail.title.text.contains(scene.NAMES.longLaser) and not p.detail.title.text.contains(scene.NAMES.armour) and p.pending_key=="longLaser","Immediate actual comparison action opens beam rather than previous armor, resetting candidate identity")
 check(g.profile.resources==resources and g.module_entry("defence",0)==old_defence and g.rng.state==rng and card==p.cards.weapons_0 and other==p.cards.defence_0,"Free refit preserves resources, unrelated module, RNG and card instances")
 p.select_item("defence_0");p.change_card_equipment("weapons_0","unavailable-fixture-weapon")
 check(p.selected=="defence_0" and g.module_entry("weapons",0).key=="longLaser","Rejected refit preserves previous comparison selection and actual equipment")
 p.select_item("weapons_0");p.select_item("defence_0");p.footer_buttons.details.pressed.emit()
 check(p.selected=="defence_0" and p.detail.title.text.contains(scene.NAMES.armour),"Explicit later armor selection retains ordinary comparison semantics")
 scene.queue_free();await process_frame
 print("Refit comparison focus: ",checks," checks, ",failures," failures");quit(1 if failures else 0)
