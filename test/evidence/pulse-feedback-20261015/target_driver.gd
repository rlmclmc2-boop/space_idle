extends SceneTree
class UI extends "res://scripts/battlefield.gd":
 var played_beeps:Array=[]
 func beep(frequency:float)->void:
  var before=last_sound
  super.beep(frequency)
  if last_sound!=before:played_beeps.append([clock,frequency])
 func show_qa_tools()->void:pass
 func show_chrono_login_report()->void:pass
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

func check_state(scene)->Dictionary:
 var g=scene.game
 var enemies=[]
 for e in g.enemies:enemies.append([e.uid,e.hp,e.shield,e.x,e.y])
 var floats=[]
 for e in scene.floats:
  if e.get("damage",false):floats.append([e.uid,e.amount,e.absorbed,e.critical,e.life,e.born,e.get("retiring",false)])
 var pending=[]
 for e in scene.damage_pending:pending.append([e.uid,e.amount,e.absorbed,e.critical,e.life,e.born,e.get("retiring",false)])
 var anchors=[]
 for e in scene.floats+scene.damage_pending:
  if e.get("damage",false):anchors.append([e.get("uid",-1),e.get("target",""),e.get("target_entity",{}).get("uid",-1),e.get("needs_origin",false),e.get("origin",Vector2.ZERO),e.get("pos",Vector2.ZERO)])
 var turrets=[]
 for mount in 8:
  var pose=scene.turret_pose(mount)
  turrets.append([pose.get("target",{}).get("uid",-1),pose.get("fired_at",-1.0)])
 var contacts=g.combat_presentation.contact_snapshot(1)
 var effects={"flash":0,"ring":0,"spark":0}
 for particle in scene.particles:
  for key in effects:
   if particle.has(key):effects[key]+=1
 return {"clock":g.production_time(),"fx_time":scene.fx_time,"speed":g.speed,"damage_mode":scene.damage_mode,"accelerated":scene.accelerated_visual_mode,"player":g.player.duplicate(true),"enemies":enemies,"game_rng":str(g.rng.state),"kernel_rng":str(g.native_execution.kernel.rng_source().state) if g.native_execution!=null else "", "projectiles":g.native_execution.kernel.metrics().active_flights if g.native_execution!=null else g.projectiles.size(),"history":scene.damage_history.duplicate(),"floats":floats,"pending":pending,"anchors":anchors,"turrets":turrets,"contacts":contacts,"effects":effects,"played_beeps":scene.played_beeps.duplicate(true),"owned":g.native_execution.pulse_feedback_owned if g.native_execution!=null else false,"feedback_rows":g.native_execution.feedback_rows if g.native_execution!=null else -1,"native":g.native_execution!=null,"paused":g.paused,"compatibility":g.native_execution.pulse_feedback_compatibility if g.native_execution!=null else false}

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
  var e=template.duplicate(true);e.uid=100+i;e.slot=i;e.x=80+80*(i%5);e.y=150+80*(i/5);e.hp=1e15 if OS.get_environment("PULSE_QA_SCENARIO")=="death" else 1e100;e.max_hp=e.hp
  g.enemies.append(e)
 var stress=preload("res://combat_stress_fixture.gd").new();assert(stress.configure(g,2))
 scene.refresh_structure();scene.refresh_tab_visibility();scene.select_system(0)
 assert(g.assign_crew("navigator","equipment_upgrade","equipment"))
 g.native_execution_auto=true
 var admission=preload("res://scripts/native_execution_compiler.gd").new().compile(g,"native_rich15_layer2")
 assert(g.admit_native_compiled_execution("native_rich15_layer2"),JSON.stringify(admission.get("error","")))
 assert(scene.attach_native_display())
 scene.retained_contacts_enabled=true
 # The stress fixture's observer is QA-only. Let rebuilt panels finish free;
 # real UI also reaches this point on the next frame.
 if g.event.is_connected(Callable(stress,"on_event")):g.event.disconnect(Callable(stress,"on_event"))
 await process_frame
 var connections=[]
 for c in g.event.get_connections():
  var owner=c.callable.get_object();var script=owner.get_script() if owner!=null else null
  connections.append({"method":str(c.callable.get_method()),"path":str(script.resource_path) if script!=null else "","flags":c.flags,"owner_scene":owner==scene,"descendant":scene.is_ancestor_of(owner) if owner is Node else false})
 var gates={"listener_ok":g.native_execution.reviewed_pulse_listeners(g),"listener_compatibility":g.native_execution.pulse_feedback_compatibility,"compact_supported":g.combat_presentation.supports_compact_lasers(scene),"fast_mode":scene.fast_mode_enabled(),"show_damage":scene.show_damage_numbers,"damage_mode":scene.damage_mode,"runtime":scene.battle_slice_runtime!=null}
 var traces=[]
 for i in 45:
  if OS.get_environment("PULSE_QA_SCENARIO")=="transitions":
   if i==19:scene.set_damage_mode(2)
   if i==22:scene.set_damage_mode(0)
   if i==26:g.speed=10.0
   if i==29:g.speed=1.0
   if i==40:g.event.connect(Callable(stress,"on_event"))
  var dt=0.0 if i%9==0 else 3.0/60.0 if i%9==8 else 1.0/60.0
  scene._process(dt)
  traces.append(check_state(scene))
  if g.native_execution==null or g.paused:break
 var result={"admission":admission.get("error",""),"connections":connections,"gates":gates,"traces":traces,"scenario":OS.get_environment("PULSE_QA_SCENARIO"),"mode":OS.get_environment("PULSE_QA_MODE"),"gate":preload("res://scripts/native_execution_session.gd").PULSE_FEEDBACK_PROTOTYPE}
 if g.native_execution!=null:
  result["before_exit_pending"]=g.combat_presentation.pulse_frame_pending()
  result["before_exit_owned"]=g.native_execution.pulse_feedback_owned
 scene.queue_free();await process_frame
 result["exit_native_alive"]=g.native_execution!=null
 result["exit_paused"]=g.paused
 FileAccess.open("res://.runtime/target.json",FileAccess.WRITE).store_string(JSON.stringify(result))
 print("PULSE_TARGET ",JSON.stringify({"mode":result.mode,"traces":traces.size(),"exit_paused":result.exit_paused,"last":traces.back() if not traces.is_empty() else {}}))
 quit()
