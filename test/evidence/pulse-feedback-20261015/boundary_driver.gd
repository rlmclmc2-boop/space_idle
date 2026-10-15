extends SceneTree
class UI extends "res://scripts/battlefield.gd":
 var played_beeps:Array=[]
 var critical_calls:Array=[]
 var exit_probe:Callable
 func show_qa_tools()->void:pass
 func show_chrono_login_report()->void:pass
 func beep(frequency:float)->void:
  var before=last_sound
  super.beep(frequency)
  if last_sound!=before:played_beeps.append([clock,frequency])
 func native_critical_pulse_effect(point:Vector2,direction:Vector2,display_time:float)->void:
  critical_calls.append([point,direction,display_time])
  super.native_critical_pulse_effect(point,direction,display_time)
 func _exit_tree()->void:
  super._exit_tree()
  if exit_probe.is_valid():exit_probe.call(self)
 func create_battle_game(_persist:bool)->BattleGame:
  var g=preload("res://scripts/presented_battle_game.gd").new(db,false)
  g.stat_cache_enabled=true;g.invalidate_stat_cache()
  db=g.db;g.native_execution_auto=false
  g.launch_provider=_prototype_launch_pose;g.drone_launch_provider=_prototype_drone_launch_pose
  g.target_provider=_prototype_target_point;g.target_spatial_source=battle_read_model
  g.rail_geometry_provider=_rail_geometry;g.rail_target_point_provider=entity_render_position
  g.enable_compiled_combat_rules()
  return g

func _initialize()->void:call_deferred("run")

func anchors(scene)->Array:
 var rows=[]
 for e in scene.floats+scene.damage_pending:
  if e.get("damage",false):rows.append([e.get("uid",-1),e.get("target",""),e.get("target_entity",{}).get("uid",-1),e.get("needs_origin",false),e.get("origin",Vector2.ZERO),e.get("pos",Vector2.ZERO),e.get("amount",0),e.get("life",0),e.get("critical",false)])
 return rows

func capture(scene)->Dictionary:
 var g=scene.game
 var turrets=[]
 for mount in 8:
  var pose=scene.turret_pose(mount)
  turrets.append([pose.get("target",{}).get("uid",-1),pose.get("fired_at",-1.0)])
 var effects={"flash":0,"ring":0,"spark":0}
 for particle in scene.particles:
  for key in effects:
   if particle.has(key):effects[key]+=1
 return {"history":scene.damage_history.duplicate(),"history_main":scene.native_damage_history_rows(),"anchors":anchors(scene),"contacts":g.combat_presentation.contact_snapshot(1),"turrets":turrets,"effects":effects,"played_beeps":scene.played_beeps.duplicate(true),"critical_calls":scene.critical_calls.duplicate(true),"visual_reservations":scene.native_laser_visuals.size(),"ordinary_visuals":scene.projectile_visuals.size(),"owned":g.native_execution.pulse_feedback_owned if g.native_execution!=null else false,"pending":g.combat_presentation.pulse_frame_pending(),"paused":g.paused,"native_alive":g.native_execution!=null,"game_rng":str(g.rng.state),"kernel_rng":str(g.native_execution.kernel.rng_source().state) if g.native_execution!=null else "","player":g.player.duplicate(true),"active_flights":g.native_execution.kernel.metrics().active_flights if g.native_execution!=null else g.projectiles.size()}

func unpublished_step(scene)->bool:
 var g=scene.game;var runtime=scene.battle_slice_runtime;const STEP=1.0/60.0
 scene.clock+=STEP
 if not g.prepare_logical_step(STEP):return false
 runtime.geometry.before_tick(STEP)
 scene.fx_time=runtime.geometry.fx_time;scene.demo_time=runtime.geometry.demo_time
 scene.turret_visuals=runtime.geometry.turret_visuals;scene.turret_ship=runtime.geometry.turret_ship
 if g.native_execution!=null:
  g.native_execution.bind_presentation_surface(scene)
  g.native_execution.prepare_geometry(runtime.geometry,g)
 scene.shield_before_hit=g.player.shield
 g.tick(STEP)
 if g.native_step_phase=="blocked":return false
 runtime.geometry.after_tick();runtime.logical_steps+=1
 return true

