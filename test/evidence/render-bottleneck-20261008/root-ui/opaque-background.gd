extends SceneTree
class IsolatedUI extends "res://scripts/battlefield.gd":
 func create_battle_game(_persist:bool)->BattleGame:
  var g=super.create_battle_game(false);g.stat_cache_enabled=true;return g
var records:Array=[]
func _initialize()->void:call_deferred("run")
func measure(scene,label:String)->void:
 for ignored in 15:await process_frame
 var rows:Array=[]
 var previous=Time.get_ticks_usec()
 for ignored in 119:
  await process_frame
  var now=Time.get_ticks_usec()
  rows.append({"wall_ms":float(now-previous)/1000.0,"root_gpu":RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid()),"ship_gpu":RenderingServer.viewport_get_measured_render_time_gpu(scene.ship_view.viewport.get_viewport_rid()),"root_cpu":RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()),"ship_cpu":RenderingServer.viewport_get_measured_render_time_cpu(scene.ship_view.viewport.get_viewport_rid()),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)})
  previous=now
 var summary:Dictionary={}
 for key in rows[0]:
  var total=0.0
  for row in rows:total+=float(row[key])
  summary[key]=total/rows.size()
 records.append({"mode":label,"rows":rows,"mean":summary});print(label," ",JSON.stringify(summary)," scale=",scene.ship_view.viewport.scaling_3d_scale," tab=",scene.equipment_tabs.current_tab," window=",root.size)
 var file=FileAccess.open("/workspace/bug-qa/performance-20261008/opaque-background.json",FileAccess.WRITE);file.store_string(JSON.stringify(records));file.close()
func run()->void:
 if DisplayServer.get_name()=="headless":quit(2);return
 root.size=Vector2i(1180,812);DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0;OS.low_processor_usage_mode=false
 var scene=load("res://main.tscn").instantiate();scene.set_script(IsolatedUI);scene.automation_args=["--capture"];root.add_child(scene);scene.automation_args=[];scene.set_process(false)
 var g=scene.game;g.save_enabled=false;g.stat_cache_enabled=true;g.profile.onboarding.completed=true;g.profile.cleared=range(1,34);g.profile.highestLevel=34;g.rebuild_unlocks();g.pending_unlocks.clear();g.profile.resources={"1":1e9,"2":1e9}
 for i in 3:g.equip_slot("weapons",i,"laser");g.upgrade_slot("weapons",i,33)
 g.upgrade_slot("defence",0,33);g.equip_slot("defence",1,"shield");g.upgrade_slot("defence",1,33)
 g.start(34,false);g.state=BattleGame.State.COMBAT;g.spawn_group();g.paused=false;scene.refresh_structure();scene.refresh_navigation();scene._process(0.0);scene.set_process(false)
 RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true);RenderingServer.viewport_set_measure_render_time(scene.ship_view.viewport.get_viewport_rid(),true)
 print("FIXTURE cache=",g.stat_cache_enabled," source=43842f56 stage=",g.profile.highestLevel," enemies=",g.enemies.size()," frozen_process=true scale=",scene.ship_view.viewport.scaling_3d_scale," engine=",Engine.get_version_info().string)
 var original=scene.background_layer.material
 var shader=Shader.new();shader.code="shader_type canvas_item; render_mode unshaded, blend_disabled;"
 var opaque=ShaderMaterial.new();opaque.shader=shader
 await measure(scene,"baseline_1")
 await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("/workspace/bug-qa/performance-20261008/opaque-before.png")
 scene.background_layer.material=opaque;await measure(scene,"opaque_background_1")
 await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("/workspace/bug-qa/performance-20261008/opaque-after.png")
 scene.background_layer.material=original;await measure(scene,"baseline_2")
 scene.background_layer.material=opaque;await measure(scene,"opaque_background_2")
 print("DONE diagnostic only; hidden/frozen modes are not production optimizations or gameplay acceptance")
 quit()
