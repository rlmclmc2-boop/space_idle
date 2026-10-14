extends "res://qa_galaxy_residence.gd"
const N=preload("res://natural_probe.gd")
var counts:Dictionary={}
var trace:Array=[]
var drop_ids:Dictionary={}
var host
func observe(kind:String,info:Dictionary)->void:
 counts[kind]=int(counts.get(kind,0))+1
 if kind in ["encounter","wave_clear","collect","upgrades_completed","native_execution_handoff","level_clear","retreat"]:
  trace.append({"kind":kind,"game":host.game.production_time(),"step":N.steps,"info":info.duplicate(true),"resources":host.game.profile.resources.duplicate(true)})
func run()->void:
 var scene=load("res://main.tscn").instantiate();scene.set_script(UI);host=scene
 scene.automation_args=["--capture"];scene.music_on=false
 root.add_child(scene);current_scene=scene;scene.automation_args=[];scene.set_process(false)
 var g=scene.game;g.save_enabled=false;g.speed=1;g.rng.seed=1701
 g.profile.onboarding.completed=true;scene.beginner_guide.hide()
 g.profile.cleared=range(1,11);g.profile.highestLevel=11;g.profile.unlocked=BattleGame.EQUIPMENT.duplicate()
 g.rebuild_unlocks();g.pending_unlocks.clear();g.profile.selectedShip="Heavy_Battleship"
 g.profile.resources={"1":3000.0,"2":300.0}
 g.profile.loadout={"weapons":[{"key":"laser","level":5},{"key":"cannon","level":5},{"key":"missile","level":5},{"key":"longLaser","level":5}],"defence":[{"key":"armour","level":5},{"key":"shield","level":5}]}
 g.invalidate_stat_cache();g.reset_player()
 assert(g.assign_crew("navigator","equipment_upgrade","equipment"))
 scene.refresh_structure();scene.refresh_tab_visibility();scene.select_system(0)
 g.event.connect(scene.watch);g.event.connect(observe)
 g.native_execution_auto=true;assert(g.start(1,false))
 var initial={"resources":g.profile.resources.duplicate(true),"loadout":g.profile.loadout.duplicate(true),"level":1,"prior_cleared":g.profile.cleared.duplicate(),"notes":"Finite replay configuration, not a claim of fresh-player natural progression. Original table enemies/HP/drops, no held-health fixture or replenishment."}
 RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
 RenderingServer.viewport_set_measure_render_time(scene.ship_view.viewport.get_viewport_rid(),true)
 var frames:Array=[];var samples:Array=[];var start:=Time.get_ticks_usec();var previous:=start;var start_game:float=g.production_time();var start_steps:=N.steps
 var reason:="45_game_second_limit"
 scene.set_process(true)
 while g.production_time()-start_game<45.0:
  await RenderingServer.frame_post_draw
  var now:=Time.get_ticks_usec();frames.append(now-previous);previous=now
  for drop in g.drops:drop_ids[int(drop.uid)]=true
  samples.append({"step":N.steps,"game":g.production_time(),"native":g.native_execution!=null,"state":g.state,"group":g.group_index,"enemies":g.enemies.size(),"projectiles":g.projectiles.size(),"drops":g.drops.size(),"render":render_times(scene)})
  if g.production_time()-start_game>=15.0 and int(counts.get("encounter",0))>=3 and int(counts.get("wave_clear",0))>=2 and N.admissions.filter(func(x):return x.success).size()>=3 and int(counts.get("collect",0))>0 and int(counts.get("upgrades_completed",0))>0:
   reason="coverage_endpoint";break
  if now-start>90000000:reason="90_wall_second_safety_limit";break
 scene.set_process(false)
 var row={"source":"346c67f8","dll_sha256":FileAccess.get_sha256("res://bin/space_native.dll"),"config":config(scene),"initial":initial,"stop_reason":reason,"frames_us":frames,"samples":samples,"events":counts,"trace":trace,"admissions":N.admissions,"transfers":N.transfers,"observed_drop_ids":drop_ids.keys(),"steps":N.steps-start_steps,"game_seconds":g.production_time()-start_game,"wall_seconds":(previous-start)/1000000.0,"resources_end":g.profile.resources,"loadout_end":g.profile.loadout,"game_rng_end":str(g.rng.state),"native_handoffs":g.native_handoff_count}
 FileAccess.open("res://.runtime/natural-current.json",FileAccess.WRITE).store_string(JSON.stringify(row))
 root.get_texture().get_image().save_png("res://.runtime/natural-current.png")
 print("NATURAL_RESULT ",reason," game=",row.game_seconds," encounters=",counts.get("encounter",0)," waves=",counts.get("wave_clear",0)," collects=",counts.get("collect",0)," admits=",N.admissions.size())
 g.begin_retreat();scene.queue_free();await process_frame;await process_frame;quit()
