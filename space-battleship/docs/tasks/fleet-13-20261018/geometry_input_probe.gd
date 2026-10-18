# Fixed-step native-input diagnostic derived from the existing port_perf driver.
# Headless: no GUI, FPS assertion or performance measurement.
extends SceneTree
## Single uncapped QA-only full-wall-frame acceptance; four disjoint wall spans.
## Copy this file and test/combat_stress_fixture.gd to an isolated project root;
## run it with the matching native DLL loaded and PERF_NATIVE=1. No player save.
class UI extends "res://scripts/battlefield.gd":
 func show_qa_tools()->void:pass
 func show_chrono_login_report()->void:pass
 func create_battle_game(_persist:bool)->BattleGame:
  var g=preload("res://scripts/presented_battle_game.gd").new(db,false)
  g.stat_cache_enabled=true;g.invalidate_stat_cache()
  assert(g.stat_cache_enabled and not g.save_enabled,"QA save false, production stat cache true")
  db=g.db;g.native_execution_auto=false
  g.launch_provider=_prototype_launch_pose;g.drone_launch_provider=_prototype_drone_launch_pose
  g.target_provider=_prototype_target_point;g.target_spatial_source=battle_read_model
  g.rail_geometry_provider=_rail_geometry;g.rail_target_point_provider=entity_render_position
  g.enable_compiled_combat_rules()
  return g
 var activity_rows:Array=[]
 func activity()->Dictionary:
  var row={"active_by_weapon":{},"beams":0,"links":0,"chain_hops":0,"prism_beams":0,"endless_beams":0}
  for shot in game.projectiles:
   if shot.get("hostile",false):continue
   var key=str(shot.get("key",""))
   row.active_by_weapon[key]=int(row.active_by_weapon.get(key,0))+1
   if shot.get("chain_hop",false):row.chain_hops+=1
   if shot.get("beam",false):
    row.beams+=1
    if shot.get("prism_tower",false):row.prism_beams+=1
    if shot.get("endless",false):row.endless_beams+=1
    for link in shot.get("attack_instance",{}).get("chain",{}).get("links",[]):
     if not link.get("broken",false):row.links+=1
  return row
 var straight_shots:Array=[]
 var impacted:Dictionary={}
 var verify_geometry:=false
 var verified_hits:=0
 var ballistic_hits:=0
 var ballistic_outside:=0
 var aim_mismatches:=0
 var aim_thefts:=0
 var locks:Dictionary={}
 var lock_changes:=0
 var invalid_escapes:=0
 var counted:Dictionary={}
 var fire_count:=0
 var hit_count:=0
 var purchase_trace:Array=[]
 var observed_frames:Array=[]
 var track_frames:=false
 var batch_start:=0
 var batch_residences:Array=[]
 var main_started_us:=0
 var main_finished_us:=0
 var active_frame:=0
 var legacy_started_steps:=0
 func before_logical_game_tick(dt:float)->void:
  super.before_logical_game_tick(dt)
  legacy_started_steps+=1
 func logical_step_count(in_tick:bool=false)->int:
  if battle_slice_runtime!=null:return battle_slice_runtime.logical_steps
  return legacy_started_steps-1 if in_tick else legacy_started_steps
 func watch(kind:String,info:Dictionary)->void:
  if kind=="fire":
   fire_count+=1
   if verify_geometry:
    var shot:Dictionary=info.shot
    if shot.has("fixed_screen_step"):straight_shots.append(shot)
    if battle_slice_runtime!=null and not bool(shot.get("hostile",false)):
     var mount=battle_slice_runtime.geometry.shot_mount(shot)
     if mount>=0:
      var pose=battle_slice_runtime.geometry.turret_pose(mount)
      var uid=int(pose.target.get("uid",-1))
      if not bool(shot.get("owns_primary_aim",true)) and locks.has(mount) and uid!=locks[mount]:aim_thefts+=1
      if locks.has(mount) and uid!=locks[mount]:lock_changes+=1
      if bool(shot.get("owns_primary_aim",false)) and uid!=int(shot.get("primary_target",shot.target).get("uid",-1)):aim_mismatches+=1
      locks[mount]=uid
  elif verify_geometry and kind=="projectile_impact" and info.shot.has("fixed_screen_step"):
   impacted[int(info.shot.serial)]=true;ballistic_hits+=1
   if verify_geometry:
    verified_hits+=1
    var geometry=battle_slice_runtime.geometry
    var shot:Dictionary=info.shot;var target:Dictionary=shot.target
    var packet:Dictionary=geometry.enemy_recognition_geometry(target,geometry.enemy_render_width(target))
    var polygon=PackedVector2Array();var center:Vector2=geometry.enemy_render_position(target)
    for vertex in packet.inner:polygon.append(center+Vector2(vertex).rotated(PI+geometry.enemy_render_angle(target)))
    var screen:Vector2=shot.fixed_screen_origin+shot.fixed_screen_step*(Vector2(info.pos)-Vector2(shot.launch_point)).dot(game.projectile_direction(shot))
    var near=false
    for i in polygon.size():
     if screen.distance_to(Geometry2D.get_closest_point_to_segment(screen,polygon[i],polygon[(i+1)%polygon.size()]))<1.0:near=true
    if not Geometry2D.is_point_in_polygon(screen,polygon) and not near:ballistic_outside+=1
  elif kind=="hit":hit_count+=1
  elif kind=="upgrades_completed":
   purchase_trace.append({"clock":game.production_time(),"steps":logical_step_count(true),"slots":info.slots.duplicate(),"frame":active_frame})
 func _process(delta:float)->void:
  main_started_us=Time.get_ticks_usec()
  active_frame+=1
  super._process(delta)
  if track_frames:observed_frames.append({"logic_steps":logical_step_count(),"clock":game.production_time(),"delta":delta,"projectiles":game.projectiles.size(),"floats":floats.size(),"pending":damage_pending.size(),"unfocused":background_unfocused,"window_focused":get_tree().root.has_focus(),"engine_max_fps":Engine.max_fps,"vsync":DisplayServer.window_get_vsync_mode(),"fires":fire_count,"hits":hit_count})
  # No per-frame projectile scan in the measurement observer.
  main_finished_us=Time.get_ticks_usec()
 func levels()->int:
  var total=0
  for entry in game.loadout_entries("weapons")+game.loadout_entries("defence"):total+=int(entry.level)
  return total
