extends SceneTree
class Smoke extends "res://dev/diagnostics/frame_sample.gd".SampleScene:
 func show_qa_tools()->void:pass
 func show_chrono_login_report()->void:pass
func _initialize()->void:call_deferred("run")
func run()->void:
 var scene=load("res://main.tscn").instantiate()
 scene.set_script(Smoke)
 root.add_child(scene)
 scene.game.speed=1;scene.game.paused=false;scene.background_unfocused=false
 scene.equipment_panel.set_upgrade_amount(1)
 scene.duration=2.0
 scene.warmup=0.0
 var started=Time.get_ticks_msec()
 while not scene.completed and Time.get_ticks_msec()-started<10000:await process_frame
 if not scene.completed or scene.rows.size()<2:
  printerr("FAIL: sampler did not automatically finish");quit(1);return
 if scene.game.speed!=1 or Engine.max_fps!=60:
  printerr("FAIL: sampler changed speed or cap");quit(1);return
 var sums=0
 for row in scene.rows:
  sums+=row.combat.get("tick_calls",0)
  if row.main_us<=0 or row.frame_us<=0 or not row.condition_valid:
   printerr("FAIL: invalid timing row");quit(1);return
 if sums<1:
  printerr("FAIL: no real combat steps measured");quit(1);return
 print("PASS automatic sampler rows=",scene.rows.size()," real ticks=",sums," speed=",scene.game.speed," max_fps=",Engine.max_fps)
 scene.game.launch_provider=Callable();scene.game.target_provider=Callable()
 scene.queue_free();await process_frame;await process_frame
 quit()
