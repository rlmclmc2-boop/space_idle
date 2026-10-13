extends "res://qa_galaxy_residence.gd"
## Reuse the frozen UI/fixture instrumentation in evidence/galaxy-boundary-20261014.
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
 scene.refresh_structure();scene.refresh_tab_visibility();scene.select_system(0)

 assert(g.assign_crew("navigator","equipment_upgrade","equipment"),"normal main batch scheduler enabled")
 # One real equipment building has paid its work and has one construction second left.
 # Hidden settlement completes it at 10s; the window includes eight more seconds.
 g.galaxy.refresh_unlocks(g)
 var assigned:=""
 for member in g.profile.crew:
  if str(member.crewId)!="navigator" and g.assign_crew(str(member.crewId),"galaxy_explore","galaxy_1"):
   assigned=str(member.crewId);break
 assert(not assigned.is_empty(),"galaxy crew assigned before admission")
 var region=g.galaxy.regions.galaxy_1
 var chosen:=""
 for build in region.builds.values():
  if build.effect_type=="equipment_value":chosen=str(build.key);break
 assert(not chosen.is_empty())
 var slot:Dictionary=region.slots[0]
 slot.type=chosen;slot.planned_type=chosen;slot.status="constructing";slot.level=1;slot.work=region.work_cost();slot.construction=1.0
 region.state.explore_work=region.work_cost();region.refresh_counts();region.sync_map()
 var multiplier_before:float=g.galaxy.multiplier("equipment_value")
 g.native_execution_auto=true
 var admitted:bool=g.admit_native_compiled_execution("native_rich15_layer2")
 assert(admitted and scene.attach_native_display(),"both candidates begin with native fixed geometry")
 scene.retained_contacts_enabled=true
 g.event.connect(scene.watch)
 var transitions:Array=[]
 g.event.connect(func(kind:String,info:Dictionary):
  if kind=="native_execution_handoff":transitions.append({"kind":kind,"reason":info.reason,"game":g.production_time(),"revision":region.building_revision}))
 var before=snapshot(scene);var frames:Array=[];var owners:Array=[];var counts:Array=[];var revisions:Array=[]
 var samples:Array=[]
 var session=g.native_execution
 RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
 RenderingServer.viewport_set_measure_render_time(scene.ship_view.viewport.get_viewport_rid(),true)
 var start:=Time.get_ticks_usec();var previous:=start;var start_game:float=g.production_time()
 var native_game:=0.0;var last_game:float=start_game
 scene.set_process(true)
 while g.production_time()-start_game<18.0:
  await RenderingServer.frame_post_draw
  var now:=Time.get_ticks_usec();frames.append(now-previous);previous=now
  var active:bool=g.native_execution!=null
  if active:native_game+=g.production_time()-last_game
  last_game=g.production_time();owners.append(active);counts.append(g.projectiles.size());revisions.append(region.building_revision)
  samples.append({"game":g.production_time()-start_game,"fires":scene.fire_count-before.fires,"hits":scene.hit_count-before.hits,"purchases":scene.levels()-before.purchases,"floats":scene.floats.size(),"pending_text":scene.damage_pending.size(),"render":render_times(scene),"total_steps":session.ticks+scene.legacy_started_steps})
 scene.set_process(false)
 var row={"label":OS.get_environment("GALAXY_CASE"),"samples":samples,"total_steps":session.ticks+scene.legacy_started_steps,"multiplier_before":multiplier_before,"multiplier_after":g.galaxy.multiplier("equipment_value"),"frames_us":frames,"owners":owners,"projectile_counts":counts,"revisions":revisions,"admitted":admitted,"native_game_seconds_lower_bound":native_game,"before":before,"after":snapshot(scene),"transitions":transitions,"config":config(scene),"galaxy_crew":assigned,"region_state":region.save_data(),"wall_seconds":(previous-start)/1000000.0,"game_seconds":g.production_time()-start_game,"scope":"same native/fixed geometry start; one real equipment building completes at the 10s hidden settlement; 18 game seconds include at least eight seconds after completion"}
 assert(region.building_revision>0 and g.galaxy.multiplier("equipment_value")>multiplier_before,"actual equipment multiplier completion")
 if OS.get_environment("GALAXY_CASE")=="B" and (g.native_execution!=session or not transitions.is_empty()):printerr("REFIT_RESIDENCE_FAILED ",transitions);quit(1);return
 if OS.get_environment("GALAXY_CASE")!="B":assert(g.native_execution==null and transitions.size()==1 and transitions[0].reason=="galaxy_configuration","baseline safely transfers at completion")
 FileAccess.open("res://.runtime/galaxy-refit-"+OS.get_environment("GALAXY_CASE")+".json",FileAccess.WRITE).store_string(JSON.stringify(row))
 root.get_texture().get_image().save_png("res://.runtime/galaxy-refit-"+OS.get_environment("GALAXY_CASE")+".png")
 print("GALAXY_REFIT ",OS.get_environment("GALAXY_CASE")," frames ",frames.size()," game ",row.game_seconds," wall ",row.wall_seconds," native ",native_game," transitions ",transitions)
 stress.finish(g);g.begin_retreat();scene.queue_free();await process_frame;await process_frame;quit()