const Probe=preload("res://probe.gd")
const Counters=preload("res://counter_probe.gd")
var cold_state_exports:=0
var cold_counter_reads:=0
var sample_events:Dictionary={}
var equipment_events:Array=[]
var fires_by_weapon:Dictionary={}
var admitted:=false
var admission_reason:Dictionary={}
func count_event(kind:String,info:Dictionary)->void:
 if kind=="equipment_stats":
  equipment_events.append({"step":current_scene.battle_slice_runtime.logical_steps,"payload":info.duplicate(true),"incoming":current_scene.game.profile.enhancementHits,"attacks":current_scene.game.profile.enhancementAttacks})
 sample_events[kind]=int(sample_events.get(kind,0))+1
 if kind=="hit":
  var side="player_hits" if info.get("player",false) else "enemy_hits"
  sample_events[side]=int(sample_events.get(side,0))+1
 if kind=="beam_hit":
  var side="hostile_periods" if info.shot.hostile else "friendly_periods"
  sample_events[side]=int(sample_events.get(side,0))+1
 if not Probe.active:return
 if kind=="fire":
  var shot:Dictionary=info.get("shot",{})
  if not shot.get("hostile",false):
   var key=str(shot.get("key",""));fires_by_weapon[key]=int(fires_by_weapon.get(key,0))+1
   if shot.get("combat_context",{}).get("wild_missile",false):Probe.effect("wild_missile_fires")
 if kind=="beam_started":
  var shot:Dictionary=info.get("shot",{})
  if shot.get("prism_tower",false):Probe.effect("prism_main_beams_started")
  if shot.get("endless",false):Probe.effect("endless_main_beams_started")
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
 cold_state_exports+=1
 var kernel:Dictionary=g.native_execution.kernel.export_handoff() if g.native_execution!=null else {}
 # Export carries mutable display views and live RNG/lease objects. Keep typed
 # motion/queues/defence/attack state; replace redundant flight display views
 # with identity/target fields, and serialize actual RNG state instead of IDs.
 for flight in kernel.get("flights",[]):
  var view:Dictionary=flight.view
  flight.view={"serial":view.get("serial"),"target_uid":view.get("target",{}).get("uid",-1),"source_uid":view.get("source",{}).get("uid",-1),"primary_uid":view.get("primary_target",{}).get("uid",-1)}
 var canonical=scalar_copy(kernel)
 var beam_state:Array=[]
 for shot in g.projectiles:
  if not shot.get("beam",false):continue
  var links=shot.get("attack_instance",{}).get("chain",{}).get("links",[])
  beam_state.append({"serial":shot.serial,"mount":shot.mount,"hostile":shot.hostile,"repeated":shot.get("repeated",false),"endless":shot.get("endless",false),"prism":shot.get("prism_tower",false),"await_target":shot.get("await_target",false),"dead":shot.dead,"ticks":shot.ticks,"elapsed":shot.elapsed,"maximum":shot.weapon.para2,"target_uid":shot.target.get("uid",-1),"links":links.size(),"unbroken_links":links.filter(func(l):return not l.broken).size()})
 var enemies:Array=[]
 for e in g.enemies:enemies.append([e.get("uid"),e.get("hp"),e.get("shield"),e.get("x"),e.get("y")])
 return {"beam_state":beam_state,"endless_source_slot":g.weapon_entries().find(g.endless_source()),"kernel_hash":JSON.stringify(canonical).sha256_text(),"kernel_rng":str(g.native_execution.kernel.rng_source().state) if g.native_execution!=null else "","game_rng":str(g.rng.state),"clock":g.production_time(),"player":g.player.duplicate(true),"enemies":enemies,"resources":g.profile.resources.duplicate(true),"loadout":g.profile.loadout.duplicate(true),"drops":g.drops.size(),"projectiles":g.projectiles.size(),"state":g.state,"stage":g.stage,"group":g.group_index,"canonical_kernel":canonical}
