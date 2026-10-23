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
var page_checks:Array=[]
var galaxy_settlements:=0
var galaxy_income_events:=0
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
 var galaxy_work:=OS.get_environment("PERF_GALAXY_WORK")
 if galaxy_work.is_empty():galaxy_work="complete"
 if galaxy_work!="complete":
  # Reuse the authored full-city fixture. Only its legal work state changes;
  # all production costs, power, cadence, assets and slot topology stay intact.
  fixture.save.status="developing";fixture.save.upgrade_work=0.0
  for slot in fixture.save.slots:slot.status="active";slot.level=4;slot.upgrade_progress=0.0
  var definition:Dictionary=g.db.data.galaxy.galaxy_1
  var share:float=(float(definition.upgrade_power_base)+float(definition.upgrade_power_per_crew))/int(definition.concurrent_upgrade_count)
  for index in 2:
   var slot:Dictionary=fixture.save.slots[index]
   slot.status="upgrading";slot.upgrade_progress=float(definition.upgrade_cost_lv5)-[4.0,14.0][index]*share
   fixture.save.upgrade_work+=slot.upgrade_progress
 var rich:=OS.get_environment("PERF_RICH")=="1"
 var balance:=float(OS.get_environment("PERF_BALANCE")) if not OS.get_environment("PERF_BALANCE").is_empty() else 1e80
 var reactor_level:=int(OS.get_environment("PERF_REACTOR_LEVEL"))
 var enemy_count:=int(OS.get_environment("PERF_ENEMIES"))
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
  var reactor:Dictionary=g.reactor.save_data();reactor.reactorLevel=reactor_level
  assert(g.reactor.install_snapshot(reactor,g.db.config))
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
  g.profile.reactorLevel=reactor_level
  g.rebuild_unlocks();g.galaxy.load_state(g,{"galaxy_1":fixture.save});g.galaxy.refresh_unlocks(g);g.invalidate_stat_cache()
 g.pending_unlocks.clear();g.native_execution_auto=false;g.reset_player()
 var allocation_started:=Time.get_ticks_usec()
 if reactor_level>1:assert(g.set_reactor_allocation("smelting",g.reactor_capacity()))
 var allocation_command_us:=Time.get_ticks_usec()-allocation_started
 var galaxy_assignment:=false
 if galaxy_work=="active":
  galaxy_assignment=g.assign_crew("navigator","galaxy_explore","galaxy_1")
  page_check(galaxy_assignment and g.galaxy.crew_count(g,"galaxy_1")==1,"Actual navigator assignment to existing developing galaxy_1 succeeds")
  if not galaxy_assignment:print("CHECKS ",JSON.stringify(page_checks));quit(1);return
 g.event.connect(func(kind,info):
  if kind=="galaxy_changed" and info.get("key")=="galaxy_1":galaxy_settlements+=1
  if kind=="galaxy_income":galaxy_income_events+=1)
 var galaxy_initial=galaxy_progress(g)
 if rich:
  g.state=BattleGame.State.COMBAT;g.spawn_group()
  var template=g.enemies[0].duplicate(true);g.enemies.clear()
  var slots:Array=[]
  for i in enemy_count:slots.append(template.id)
  var formation:Dictionary=preload("res://scripts/enemy_formation.gd").positions(slots,g.db.enemies)
  for i in enemy_count:
   var enemy=template.duplicate(true);enemy.uid=100+i;enemy.slot=i;enemy.x=formation[i].x;enemy.y=formation[i].y;enemy.formation_count=enemy_count;enemy.formation_columns=5
   enemy.hp=1e300 if reactor_level>1 else 1e50;enemy.max_hp=enemy.hp
   g.enemies.append(enemy)
  g.native_execution_auto=true;g.admit_native_compiled_execution("native_rich15_layer2")
 scene.refresh_structure();scene.refresh_tab_visibility()
 print("ENV ",JSON.stringify({"engine":Engine.get_version_info().string,"adapter":RenderingServer.get_video_adapter_name(),"vendor":RenderingServer.get_video_adapter_vendor(),"method":RenderingServer.get_current_rendering_method(),"display":DisplayServer.get_name(),"resolution":str(root.size),"cap":Engine.max_fps,"low_processor":OS.low_processor_usage_mode,"galaxy_assignment":galaxy_assignment,"galaxy_work":galaxy_work,"galaxy_initial":galaxy_initial}))
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
  meter.times.clear();meter.enabled=true
  var switch_started=Time.get_ticks_usec()
  scene.select_system(page)
  if page==8 and OS.get_environment("PERF_GALAXY_STEADY")=="1":
   # Settle presentation-only departure staggering; never advance gameplay.
   scene.galaxy_panel.map.visual_clock+=60.0
  var switch_cpu_us=Time.get_ticks_usec()-switch_started
  await process_frame
  var switch_frame_us=Time.get_ticks_usec()-switch_started
  meter.enabled=false
  var switch_timings=meter.times.duplicate(true)
  meter.times.clear();meter.enabled=true
  var preparation_stages:Array=[]
  var preparation_frames:Array=[]
  var preparation_time_before:float=g.production_time()
  var preparation_started:=Time.get_ticks_usec()
  var shell_visible:bool=page_preparing(scene,page)
  if page in [6,8]:
   while page_preparing(scene,page) and preparation_frames.size()<600:
    preparation_stages.append(scene.galaxy_panel.map.prepare_stage if page==8 else 0)
    var began:=Time.get_ticks_usec()
    if not realtime:scene._process(1.0/60.0)
    await process_frame
    preparation_frames.append(Time.get_ticks_usec()-began)
   page_check(not page_preparing(scene,page),"Selected page reaches ready through bounded view preparation")
  var preparation_timings=meter.times.duplicate(true);meter.enabled=false
  var preparation_us:=Time.get_ticks_usec()-preparation_started
  var preparation_game_seconds:float=g.production_time()-preparation_time_before
  var frames=[];var cpu=[];var calls=[];var primitives=[];var projectiles=[];var queue=[];var live_enemies=[]
  var memory=0;var nodes=0;var resources=0
  var galaxy_before:Dictionary={};var settlement_samples:Array=[];var native_frames:=0
  meter.enabled=false;meter.times.clear()
  var count=int(OS.get_environment("PERF_FRAMES")) if not OS.get_environment("PERF_FRAMES").is_empty() else 60
  for i in range(count+15):
   if i==15:
    galaxy_before=galaxy_progress(g)
    meter.enabled=true;memory=OS.get_static_memory_usage();nodes=get_node_count();resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
   var settlements_before:=galaxy_settlements
   var effects_before:int=g.galaxy.effect_generation if owned else 0
   var building_before:int=g.galaxy.regions.galaxy_1.building_revision if owned else 0
   var combat_before:Variant=g.galaxy.get("combat_generation") if owned else null
   var start=Time.get_ticks_usec()
   if OS.get_environment("PERF_RICH")=="1":
    if owned:g.economy.credit_many({"1":balance*1e-10,"2":balance*1e-10})
    else:g.profile.resources["1"]+=balance*1e-10;g.profile.resources["2"]+=balance*1e-10
   if not realtime:scene._process(1.0/60.0)
   var elapsed=Time.get_ticks_usec()-start
   await process_frame
   if i>=15:
    var frame_us:int=Time.get_ticks_usec()-start
    var cpu_us:int=scene.last_process_us if realtime else elapsed
    frames.append(frame_us);cpu.append(cpu_us)
    native_frames+=int(g.native_execution!=null)
    if galaxy_settlements>settlements_before:settlement_samples.append({"frame":i-15,"cpu_us":cpu_us,"frame_us":frame_us,"commits":galaxy_settlements-settlements_before,"building_changed":owned and g.galaxy.regions.galaxy_1.building_revision!=building_before,"effects_changed":owned and g.galaxy.effect_generation!=effects_before,"combat_changed":combat_before!=null and g.galaxy.get("combat_generation")!=combat_before})
    calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
    primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
    projectiles.append(g.projectiles.size());queue.append(g.missile_queue.size());live_enemies.append(g.enemies.size())
  meter.enabled=false
  var viewport_rows=[];views(root,viewport_rows)
  var row={"preparation_stages":preparation_stages,"preparation_timings":preparation_timings,"loading_shell_visible":shell_visible,"preparation_us":preparation_us,"preparation_frames_us":preparation_frames,"preparation_game_seconds":preparation_game_seconds,"galaxy_before":galaxy_before,"galaxy_after":galaxy_progress(g),"settlement_samples":settlement_samples,"native_frames":native_frames,"page":page,"scenario":scenario_index,"native":g.native_execution!=null,"owned_domains":owned,"enemies":enemy_count,"reactor_level":reactor_level,"allocation_command_us":allocation_command_us,"switch_cpu_us":switch_cpu_us,"switch_timings":switch_timings,"switch_frame_us":switch_frame_us,"frames_us":stats(frames),"main_us":stats(cpu),"calls":stats(calls),"primitives":stats(primitives),"projectiles":stats(projectiles),"missile_queue":stats(queue),"live_enemies":stats(live_enemies),"memory":OS.get_static_memory_usage(),"memory_delta":OS.get_static_memory_usage()-memory,"node_delta":get_node_count()-nodes,"resources_delta":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)-resources,"timings":meter.times.duplicate(true),"views":viewport_rows}
  results.append(row);print("ROW ",JSON.stringify(row))
  if OS.get_environment("PERF_CAPTURE")=="1" and DisplayServer.get_name()!="headless":
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("res://.runtime/page-%d.png" % page)
 FileAccess.open("res://.runtime/whole-perf.json",FileAccess.WRITE).store_string(JSON.stringify(results," "))
 if galaxy_work=="active":
  var galaxy_final=galaxy_progress(g)
  page_check(galaxy_final.crew_count==1 and galaxy_final.upgrade_work>galaxy_initial.upgrade_work and galaxy_settlements>0,"Assigned galaxy advances real work and commits through the external clock")
  page_check(galaxy_final.level_total>galaxy_initial.level_total,"Production upgrade boundaries actually complete during the measured run")
  print("CHECKS ",JSON.stringify(page_checks))
 if OS.get_environment("PERF_CHECK_PAGES")=="1":await check_pages(scene)
 scene.set_process(false)
 if scene.battle_slice_runtime!=null:scene.battle_slice_runtime.close();scene.battle_slice_runtime=null
 if g.native_execution!=null:g.native_execution.cancel(g);g.native_execution=null
 scene.game.launch_provider=Callable();scene.game.target_provider=Callable()
 scene.queue_free();await process_frame;await process_frame
 Engine.remove_meta("saved_perf")
 quit(1 if page_checks.any(func(item):return not item.ok) else 0)

