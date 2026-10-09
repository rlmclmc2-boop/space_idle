extends SceneTree
const Rewards=preload("res://scripts/drone_rewards.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func _initialize()->void:call_deferred("run")
func run()->void:
 var scene=load("res://main.tscn").instantiate();scene.automation_args=["--capture"]
 root.add_child(scene);scene.set_process(false)
 var g=scene.game;g.save_enabled=false;g.paused=true;g.pending_unlocks.clear();g.profile.onboarding.completed=true
 var before:=JSON.stringify(g.profile);var rng_before:int=g.rng.state
 var tutorial=scene.unlock_tutorial
 var starter:Dictionary=g.db.unlock_row("ship",g.profile.selectedShip)
 var gate:Dictionary=g.db.unlock_row("ship","Destroyer")
 tutorial.show_detail(starter)
 check(tutorial.description.text.contains(str(int(gate.level))) and tutorial.description.text.contains(gate.title) and tutorial.description.text.contains("已自动启用"),"Starter guide gives actual next ship gate rather than a nonexistent page action")
 gate.level=12;gate.mode="reached";tutorial.show_detail(starter)
 check(tutorial.description.text.contains("到达第12关"),"Ship hint follows a distinct configuration and reached mode")
 gate.level=10;gate.mode="cleared"
 var c=scene.hyperspace_panel.commands
 var random:=RandomNumberGenerator.new();random.seed=827
 var d:Dictionary=Rewards.create_drone(random,g.hyperspace.config,"scope-hint","legendary","missile",1,"1")
 d.affixes=[{"key":"attack_speed","tier":4,"value":0.033,"locked":false},{"key":"critical_chance","tier":5,"value":0.011,"locked":false}]
 check(c.modernization_scope(d).contains("本次词条数值不变") and c.modernization_scope(d).contains("主武器"),"All nonamplified affixes explicitly state modernization does not improve those values or main weapon level")
 d.affixes.append({"key":"global_damage","tier":5,"value":0.07,"locked":false})
 check(c.modernization_scope(d).contains("1条"),"Mixed affixes report only the actually amplified scope")
 check(JSON.stringify(g.profile)==before and g.rng.state==rng_before,"All scope hints preserve profile and RNG")
 g.profile.highestLevel=20;g.profile.cleared=range(1,20);g.rebuild_unlocks();g.pending_unlocks.clear();scene.refresh_tab_visibility()
 tutorial.show_detail(starter)
 check(tutorial.description.text==starter.desc,"Once ship page is available the authoritative ordinary guide remains")
 var p=scene.equipment_panel;scene.select_system(scene.equipment_tabs.get_tab_idx_from_control(p));p.refresh();p.select_item("weapons_0");p.show_inspector()
 p.pending_key="cannon";p.refresh_detail({},true)
 var title:String=UIText.t("equipment.current_attributes",{"name":p.items.weapons_0.name})
 check(p.detail.basics.text.begins_with(title) and p.detail.stats.text.contains(title),"Candidate comparison marks underlying basic and expanded attributes as current equipment")
 var crew=scene.crew_panel;crew.refresh()
 check(crew.hyperspace_hint.text.contains(UIText.t("hyperspace.crew")) and crew.hyperspace_hint.text.contains(UIText.t("hyperspace.layer_crew_start")),"Crew page points to exact existing management and dispatch controls")
 var storage:Dictionary=g.profile.hyperspace.hanging_modules.extra_storage
 storage.unlocked=true;storage.level=0
 check(c.hanging_slot_scope({"hangings":[]}).contains("有效模块0种"),"First unlockedLv0 module does not promise a slot return")
 storage.level=1
 check(c.hanging_slot_scope({"hangings":[]}).contains("1种") and c.hanging_slot_scope({"hangings":["extra_storage"]}).contains("有效模块0种"),"Only usable positive unmounted modules count as new-slot benefit")
 scene.queue_free();await process_frame
 print("DECISION SCOPE: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
