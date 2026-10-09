extends SceneTree
const Rewards=preload("res://scripts/drone_rewards.gd")
const Bag=preload("res://scripts/drone_inventory.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize()->void:call_deferred("run")
func run()->void:
 var scene=load("res://main.tscn").instantiate();scene.automation_args=["--capture"]
 root.add_child(scene);scene.set_process(false)
 var g=scene.game;g.save_enabled=false;g.paused=true;g.profile.highestLevel=20;g.profile.cleared=range(1,20);g.rebuild_unlocks();g.pending_unlocks.clear();g.profile.onboarding.completed=true;g.profile.hyperspace.unlocked_drones=true
 var rng:=RandomNumberGenerator.new();rng.seed=935
 var d:Dictionary=Rewards.create_drone(rng,g.hyperspace.config,"detail-priority","legendary","missile",6,"1")
 d.affixes=[{"key":"shield_capacity","tier":1,"value":1.99,"locked":false},{"key":"attack_speed","tier":4,"value":0.033,"locked":false}]
 d.origin_quality="gold";d.preserved_hanging_slots=1;d.hanging_slots=1;d.hangings=["extra_storage"];g.profile.hyperspace.hanging_modules.extra_storage.unlocked=true;g.profile.hyperspace.hanging_modules.extra_storage.level=1
 check(Bag.insert(g.profile.hyperspace.inventory,d,g.hyperspace.config),"Legal T1 shield/installed storage fixture")
 scene.refresh_tab_visibility();scene.select_system(9);await process_frame
 var p=scene.hyperspace_panel;p.refresh_manual_status();p.selected_id=d.id;p.select_section(1);p.refresh()
 var before:=JSON.stringify(g.profile);var rng_before:int=g.rng.state
 var text:String=p.details.text
 check(text.get_slice("\n",0)==p.affix_summary(d.affixes[0],d),"Actual inventory details begin with the high-value ordinary affix")
 var general:String=p.t("drone_dynamic_weapon_hint")
 check(text.find(p.affix_summary(d.affixes[1],d))<text.find(general) and text.find(p.hanging_name("extra_storage"))<text.find(general),"Ordinary affixes and hanging are above general weapon rules")
 check(text.contains(general) and text.contains(p.t("drone_fire_missile",{"interval":"%.2f"%float(g.player_weapon_row(g.drone_weapon_entry(d)).cd),"count":str(int(g.player_weapon_row(g.drone_weapon_entry(d)).para1))})),"Existing weapon explanation and firing facts remain available below")
 var effect_id:String=d.legendary_effect.effect_id
 var legend_text:String=p.legendary_help.summary(effect_id)+( "\n"+p.legendary_help.master_status(d.id) if effect_id=="drone_master" else "")
 check(p.legendary_group.visible and p.legendary_summary.text==legend_text,"Legendary short summary remains in its independent area")
 p.show_selected_legendary()
 check(p.legendary_help.dialog.visible and p.legendary_help.body.text.contains(p.effect_name(d.legendary_effect.effect_id)),"Independent legendary detail entry remains usable")
 check(JSON.stringify(g.profile)==before and g.rng.state==rng_before,"Reordering and explanation entry preserve profile and RNG")
 scene.queue_free();await process_frame
 print("DRONE DETAIL PRIORITY: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
