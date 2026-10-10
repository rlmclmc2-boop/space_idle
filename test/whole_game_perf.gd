extends SceneTree
# Use whole_game_perf.py: synthetic fixtures, copied project and isolated player data.
# Fixed-step wall times include rendering; headless wall times are not FPS.
class UI extends "res://scripts/battlefield.gd":
 func create_battle_game(_persist:bool)->BattleGame:return super.create_battle_game(false)
 func show_qa_tools()->void:pass
 func show_chrono_login_report()->void:pass
 var window_events_enabled := false
 var window_event_labels: Array=[]
 var frame_launches := 0
 var frame_enemy_launches := 0
 func weapon_launch(shot:Dictionary,spread:=0.0)->void:
  frame_launches+=1
  if bool(shot.hostile):frame_enemy_launches+=1
  super.weapon_launch(shot,spread)
 func on_event(kind:String,info:Dictionary)->void:
  if window_events_enabled and kind in ["state","wave_clear","level_clear","planet_changed","hyperspace_settled","crew_changed","hightech_changed","save_success","reactor_changed","unlocks_changed","jewels_changed","tutorial_changed"] and not window_event_labels.has(kind):window_event_labels.append(kind)
  var inspect=OS.get_environment("PERF_CPU_PEAKS")=="1"
  if inspect:
   Engine.get_meta("saved_perf").target_seen.clear()
   Engine.get_meta("saved_perf").steering_seen.clear()
   Engine.get_meta("saved_perf").steering_active=false
  super.on_event(kind,info)
  if inspect:
   Engine.get_meta("saved_perf").target_seen.clear()
   Engine.get_meta("saved_perf").steering_seen.clear()
   Engine.get_meta("saved_perf").steering_active=false
 var retention_previous := {}
 var retention_counts := {"contacts":0,"same_width":0,"same_protection":0,"same_mount_shape":0}
 func draw_enemy_hull_and_status(enemy:Dictionary,offset:Vector2,boss:bool)->void:
  if OS.get_environment("PERF_RETENTION_PROFILE")=="1" and Engine.get_meta("saved_perf").enabled:
   var width=enemy_render_width(enemy)
   var state=enemy_recognition.state(enemy,game.enemy_shield_time,game.paused,enemy_pose(enemy))
   var uid=int(enemy.uid)
   var current=[width,JSON.stringify(state),JSON.stringify(enemy.equipment)]
   if retention_previous.has(uid):
    var previous=retention_previous[uid]
    if current[0]==previous[0]:retention_counts.same_width+=1
    if current[0]==previous[0] and current[1]==previous[1]:retention_counts.same_protection+=1
    if current[0]==previous[0] and current[2]==previous[2]:retention_counts.same_mount_shape+=1
   retention_previous[uid]=current
   retention_counts.contacts+=1
  super.draw_enemy_hull_and_status(enemy,offset,boss)
 var last_process_us := 0
 var last_draw_us := 0
 var logical_ticks := 0
 var process_callbacks := 0
 var process_delta_total := 0.0
 var last_process_delta := 0.0
 func before_logical_game_tick(dt:float)->void:
  logical_ticks+=1
  super.before_logical_game_tick(dt)
 func _process(dt: float) -> void:
  process_callbacks+=1;process_delta_total+=dt;last_process_delta=dt
  var inspect_cards=OS.get_environment("PERF_CPU_PEAKS")=="1"
  var before={}
  if inspect_cards and is_instance_valid(equipment_panel):
   for id in equipment_panel.cards:before[id]=equipment_panel.cards[id].last_state.duplicate()
  var began := Time.get_ticks_usec()
  super._process(dt)
  if OS.get_environment("PERF_FREEZE_SHIP_BUFFER")=="1" and Engine.get_meta("saved_perf").enabled:
   ship_view.viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
  last_process_us = Time.get_ticks_usec()-began
  if inspect_cards and is_instance_valid(equipment_panel):
   var measure=Engine.get_meta("saved_perf")
   for id in equipment_panel.cards:
    var state=equipment_panel.cards[id].last_state
    var changed=[]
    if before.has(id) and before[id].size()==state.size():
     for index in state.size():
      if before[id][index]!=state[index]:changed.append(index)
    elif before.get(id,[])!=state:changed.append(-1)
    if not changed.is_empty():measure.card_changes.append([id,changed])
 func draw_battle()->void:
  var began=Time.get_ticks_usec()
  super.draw_battle()
  last_draw_us=Time.get_ticks_usec()-began
 func visual_muzzle(shot:Dictionary)->Vector2:
  var began=Time.get_ticks_usec()
  var point=super.visual_muzzle(shot)
  var measure=Engine.get_meta("saved_perf")
  if measure.enabled and OS.get_environment("PERF_CPU_PEAKS")=="1" and bool(shot.hostile):
   var serial=int(shot.get("serial",-1))
   var role="repeat" if measure.muzzle_seen.has(serial) else "first"
   measure.muzzle_seen[serial]=true
   measure.record("probe.enemy_muzzle_"+role,Time.get_ticks_usec()-began)
  return point
