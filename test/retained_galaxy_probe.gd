extends SceneTree
# Diagnostic only: whole_game_perf.py --retained-galaxy-probe --rich --pages 8.
# Frozen synthetic scene, one transport pose, Godot4.6.3 Compatibility only.
# No production cache, camera invalidation, construction or startup acceptance.
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
func ship_inventory(scene):
 var view=scene.ship_view
 var bodies=[]
 for record in view.body_baker.records.values():
  bodies.append({"request":record.request,"active":record.active,"visible":record.root.is_visible_in_tree(),"asset_ready":view.body_baker.textures.has(record.key) and view.body_baker.textures[record.key].ready,"source_meshes":record.parts.size()})
 var geometry=0
 for node in view.world.find_children("*","GeometryInstance3D",true,false):
  if node.is_visible_in_tree():geometry+=1
 return {"battle_visible":scene.battle_layer.is_visible_in_tree(),"ship_visible":view.is_visible_in_tree(),"ship_render_scale":view.viewport.scaling_3d_scale,"ship_msaa":view.viewport.msaa_3d,"live_shadows":view.world.get_node("KeyLight").shadow_enabled,"body_roots":view.body_baker.body_roots.size(),"bodies":bodies,"visible_geometry":geometry,"flat_enabled":view.flat_compositor.enabled,"flat_active":view.flat_compositor.active,"flat_reason":view.flat_compositor.fallback_reason,"flat_items":view.flat_compositor.items.size(),"flat_textures":view.flat_compositor.textures.size()}
func meshes(node, output):
 if node is MeshInstance3D:output.append(node)
 for child in node.get_children():meshes(child,output)
func camera_copy(source, viewport, mask):
 var cam=Camera3D.new();viewport.add_child(cam)
 cam.projection=source.projection;cam.size=source.size;cam.near=source.near;cam.far=source.far;cam.keep_aspect=source.keep_aspect
 cam.global_transform=source.global_transform;cam.cull_mask=mask;cam.current=true
 return cam
func vp(map, label, own):
 var v=SubViewport.new();v.name=label;v.size=map.view.size;v.own_world_3d=own;v.msaa_3d=map.view.msaa_3d;v.mesh_lod_threshold=map.view.mesh_lod_threshold
 if not own:v.world_3d=map.view.find_world_3d()
 map.add_child(v);v.render_target_update_mode=SubViewport.UPDATE_DISABLED
 return v
func run():
 if Engine.get_version_info().string!="4.6.3-stable (official)" or RenderingServer.get_current_rendering_method()!="gl_compatibility":
  printerr("Retained proof supports the checked Godot4.6.3 Compatibility transfer only")
  Engine.remove_meta("saved_perf");quit(2);return
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
 g.invalidate_stat_cache();g.paused=true
 scene.refresh_structure();scene.refresh_tab_visibility();scene.select_system(int("8"))
 await process_frame
 scene._process(1.0/60.0)
 scene.galaxy_panel.refresh()
 scene.ship_view.set_rendering(true,false)
 var map=scene.galaxy_panel.map
 map.set_running(true)
 map.visual_clock+=60;map._process(0.0);map.set_process(false)
 if map.core==null:printerr("missing galaxy core");quit(1);return
 print("ENV ",JSON.stringify({"engine":Engine.get_version_info().string,"adapter":RenderingServer.get_video_adapter_name(),"vendor":RenderingServer.get_video_adapter_vendor(),"method":RenderingServer.get_current_rendering_method(),"display":DisplayServer.get_name(),"resolution":str(root.size),"cap":Engine.max_fps,"low_processor":OS.low_processor_usage_mode}))
 var creation_start=Time.get_ticks_usec()
 var original_profile=JSON.stringify(g.profile,"",true,true)
 var all=[];meshes(map.world,all)
 var dynamic=[]
 for item in map.transports:meshes(item.node,dynamic)
 for item in map.explorers:meshes(item.node,dynamic)
 for item in map.pulses:meshes(item.node,dynamic)
 for part in map.activity:meshes(part,dynamic)
 meshes(map.highlight,dynamic)
 for node in all:node.layers=2 if dynamic.has(node) else 1
 for light in map.world.find_children("*","Light3D",true,false):
  light.layers=3;light.light_cull_mask=3
 var depth=vp(map,"CachedDepth",true);depth.msaa_3d=Viewport.MSAA_DISABLED
 var depth_world=Node3D.new();depth.add_child(depth_world)
 var environment_node=WorldEnvironment.new();var environment=Environment.new()
 environment.background_mode=Environment.BG_COLOR;environment.background_color=Color.BLACK;environment.ambient_light_source=Environment.AMBIENT_SOURCE_DISABLED
 environment_node.environment=environment;depth_world.add_child(environment_node)
 var depth_mat=ShaderMaterial.new();depth_mat.shader=load("res://retained_galaxy_depth.gdshader")
 for original in all:
  if dynamic.has(original) or not original.is_visible_in_tree():continue
  var node=MeshInstance3D.new();node.mesh=original.mesh;node.material_override=depth_mat;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  depth_world.add_child(node);node.global_transform=original.global_transform;node.lod_bias=original.lod_bias
 var depth_camera=camera_copy(map.camera,depth,1)
 var lut_image=Image.create(256,1,false,Image.FORMAT_RF)
 for i in 256:
  var target=pow((float(i)/255.0+0.055)/1.055,2.4) if i>0 else 0.0
  var lo=0.0;var hi=1.0
  for _j in 48:
   var mid=(lo+hi)*0.5
   var value=mid*(mid*(mid*0.305306011+0.682171111)+0.012522878)
   if value<target:lo=mid
   else:hi=mid
  lut_image.set_pixel(i,0,Color((lo+hi)*0.5,0,0,1))
 var lut=ImageTexture.create_from_image(lut_image);depth_mat.set_shader_parameter("transfer_lut",lut)
 var dynamic_view=vp(map,"CachedDynamic",false);var dynamic_camera=camera_copy(map.camera,dynamic_view,6)
 var plane=MeshInstance3D.new();var quad=QuadMesh.new();quad.size=Vector2(2,2);plane.mesh=quad;plane.layers=4;plane.extra_cull_margin=10000;plane.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 var cache_mat=ShaderMaterial.new();cache_mat.shader=load("res://retained_galaxy_color.gdshader")
 cache_mat.set_shader_parameter("cached_color",map.view.get_texture());cache_mat.set_shader_parameter("cached_depth",depth.get_texture());cache_mat.set_shader_parameter("transfer_lut",lut);plane.material_override=cache_mat;plane.visible=false;map.world.add_child(plane)
 print("CACHE_CREATE_US ",Time.get_ticks_usec()-creation_start)
 await check_retained(scene,map,g,original_profile,depth,dynamic_view,plane,depth_camera,dynamic_camera,depth_mat,cache_mat,quad)
 scene.queue_free();await process_frame;Engine.remove_meta("saved_perf");quit()