func read_counters(g)->Dictionary:
 cold_counter_reads+=1
 return {"legacy":Counters.snapshot()}
var pre_draw_us:=0
func _initialize()->void:
 RenderingServer.frame_pre_draw.connect(func():pre_draw_us=Time.get_ticks_usec())
 call_deferred("run")
func snapshot(scene)->Dictionary:
 return {"steps":scene.logical_step_count(),"game":scene.game.production_time(),"fires":scene.fire_count,"hits":scene.hit_count,"purchases":scene.levels(),"handoffs":scene.game.native_handoff_count}
func config(scene)->Dictionary:
 var g=scene.game
 return {"stat_cache_enabled":g.stat_cache_enabled,"save_enabled":g.save_enabled,"compiled_rules":g.compiled_combat_rules!=null,"independent_qualification_plan":("enhancement_plan" in g),"combat_presentation":g.combat_presentation!=null,"native_auto":g.native_execution_auto,"native_active":g.native_execution!=null,"retained":scene.retained_contacts_enabled,"speed":g.speed,"engine_max_fps":Engine.max_fps,"vsync":DisplayServer.window_get_vsync_mode(),"time_scale":Engine.time_scale,"fixed_logic_hz":60,"window":str(DisplayServer.window_get_size()),"accelerated_visual_mode":scene.accelerated_visual_mode,"pulse_fx":scene.pulse_vfx_enabled,"missile_fx":scene.missile_vfx_enabled,"enemy_fx":scene.enemy_vfx_enabled,"old_pipeline_class":ClassDB.class_exists("SpaceNativePipeline")}
