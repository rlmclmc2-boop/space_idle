extends SceneTree
# Bounded attribution on the named natural QA checkpoint copy, never a player save.
# Copy this script to the isolated project; checkpoint20.json comes from the authorized Git QA checkpoint.
# This checkpoint completed20, brieflyentered21, thenreturned20/1; no pure<=20 provenance claim.
class UI extends "res://scripts/battlefield.gd":
 func create_battle_game(_persist:bool)->BattleGame:
  var g=super.create_battle_game(false)
  g.stat_cache_enabled=true
  var raw=JSON.parse_string(FileAccess.get_file_as_string("res://checkpoint20.json"))
  g.load_progress_data(raw)
  g.save_enabled=false
  return g
 func show_qa_tools()->void:pass
 func show_chrono_login_report()->void:pass
 var last_process_us=0
 func _process(dt:float)->void:
  var began=Time.get_ticks_usec();super._process(dt);last_process_us=Time.get_ticks_usec()-began
class Meter extends RefCounted:
 var enabled=false;var times={};var draw_us=0
 func record(key,us):
  if not enabled:return
  if not times.has(key):times[key]=[0,0,0]
  times[key][0]+=1;times[key][1]+=us;times[key][2]=max(times[key][2],us)
  if key=="main.draw_battle":draw_us+=us
var meter=Meter.new()
func _initialize():Engine.set_meta("saved_perf",meter);call_deferred("run")
func stats(a):
 a.sort();var total=0.0
 for v in a:total+=v
 return {"mean":total/a.size(),"p50":a[a.size()/2],"p95":a[int(a.size()*.95)],"max":a[-1]}
func views(node,rows):
 if node is SubViewport:rows.append({"path":str(node.get_path()),"size":str(node.size),"mode":node.render_target_update_mode,"calls":node.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),"primitives":node.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE,Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME)})
 for child in node.get_children():views(child,rows)
func fail(reason):printerr("CHECKPOINT_FAILURE ",reason);Engine.remove_meta("saved_perf");quit(2)
func run():
 Engine.max_fps=0;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 var save_hash=FileAccess.get_sha256("res://checkpoint20.json")
 var scene=load("res://main.tscn").instantiate();scene.set_script(UI);scene.automation_args=[];scene.music_on=false
 root.add_child(scene);current_scene=scene;scene.set_process(false)
 var g=scene.game
 if not g.startup_error.is_empty() or g.stage!=20 or g.group_index!=1 or str(g.profile.selectedShip)!="Destroyer" or not g.stat_cache_enabled:
  fail({"startup":g.startup_error,"stage":g.stage,"group":g.group_index,"ship":g.profile.get("selectedShip"),"cache":g.stat_cache_enabled});return
 print("ENV ",JSON.stringify({"engine":Engine.get_version_info().string,"adapter":RenderingServer.get_video_adapter_name(),"method":RenderingServer.get_current_rendering_method(),"resolution":str(root.size),"display":DisplayServer.get_name(),"cap":Engine.max_fps}))
 print("CHECKPOINT_INIT ",JSON.stringify({"save_sha256":save_hash,"stage":g.stage,"group":g.group_index,"state":g.state,"loop":g.profile.loop,"speed":g.speed,"resources":g.profile.resources,"ship":g.profile.selectedShip,"inventory_count":g.profile.hyperspace.inventory.drones.size(),"equipped_count":g.profile.hyperspace.inventory.equipped.size(),"loaded_chrono_login":g.login_chrono_particles,"save_enabled":g.save_enabled,"stat_cache_enabled":g.stat_cache_enabled,"flat_enabled":scene.ship_view.flat_compositor.enabled}))
 await measure(scene,g,save_hash)
 print("CHECKPOINT_END ",JSON.stringify({"source_save_unchanged":FileAccess.get_sha256("res://checkpoint20.json")==save_hash}))
 scene.queue_free();await process_frame;Engine.remove_meta("saved_perf");quit()
func measure(scene,g,save_hash):
 var frames=[];var cpu=[];var drawing=[];var calls=[];var primitives=[];var stages=[];var groups=[];var states=[];var enemies=[];var projectiles=[]
 await process_frame;await RenderingServer.frame_post_draw
 for i in 45:
  if g.stage>20:fail("measurement crossedstage20");return
  if i==15:meter.enabled=true;meter.times.clear()
  meter.draw_us=0
  var began=Time.get_ticks_usec();scene._process(1.0/60.0)
  await process_frame;await RenderingServer.frame_post_draw
  if i>=15:
   frames.append(Time.get_ticks_usec()-began);cpu.append(scene.last_process_us);drawing.append(meter.draw_us)
   calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME));primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
   stages.append(g.stage);groups.append(g.group_index);states.append(g.state);enemies.append(g.enemies.size());projectiles.append(g.projectiles.size())
 meter.enabled=false
 var inventory=[];views(root,inventory)
 print("ROW ",JSON.stringify({"frames_us":stats(frames),"host_process_us":stats(cpu),"battle_draw_us":stats(drawing),"timings":meter.times,"calls":stats(calls),"primitives":stats(primitives),"stages":stages,"groups":groups,"states":states,"enemies":enemies,"projectiles":projectiles,"views":inventory,"source_save_unchanged":FileAccess.get_sha256("res://checkpoint20.json")==save_hash,"logical_elapsed_seconds":45.0/60.0,"save_enabled":g.save_enabled,"ship_body_records":scene.ship_view.body_baker.records.size(),"flat_enabled":scene.ship_view.flat_compositor.enabled}))
 root.get_texture().get_image().save_png("res://.runtime/checkpoint20-scene.png")
