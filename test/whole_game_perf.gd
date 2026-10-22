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
 var fixture=JSON.parse_string(FileAccess.get_file_as_string("res://galaxy_fixture.json"))
 var rich:=OS.get_environment("PERF_RICH")=="1"
 var balance:=float(OS.get_environment("PERF_BALANCE")) if not OS.get_environment("PERF_BALANCE").is_empty() else 1e80
 var owned:bool=g.get("equipment")!=null
 var ship:="Heavy_Battleship" if rich else "Frigate"
 var loadout:Dictionary={"weapons":[],"defence":[]}
 for i in int(g.db.ship(ship).weaponSlots):loadout.weapons.append({"key":["laser","missile","cannon","longLaser"][i%4],"level":150 if rich else 1})
 for i in int(g.db.ship(ship).defenseSlots):loadout.defence.append({"key":"armour" if i%2==0 else "shield","level":150 if rich else 1})
 if owned:
  var equipment:Dictionary=g.equipment.save_data();equipment.selectedShip=ship;equipment.loadout=loadout
  assert(g.equipment.install_snapshot(equipment,g.db))
  var wallet:Dictionary=g.economy.save_data();wallet.resources={"1":balance,"2":balance};wallet.jewelFragments=1e40
  assert(g.economy.install_snapshot(wallet))
  var growth:Dictionary=g.enhancement_growth.save_data();growth.enhancementLevel=30 if rich else 0;growth.enhancementAttacks=1000000;growth.enhancementHits=1000000
  assert(g.enhancement_growth.install_snapshot(growth))
  var crew:Dictionary=g.crew.save_data()
  if rich:
   for member in crew.crew:member.level=103;member.exp=13159583000.0
  assert(g.crew.install_snapshot(crew,g.db))
  var planets:Dictionary=g.planets.save_data();planets.merge(crew)
  for planet in planets.planets.values():planet.conquered=true
  if rich:
   for item in planets.planets["1"].buildings.values():item.status="built"
  assert(g.planets.install_snapshot(planets,g.db))
  var research:Dictionary=g.research.save_data()
  for key in g.db.data.ai_tech_tree:research.aiTechLevels[key]=30 if rich else 0
  assert(g.research.install_snapshot(research,g.db.data.ai_tech_tree))
  var galaxy:Dictionary=g.galaxy.save_data();galaxy.galaxies.galaxy_1=fixture.save.duplicate(true)
  galaxy.galaxies.galaxy_1.pending_online_time=0.0;galaxy.galaxies.galaxy_1.pending_crew_count=0
  assert(g.galaxy.install_snapshot(galaxy,g.db))
  g.rebuild_unlocks();g.galaxy_runtime.refresh_unlocks(g);g.notify_configuration_changed();g.crew.reset_schedule(g)
 else:
  # The main baseline owns the same authored values in its former profile.
  # This adapter is confined to the before/after fixture, not save compatibility.
  g.profile.selectedShip=ship;g.profile.loadout=loadout;g.profile.resources={"1":balance,"2":balance};g.profile.jewelFragments=1e40
  g.profile.enhancementLevel=30 if rich else 0;g.profile.enhancementAttacks=1000000;g.profile.enhancementHits=1000000
  if rich:
   for member in g.profile.crew:member.level=103;member.exp=13159583000.0
  for planet in g.profile.planets.values():planet.conquered=true
  if rich:
   g.planet_buildings.sync(g,"1")
   for item in g.profile.planets["1"].buildings.values():item.status="built"
  for key in g.db.data.ai_tech_tree:g.profile.aiTechLevels[key]=30 if rich else 0
  g.rebuild_unlocks();g.galaxy.load_state(g,{"galaxy_1":fixture.save});g.galaxy.refresh_unlocks(g);g.invalidate_stat_cache()
 g.pending_unlocks.clear();g.native_execution_auto=false;g.reset_player()
 if rich:
  g.assign_crew("navigator","galaxy_explore","galaxy_2")
  g.state=BattleGame.State.COMBAT;g.spawn_group()
  var template=g.enemies[0].duplicate(true);g.enemies.clear()
  for i in 3:
   var enemy=template.duplicate(true);enemy.uid=100+i;enemy.slot=i;enemy.x=200+80*i;enemy.y=230-2*i;enemy.hp=1e50;enemy.max_hp=1e50
   g.enemies.append(enemy)
  g.native_execution_auto=true;g.admit_native_compiled_execution("native_rich15_layer2")
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
  if page==8 and OS.get_environment("PERF_GALAXY_STEADY")=="1":
   # Settle presentation-only departure staggering; never advance gameplay.
   scene.galaxy_panel.map.visual_clock+=60.0
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
    if owned:g.economy.credit_many({"1":balance*1e-10,"2":balance*1e-10})
    else:g.profile.resources["1"]+=balance*1e-10;g.profile.resources["2"]+=balance*1e-10
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
  var row={"page":page,"scenario":scenario_index,"native":g.native_execution!=null,"owned_domains":owned,"switch_cpu_us":switch_cpu_us,"switch_frame_us":switch_frame_us,"frames_us":stats(frames),"main_us":stats(cpu),"calls":stats(calls),"primitives":stats(primitives),"projectiles":stats(projectiles),"missile_queue":stats(queue),"memory":OS.get_static_memory_usage(),"memory_delta":OS.get_static_memory_usage()-memory,"node_delta":get_node_count()-nodes,"resources_delta":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)-resources,"timings":meter.times.duplicate(true),"views":viewport_rows}
  results.append(row);print("ROW ",JSON.stringify(row))
  if OS.get_environment("PERF_CAPTURE")=="1" and DisplayServer.get_name()!="headless":
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("res://.runtime/page-%d.png" % page)
 FileAccess.open("res://.runtime/whole-perf.json",FileAccess.WRITE).store_string(JSON.stringify(results," "))
 scene.set_process(false)
 if scene.battle_slice_runtime!=null:scene.battle_slice_runtime.close();scene.battle_slice_runtime=null
 if g.native_execution!=null:g.native_execution.cancel(g);g.native_execution=null
 scene.game.launch_provider=Callable();scene.game.target_provider=Callable()
 scene.queue_free();await process_frame;await process_frame
 Engine.remove_meta("saved_perf")
 quit()
