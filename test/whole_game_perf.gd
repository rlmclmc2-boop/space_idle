extends SceneTree
# Use whole_game_perf.py: synthetic fixtures, copied project and isolated player data.
# Fixed-step wall times include rendering; headless wall times are not FPS.
class UI extends "res://scripts/battlefield.gd":
 func create_battle_game(_persist:bool)->BattleGame:return super.create_battle_game(false)
 func show_qa_tools()->void:pass
 func show_chrono_login_report()->void:pass
 var last_process_us := 0
 func _process(dt: float) -> void:
  var began := Time.get_ticks_usec()
  super._process(dt)
  last_process_us = Time.get_ticks_usec()-began
class Meter extends RefCounted:
 var enabled=false
 var times={}
 func record(key,us):
  if not enabled:return
  if not times.has(key):times[key]=[0,0,0]
  times[key][0]+=1;times[key][1]+=us;times[key][2]=max(times[key][2],us)
var meter=Meter.new()
var results=[]
func _initialize():
 Engine.set_meta("saved_perf",meter)
 call_deferred("run")
func stats(a):
 a.sort();var sum=0.0
 for x in a:sum+=x
 return {"mean":sum/a.size(),"p50":a[a.size()/2],"p95":a[int(a.size()*.95)],"p99":a[int(a.size()*.99)],"max":a[-1]}
func views(node,rows):
 if node is SubViewport:rows.append({"path":str(node.get_path()),"size":str(node.size),"mode":node.render_target_update_mode,"calls":node.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)})
 for c in node.get_children():views(c,rows)
