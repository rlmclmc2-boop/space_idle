extends "res://qa_galaxy_residence.gd"
## Reuse the frozen UI/fixture instrumentation in evidence/galaxy-boundary-20261014.
const Gate=preload("res://strip_gate.gd")
var system_events:Dictionary={}
var admissions:=0
var seen_native_id:=0
func record_event(kind:String,_info:Dictionary)->void:
 system_events[kind]=int(system_events.get(kind,0))+1
func tree_fingerprint(node:Node,rows:Array)->void:
 if node is Node3D:rows.append([str(node.get_path()),str(node.transform),node.visible])
 elif node is Node2D:rows.append([str(node.get_path()),str(node.transform),node.visible])
 for child in node.get_children():tree_fingerprint(child,rows)
func clear_commands(node:Node)->void:
 if node is CanvasItem:RenderingServer.canvas_item_clear(node.get_canvas_item());node.queue_redraw()
 for child in node.get_children():clear_commands(child)
func scalar_copy(value):
 if value is RandomNumberGenerator:return {"class":"RandomNumberGenerator","state":str(value.state),"seed":str(value.seed)}
 if value is Object:return {"class":value.get_class()}
 if value is Dictionary:
  var out:Dictionary={}
  for key in value:out[key]=scalar_copy(value[key])
  return out
 if value is Array:
  var out:Array=[]
  for item in value:out.append(scalar_copy(item))
  return out
 return value
func state_digest(g)->Dictionary:
 var kernel:Dictionary=g.native_execution.kernel.export_handoff() if g.native_execution!=null else {}
 # Export carries mutable display views and live RNG/lease objects. Keep typed
 # motion/queues/defence/attack state; replace redundant flight display views
 # with identity/target fields, and serialize actual RNG state instead of IDs.
 for flight in kernel.get("flights",[]):
  var view:Dictionary=flight.view
  flight.view={"serial":view.get("serial"),"target_uid":view.get("target",{}).get("uid",-1),"source_uid":view.get("source",{}).get("uid",-1),"primary_uid":view.get("primary_target",{}).get("uid",-1)}
 var canonical=scalar_copy(kernel)
 var enemies:Array=[]
 for e in g.enemies:enemies.append([e.get("uid"),e.get("hp"),e.get("shield"),e.get("x"),e.get("y")])
 return {"kernel_hash":JSON.stringify(canonical).sha256_text(),"kernel_rng":str(g.native_execution.kernel.rng_source().state) if g.native_execution!=null else "","game_rng":str(g.rng.state),"clock":g.production_time(),"player":g.player.duplicate(true),"enemies":enemies,"resources":g.profile.resources.duplicate(true),"loadout":g.profile.loadout.duplicate(true),"drops":g.drops.size(),"projectiles":g.projectiles.size(),"state":g.state,"stage":g.stage,"group":g.group_index,"canonical_kernel":canonical}
func cpu_handshake(label:String,phase:String)->int:
 var began:=Time.get_ticks_usec()
 print("CPU_MARK ",label," ",phase)
 var path:="res://.runtime/cpu-ack-"+label+"-"+phase
 while not FileAccess.file_exists(path):
  assert(Time.get_ticks_usec()-began<5000000,"CPU sampler did not acknowledge")
  OS.delay_msec(1)
 return Time.get_ticks_usec()-began
