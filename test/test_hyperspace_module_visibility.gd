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
 root.size=Vector2i(1280,800);root.gui_embed_subwindows=true
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
 commands.module_dialog.hide();scene.queue_free();await process_frame
 print("MODULE VISIBILITY: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
