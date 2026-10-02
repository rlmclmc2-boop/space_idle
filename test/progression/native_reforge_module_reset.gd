extends SceneTree
func _initialize():call_deferred("run")
func run():
 var path:=OS.get_environment("PROGRESSION_UI_CHECKPOINT")
 assert(not path.is_empty())
 var checkpoint:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
 var scene=load("res://main.tscn").instantiate();scene.automation_args=["--capture"];root.add_child(scene);scene.set_process(false);scene.automation_args=[]
 # Keep the actual scene-owned Presented game; no game-instance replacement.
 var g=scene.game;g.save_enabled=false
 var raw:Dictionary=checkpoint.save.duplicate(true);raw.chronoSavedAt=Time.get_unix_time_from_system()
 g.load_progress_data(raw);g.resume_progress();scene.build_ui()
 var before:int=scene.equipment_panel.cards.size()
 var survivor_id:String=g.slot_id("weapons",0)
 var survivor_instance:int=scene.equipment_panel.cards[survivor_id].get_instance_id()
 scene.equipment_panel.select_item(g.slot_id("weapons",g.module_entries("weapons").size()-1))
 g.planet_buildings.sync(g,"1");g.planet_buildings.state(g,"1","shipyard").status="ready"
 assert(g.planet_buildings.activate(g,"1","shipyard"));assert(g.can_reforge_planet("1"))
 # Valid queued projection invalidation, as occurs after reactor/research changes.
 scene.equipment_panel.invalidate_stats({"category":"weapons"})
 scene.planet_panel._confirm_reforge("1")
 var dialogs=scene.planet_panel.get_children().filter(func(child):return child is ConfirmationDialog)
 assert(dialogs.size()==1)
 var dialog=dialogs[0]
 assert(dialog.dialog_text.contains("装备效果等级 +35"));assert(dialog.dialog_text.contains("AI工厂效果等级 +25"))
 assert(dialog.dialog_text.contains("保留铁与铀余额、时空粒子"));assert(dialog.dialog_text.contains("进行中的星球探索继续"))
 dialog.confirmed.emit();assert(g.planet_progress("1").get("conquered",false))
 print("NATIVE_REFORGE_CONFIRM_PASS rewards_from_source=true reserve_and_exploration_text_correct=true")
 var expected:int=g.module_entries("weapons").size()+g.module_entries("defence").size()
 var after:int=scene.equipment_panel.cards.size()
 print("NATIVE_REFORGE_MODULES before=",before," after=",after," expected=",expected," pending_rebuild=",scene.ui_rebuild_pending)
 if after!=expected:
  printerr("NATIVE_REFORGE_MODULES_MISMATCH");quit(1);return
 assert(scene.equipment_panel.cards[survivor_id].get_instance_id()==survivor_instance)
 assert(scene.equipment_panel.items.has(scene.equipment_panel.selected))
 print("NATIVE_REFORGE_LOCAL_REFRESH_PASS surviving_card_reused=true removed_selection_reset=true")
 scene.queue_free();quit()