func run()->void:
 assert(ClassDB.class_exists("SpaceCombatPresentation") and ClassDB.class_exists("SpaceCombatKernel"),"accepted native classes available")
 assert(GDExtensionManager.get_extension("res://addons/native_battle/space_native.gdextension").is_library_open(),"accepted DLL loaded")
 Engine.max_fps=0
 DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 var scene=load("res://main.tscn").instantiate();scene.set_script(UI)
 scene.automation_args=["--capture"];scene.music_on=false
 root.add_child(scene);current_scene=scene;scene.automation_args=[];scene.set_process(false)
 var g=scene.game;g.save_enabled=false;g.speed=1;g.rng.seed=1701
 g.profile.onboarding.completed=true;scene.beginner_guide.hide()
 g.profile.cleared=range(1,101);g.profile.highestLevel=101;g.profile.unlocked=BattleGame.EQUIPMENT.duplicate()
 g.rebuild_unlocks();g.pending_unlocks.clear();g.profile.selectedShip="Heavy_Battleship"
 g.profile.resources={"1":1e80,"2":1e80};g.profile.hyperspace.materials["degenerate_matter"]=1e80;g.profile.loadout={"weapons":[],"defence":[]}
 for key in ["missile","missile","cannon","longLaser","laser","missile","cannon","longLaser"]:g.profile.loadout.weapons.append({"key":key,"level":140})
 for key in ["shield","armour","shield","armour"]:g.profile.loadout.defence.append({"key":key,"level":140})
 g.invalidate_stat_cache();g.reset_player();g.state=BattleGame.State.COMBAT;g.spawn_group()
 var template=g.enemies[0].duplicate(true);g.enemies.clear()
 for i in 15:
  var e=template.duplicate(true);e.uid=100+i;e.slot=i;e.x=80+80*(i%5);e.y=150+80*(i/5);e.hp=1e100;e.max_hp=1e100
  g.enemies.append(e)
 var stress=preload("res://combat_stress_fixture.gd").new();assert(stress.configure(g,2))
 scene.refresh_structure();scene.refresh_tab_visibility();scene.select_system(1 if OS.get_environment("AI_TECH_PERF_STATE")=="open" else 0)
 if OS.get_environment("AI_TECH_PERF_STATE")!="absent":
  assert(g.call("select_tech","singularity"),"research active before sampling")
  assert(scene.hightech_page.art_enabled,"final static art enabled")
  assert(scene.hightech_page.is_visible_in_tree()==(OS.get_environment("AI_TECH_PERF_STATE")=="open"),"technology page visibility")

 assert(g.assign_crew("navigator","equipment_upgrade","equipment"),"normal main batch scheduler enabled")
 var native=OS.get_environment("PERF_NATIVE")=="1"
 g.native_execution_auto=native
 if native:
  admission_reason=preload("res://scripts/native_execution_compiler.gd").new().compile(g,"native_rich15_layer2")
  admitted=g.admit_native_compiled_execution("native_rich15_layer2")
  if admitted:assert(scene.attach_native_display(),"native display attached")
  print("ADMISSION ",admitted," ",JSON.stringify(admission_reason.get("error","")))
 scene.retained_contacts_enabled=true
 if scene.has_method("refresh_evolution_visuals"):scene.refresh_evolution_visuals()
 print("EVOLUTION_TIER ",scene.weapon_evolution_tier({"mount":0,"hostile":false}) if scene.has_method("weapon_evolution_tier") else "none")
 assert(g.stat_cache_enabled and not g.save_enabled and g.compiled_combat_rules!=null and g.combat_presentation!=null,"startup cache/compiled/presentation contract")
 var startup_config=config(scene)
 print("CACHE_ON_START ",JSON.stringify(startup_config))
 Counters.enabled=true
 g.event.connect(scene.watch)
 g.event.connect(count_event)
 var traces:Array=[]
 var geo=scene.battle_slice_runtime.geometry
 for step in 721:
  var session=g.native_execution
  var actors:Array=[]
  for e in g.enemies:
   var shape=geo.battle_read_model.ballistic_shape(e)
   var component=geo.enemy_component_for_slot(e,0)
   actors.append({"uid":e.uid,"position":geo.enemy_render_position(e),"width":geo.enemy_render_width(e),"angle":geo.enemy_render_angle(e),"hull":shape.hull,"center":shape.center,"port":geo.execution_enemy_port_offset(e,0,geo.enemy_render_position(e)),"hardpoint":component.hardpoint if component!=null else {},"profile":component.profile if component!=null else {},"component_pose":geo._source_enemy_component_pose(e,component) if component!=null else {}})
  traces.append({"step":step,"clock":g.production_time(),"player":geo.player_render_position(),"height":geo.reference_height,"aim":session.geometry_player,"muzzles":session.geometry_muzzles,"actors":actors,"incoming":g.profile.enhancementHits,"attacks":g.profile.enhancementAttacks})
  if step<720:scene.battle_slice_runtime.advance(1.0/60.0)
 FileAccess.open("res://.runtime/geometry-probe.json",FileAccess.WRITE).store_string(JSON.stringify(traces))
 FileAccess.open("res://.runtime/geometry-events.json",FileAccess.WRITE).store_string(JSON.stringify({"equipment_stats":equipment_events,"events":sample_events,"state_after":state_digest(g)}))
 print("GEOMETRY_PROBE_DONE ",traces.size())
 g.begin_retreat();scene.queue_free();await process_frame;await process_frame
 quit()
