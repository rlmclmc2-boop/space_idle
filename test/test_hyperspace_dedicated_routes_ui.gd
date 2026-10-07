extends SceneTree
class IsolatedUI extends "res://scripts/battlefield.gd":
 func create_battle_game(_persist:bool)->BattleGame:return super.create_battle_game(false)
func _initialize()->void:call_deferred("run")
func run()->void:
 if DisplayServer.get_name()=="headless":printerr("Requires a real graphical display for production geometry checks");quit(2);return
 root.size=Vector2i(1280,800)
 var scene=load("res://main.tscn").instantiate();scene.set_script(IsolatedUI);scene.automation_args=["--capture"];root.add_child(scene);scene.automation_args=[];scene.set_process(false)
 await process_frame;await process_frame
 var failures:=0
 var g=scene.game;g.save_enabled=false
 var fixtures={}
 var candidates=JSON.parse_string(FileAccess.get_file_as_string("res://data/space_enemy_candidates.json"))
 for route in ["alpha","beta","gamma","delta"]:
  var prep=BattleGame.new(g.db,false);prep.profile.highestLevel=34;prep.profile.cleared=range(1,34);prep.rebuild_unlocks();prep.pending_unlocks.clear();prep.profile.onboarding.completed=true
  prep.profile.resources["1"]=1000000000.;prep.profile.resources["2"]=1000000000.
  var weapon=str(prep.hyperspace.config.routes[route].weapon)
  if not prep.equip_slot("weapons",0,weapon) or not prep.upgrade_slot("weapons",0,34) or not prep.upgrade_slot("defence",0,34) or not prep.equip_slot("defence",1,"shield") or not prep.upgrade_slot("defence",1,34):printerr("QA equipment preparation failed");quit(1);return
  fixtures[route]=prep.portable_save_data()
 for route in ["alpha","beta","gamma","delta"]:
  for point in range(10):
   g.load_progress_data(fixtures[route].duplicate(true));g.resume_progress();g.pending_unlocks.clear();g.load_hyperspace_routes()
   if not g.start_hyperspace(route,5):printerr("STAGE FAILED ",route);quit(1);return
   g.manual_hyperspace.last_rejection={}
   g.group_index=point;g.spawn_group();g.paused=true
   scene.refresh_tab_visibility();scene.select_system(9);scene.hyperspace_panel.route=route;scene.hyperspace_panel.dirty=true;scene.hyperspace_panel.refresh();var presentation=scene.get("encounter_presentation")
   if presentation!=null:presentation.sync(g,0)
   scene.refresh_draw_layers(0)
   # QA jumps between paused encounters; request the new actor drawing explicitly.
   scene.battle_layer.queue_redraw()
   await process_frame;await process_frame;await RenderingServer.frame_post_draw
   var name="staged-"+route+"-"+str(point+1)
   var output=OS.get_environment("HYPERSPACE_SCENE_EVIDENCE")
   if point>=8 and not output.is_empty():root.get_texture().get_image().save_png(output.path_join(name+".png"))
   print("RENDERED ",name," actors=",g.enemies.size()," active=",g.manual_hyperspace.active," rejection=",JSON.stringify(g.manual_hyperspace.last_rejection))
   if not g.manual_hyperspace.active or g.enemies.size()!=candidates.groups[str(g.db.levels[g.stage-1].groups[point].id)].slots.filter(func(id):return id!=null).size():failures+=1
   g.manual_hyperspace.finish(g,false,"qa_stage")
 scene.queue_free();await process_frame;print("SCENE ALL40 failures=",failures);quit(1 if failures else 0)
