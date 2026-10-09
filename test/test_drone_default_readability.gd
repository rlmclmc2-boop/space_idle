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
 var g=scene.game;g.save_enabled=false;g.paused=true;g.profile.highestLevel=34;g.profile.cleared=range(1,34);g.rebuild_unlocks();g.pending_unlocks.clear();g.profile.hyperspace.unlocked_drones=true;g.profile.droneWeaponFloor=130
 var rng=RandomNumberGenerator.new();rng.seed=929
 var plain=Rewards.create_drone(rng,g.hyperspace.config,"default-plain","white","laser",1,"1");plain.hangings=[];plain.hanging_slots=0
 var legend=Rewards.create_drone(rng,g.hyperspace.config,"default-legend","legendary","laser",1,"1")
 Bag.insert(g.profile.hyperspace.inventory,plain,g.hyperspace.config);Bag.insert(g.profile.hyperspace.inventory,legend,g.hyperspace.config)
 scene.refresh_tab_visibility();scene.select_system(9);await process_frame
 var p=scene.hyperspace_panel;p.select_section(1);p.choose_drone(plain.id)
 var before=JSON.stringify(g.profile);var state=g.rng.state
 check(not p.details.text.contains(p.t("drone_dynamic_weapon_hint")) and not p.details.text.contains(p.t("no_hangings")) and not p.details.text.contains(p.t("unprotected")),"Default plain drone omits growth paragraph and empty module/protection states")
 check(p.details.text.begins_with(p.t("drone_independent_weapon",{"weapon":p.t(plain.weapon),"level":str(g.drone_weapon_entry(plain).level)})) and p.detail_title.text.contains("改造等级 1"),"Default card distinguishes modification grade from actual inherited weapon level")
 check(not p.capacity.text.contains("缓存") and not p.capacity.text.contains("保留") and not p.budgets.visible,"Default warehouse omits zero overflow/retention and unused rare budgets")
 check(not p.dismantle_button.disabled and not p.equip.disabled and not p.module_manage.disabled and p.commands.material_route_button!=null,"Existing equip, dismantle, module and shortage-route controls remain available")
 p.detail_toggle.pressed.emit()
 check(p.details_expanded and p.details.text.contains(p.t("drone_dynamic_weapon_hint")) and p.details.text.contains(p.t("no_hangings")),"Existing selected-card text area reveals complete growth and empty-slot explanation only on request")
 p.refresh_details()
 check(p.details_expanded,"Refreshing the same selected drone preserves requested expansion")
 p.choose_drone(legend.id)
 check(not p.details_expanded and p.legendary_group.visible and not p.legendary_summary.text.is_empty() and p.legendary_button.text.contains("详情"),"Changing selection collapses ordinary attributes while preserving legendary short summary and existing details entry")
 p.choose_drone(plain.id)
 var cap=int(p.hull_capacity_provider.call());p.equipment_ui.refresh()
 check(p.equipment_ui.slots.filter(func(slot):return slot.visible).size()==cap and not p.equipment_ui.capacity_hint.text.is_empty(),"Only current-hull slots show; useful hull-capacity guidance remains")
 check(JSON.stringify(g.profile)==before and g.rng.state==state,"All readability and detail-toggle operations preserve drone data, resources and RNG")
 p.equip.pressed.emit();p.refresh_details()
 var expected=g.drone_weapon_entry(plain).level
 check(g.profile.hyperspace.inventory.equipped.has(plain.id) and p.equipment_ui.slots[0].text.contains("武器等级 "+str(expected)),"Real equip action shows authoritative dynamic weapon level in occupied slot")
 scene.queue_free();await process_frame
 print("Drone default readability: ",checks," checks, ",failures," failures");quit(1 if failures else 0)