func run()->void:
 var scene=load("res://main.tscn").instantiate();scene.set_script(UI)
 scene.automation_args=["--capture"];scene.music_on=false
 root.add_child(scene);current_scene=scene;scene.automation_args=[];scene.set_process(false)
 var g=scene.game;g.save_enabled=false;g.speed=1;g.rng.seed=1701
 if OS.get_environment("GPU_CONTACT_CASE")=="CPU":
  g.combat_presentation.configure_contact_gpu([],RID(),null);scene.pulse_layer.material=null
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

 var label:=OS.get_environment("STRIP_CASE")
 var mode:=int(OS.get_environment("STRIP_MODE"))
 var profile:=OS.get_environment("STRIP_PROFILE")=="1"
 Engine.max_fps=0
 DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 OS.low_processor_usage_mode=false
 assert(Engine.physics_ticks_per_second==60 and Engine.time_scale==1.0)
 assert(Engine.max_fps==0 and DisplayServer.window_get_vsync_mode()==DisplayServer.VSYNC_DISABLED)
 Gate.steps=0;Gate.limit=180;Gate.mode=0;Gate.sampled=false
 scene.set_process(true)
 while Gate.steps<Gate.limit:await RenderingServer.frame_post_draw
 scene.set_process(false)
 var before=snapshot(scene);var state_before=state_digest(g);var initial_ticks:int=g.native_execution.ticks
 Gate.mode=mode
 if mode>=1:
  # Leave visible booleans/logic predicates unchanged; stop all battle rendering.
  scene.ship_view.modulate.a=0.0
  scene.ship_view.viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
  for item in [scene.battle_layer,scene.stars_layer,scene.drop_layer,scene.battle_hud_layer,scene.pulse_layer,scene.retained_contacts]:clear_commands(item)
 # Settle the one-time diagnostic transition outside measured intervals.
 await RenderingServer.frame_post_draw
 var nodes_before:Array=[];tree_fingerprint(scene.ship_view,nodes_before);tree_fingerprint(scene.retained_contacts,nodes_before)
 g.event.connect(record_event);system_events.clear()
 Gate.steps=0;Gate.limit=480;Gate.counts.clear();Gate.spans.clear();Gate.sampled=true;Gate.profiling=profile
 var frames:Array=[];var samples:Array=[];var phases:Array=[]
 var cpu_begin_wait:=cpu_handshake(label,"begin")
 var sampling_us:=0
 var begin:=Time.get_ticks_usec();var previous:=begin
 scene.set_process(true)
 while Gate.steps<Gate.limit:
  await RenderingServer.frame_post_draw
  var now:=Time.get_ticks_usec();var sample_start:=now;frames.append(now-previous)
  assert(Engine.max_fps==0 and DisplayServer.window_get_vsync_mode()==DisplayServer.VSYNC_DISABLED,"limiter restored")
  if mode>=1:assert(scene.ship_view.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,"submission remains disabled")
  if profile:
   phases.append({"start":previous,"end":now,"signal":process_signal_us,"main_start":scene.process_begin_us,"main_end":scene.process_end_us,"pre_draw":pre_draw_us,"spans":Gate.spans})
   Gate.spans=[]
  samples.append({"step":Gate.steps,"game":g.production_time(),"native":g.native_execution!=null,"projectiles":g.projectiles.size(),"floats":scene.floats.size(),"drops":g.drops.size(),"render":render_times(scene)})
  previous=now
  sampling_us+=Time.get_ticks_usec()-sample_start
 scene.set_process(false);Gate.sampled=false
 var cpu_end_wait:=cpu_handshake(label,"end")
 var nodes_after:Array=[];tree_fingerprint(scene.ship_view,nodes_after);tree_fingerprint(scene.retained_contacts,nodes_after)
 for key in Gate.counts:
  if mode>=1:assert(not str(key).begins_with("executed:draw."),"draw body executed despite stripping")
  if mode>=2:assert(not str(key).begins_with("executed:node."),"node body executed despite stripping")
 if mode>=2:assert(nodes_before==nodes_after,"battle node transforms/visibility changed")
 assert(int(Gate.counts.get("logic.tick",0))==480)
 assert(int(Gate.counts.get("kept.simulation_geometry_authority.gd.before_tick",0))==480)
 assert(int(Gate.counts.get("kept.native_execution_session.gd.prepare_geometry",0))==480)
 assert(int(Gate.counts.get("kept.native_execution_session.gd.consume_feedback",0))==480)
 var contact_metrics:Dictionary=g.combat_presentation.contact_gpu_metrics()
 assert(contact_metrics.enabled==(OS.get_environment("GPU_CONTACT_CASE")!="CPU"))
 var row={"contact_gpu":contact_metrics,"uncapped":true,"sampling_us":sampling_us,"cpu_begin_handshake_us":cpu_begin_wait,"cpu_end_handshake_us":cpu_end_wait,"low_processor_mode":OS.low_processor_usage_mode,"physics_ticks_per_second":Engine.physics_ticks_per_second,"label":label,"mode":mode,"profile":profile,"source":"346c67f8","dll_sha256":FileAccess.get_sha256("res://bin/space_native.dll"),"config":config(scene),"accessibility":ProjectSettings.get_setting("accessibility/general/accessibility_support"),"frames_us":frames,"samples":samples,"phases":phases,"before":before,"after":snapshot(scene),"state_before":state_before,"state_after":state_digest(g),"steps":Gate.steps,"native_steps":g.native_execution.ticks-initial_ticks,"events":system_events,"counts":Gate.counts,"wall_seconds":(previous-begin)/1000000.0,"game_seconds":g.production_time()-float(before.game),"node_fingerprint_equal":nodes_before==nodes_after,"node_count":nodes_before.size(),"damage_history_count":scene.damage_history_records.size()}
 FileAccess.open("res://.runtime/strip-"+label+".json",FileAccess.WRITE).store_string(JSON.stringify(row))
 root.get_texture().get_image().save_png("res://.runtime/strip-"+label+".png")
 print("STRIP_RESULT ",label," frames=",frames.size()," wall=",row.wall_seconds," steps=",Gate.steps," native=",row.native_steps)
 stress.finish(g);g.begin_retreat();scene.queue_free();await process_frame;await process_frame;quit()