func check_retained(_scene,map,g,original_profile,depth,dynamic_view,plane,_depth_camera,_dynamic_camera,_depth_mat,_cache_mat,_quad):
 # Compare real geometry to retained color/depth at identical frozen actor poses.
 for phase in [0.45]:
  for i in map.transports.size():
   map.transports[i].phase=clampf(phase+float(i)*0.005,0,0.999)
  map._process(0.0)
  plane.visible=false;dynamic_view.render_target_update_mode=SubViewport.UPDATE_DISABLED;map.camera.cull_mask=3;map.view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;map.container.texture=map.view.get_texture()
  var times=[]
  var count=int(OS.get_environment("PERF_FRAMES"));var warmup=int(OS.get_environment("PERF_WARMUP_FRAMES"))
  for i in count+warmup:
   var started=Time.get_ticks_usec();await process_frame
   if i>=warmup:times.append(Time.get_ticks_usec()-started)
  await RenderingServer.frame_post_draw
  map.view.get_texture().get_image().save_png("res://.runtime/cache-before-%s.png"%phase)
  print("ROW ",JSON.stringify({"kind":"live_geometry","phase":phase,"frames_us":stats(times),"profile_equal":original_profile==JSON.stringify(g.profile,"",true,true)}))
  var prepare=Time.get_ticks_usec()
  map.camera.cull_mask=1;map.view.render_target_update_mode=SubViewport.UPDATE_ONCE;depth.render_target_update_mode=SubViewport.UPDATE_ONCE
  await process_frame;await RenderingServer.frame_post_draw
  map.view.render_target_update_mode=SubViewport.UPDATE_DISABLED;depth.render_target_update_mode=SubViewport.UPDATE_DISABLED;plane.visible=true;dynamic_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;map.container.texture=dynamic_view.get_texture()
  await process_frame;await RenderingServer.frame_post_draw
  print("CACHE_PREPARE ",Time.get_ticks_usec()-prepare)
  times=[]
  for i in count+warmup:
   var started=Time.get_ticks_usec();await process_frame
   if i>=warmup:times.append(Time.get_ticks_usec()-started)
  await RenderingServer.frame_post_draw
  dynamic_view.get_texture().get_image().save_png("res://.runtime/cache-after-%s.png"%phase)
  var v=[];views(root,v)
  print("ROW ",JSON.stringify({"kind":"retained_color_depth","phase":phase,"frames_us":stats(times),"profile_equal":original_profile==JSON.stringify(g.profile,"",true,true),"views":v}))
 plane.visible=false;map.camera.cull_mask=3;map.container.texture=map.view.get_texture();map.view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