func run()->void:
 assert(ClassDB.class_exists("SpaceCombatPresentation") and ClassDB.class_exists("SpaceCombatKernel"))
 assert(GDExtensionManager.get_extension("res://space_native.gdextension").is_library_open())
 var scene=load("res://main.tscn").instantiate();scene.set_script(UI)
 scene.automation_args=["--capture"];scene.music_on=false;scene.sound_on=true
 root.add_child(scene);current_scene=scene;scene.automation_args=[];scene.set_process(false)
 var g=scene.game;g.save_enabled=false;g.speed=1;g.rng.seed=1701
 g.profile.onboarding.completed=true;scene.beginner_guide.hide()
 g.profile.cleared=range(1,101);g.profile.highestLevel=101;g.profile.unlocked=BattleGame.EQUIPMENT.duplicate()
 g.rebuild_unlocks();g.pending_unlocks.clear();g.profile.selectedShip="Heavy_Battleship"
 g.profile.resources={"1":1e80,"2":1e80};g.profile.loadout={"weapons":[],"defence":[]}
 for key in ["laser","laser","laser","laser","laser","laser","laser","laser"]:g.profile.loadout.weapons.append({"key":key,"level":150})
 for key in ["shield","armour","shield","armour"]:g.profile.loadout.defence.append({"key":key,"level":150})
 g.invalidate_stat_cache();g.reset_player();g.state=BattleGame.State.COMBAT;g.spawn_group()
 var template=g.enemies[0].duplicate(true);g.enemies.clear()
 for i in 15:
  var e=template.duplicate(true);e.uid=100+i;e.slot=i;e.x=80+80*(i%5);e.y=150+80*(i/5);e.hp=1e100;e.max_hp=1e100
  g.enemies.append(e)
 var stress=preload("res://combat_stress_fixture.gd").new();assert(stress.configure(g,2))
 scene.refresh_structure();scene.refresh_tab_visibility();scene.select_system(0)
 assert(g.assign_crew("navigator","equipment_upgrade","equipment"))
 g.native_execution_auto=true
 var admission=preload("res://scripts/native_execution_compiler.gd").new().compile(g,"native_rich15_layer2")
 assert(g.admit_native_compiled_execution("native_rich15_layer2"),JSON.stringify(admission.get("error","")))
 assert(scene.attach_native_display())
 scene.retained_contacts_enabled=true
 if g.event.is_connected(Callable(stress,"on_event")):g.event.disconnect(Callable(stress,"on_event"))
 await process_frame
 var action=OS.get_environment("PULSE_QA_ACTION")
 assert(action in ["close","handoff","cap"])
 for i in 24:
  var dt=0.0 if i%9==0 else 3.0/60.0 if i%9==8 else 1.0/60.0
  scene._process(dt)
 assert(g.native_execution!=null and not g.paused)
 var pre=capture(scene)
 var cap_seeded=0
 if action=="cap":
  assert(pre.ordinary_visuals+pre.visual_reservations<255)
  while scene.projectile_visuals.size()+scene.native_laser_visuals.size()<255:
   scene.native_laser_visuals[-1000000-cap_seeded]=true;cap_seeded+=1
 var contacts_before=g.combat_presentation.contact_snapshot(1).size()
 assert(unpublished_step(scene),"single native step completes before display snapshot")
 var before=capture(scene)
 var fresh_fire=0
 for contact in g.combat_presentation.contact_snapshot(1):
  if contact.get("kind","")=="fire" and is_equal_approx(float(contact.born),scene.fx_time):fresh_fire+=1
 var result={"action":action,"mode":OS.get_environment("PULSE_QA_MODE"),"pre":pre,"before":before,"fresh_fire":fresh_fire,"contact_count_before":contacts_before,"cap_seeded":cap_seeded}
 if action=="close":
  scene.exit_probe=func(active):
   result["close_ok"]=active.battle_slice_runtime==null
   result["after"]=capture(active)
  scene.queue_free();await process_frame
  result["after_tree_free"]={"paused":g.paused,"native_alive":g.native_execution!=null,"pending":g.combat_presentation.pulse_frame_pending(),"owned":g.native_execution.pulse_feedback_owned if g.native_execution!=null else false}
 elif action=="handoff":
  result["handoff_ok"]=g.native_execution.handoff_to_legacy(g,"qa_pending")
  result["after"]=capture(scene)
  scene.queue_free();await process_frame
 else:
  result["publish_ok"]=g.native_execution.publish_pulse_frame(g)
  result["after"]=capture(scene)
  scene.queue_free();await process_frame
 FileAccess.open("res://.runtime/boundary.json",FileAccess.WRITE).store_string(JSON.stringify(result))
 print("PULSE_BOUNDARY ",JSON.stringify({"mode":result.mode,"action":action,"fresh_fire":fresh_fire,"before_owned":before.owned,"before_pending":before.pending,"after_owned":result.after.owned,"after_pending":result.after.pending,"total_visuals":int(result.after.visual_reservations)+int(result.after.ordinary_visuals)}))
 quit()
