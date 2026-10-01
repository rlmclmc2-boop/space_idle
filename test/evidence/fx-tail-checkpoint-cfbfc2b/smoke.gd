extends SceneTree
var diag=preload("res://fx_tail_meter.gd").new()
class SmokeScene extends "res://live_fx_sample.gd".LiveScene:
 func blocking_reasons()->PackedStringArray:return PackedStringArray()
 func show_qa_tools()->void:pass
 func show_chrono_login_report()->void:pass
func _initialize()->void:
 diag.enabled=false;Engine.set_meta("fx_tail",diag);call_deferred("run")
func run()->void:
 var scene=load("res://main.tscn").instantiate();scene.set_script(SmokeScene)
 root.add_child(scene);current_scene=scene;scene.set_process(false)
 scene.game.paused=false;scene.game.speed=1;scene.game.stat_cache_enabled=true
 scene.select_system(0);scene.equipment_panel.set_upgrade_amount(1)
 scene.warmup=2.0;scene.duration=999.0
 for frame in 6:
  scene._process(1.0/60.0)
  scene.previous.smoke_frame=frame
  await RenderingServer.frame_post_draw
  diag.stages.sentinel={"frame":frame}
 var ok=scene.rows.size()==5 and not diag.cpu_available
 for row in scene.rows:ok=ok and int(row.smoke_frame)==int(row.fx_detail.stages.sentinel.frame)
 ok=ok and scene.metadata.fx_build.stat_cache_enabled and scene.metadata.fx_source.has("original_sha256")
 scene.finish_capture();diag.enabled=false
 print("LIVE FX SMOKE matched_rows=",scene.rows.size()," wall_only=",not diag.cpu_available," pass=",ok)
 scene.game.launch_provider=Callable();scene.game.target_provider=Callable()
 scene.queue_free();await process_frame;await process_frame
 Engine.remove_meta("fx_tail");quit(0 if ok else 1)
func _finalize()->void:
 if Engine.has_meta("fx_tail"):Engine.remove_meta("fx_tail")