class Meter extends RefCounted:
 var enabled=false
 var times={}
 var frame_times={}
 var muzzle_seen={}
 var card_changes=[]
 var target_seen={}
 var steering_seen={}
 var steering_active=false
 func record(key,us):
  if not enabled:return
  if not times.has(key):times[key]=[0,0,0]
  times[key][0]+=1;times[key][1]+=us;times[key][2]=max(times[key][2],us)
  if OS.get_environment("PERF_CPU_PEAKS")=="1":
   if not frame_times.has(key):frame_times[key]=[0,0]
   frame_times[key][0]+=1;frame_times[key][1]+=us
var meter=Meter.new()
var results=[]
func _initialize():
 Engine.set_meta("saved_perf",meter)
 call_deferred("run")
func stats(a):
 a=a.duplicate();a.sort();var sum=0.0
 for x in a:sum+=x
 return {"mean":sum/a.size(),"p50":a[a.size()/2],"p95":a[int(a.size()*.95)],"p99":a[int(a.size()*.99)],"max":a[-1]}
func views(node,rows):
 if node is SubViewport:rows.append({"path":str(node.get_path()),"size":str(node.size),"mode":node.render_target_update_mode,"calls":node.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)})
 for c in node.get_children():views(c,rows)
func measured_views(node,rows):
 if node is Viewport:
  RenderingServer.viewport_set_measure_render_time(node.get_viewport_rid(),true)
  rows.append(node)
 for child in node.get_children():measured_views(child,rows)
func ship_inventory(scene):
 var view=scene.ship_view
 var bodies=[]
 for record in view.body_baker.records.values():
  bodies.append({"request":record.request,"active":record.active,"visible":record.root.is_visible_in_tree(),"asset_ready":view.body_baker.textures.has(record.key) and view.body_baker.textures[record.key].ready,"source_meshes":record.parts.size()})
 var geometry=0
 for node in view.world.find_children("*","GeometryInstance3D",true,false):
  if node.is_visible_in_tree():geometry+=1
 return {"battle_visible":scene.battle_layer.is_visible_in_tree(),"ship_visible":view.is_visible_in_tree(),"ship_render_scale":view.viewport.scaling_3d_scale,"ship_msaa":view.viewport.msaa_3d,"live_shadows":view.world.get_node("KeyLight").shadow_enabled,"body_roots":view.body_baker.body_roots.size(),"bodies":bodies,"visible_geometry":geometry,"flat_enabled":view.flat_compositor.enabled,"flat_active":view.flat_compositor.active,"flat_reason":view.flat_compositor.fallback_reason,"flat_items":view.flat_compositor.items.size(),"flat_textures":view.flat_compositor.textures.size()}
func cache_enemy_bitmap(scene)->Dictionary:
 var began=Time.get_ticks_usec()
 var group=scene.retained_contacts
 var transform:Transform2D=root.get_stretch_transform()*scene.battle_layer.get_global_transform_with_canvas()
 var scale_value:Vector2=transform.get_scale()
 var fraction:Vector2=transform.origin-transform.origin.floor()
 var view=SubViewport.new();view.name="FrozenEnemyBitmap"
 view.size=Vector2i((scene.BATTLE_VIEW_SIZE*scale_value+fraction).ceil())+Vector2i.ONE
 view.transparent_bg=true;view.render_target_update_mode=SubViewport.UPDATE_ONCE
 group.add_child(view)
 var canvas=Node2D.new();canvas.transform=Transform2D(transform.x,transform.y,fraction)
 view.add_child(canvas)
 for record in group.records.values():record.root.reparent(canvas,false)
 await process_frame;await RenderingServer.frame_post_draw
 view.render_target_update_mode=SubViewport.UPDATE_DISABLED
 var sprite=Node2D.new();sprite.name="FrozenEnemyComposite"
 sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
 var material=ShaderMaterial.new();var shader=Shader.new()
 shader.code="shader_type canvas_item; render_mode unshaded, blend_premul_alpha;"
 material.shader=shader;sprite.material=material
 group.add_child(sprite);group.move_child(sprite,0)
 var texture=view.get_texture()
 var rect=Rect2(-fraction/scale_value,Vector2(view.size)/scale_value)
 sprite.draw.connect(func():sprite.draw_texture_rect(texture,rect,false))
 sprite.queue_redraw()
 await process_frame;await RenderingServer.frame_post_draw
 return {"setup_wall_us":Time.get_ticks_usec()-began,"viewport":view,"sprite":sprite,"start":image_digest(texture),"used_rect":str(texture.get_image().get_used_rect()),"size":str(view.size)}