func page_check(ok:bool,label:String)->void:
 page_checks.append({"ok":ok,"label":label})
 if not ok:printerr("PAGE CHECK FAILED: ",label)
func check_pages(scene)->void:
 # Run only after the timed frames; mutations here never enter comparisons.
 var g=scene.game
 g.paused=true
 scene.select_system(6)
 var panel=scene.planet_panel
 page_check(panel.cards.size()==6 and panel.cards.values().filter(func(card):return card.has("visual")).size()==1,"Only the visited planet owns detail controls; all six navigation entries exist")
 var planets=g.planets.save_data();var crew=g.crew.save_data()
 panel._append_log("2","C18 pending event")
 var identities:Dictionary={}
 for id in panel.cards:
  panel.cards[id].list_button.pressed.emit()
  await process_frame
  var card:Dictionary=panel.cards[id]
  page_check(panel.selected_planet_id==id and card.visual.planet_id==id and card.stage.is_visible_in_tree(),"Planet "+id+" real selection signal builds its current content")
  page_check(panel.cards.values().filter(func(item):return item.has("stage") and item.stage.is_visible_in_tree()).size()==1,"Planet "+id+" has exactly one visible stage")
  if id=="2":page_check(card.log_label.text.contains("C18 pending event"),"Unvisited planet retains pending presentation events")
  identities[id]=card.stage.get_instance_id()
 scene.select_system(0);scene.select_system(6)
 for id in panel.cards:
  panel.cards[id].list_button.pressed.emit()
  page_check(panel.cards[id].stage.get_instance_id()==identities[id],"Planet "+id+" reuses visited controls")
 page_check(g.planets.save_data()==planets and g.crew.save_data()==crew,"Page construction and switching leave owned planet/crew state unchanged")
 scene.select_system(8)
 var map=scene.galaxy_panel.map
 var complete=g.galaxy.regions.galaxy_1
 var fresh=preload("res://scripts/galaxy_region.gd").new()
 fresh.setup(complete.row,complete.builds,complete.chunk_size)
 for region in [complete,fresh]:
  var key:String="complete" if region==complete else "fresh"
  map.select(region)
  var bytes:PackedByteArray=map.fog_image.get_data();var equal:bool=bytes.size()==region.cells.size()
  for index in bytes.size():
   if bytes[index]!=(255 if region.cells[index]!=0 else 0):equal=false;break
  page_check(equal,"Galaxy "+key+" full R8 mask equals its authoritative cells")
  var builds:int=map.city.rebuild_count
  map.refresh();map.sync_visibility()
  page_check(map.city.rebuild_count==builds,"Galaxy "+key+" stable refresh preserves static geometry")
 scene.select_system(0)
 var equipment=scene.equipment_panel
 var wallet:Dictionary=g.economy.save_data()
 wallet.resources={"1":0.0,"2":0.0}
 page_check(g.economy.install_snapshot(wallet),"Zero-budget fixture installs through economy")
 equipment.refresh_pending()
 page_check(equipment.items.values().all(func(item):return not item.upgradeable and not item.direct_upgradeable),"Cards immediately disable purchases after budget depletion")
 equipment.status_filter=2;equipment.apply_filters()
 page_check(not equipment.cards.weapons_0.visible,"Affordable-only filter hides a depleted module")
 var quote:Dictionary=g.slot_upgrade_cost("weapons",0,1)
 for id in quote:
  if wallet.resources.has(str(id)):wallet.resources[str(id)]=quote[id]
  else:wallet.materials[str(id)]=quote[id]
 page_check(g.economy.install_snapshot(wallet),"Exact one-level budget installs")
 equipment.set_upgrade_amount(10)
 page_check(equipment.cards.weapons_0.visible and equipment.items.weapons_0.upgradeable and not equipment.items.weapons_0.direct_upgradeable,"Amount action resamples resource filters before the next frame")
 equipment.set_upgrade_amount(1);equipment.refresh_pending()
 page_check(equipment.items.weapons_0.upgradeable and equipment.items.weapons_0.direct_upgradeable,"One-level affordability matches the domain quote")
 equipment.set_upgrade_amount(10)
 page_check(equipment.items.weapons_0.upgradeable and not equipment.items.weapons_0.direct_upgradeable,"Ten-level button and one-level filter retain distinct affordability")
 equipment.set_upgrade_amount(0)
 page_check(equipment.items.weapons_0.direct_upgradeable and g.max_upgrade_amount_slot("weapons",0)==1,"MAX uses the same exact budget and domain count")
 var level:int=g.slot_entry("weapons",0).level
 equipment.cards.weapons_0.upgrade_button.pressed.emit()
 page_check(g.slot_entry("weapons",0).level==level+1,"Actual card signal purchases its quoted MAX level")
 print("CHECKS ",JSON.stringify(page_checks))

func galaxy_progress(g)->Dictionary:
 if g.get("equipment")==null:return {}
 var region=g.galaxy.regions.galaxy_1
 var work:float=0.0;var levels:=0
 for slot in region.slots:work+=float(slot.upgrade_progress);levels+=int(slot.level)
 var member:Dictionary={}
 for candidate in (g.crew.members() if g.get("equipment")!=null else g.profile.crew):
  if candidate.crewId=="navigator":member={"id":candidate.crewId,"assignment":candidate.assignmentType,"target":candidate.targetId}
 return {"status":region.state.status,"crew":member,"crew_count":g.galaxy.crew_count(g,"galaxy_1"),"upgrade_work":region.state.upgrade_work,"active_upgrade_work":work,"level_total":levels,"building_revision":region.building_revision,"effect_generation":g.galaxy.effect_generation,"settlements":galaxy_settlements,"income_events":galaxy_income_events,"game_time":g.production_time()}

func page_preparing(scene,page:int)->bool:
 if page==8:return scene.galaxy_panel.map.get("preparing")==true
 if page==6:
  for card in scene.planet_panel.cards.values():
   if card.icon.get("preparing")==true or (card.has("visual") and card.visual.get("preparing")==true):return true
 return false