func run():
 Engine.max_fps=0
 DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 seed(1701)
 var scene=load("res://main.tscn").instantiate();scene.set_script(UI)
 scene.automation_args=["--capture"];scene.music_on=false
 root.add_child(scene);current_scene=scene;scene.automation_args=[];scene.set_process(false)
 var g=scene.game
 g.save_enabled=false;g.stat_cache_enabled=true;g.rng.seed=1701;g.speed=1
 g.profile.onboarding.completed=true
 if is_instance_valid(scene.beginner_guide):scene.beginner_guide.hide()
 g.profile.cleared=range(1,101);g.profile.highestLevel=101
 g.profile.unlocked=BattleGame.EQUIPMENT.duplicate()
 for p in g.profile.planets.values():p.conquered=true
 g.rebuild_unlocks();g.pending_unlocks.clear();g.galaxy.refresh_unlocks(g)
 g.profile.scientists=49
 for key in g.db.data.hightech:
  g.profile.scientistAssignments[key]=11
  g.profile.techPoints[key]=g.hightech_required(key)*0.45
 var fixture=JSON.parse_string(FileAccess.get_file_as_string("res://galaxy_fixture.json"))
 g.galaxy.load_state(g,{"galaxy_1":fixture.save})
 if OS.get_environment("PERF_RICH")=="1":
  g.profile.selectedShip="Heavy_Battleship"
  var balance=float(OS.get_environment("PERF_BALANCE")) if not OS.get_environment("PERF_BALANCE").is_empty() else 1e80
  g.profile.resources={"1":balance,"2":balance}
  g.profile.jewelFragments=1e40;g.profile.enhancementLevel=30
  g.profile.enhancementAttacks=1000000;g.profile.enhancementHits=1000000
  g.profile.loadout={"weapons":[],"defence":[]}
  for key in ["laser","missile","cannon","longLaser","laser","missile","cannon","longLaser"]:g.profile.loadout.weapons.append({"key":key,"level":150})
  for key in ["shield","armour","shield","armour"]:g.profile.loadout.defence.append({"key":key,"level":150})
  for crew in g.profile.crew:crew.level=103;crew.exp=13159583000.0
  for key in g.db.data.hightech:g.profile.hightechLevels[key]=303
  g.planet_buildings.sync(g,"1")
  for item in g.profile.planets["1"].buildings.values():item.status="built"
  g.invalidate_stat_cache();g.reset_player();g.state=BattleGame.State.COMBAT;g.spawn_group()
  var template=g.enemies[0].duplicate(true);g.enemies.clear()
  for i in 3:
   var enemy=template.duplicate(true);enemy.uid=100+i;enemy.slot=i;enemy.x=200+80*i;enemy.y=230-2*i;enemy.hp=1e100;enemy.max_hp=1e100
   g.enemies.append(enemy)
 g.invalidate_stat_cache()
 scene.refresh_structure();scene.refresh_tab_visibility()
 print("ENV ",JSON.stringify({"engine":Engine.get_version_info().string,"adapter":RenderingServer.get_video_adapter_name(),"vendor":RenderingServer.get_video_adapter_vendor(),"method":RenderingServer.get_current_rendering_method(),"display":DisplayServer.get_name(),"resolution":str(root.size),"cap":Engine.max_fps,"low_processor":OS.low_processor_usage_mode}))
 var realtime=OS.get_environment("PERF_REALTIME")=="1"
 scene.set_process(realtime)
 var scenarios=[0,4,1,2,6,8]
 if not OS.get_environment("PERF_PAGES").is_empty():
  scenarios=[]
  for value in OS.get_environment("PERF_PAGES").split(","):scenarios.append(int(value))
 if OS.get_environment("PERF_MAX")=="1":
  scenarios=[0]
  scene.equipment_panel.set_upgrade_amount(0)
 var scenario_index=-1
 for page in scenarios:
  scenario_index+=1
  var switch_started=Time.get_ticks_usec()
  scene.select_system(page)
  var switch_cpu_us=Time.get_ticks_usec()-switch_started
  await process_frame
  var switch_frame_us=Time.get_ticks_usec()-switch_started
  var frames=[];var cpu=[];var calls=[];var primitives=[];var projectiles=[];var queue=[]
  var memory=0;var nodes=0;var resources=0
  meter.enabled=false;meter.times.clear()
  var count=int(OS.get_environment("PERF_FRAMES")) if not OS.get_environment("PERF_FRAMES").is_empty() else 60
  for i in range(count+15):
   if i==15:
    meter.enabled=true;memory=OS.get_static_memory_usage();nodes=get_node_count();resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
   var start=Time.get_ticks_usec()
   if OS.get_environment("PERF_RICH")=="1":
    g.profile.resources["1"]*=1.0000000001;g.profile.resources["2"]*=1.0000000001
   if not realtime:scene._process(1.0/60.0)
   var elapsed=Time.get_ticks_usec()-start
   await process_frame
   if i>=15:
    frames.append(Time.get_ticks_usec()-start);cpu.append(scene.last_process_us if realtime else elapsed)
    calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
    primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
    projectiles.append(g.projectiles.size());queue.append(g.missile_queue.size())
  meter.enabled=false
  var viewport_rows=[];views(root,viewport_rows)
  var row={"page":page,"scenario":scenario_index,"switch_cpu_us":switch_cpu_us,"switch_frame_us":switch_frame_us,"frames_us":stats(frames),"main_us":stats(cpu),"calls":stats(calls),"primitives":stats(primitives),"projectiles":stats(projectiles),"missile_queue":stats(queue),"memory":OS.get_static_memory_usage(),"memory_delta":OS.get_static_memory_usage()-memory,"node_delta":get_node_count()-nodes,"resources_delta":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)-resources,"timings":meter.times.duplicate(true),"views":viewport_rows}
  results.append(row);print("ROW ",JSON.stringify(row))
  if OS.get_environment("PERF_CAPTURE")=="1" and DisplayServer.get_name()!="headless":
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("res://.runtime/page-%d.png" % page)
 FileAccess.open("res://.runtime/whole-perf.json",FileAccess.WRITE).store_string(JSON.stringify(results," "))
 scene.set_process(false)
 scene.game.launch_provider=Callable();scene.game.target_provider=Callable()
 scene.queue_free();await process_frame;await process_frame
 Engine.remove_meta("saved_perf")
 quit()
