extends SceneTree
## Frozen mixed GL full-frame render attribution; all gameplay and visuals remain active.
const QADraw=preload("res://qa_draw_cost.gd")
class UI extends "res://scripts/battlefield.gd":
 var main_started_us:=0
 var main_finished_us:=0
 func _process(delta:float)->void:
  main_started_us=Time.get_ticks_usec()
  super._process(delta)
  main_finished_us=Time.get_ticks_usec()
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

var pre_draw_us:=0
var pre_measure:Dictionary={}
var measure_enabled:=false
var viewports:Array=[]

func _initialize()->void:
 RenderingServer.frame_pre_draw.connect(on_pre_draw)
 call_deferred("run")

func on_pre_draw()->void:
 pre_draw_us=Time.get_ticks_usec()
 pre_measure=read_render() if measure_enabled else {}

func read_render()->Dictionary:
 var start=Time.get_ticks_usec()
 var rows:Dictionary={}
 for viewport in viewports:
  if not is_instance_valid(viewport) or viewport.is_queued_for_deletion():continue
  var rid=viewport.get_viewport_rid()
  rows[str(viewport.get_path())]=[RenderingServer.viewport_get_measured_render_time_cpu(rid),RenderingServer.viewport_get_measured_render_time_gpu(rid)]
 return {"viewports":rows,"setup_cpu":RenderingServer.get_frame_setup_time_cpu(),"query_us":Time.get_ticks_usec()-start}

func gather_viewports(node:Node)->void:
 if node is Viewport:viewports.append(node)
 for child in node.get_children():gather_viewports(child)

func viewport_inventory()->Array:
 var rows=[]
 for viewport in viewports:
  if not is_instance_valid(viewport) or viewport.is_queued_for_deletion():continue
  rows.append({"path":str(viewport.get_path()),"class":viewport.get_class(),"size":str(viewport.size),"update_mode":viewport.render_target_update_mode if viewport is SubViewport else -1,"visible":viewport.visible if viewport is Window else null,"rid_valid":viewport.get_viewport_rid().is_valid()})
 return rows

func steps(scene)->int:
 return scene.battle_slice_runtime.logical_steps if scene.battle_slice_runtime!=null else -1

func work(scene)->Dictionary:
 var g=scene.game;var session=g.native_execution
 var levels=0
 for entry in g.loadout_entries("weapons")+g.loadout_entries("defence"):levels+=int(entry.level)
 return {"game_clock":g.production_time(),"steps":steps(scene),"feedback_rows":session.feedback_rows,"kernel":session.kernel.metrics(),"rng":str(g.rng.state),"kernel_rng":str(session.kernel.rng_source().state),"player":g.player.duplicate(true),"resources":g.profile.resources.duplicate(true),"levels":levels,"loadout":g.profile.loadout.duplicate(true),"drops":g.drops.size(),"enemies_alive":g.enemies.filter(func(e):return GrowthNumber.compare(e.hp,0)>0).size(),"history_size":scene.damage_history.size(),"floats":scene.floats.size(),"pending":scene.damage_pending.size(),"compact_membership":session.kernel.presentation_membership().compact_laser_serials.size(),"native_handoffs":g.native_handoff_count,"accelerated":scene.accelerated_visual_mode}