func image_digest(texture:Texture2D)->String:
 var context=HashingContext.new();context.start(HashingContext.HASH_SHA256)
 context.update(texture.get_image().get_data())
 return context.finish().hex_encode()
func contact_part_builds(scene)->Dictionary:
 var counts={};var contacts=scene.get("retained_contacts")
 if not is_instance_valid(contacts):return counts
 for record in contacts.records.values():
  var pending=record.root.get_children()
  while not pending.is_empty():
   var child=pending.pop_back()
   if child.get_script()!=null:
    counts[child.kind]=counts.get(child.kind,0)+child.builds
   pending.append_array(child.get_children())
 return counts
func run():
 var native_profile=OS.get_environment("PERF_NATIVE_SCRIPT_PROFILE")=="1"
 if native_profile:
  print("NATIVE_PROFILE_AVAILABLE ",JSON.stringify({"active":EngineDebugger.is_active(),"has_scripts":EngineDebugger.has_profiler("scripts"),"profiling":EngineDebugger.is_profiling("scripts")}))
  if not EngineDebugger.has_profiler("scripts"):push_error("Native scripts profiler unavailable");quit(1);return
  EngineDebugger.profiler_enable("scripts",false)

 Engine.max_fps=0
 DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 seed(1701)
 var scene=load("res://main.tscn").instantiate();scene.set_script(UI)
 scene.automation_args=["--capture"];scene.music_on=false
 scene.window_events_enabled=OS.get_environment("PERF_WINDOW_EVENTS")=="1"
 root.add_child(scene);current_scene=scene;scene.automation_args=[];scene.set_process(false)
 if OS.get_environment("PERF_RETAINED_CONTACTS")=="0":
  scene.retained_contacts_enabled=false;scene.retained_contacts.visible=false
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
  var weapon_keys=["laser","missile","cannon","longLaser","laser","missile","cannon","longLaser"]
  if OS.get_environment("PERF_MISSILE_LOADOUT")=="1":weapon_keys=["missile","missile","missile","missile","missile","missile","missile","missile"]
  for key in weapon_keys:g.profile.loadout.weapons.append({"key":key,"level":150})
  for key in ["shield","armour","shield","armour"]:g.profile.loadout.defence.append({"key":key,"level":150})
  for crew in g.profile.crew:crew.level=103;crew.exp=13159583000.0
  for key in g.db.data.hightech:g.profile.hightechLevels[key]=303
  g.planet_buildings.sync(g,"1")
  for item in g.profile.planets["1"].buildings.values():item.status="built"
  var authored_stage=int(OS.get_environment("PERF_AUTHORED_STAGE"))
  if authored_stage>0:g.stage=authored_stage;g.group_index=0
  g.invalidate_stat_cache();g.reset_player();g.state=BattleGame.State.COMBAT;g.spawn_group()
  if authored_stage>0:
   for enemy in g.enemies:enemy.hp=1e100;enemy.max_hp=1e100
  else:
   var template=g.enemies[0].duplicate(true);g.enemies.clear()
   var stress_count=int(OS.get_environment("PERF_STRESS_ENEMIES")) if OS.has_environment("PERF_STRESS_ENEMIES") else 3
   for i in stress_count:
    var enemy=template.duplicate(true);enemy.uid=100+i;enemy.slot=i;enemy.x=80+80*(i%5);enemy.y=150+80*(i/5);enemy.hp=1e100;enemy.max_hp=1e100
    g.enemies.append(enemy)
 g.invalidate_stat_cache()
 scene.refresh_structure();scene.refresh_tab_visibility()
 print("ENV ",JSON.stringify({"engine":Engine.get_version_info().string,"adapter":RenderingServer.get_video_adapter_name(),"vendor":RenderingServer.get_video_adapter_vendor(),"method":RenderingServer.get_current_rendering_method(),"display":DisplayServer.get_name(),"resolution":str(root.size),"cap":Engine.max_fps,"low_processor":OS.low_processor_usage_mode}))
 var submission_mode=OS.get_environment("PERF_SUBMISSION_MODE")
 if submission_mode.is_empty():submission_mode="full"
 var realtime=OS.get_environment("PERF_REALTIME")=="1"
 var initial_combat_sha=JSON.stringify({"enemies":g.enemies,"projectiles":g.projectiles,"player":g.player,"rng":str(g.rng.state)}).sha256_text()
 scene.set_process(realtime)
 var scenarios=[0,4,1,2,6,8]
 if not OS.get_environment("PERF_PAGES").is_empty():
  scenarios=[]
  for value in OS.get_environment("PERF_PAGES").split(","):scenarios.append(int(value))
 if OS.get_environment("PERF_MAX")=="1":
  scenarios=[0]
  scene.equipment_panel.set_upgrade_amount(0)
 var scenario_index=-1
 var render_inventory=OS.get_environment("PERF_RENDER_INVENTORY")=="1"
 var render_cost=OS.get_environment("PERF_RENDER_COST")=="1"
 var cost_views=[]
 if render_cost:measured_views(root,cost_views)
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
  if submission_mode in ["no-submit","no-presentation"]:RenderingServer.set_render_loop_enabled(false)
  if submission_mode=="no-presentation":scene.hide()
  elif submission_mode=="empty":root.remove_child(scene)
  var frames=[];var cpu=[];var calls=[];var primitives=[];var projectiles=[];var queue=[]
  var frame_trace=[];var effect_trace=[];var alive=[];var states=[];var stages=[];var groups=[]
  var render_cost_trace=[]
  var sample_time_us=[]
  var slow_callback_trace=[];var memory_trace=[];var next_memory_us=0
  var cpu_peak_trace=[]
  var launch_trace=[]
  var presentation_trace=[]
  var card_change_trace=[]
  var memory=0;var nodes=0;var resources=0
  meter.enabled=false;meter.times.clear()
  var enemy_bitmap={}
  var ship_buffer_start=""
  var part_build_start={}
  var envelope_build_start=0
  var sampled_draw_start=0
  var sampled_clock_start=0.0
  var descriptor_start={}
  var tutorial_build_start={}
  var enhancement_plan_start={}
  var realtime_start=Time.get_ticks_usec()
  var wall_start=0;var wall_end=0;var logical_start=0;var callbacks_start=0;var delta_start=0.0
  var sample_started=false
  var logic_frame_trace=[];var cpu_no_tick=[];var cpu_one_tick=[];var cpu_multi_tick=[]
  var cpu_total_us=0.0
  var seconds=float(OS.get_environment("PERF_SECONDS"));var warm_seconds=float(OS.get_environment("PERF_WARMUP_SECONDS"))
  var count=int(OS.get_environment("PERF_FRAMES")) if not OS.get_environment("PERF_FRAMES").is_empty() else 60
  var warmup=int(OS.get_environment("PERF_WARMUP_FRAMES")) if not OS.get_environment("PERF_WARMUP_FRAMES").is_empty() else 15
  if realtime:count=20000;warmup=0
  for i in range(count+warmup):
   if realtime:
    if sample_started and Time.get_ticks_usec()-wall_start>=seconds*1000000.0:break
    if not sample_started:warmup=i if Time.get_ticks_usec()-realtime_start>=warm_seconds*1000000.0 else i+1
   if i==warmup:
    if native_profile:
     print("NATIVE_PROFILE_BEGIN ",JSON.stringify({"us":Time.get_ticks_usec(),"motion_clock":g.motion_clock,"logical_ticks":scene.logical_ticks,"render_index":i}))
     EngineDebugger.profiler_enable("scripts",true)
    sample_started=true;wall_start=Time.get_ticks_usec();logical_start=scene.logical_ticks;callbacks_start=scene.process_callbacks;delta_start=scene.process_delta_total
    if OS.get_environment("PERF_FREEZE_SHIP_BUFFER")=="1":ship_buffer_start=image_digest(scene.ship_view.viewport.get_texture())
    part_build_start=contact_part_builds(scene)
    envelope_build_start=scene.enemy_recognition.envelope_builds
    sampled_draw_start=Engine.get_frames_drawn();sampled_clock_start=g.motion_clock
    descriptor_start=combat_descriptor_counts(g)
    enhancement_plan_start=enhancement_plan_counts(g)
    tutorial_build_start={"eligibility":tutorial_projection_builds(scene,"builds"),"reads":tutorial_projection_builds(scene,"read_builds")}
    meter.enabled=true;memory=OS.get_static_memory_usage();nodes=get_node_count();resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
    if render_cost:
     cost_views.clear();measured_views(root,cost_views)
   scene.frame_launches=0;scene.frame_enemy_launches=0
   scene.window_event_labels.clear()
   meter.frame_times.clear()
   meter.muzzle_seen.clear()
   meter.card_changes.clear()
   var frame_logical_start=scene.logical_ticks
   var start=Time.get_ticks_usec()
   if OS.get_environment("PERF_RICH")=="1" and OS.get_environment("PERF_ORGANIC_ECONOMY")!="1":
    g.profile.resources["1"]*=1.0000000001;g.profile.resources["2"]*=1.0000000001
   if not realtime and submission_mode!="empty":scene._process(1.0/60.0)
   var elapsed=Time.get_ticks_usec()-start
   await process_frame
   if realtime:await RenderingServer.frame_post_draw
   if i>=warmup:
    frames.append(Time.get_ticks_usec()-start);cpu.append(scene.last_process_us if realtime else elapsed)
    wall_end=Time.get_ticks_usec()
    sample_time_us.append(wall_end-wall_start)
    if scene.window_events_enabled:
     if frames[-1]>16670:slow_callback_trace.append([i,sample_time_us[-1],frames[-1],cpu[-1],scene.last_draw_us,scene.window_event_labels.duplicate()])
     if sample_time_us[-1]>=next_memory_us:
      memory_trace.append([sample_time_us[-1],OS.get_static_memory_usage(),Performance.get_monitor(Performance.OBJECT_COUNT),get_node_count(),Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),g.projectiles.size(),g.missile_queue.size()])
      next_memory_us+=10000000

    var logical_delta=scene.logical_ticks-frame_logical_start
    logic_frame_trace.append([i,logical_delta,g.motion_clock,scene.last_process_delta])
    cpu_total_us+=cpu[-1]
    if logical_delta==0:cpu_no_tick.append(cpu[-1])
    elif logical_delta==1:cpu_one_tick.append(cpu[-1])
    else:cpu_multi_tick.append(cpu[-1])
    calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
    primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
    projectiles.append(g.projectiles.size());queue.append(g.missile_queue.size())
    var living=0
    for enemy in g.enemies:
     if float(enemy.get("hp",0))>0:living+=1
    alive.append(living);states.append(g.state);stages.append(g.stage);groups.append(g.group_index)
    frame_trace.append([i,frames[-1],cpu[-1],living,g.projectiles.size(),g.missile_queue.size()])
    launch_trace.append([i,scene.frame_launches,scene.frame_enemy_launches])
    if OS.get_environment("PERF_PRESENTATION_AUDIT")=="1":
     var card_states=[]
     for id in scene.equipment_panel.cards:
      var state=scene.equipment_panel.cards[id].last_state.duplicate()
      if state.size()>13 and state[13] is Resource:state[13]=state[13].resource_path
      card_states.append([id,state])
     presentation_trace.append([i,JSON.stringify([scene.enemy_impacts,scene.missile_events,scene.pulse_events,scene.rail_events,scene.projectile_visuals,card_states]).sha256_text()])
    effect_trace.append([i,scene.missile_events.size(),scene.pulse_events.size(),scene.particles.size(),scene.projectile_visuals.size()])
    if OS.get_environment("PERF_CPU_PEAKS")=="1":
     cpu_peak_trace.append([i,meter.frame_times.duplicate(true),g.speed,g.motion_clock])
     card_change_trace.append([i,meter.card_changes.duplicate(true)])
    if render_cost:
     var view_costs=[]
     for view in cost_views:
      if not is_instance_valid(view):continue
      var rid=view.get_viewport_rid()
      view_costs.append([str(view.get_path()),RenderingServer.viewport_get_measured_render_time_cpu(rid),RenderingServer.viewport_get_measured_render_time_gpu(rid)])
     render_cost_trace.append([i,Engine.get_frames_drawn(),RenderingServer.get_frame_setup_time_cpu(),Performance.get_monitor(Performance.TIME_PROCESS)*1000.0,scene.last_draw_us/1000.0,view_costs])
   if i==warmup and OS.get_environment("PERF_FREEZE_CONTACT_BITMAP")=="1":enemy_bitmap=await cache_enemy_bitmap(scene)
  if native_profile:
   print("NATIVE_PROFILE_STOP ",JSON.stringify({"us":Time.get_ticks_usec(),"motion_clock":g.motion_clock,"logical_ticks":scene.logical_ticks,"render_index":logic_frame_trace[-1][0] if not logic_frame_trace.is_empty() else -1}))
   EngineDebugger.profiler_enable("scripts",false)
   print("NATIVE_PROFILE_DONE ",Time.get_ticks_usec())
  meter.enabled=false
  var viewport_rows=[];views(root,viewport_rows)
  var row={"frame_trace":frame_trace,"combat_sha256":JSON.stringify({"enemies":g.enemies,"projectiles":g.projectiles,"player":g.player,"rng":str(g.rng.state)}).sha256_text(),"alive":stats(alive),"states":states,"stages":stages,"groups":groups,"rng_state":str(g.rng.state),"page":page,"scenario":scenario_index,"switch_cpu_us":switch_cpu_us,"switch_frame_us":switch_frame_us,"frames_us":stats(frames),"main_us":stats(cpu),"calls":stats(calls),"primitives":stats(primitives),"projectiles":stats(projectiles),"missile_queue":stats(queue),"memory":OS.get_static_memory_usage(),"memory_delta":OS.get_static_memory_usage()-memory,"node_delta":get_node_count()-nodes,"resources_delta":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)-resources,"timings":meter.times.duplicate(true),"views":viewport_rows}
  var wall_seconds=float(wall_end-wall_start)/1000000.0
  var game_seconds=g.motion_clock-sampled_clock_start
  var tick_count=scene.logical_ticks-logical_start
  row.clock_validation={"mode":"engine real delta / production fixed60Hz accumulator" if realtime else "fixed workload per submitted frame", "wall_seconds":wall_seconds,"game_seconds":game_seconds,"game_wall_ratio":game_seconds/wall_seconds,"logical_ticks":tick_count,"logic_hz":float(tick_count)/wall_seconds,"render_frames":frames.size(),"render_hz":float(frames.size())/wall_seconds,"process_callbacks":scene.process_callbacks-callbacks_start,"process_delta_seconds":scene.process_delta_total-delta_start,"game_time_remainder":scene.game_time_remainder,"valid":not realtime or (wall_seconds>=seconds and absf(game_seconds/wall_seconds-1.0)<0.03 and absf(float(tick_count)/wall_seconds-60.0)<2.0)}
  row.main_budget={"scope":"Root _process wall time only; excludes later _draw and other autonomous/native callbacks","total_us":cpu_total_us,"wall_percent":cpu_total_us/(wall_seconds*10000.0),"no_tick_frames":cpu_no_tick.size(),"one_tick_frames":cpu_one_tick.size(),"multi_tick_frames":cpu_multi_tick.size(),"no_tick_us":stats(cpu_no_tick) if not cpu_no_tick.is_empty() else {},"one_tick_us":stats(cpu_one_tick) if not cpu_one_tick.is_empty() else {},"multi_tick_us":stats(cpu_multi_tick) if not cpu_multi_tick.is_empty() else {}}
  row.sample_time_us=sample_time_us;row.slow_callback_trace=slow_callback_trace;row.memory_trace=memory_trace;row.window_events_capture=scene.window_events_enabled
  row.logic_frame_trace=logic_frame_trace;row.initial_combat_sha256=initial_combat_sha
  row.enhancement_plan_start=enhancement_plan_start;row.enhancement_plan_end=enhancement_plan_counts(g)
  row.tutorial_projection_start=tutorial_build_start;row.tutorial_projection_end={"eligibility":tutorial_projection_builds(scene,"builds"),"reads":tutorial_projection_builds(scene,"read_builds")}
  row.combat_descriptor_start=descriptor_start;row.combat_descriptor_end=combat_descriptor_counts(g)
  row.retention_counts=scene.retention_counts.duplicate()
  row.retained_part_builds=contact_part_builds(scene)
  row.envelope_builds_in_sample=scene.enemy_recognition.envelope_builds-envelope_build_start
  row.part_builds_in_sample={}
  for kind in row.retained_part_builds:row.part_builds_in_sample[kind]=row.retained_part_builds[kind]-part_build_start.get(kind,0)
  row.enemy_bitmap_setup_wall_us=enemy_bitmap.get("setup_wall_us",0)
  row.enemy_bitmap_frozen=not enemy_bitmap.is_empty()
  row.enemy_bitmap_used_rect=enemy_bitmap.get("used_rect","")
  row.enemy_bitmap_size=enemy_bitmap.get("size","")
  row.enemy_bitmap_start=enemy_bitmap.get("start","")
  row.enemy_bitmap_end=image_digest(enemy_bitmap.viewport.get_texture()) if not enemy_bitmap.is_empty() else ""
  row.ship_buffer_frozen=OS.get_environment("PERF_FREEZE_SHIP_BUFFER")=="1"
  row.ship_composite_visible=scene.ship_view.get_node("ShipComposite").visible
  row.ship_buffer_start=ship_buffer_start
  row.ship_buffer_end=image_digest(scene.ship_view.viewport.get_texture()) if row.ship_buffer_frozen else ""
  row.enemy_canvas_frozen=OS.get_environment("PERF_FREEZE_CONTACT_CANVAS")=="1"
  row.submission_mode=submission_mode
  row.frames_drawn_delta=Engine.get_frames_drawn()-sampled_draw_start
  row.motion_clock_start=sampled_clock_start
  row.motion_clock_end=g.motion_clock
  row.render_loop_enabled=RenderingServer.is_render_loop_enabled()
  row.vsync_mode=DisplayServer.window_get_vsync_mode()
  row.physics_us=Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000000.0
  if render_inventory:row.ship_inventory=ship_inventory(scene)
  row.effect_trace=effect_trace
  row.render_cost_trace=render_cost_trace
  row.cpu_peak_trace=cpu_peak_trace
  row.card_change_trace=card_change_trace
  row.launch_trace=launch_trace
  row.presentation_trace=presentation_trace
  row.render_cost_scope="milliseconds, native render CPU is wall time and may include stalls; GPU last available queries, never added to CPU frame wall time"
  row.missile_parameters={"row":g.db.equip("missile",150),"lifetime":g.MISSILE_LIFETIME,"ejection_gap":g.EJECTION_GAP,"loadout":g.profile.loadout.weapons}
  row.missile_parameters.effective_rows=[]
  for entry in g.profile.loadout.weapons:row.missile_parameters.effective_rows.append(g.player_weapon_row(entry))
  row.artificial_wealth_mutation=OS.get_environment("PERF_RICH")=="1" and OS.get_environment("PERF_ORGANIC_ECONOMY")!="1"
  row.canvas_materials={"battle":str(scene.battle_layer.material),"feedback":str(scene.pulse_layer.material)}
  results.append(row);print("ROW ",JSON.stringify(row))
  if OS.get_environment("PERF_CAPTURE")=="1" and DisplayServer.get_name()!="headless":
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("res://.runtime/page-%d.png" % page)
 FileAccess.open("res://.runtime/whole-perf.json",FileAccess.WRITE).store_string(JSON.stringify(results," "))
 RenderingServer.set_render_loop_enabled(true)
 scene.set_process(false)
 scene.game.launch_provider=Callable();scene.game.target_provider=Callable()
 scene.queue_free();await process_frame;await process_frame
 Engine.remove_meta("saved_perf")
 quit()

func combat_descriptor_counts(g)->Dictionary:
 var result={}
 for pair in [[g,"combat_source_builds"],[g.db,"combat_descriptor_builds"],[g.db,"combat_snapshot_builds"],[g.db.get_meta("prototype_enemy_source",g.db),"combat_enemy_builds"]]:
  if pair[0].get(pair[1])!=null:result[pair[1]]=pair[0].get(pair[1])
 return result

func tutorial_projection_builds(scene,field:String)->int:
 var projection=scene.get("tutorial_projection")
 return int(projection.get(field)) if projection!=null else -1

func enhancement_plan_counts(g)->Dictionary:
 var plan=g.get("enhancement_plan")
 return {"builds":int(plan.builds),"revision":int(plan.revision),"reconciliations":int(g.enhancement_branches.get("reconciliations"))} if plan!=null else {}
