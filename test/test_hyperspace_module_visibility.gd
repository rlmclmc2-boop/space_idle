extends SceneTree
class IsolatedUI extends "res://scripts/battlefield.gd":
 func create_battle_game(_persist:bool)->BattleGame:return super.create_battle_game(false)
const Rewards=preload("res://scripts/drone_rewards.gd")
const Bag=preload("res://scripts/drone_inventory.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label)
func keys(commands)->Array:
 return commands.module_choices.map(func(choice):return str(choice.get_meta("module_key")))
func labels(node:Node)->String:
 var result:String=node.text+"\n" if node is Label else ""
 for child in node.get_children():result+=labels(child)
 return result
func capture(commands,label:String)->void:
 var dir:=OS.get_environment("MODULE_VISIBILITY_EVIDENCE")
 if dir.is_empty() or DisplayServer.get_name()=="headless":return
 await process_frame;await process_frame;await RenderingServer.frame_post_draw
 commands.module_dialog.get_texture().get_image().save_png(dir.path_join(label+".png"))
func _initialize()->void:call_deferred("run")
func run()->void:
 root.size=Vector2i(1178,814);root.gui_embed_subwindows=true
 var scene=load("res://main.tscn").instantiate();scene.set_script(IsolatedUI);scene.automation_args=["--capture"];root.add_child(scene);scene.set_process(false)
 var g=scene.game;g.paused=true;g.save_enabled=false;g.profile.highestLevel=40;g.profile.cleared=range(1,40);g.rebuild_unlocks();g.pending_unlocks.clear();g.profile.onboarding.completed=true;g.profile.hyperspace.unlocked_drones=true
 var rng=RandomNumberGenerator.new();rng.seed=12345
 var d:=Rewards.create_drone(rng,g.hyperspace.config,"visibility-fixture","blue","laser",5,"1");d.hanging_slots=2;Bag.insert(g.profile.hyperspace.inventory,d,g.hyperspace.config)
 scene.refresh_tab_visibility();scene.select_system(9);var p=scene.hyperspace_panel;p.refresh_manual_status();p.dirty=true;p.refresh();p.selected_id=d.id
 var commands=p.commands;var before:Dictionary=g.profile.duplicate(true)
 commands.show_modules();await capture(commands,"01-no-owned-modules")
 check(keys(commands).is_empty(),"Never-unlocked unowned modules reveal no names")
 check(not labels(commands.module_dialog).contains(p.hanging_name("resource_collector")),"Source hint does not reveal the unowned collector by name")
 check(g.profile==before,"Opening module manager preserves progress")
 var window_id:int=commands.module_dialog.get_instance_id();commands.module_dialog.hide()
 g.profile.hyperspace.hanging_modules.resource_collector.unlocked=true
 commands.show_modules();await capture(commands,"02-one-unlocked-module")
 check(keys(commands)==["resource_collector"] and not commands.module_choices[0].disabled,"Unlocked module is visible and selectable")
 check(commands.module_dialog.get_instance_id()==window_id,"Module manager reuses its window")
 commands.module_choices[0].button_pressed=true
 check(g.hyperspace.attach_hangings(g,d.id,keys(commands)),"Visible unlocked selection remains valid for the authoritative attach command")
 commands.module_dialog.hide()
 g.profile.hyperspace.hanging_modules.resource_collector.unlocked=false
 g.profile.hyperspace.hanging_modules.distributed_algorithm.level=2
 g.profile.hyperspace.hanging_modules.extra_storage.exp=1.0
 g.profile.hyperspace.hanging_modules.gem_refiner.unlocked=true
 g.profile.highestLevel=int(g.hyperspace.config.hanging_modules.gem_refiner.unlock_stage)-1
 p.refresh_manual_status();p.dirty=true;p.refresh();p.selected_id=d.id;commands.show_modules();await capture(commands,"03-existing-assets-below-gate")
 check(keys(commands)==["resource_collector","distributed_algorithm","extra_storage","gem_refiner"],"Installed module, accumulated levels/experience and owned module below gate stay visible")
 check(commands.module_choices[0].button_pressed and commands.module_choices.all(func(choice):return choice.disabled),"Existing installed information survives while unavailable choices remain disabled")
 commands.module_dialog.hide()
 # Owned Lv1 module and one free slot: the unmet progress gate must be explicit.
 g.profile.hyperspace.hanging_modules=Rewards.module_progress(g.hyperspace.config)
 g.profile.hyperspace.hanging_modules.gem_refiner={"unlocked":true,"level":1,"exp":0}
 var owned_carrier:Dictionary=g.profile.hyperspace.inventory.drones[d.id]
 owned_carrier.hangings=[];owned_carrier.hanging_slots=1;g.profile.hyperspace.inventory.generation+=1;g.profile.highestLevel=7
 p.refresh_manual_status();p.selected_id=d.id
 var owned_before=g.profile.duplicate(true);var rng_before=g.rng.state
 commands.show_modules();await capture(commands,"04-owned-refiner-one-free-slot")
 var gate:int=int(g.hyperspace.config.hanging_modules.gem_refiner.unlock_stage)
 check(labels(commands.module_dialog).contains(p.t("module_slots",{"used":"0","cap":"1"})),"Fixture shows one genuinely free hanging slot")
 check(keys(commands)==["gem_refiner"] and commands.module_choices[0].disabled,"Owned refiner is blocked by progress despite a free slot")
 check(labels(commands.module_dialog).contains(p.t("module_requirement_stage",{"stage":str(gate),"current":"7"})) and not labels(commands.module_dialog).contains(p.t("module_no_slots")),"Owned module states the actual missing stage without claiming a capacity shortage")
 check(g.profile==owned_before and g.rng.state==rng_before,"Opening condition details changes no progress or RNG")
 commands.module_dialog.hide()
 g.profile.highestLevel=gate;commands.show_modules()
 check(not commands.module_choices[0].disabled and commands.module_requirement_text("gem_refiner").is_empty(),"Meeting the exact gate removes the warning and allows selection")
 commands.module_dialog.hide()
 g.hyperspace.config.hanging_modules.gem_refiner.unlock_stage=gate+4;commands.show_modules()
 check(commands.module_choices[0].disabled and labels(commands.module_dialog).contains(p.t("module_requirement_stage",{"stage":str(gate+4),"current":str(gate)})),"Condition follows a distinct configured threshold rather than hard-coded stage 15")
 commands.module_dialog.hide();scene.queue_free();await process_frame
 print("MODULE VISIBILITY: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