func run()->void:
 assert(ClassDB.class_exists("SpaceCombatPresentation") and ClassDB.class_exists("SpaceCombatKernel"))
 assert(GDExtensionManager.get_extension("res://space_native.gdextension").is_library_open())
 Engine.max_fps=0;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 var scene=load("res://main.tscn").instantiate();scene.set_script(UI)
 scene.automation_args=["--capture"];scene.music_on=false
 root.add_child(scene);current_scene=scene;scene.automation_args=[];scene.set_process(false)
 var g=scene.game;g.save_enabled=false;g.speed=1;g.rng.seed=1701
 var case_name=OS.get_environment("RENDER_CASE")
 assert(case_name=="mixed")
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
 var stress=preload("res://combat_stress_fixture.gd").new()
 assert(stress.configure(g,2))
 scene.refresh_structure();scene.refresh_tab_visibility();scene.select_system(0)
 assert(g.assign_crew("navigator","equipment_upgrade","equipment"))
 g.native_execution_auto=true
 var admission=preload("res://scripts/native_execution_compiler.gd").new().compile(g,"native_rich15_layer2")
 assert(g.admit_native_compiled_execution("native_rich15_layer2"),JSON.stringify(admission.get("error","")))
 assert(scene.attach_native_display())
 scene.retained_contacts_enabled=true
 if g.event.is_connected(Callable(stress,"on_event")):g.event.disconnect(Callable(stress,"on_event"))
 scene.set_process(true)
 for i in 12:await RenderingServer.frame_post_draw
 scene.set_process(false)
 var view=scene.ship_view
 var meshes=[]
 visit_meshes(view.viewport,view,meshes)
 var records=[]
 for id in view.body_baker.records:
  var record=view.body_baker.records[id]
  records.append({"key":record.key,"active":record.active,"root":str(record.root.get_path()),"parts":record.parts.size(),"hidden_parts":record.parts.filter(func(part):return not part.source.visible).size(),"proxy_visible":record.plane.visible if is_instance_valid(record.plane) else false})
 var light=view.world.get_node_or_null("KeyLight")
 var rid=view.viewport.get_viewport_rid()
 var stats={}
 for kind in [RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW]:
  stats[str(kind)]={"objects":RenderingServer.viewport_get_render_info(rid,kind,RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME),"primitives":RenderingServer.viewport_get_render_info(rid,kind,RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME),"draw_calls":RenderingServer.viewport_get_render_info(rid,kind,RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)}
 var result={"engine":Engine.get_version_info(),"adapter":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method(),"dll_open":GDExtensionManager.get_extension("res://space_native.gdextension").is_library_open(),"fixture_manifest":stress.manifest,"view_size":str(view.viewport.size),"msaa_3d":view.viewport.msaa_3d,"view_update_mode":view.viewport.render_target_update_mode,"light_shadow_enabled":light.shadow_enabled if light!=null else null,"baker_records":records,"baker_export_mode":view.body_baker.export_mode,"mesh_rows":meshes,"render_info":stats,"logical_steps":scene.battle_slice_runtime.logical_steps if scene.battle_slice_runtime!=null else -1}
 FileAccess.open("res://.runtime/ship_structure.json",FileAccess.WRITE).store_string(JSON.stringify(result))
 print("SHIP_STRUCTURE ",JSON.stringify({"meshes":meshes.size(),"records":records.size(),"stats":stats,"shadow":result.light_shadow_enabled,"steps":result.logical_steps}))
 scene.queue_free();await process_frame;quit()

func below(node:Node,ancestor:Node)->bool:
 var here=node
 while here!=null:
  if here==ancestor:return true
  here=here.get_parent()
 return false

func category(mesh:MeshInstance3D,view)->String:
 if mesh==view.shield:return "shield"
 if view.exhaust_nodes.has(mesh):return "exhaust"
 if mesh.has_meta("body_bake_proxy"):return "baked_proxy"
 for module in view.modules:
  if below(mesh,module.node):return "weapon_"+str(module.key)
 for carrier in view.carriers:
  if below(mesh,carrier):return "carrier_decoration" if str(mesh.get_path()).contains("Appearance") else "carrier_body"
 if below(mesh,view.ship):return "hull_decoration" if str(mesh.get_path()).contains("Appearance") else "hull_body"
 return "other"

func visit_meshes(node:Node,view,rows:Array)->void:
 if node is MeshInstance3D:
  var mesh:MeshInstance3D=node
  var materials=[]
  if mesh.mesh!=null:
   for surface in mesh.mesh.get_surface_count():
    var mat=mesh.get_active_material(surface)
    var code=mat.shader.code if mat is ShaderMaterial else ""
    materials.append({"id":mat.get_instance_id() if mat!=null else 0,"class":mat.get_class() if mat!=null else "null","shader_hash":code.sha256_text() if not code.is_empty() else "","render_mode":code.split("render_mode ")[1].split(";")[0] if code.contains("render_mode ") else "","priority":mat.render_priority if mat!=null else 0})
  rows.append({"path":str(mesh.get_path()),"category":category(mesh,view),"visible":mesh.is_visible_in_tree(),"local_visible":mesh.visible,"mesh_id":mesh.mesh.get_instance_id() if mesh.mesh!=null else 0,"mesh_class":mesh.mesh.get_class() if mesh.mesh!=null else "null","mesh_path":mesh.mesh.resource_path if mesh.mesh!=null else "","surfaces":mesh.mesh.get_surface_count() if mesh.mesh!=null else 0,"materials":materials,"shadow_cast":mesh.cast_shadow,"layers":mesh.layers})
 for child in node.get_children():visit_meshes(child,view,rows)
