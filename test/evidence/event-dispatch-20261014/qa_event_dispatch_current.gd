extends "res://qa_galaxy_residence.gd"
## Reuse the frozen UI/fixture instrumentation in evidence/galaxy-boundary-20261014.
const Probe=preload("res://event_dispatch_probe.gd")
var system_events:Dictionary={}
func record_event(kind:String,_info:Dictionary)->void:
 system_events[kind]=int(system_events.get(kind,0))+1
func run()->void:
 var scene=load("res://main.tscn").instantiate();scene.set_script(UI)
 scene.automation_args=["--capture"];scene.music_on=false
 root.add_child(scene);current_scene=scene;scene.automation_args=[];scene.set_process(false)
 var g=scene.game;g.save_enabled=false;g.speed=1;g.rng.seed=1701
 g.profile.onboarding.completed=true;scene.beginner_guide.hide()
 g.profile.cleared=range(1,101);g.profile.highestLevel=101;g.profile.unlocked=BattleGame.EQUIPMENT.duplicate()
 g.rebuild_unlocks();g.pending_unlocks.clear();g.profile.selectedShip="Heavy_Battleship"
 g.profile.resources={"1":1e80,"2":1e80};g.profile.loadout={"weapons":[],"defence":[]}
 for key in ["missile","missile","cannon","longLaser","laser","missile","cannon","longLaser"]:g.profile.loadout.weapons.append({"key":key,"level":150})
 for key in ["shield","armour","shield","armour"]:g.profile.loadout.defence.append({"key":key,"level":150})
 g.invalidate_stat_cache();g.reset_player();g.state=BattleGame.State.COMBAT;g.spawn_group()
 var template=g.enemies[0].duplicate(true);g.enemies.clear()
 for i in 15:
  var e=template.duplicate(true);e.uid=100+i;e.slot=i;e.x=80+80*(i%5);e.y=150+80*(i/5);e.hp=1e100;e.max_hp=1e100
  g.enemies.append(e)
 var stress=preload("res://combat_stress_fixture.gd").new();assert(stress.configure(g,2))

 # Finite normal research: twelve purchased AI, six on each level-one furnace.
 for key in [BattleGame.FURNACE,BattleGame.JEWEL_FURNACE]:
  assert(g.hightech_unlocked(key));g.profile.hightechLevels[key]=1
 assert(g.generate_scientist(12))
 assert(g.assign_scientist(BattleGame.FURNACE,6));assert(g.assign_scientist(BattleGame.JEWEL_FURNACE,6))
 assert(g.assign_crew("navigator","equipment_upgrade","equipment"))
 var exploration:Dictionary={}
 for id in g.profile.planets:
  for member in g.profile.crew:
   if g.start_planet_exploration(str(id),str(member.crewId)):
    exploration={"id":id,"crew":member.crewId,"duration":g.planet_duration(str(id))};break
  if not exploration.is_empty():break
 scene.refresh_structure();scene.refresh_tab_visibility();scene.select_system(1)
 scene.hightech_page.select_project(BattleGame.FURNACE)
 assert(scene.hightech_page.is_visible_in_tree())
 g.native_execution_auto=true
 assert(g.admit_native_compiled_execution("native_rich15_layer2") and scene.attach_native_display())
 scene.retained_contacts_enabled=true;g.event.connect(scene.watch)
 RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
 RenderingServer.viewport_set_measure_render_time(scene.ship_view.viewport.get_viewport_rid(),true)
 scene.set_process(true)
 var warm:float=g.production_time()
 while g.production_time()-warm<3.0:await RenderingServer.frame_post_draw
 scene.set_process(false)
 var page=scene.hightech_page
 var setup={"scientists":g.profile.scientists,"assignments":g.profile.scientistAssignments.duplicate(true),"levels":g.profile.hightechLevels.duplicate(true),"points":g.profile.techPoints.duplicate(true),"auto_gen":g.auto_gen_settings(),"furnace_row":g.db.data.hightech[BattleGame.FURNACE],"jewel_furnace_row":g.db.data.hightech[BattleGame.JEWEL_FURNACE],"exploration":exploration,"visible_rows":page.rows.size(),"selected":page.selected}
 var before=snapshot(scene);var session=g.native_execution;var initial_ticks:int=session.ticks
 var refresh_before:int=page.refresh_count;var refresh_us_before:int=page.refresh_usec;var quote_before:int=page.quote_evaluations
 var samples:Array=[];var frames:Array=[];var start:=Time.get_ticks_usec();var previous:=start;var start_game:float=g.production_time()
 g.event.connect(record_event);Probe.install(g);Probe.enabled=true;scene.set_process(true)
 while g.production_time()-start_game<30.0:
  await RenderingServer.frame_post_draw
  var now:=Time.get_ticks_usec();frames.append(now-previous);previous=now
  samples.append({"game":g.production_time()-start_game,"native":g.native_execution==session,"steps":session.ticks-initial_ticks,"drops":g.drops.size(),"projectiles":g.projectiles.size(),"floats":scene.floats.size(),"refresh_count":page.refresh_count-refresh_before,"render":render_times(scene)})
 Probe.enabled=false;scene.set_process(false)
 var row={"source":"e1353c97","config":config(scene),"accessibility":ProjectSettings.get_setting("accessibility/general/accessibility_support"),"setup":setup,"before":before,"after":snapshot(scene),"steps":session.ticks-initial_ticks,"game_seconds":g.production_time()-start_game,"wall_seconds":(previous-start)/1000000.0,"frames_us":frames,"samples":samples,"listener_manifest":Probe.manifest,"emit_costs":Probe.emits,"listener_costs":Probe.costs,"nested_other_listener_calls":Probe.nested_other,"events":system_events,"ui_refresh_count":page.refresh_count-refresh_before,"ui_refresh_us":page.refresh_usec-refresh_us_before,"ui_quote_evaluations":page.quote_evaluations-quote_before,"points_end":g.profile.techPoints,"levels_end":g.profile.hightechLevels,"native_same_session":g.native_execution==session,"notes":"Single hit/impact/fire dispatch diagnostic; original synchronous listener order preserved. Listener body exclusive subtracts nested callback spans; emit residual excludes measured wrapper spans. No production changes or algorithm A/B. Necessary presentation is not removable overhead."}
 row.probe_calibration=Probe.calibration()
 Probe.uninstall(g)
 FileAccess.open("res://.runtime/event-dispatch-current.json",FileAccess.WRITE).store_string(JSON.stringify(row))
 root.get_texture().get_image().save_png("res://.runtime/event-dispatch-current.png")
 print("EVENT_DISPATCH_RESULT frames=",frames.size()," wall=",row.wall_seconds," game=",row.game_seconds," native=",row.native_same_session," refresh=",row.ui_refresh_count)
 stress.finish(g);g.begin_retreat();scene.queue_free();await process_frame;await process_frame;quit()
