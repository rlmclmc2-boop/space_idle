extends SceneTree
class IsolatedUI extends "res://scripts/battlefield.gd":
 func create_battle_game(_persist:bool)->BattleGame:return super.create_battle_game(false)
var failures:=0
var checks:=0
func check(ok:bool,message:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",message)
func _initialize()->void:call_deferred("run")
func run()->void:
 var scene=load("res://main.tscn").instantiate();scene.set_script(IsolatedUI);root.add_child(scene);current_scene=scene;scene.set_process(false)
 var g=scene.game;g.save_enabled=false;g.paused=true;g.profile.highestLevel=80;g.profile.cleared=range(1,80);g.rebuild_unlocks();g.pending_unlocks.clear();scene.refresh_tab_visibility();scene.select_system(9);await process_frame
 check(g.load_hyperspace_routes(),"Formal routes load in isolated nonpersisting scene")
 var p=scene.hyperspace_panel;p.refresh_manual_status();p.refresh()
 check(not p.start_button.disabled,"Ready route remains available")
 var before:Dictionary=g.profile.hyperspace.duplicate(true)
 g.profile.hyperspace.energy=0;p.refresh_progress()
 check(p.start_button.disabled and p.manual_reason.visible and p.manual_reason.text.contains("能源不足") and p.start_button.tooltip_text==p.manual_reason.text,"Frame refresh retains visible energy reason and tooltip")
 p.start_manual();check(g.profile.hyperspace.active.is_empty() and g.profile.hyperspace.energy==0,"Insufficient-energy action cannot debit or start")
 g.profile.hyperspace=before;p.refresh_progress();check(not p.start_button.disabled and not p.manual_reason.visible,"Energy replenishment clears stale disabled reason")
 var rng=RandomNumberGenerator.new();rng.seed=73
 var d:Dictionary=preload("res://scripts/drone_rewards.gd").create_drone(rng,g.hyperspace.config,"ux:sealed","gold","laser",5,"1")
 d.affixes=[{"key":"armour_capacity","tier":3.0,"value":0.16,"locked":false},{"key":"shield_capacity","tier":5.0,"value":0.27,"locked":false}]
 g.profile.hyperspace.unlocked_drones=true
 var bag:Dictionary=g.profile.hyperspace.inventory;bag.drones[d.id]=d;bag.warehouse.append(d.id)
 var gate:int=g.hyperspace.Permission.planet_stage(g.db.data,str(d.planet_id));bag.sealed[d.id]=gate;bag.generation+=1
 p.refresh();p.select_section(1);p.selected_id=d.id;g.profile.highestLevel=gate-1;p.refresh_details()
 check(p.unseal.disabled and p.details.text.contains(str(gate)) and p.unseal.tooltip_text.contains(str(gate)),"Below actual claim gate shows threshold and disabled action")
 check(not p.details.text.contains("未知词条") and p.details.text.contains("T3") and not p.details.text.contains("T3.0") and not p.details.text.contains("T5.0"),"Actual capacity affixes and JSON float tiers display correctly")
 var sealed_before=JSON.stringify(g.profile.hyperspace);check(not g.hyperspace.claim_sealed(g,d.id) and JSON.stringify(g.profile.hyperspace)==sealed_before,"Below-gate claim is transactionally unchanged")
 g.profile.highestLevel=gate;p.refresh_details();check(not p.unseal.disabled,"Exact reached gate enables native claim")
 p.unseal.pressed.emit();check(not g.profile.hyperspace.inventory.sealed.has(d.id),"Native claim commits at exact gate")
 var claimed=JSON.stringify(g.profile.hyperspace);check(not g.hyperspace.claim_sealed(g,d.id) and JSON.stringify(g.profile.hyperspace)==claimed,"Repeat claim cannot mutate inventory")
 var text:String=preload("res://scripts/ui_text.gd").t("planet.reforge_confirm",{"level":"8"})
 check(text.contains("保留铁与铀余额") and text.contains("未选择的无人机将删除") and text.contains("自动探索设置") and text.contains("封存"),"Confirmation discloses actual resource preservation, explicit retention selection and hyperspace resets")
 print("HYPERSPACE_UX_REASONS ",checks," checks ",failures," failures");quit(1 if failures else 0)
