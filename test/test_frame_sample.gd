extends SceneTree
class Smoke extends "res://dev/diagnostics/frame_sample.gd".SampleScene:
 var test_focused=true
 func sampler_window_focused()->bool:return test_focused
 func show_qa_tools()->void:pass
 func show_chrono_login_report()->void:pass
var failures=0
func check(value:bool,message:String)->void:
 if value:print("PASS: ",message)
 else:
  failures+=1;printerr("FAIL: ",message)
func _initialize()->void:call_deferred("run")
func run()->void:
 var scene=load("res://main.tscn").instantiate()
 scene.set_script(Smoke)
 root.add_child(scene)
 scene.game.speed=1;scene.game.paused=false;scene.background_unfocused=false
 scene.equipment_panel.set_upgrade_amount(1)
 scene.set_process(false)
 check(not scene.sampling_inspector_state().visible,"Inspector metadata starts hidden")
 scene.equipment_panel.show_inspector()
 check(scene.sampling_inspector_state().visible and scene.sampling_inspector_state().expanded and scene.sampling_inspector_state().stats_visible,"Inspector metadata distinguishes visible expanded details")
 scene.equipment_panel.toggle_details()
 check(scene.sampling_inspector_state().visible and not scene.sampling_inspector_state().expanded and not scene.sampling_inspector_state().stats_visible,"Inspector metadata distinguishes collapsed contents")
 scene.equipment_panel.detail_frame.hide()
 # A visible non-modal QA window must not require closing an invisible "popup".
 var qa=Window.new();qa.name="QATools";qa.transient=true
 root.add_child(qa);qa.show()
 check(qa.visible and not qa.exclusive and not scene.blocked(),"Visible non-modal QA window does not block")
 qa.hide();qa.free()
 # Ordinary controls (including visible children of hidden ancestors) are not modals.
 var hidden_parent=Control.new();hidden_parent.hide();root.add_child(hidden_parent)
 var ordinary=Control.new();ordinary.name="QATools";hidden_parent.add_child(ordinary)
 check(ordinary.visible and not ordinary.is_visible_in_tree() and not scene.blocked(),"Hidden ancestor visibility cannot invent a modal blocker")
 hidden_parent.free()
 var modal=Window.new();modal.title="采样门禁测试";modal.transient=true;modal.exclusive=true
 scene.add_child(modal);modal.popup_centered(Vector2i(240,120))
 scene._process(0.0)
 check(scene.blocked() and scene.sample_label.text.contains("请关闭弹窗：采样门禁测试") and scene.warmup==0.0,"Actual modal blocks with its title")
 modal.hide();modal.free()
 scene.test_focused=false;scene._process(0.0)
 check(scene.blocked() and scene.sample_label.text.contains("请点击游戏窗口") and not scene.sample_label.text.contains("弹窗"),"Missing main-window focus names the actual action")
 scene.test_focused=true
 scene.background_unfocused=true;scene._process(0.0)
 check(scene.blocked() and scene.sample_label.text.contains("焦点"),"Application background guard remains")
 scene.background_unfocused=false
 scene.game.paused=true;scene._process(0.0)
 check(scene.blocked() and scene.game.paused and scene.sample_label.text.contains("游戏已暂停"),"Paused guard explains without resuming game")
 scene.game.paused=false
 scene.warmup=0.7;scene._process(0.0)
 check(not scene.blocked() and scene.capture_started==0 and scene.sample_label.text.contains("暖机") and scene.sample_label.text.contains("1.3 秒"),"Ready state shows remaining two-second warmup")
 # Gate checks do not advance the simulation at a disallowed speed/amount.
 scene.game.speed=2
 if not scene.blocked() or scene.game.speed!=2:
  printerr("FAIL: non-1x sampling gate changed player speed");quit(1);return
 scene.update_waiting_status(scene.blocking_reasons())
 check(scene.sample_label.text.contains("当前为 2.0 倍速") and not scene.sample_label.text.contains("弹窗"),"Speed blocker shows current value")
 scene.game.speed=1
 scene.equipment_panel.set_upgrade_amount(10)
 if not scene.blocked() or scene.equipment_panel.upgrade_amount!=10:
  printerr("FAIL: non-+1 sampling gate changed selection");quit(1);return
 scene.update_waiting_status(scene.blocking_reasons())
 check(scene.sample_label.text.contains("当前升级数量为 10"),"Upgrade-amount blocker shows current selection")
 scene.equipment_panel.set_upgrade_amount(1)
 scene.capture_started=Time.get_ticks_usec();scene.game.measure=true
 scene.rows=[{"discarded":true}];scene.previous={"discarded":true}
 scene.equipment_panel.set_upgrade_amount(10)
 scene._process(0.0)
 if scene.capture_started!=0 or scene.game.measure or not scene.rows.is_empty() or not scene.armed:
  printerr("FAIL: capture did not discard invalid conditions");quit(1);return
 check(scene.sample_label.text.contains("采样已中止") and scene.sample_label.text.contains("当前升级数量为 10"),"Interrupted sample displays its precise cause")
 scene.equipment_panel.set_upgrade_amount(1)
 scene.duration=2.0
 scene.warmup=0.0
 scene.set_process(true)
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
 check(scene.metadata.window_state_at_start.main.present and scene.metadata.window_state_at_finish.main.present and scene.metadata.window_state_at_start.has("screen_refresh_hz"),"Report records own-window state and display refresh metadata")
 check(scene.rows.all(func(row):return row.has("equipment_inspector") and not row.equipment_inspector.visible) and scene.metadata.window_state_at_start.has("equipment_inspector") and scene.metadata.window_state_at_finish.has("equipment_inspector"),"Inspector state is recorded per frame and at capture boundaries")
 check(scene.metadata.started_at==scene.metadata.capture_started_at and scene.metadata.has("app_started_at") and Time.get_unix_time_from_datetime_string(scene.metadata.started_at)>=Time.get_unix_time_from_datetime_string(scene.metadata.app_started_at),"Capture timestamps exclude startup waiting and preserve app start")
 print("PASS automatic sampler rows=",scene.rows.size()," real ticks=",sums," speed=",scene.game.speed," max_fps=",Engine.max_fps)
 scene.set_process(false)
 var retry=InputEventKey.new();retry.keycode=KEY_F7;retry.pressed=true
 scene._unhandled_input(retry)
 check(scene.armed and not scene.completed and scene.rows.is_empty() and scene.sample_label.text.contains("暖机"),"F7 restarts into accurate warmup state")
 scene.metadata.started_at="stale";scene.metadata.capture_started_at="stale"
 var app_started=scene.metadata.app_started_at
 scene.warmup=2.0;scene._process(0.0)
 check(scene.capture_started>0 and scene.metadata.started_at==scene.metadata.capture_started_at and scene.metadata.started_at!="stale" and scene.metadata.app_started_at==app_started,"F7 capture refreshes timestamps without changing app start")
 scene.capture_started=0;scene.game.measure=false
 scene.game.launch_provider=Callable();scene.game.target_provider=Callable()
 scene.queue_free();await process_frame;await process_frame
 quit(1 if failures else 0)
